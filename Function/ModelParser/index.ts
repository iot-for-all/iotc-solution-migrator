import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { DTDLCapability, DTDLComponent, DTDLModel, DTDLSchema, SQLColumn, SQLConfig } from './types';
import { modelToBindingName, normalizeColumnName, writeTable } from './utils';
import { Connection } from 'tedious';
import { queryDatabase, connect } from './db';

let sqlConnection: Connection = null;

const HttpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    if (!sqlConnection) {
        try {
            sqlConnection = await connect(context);
            context.log(`Connected to db`);
        }
        catch (ex) {
            context.res = {
                status: 500,
                body: `Error connecting to db: ${JSON.stringify(ex.message)}`
            }
            return;
        }
    }
    if (req.body) {
        try {
            const model = req.body.capabilityModel;
            const config = parse(context, model);
            const tableName = modelToBindingName(model['@id']);
            const scriptCreate = scriptCreateTable(config, tableName);
            const scriptSPTelemetry = scriptCreateSelectProc(config.telemetry, tableName);
            const scriptSPProperties = scriptCreateSelectProc(config.properties, `${tableName}_props`);

            let body = await queryDatabase(context, sqlConnection, scriptCreate);
            body += `\n${await queryDatabase(context, sqlConnection, scriptSPTelemetry)}`;
            body += `\n${await queryDatabase(context, sqlConnection, scriptSPProperties)}`;

            await writeTable(context, `${tableName}.json`, JSON.stringify(config.telemetry.map(c => c.name)));
            await writeTable(context, `${tableName}_props.json`, JSON.stringify(config.properties.map(c => c.name)));
            context.res = {
                status: 201,
                body
            };
        }
        catch (err) {
            if (err.message.startsWith('There is already an object')) {
                context.res = {
                    status: 409,
                    body: err.message
                }
            } else {
                context.res = {
                    status: 500,
                    body: err.message
                }
            }
            return;
        }
    }
    else {
        context.res = {
            status: 400,
            body: "Please pass a name on the query string or in the request body"
        };
    }
};


function parse(context: Context, modelData: DTDLModel): SQLConfig {
    let res = { telemetry: [], properties: [] };
    for (const capability of modelData.contents) {
        if (capability['@type'] === 'Component') {
            // component
            const component = parseComponent(context, capability as DTDLComponent);
            res = {
                telemetry: [...res.telemetry, ...component.telemetry],
                properties: [...res.properties, ...component.properties]
            };
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability);
            res = {
                telemetry: [...res.telemetry, ...parsed.telemetry],
                properties: [...res.properties, ...parsed.properties]
            };
        }
    }
    return res;
}

function parseComponent(context: Context, component: DTDLComponent): SQLConfig {
    let res = {
        telemetry: [],
        properties: []
    }
    for (const capability of component['schema'].contents) {
        if (capability['@type'] === 'Component') {
            const component = parseComponent(context, capability as DTDLComponent);
            res = {
                telemetry: [...res.telemetry, ...component.telemetry],
                properties: [...res.properties, ...component.properties]
            }
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability, component);
            res = {
                telemetry: [...res.telemetry, ...parsed.telemetry],
                properties: [...res.properties, ...parsed.properties]
            }
        }
    }
    return res;
}

function parseSchema(schema: DTDLSchema, capabilityName: string, capabilityDisplayName: string, component?: DTDLComponent): SQLColumn[] {
    const name = component ? `${component.name}.${capabilityName}` : capabilityName;
    const displayName = component ? `${component.displayName || component.displayName['en']}.${capabilityDisplayName}` : (capabilityDisplayName); // fixed for now
    switch (schema) {
        case 'integer':
            return [{
                name,
                displayName,
                dataType: 'int'
            }];
        case 'double':
            return [{
                name,
                displayName,
                dataType: 'float'
            }];
        case 'string':
            return [{
                name,
                displayName,
                dataType: 'nvarchar(max)'
            }];
        case 'vector':
            return [{
                name: `${name}.x`,
                displayName: `${displayName}.X`,
                dataType: 'float'
            }, {
                name: `${name}.y`,
                displayName: `${displayName}.Y`,
                dataType: 'float'
            },
            {
                name: `${name}.z`,
                displayName: `${displayName}.Z`,
                dataType: 'float'
            }];
        case 'geopoint':
            return [{
                name: `${name}.lat`,
                displayName: `${displayName}.Latitude`,
                dataType: 'float'
            }, {
                name: `${name}.lon`,
                displayName: `${displayName}.Longitude`,
                dataType: 'float'
            },
            {
                name: `${name}.alt`,
                displayName: `${displayName}.Altitude`,
                dataType: 'float'
            }];
        default:
            return [{
                name,
                displayName,
                dataType: 'nvarchar(max)'
            }];
    }
}

function parseCapability(context: Context, capability: DTDLCapability, component?: DTDLComponent): SQLConfig {
    const empty = {
        telemetry: [],
        properties: []
    }
    let columns: SQLColumn[];
    const capabilityDisplayName = capability.displayName['en'] ? capability.displayName['en'] : capability.displayName;

    if (capability['@type'] === 'Command') {
        return empty;
    }

    // skip desired properties, just use reported.
    if ((capability['@type'] === 'Property' || capability['@type'].includes('Property')) && capability['writable']) {
        return empty;
    }

    if (typeof capability['schema'] === 'object' && capability['schema']['@type'] === 'object') {
        columns = capability['schema']['fields'].flatMap(field => {
            const fieldDisplayName = field.displayName['en'] ? field.displayName['en'] : field.displayName;
            return parseSchema(field.schema, `${capability.name}.${field.name}`, `${capabilityDisplayName}.${fieldDisplayName}`);
        })
    }
    else {
        columns = parseSchema(capability['schema'], capability.name, capabilityDisplayName, component);
    }

    if (capability['@type'] === 'Property') {
        return {
            telemetry: [],
            properties: columns
        }
    }
    else {
        return {
            telemetry: columns,
            properties: []
        }
    }
}

function scriptCreateTable(config: SQLConfig, tableName: string) {
    let scripts = `create table dbo.${tableName}(\ndeviceId NVARCHAR(50) NOT NULL,\nts DATETIME NOT NULL,\n`;
    for (const column of config.telemetry) {
        scripts += `${normalizeColumnName(column.name)} ${column.dataType},\n`
    }
    scripts += `primary key (deviceId,ts)\n)\n`;
    scripts += `create table dbo.${tableName}_props(\ndeviceId NVARCHAR(50) NOT NULL,\nts DATETIME NOT NULL,\nversion int,\n`;
    for (const column of config.properties) {
        scripts += `${normalizeColumnName(column.name)} ${column.dataType},\n`
    }
    scripts += `primary key (deviceId,ts)\n)`;
    return scripts;
}

function scriptCreateSelectProc(columns: SQLColumn[], tableName: string) {
    if (columns.length === 0) {
        return null;
    }
    let scripts = `create or alter procedure select_${tableName} as
    begin\n select deviceId as DeviceId, ts as EventTimestamp, `;
    columns.forEach((column, idx) => {
        scripts += `${normalizeColumnName(column.name)} as ${normalizeColumnName(column.displayName)}${(idx < (columns.length - 1)) ? ',' : ''} `
    });
    scripts += `\n from dbo.${tableName}\nend\n`;
    return scripts;
}



export default HttpTrigger;
