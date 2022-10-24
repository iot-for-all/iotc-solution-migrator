import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { DTDLCapability, DTDLComponent, DTDLDisplayName, DTDLModel, DTDLSchema, SQLColumn, SQLDataType } from './types';
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
                body: `Error connecting to db: ${JSON.stringify(ex)}`
            }
            return;
        }
    }
    if (req.body) {
        try {
            const model = req.body.capabilityModel;
            const columns = parse(context, model);
            const tableName = modelToBindingName(model['@id']);
            const scriptCreate = scriptCreateTable(columns, tableName);
            const scriptSP = scriptCreateSelectProc(columns, tableName);

            let body = await queryDatabase(context, sqlConnection, scriptCreate);
            body += `\n${await queryDatabase(context, sqlConnection, scriptSP)}`;
            await writeTable(context, `${tableName}.json`, JSON.stringify(columns.map(c => c.name)));
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


function parse(context: Context, modelData: DTDLModel) {
    let res: SQLColumn[] = [];
    for (const capability of modelData.contents) {
        if (capability['@type'] === 'Component') {
            // component
            res = [...res, ...parseComponent(context, capability as DTDLComponent)]
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability);
            res = [...res, ...parsed]
        }
    }
    return res;
}

function parseComponent(context: Context, component: DTDLComponent): SQLColumn[] {
    let res: SQLColumn[] = [];
    for (const capability of component['schema'].contents) {
        if (capability['@type'] === 'Component') {
            res = [...res, ...parseComponent(context, capability as DTDLComponent)];
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability, component);
            res = [...res, ...parsed]
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
                name: `${name}.X`,
                displayName: `${displayName}.X`,
                dataType: 'float'
            }, {
                name: `${name}.Y`,
                displayName: `${displayName}.Y`,
                dataType: 'float'
            },
            {
                name: `${name}.Z`,
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

function parseCapability(context: Context, capability: DTDLCapability, component?: DTDLComponent): SQLColumn[] {
    const capabilityDisplayName = capability.displayName['en'] ? capability.displayName['en'] : capability.displayName;

    if (capability['@type'] === 'Command') {
        return [];
    }
    if ((capability['@type'] === 'Property' || capability['@type'].includes('Property')) && capability['writable']) {
        return [];
    }

    if (typeof capability['schema'] === 'object' && capability['schema']['@type'] === 'object') {
        return capability['schema']['fields'].flatMap(field => {
            const fieldDisplayName = field.displayName['en'] ? field.displayName['en'] : field.displayName;
            return parseSchema(field.schema, `${capability.name}.${field.name}`, `${capabilityDisplayName}.${fieldDisplayName}`);
        })
    }

    return parseSchema(capability['schema'], capability.name, capabilityDisplayName, component);
}

function scriptCreateTable(columns: SQLColumn[], tableName: string) {
    let script = `create table dbo.${tableName}(\ndeviceId NVARCHAR(50) NOT NULL,\nts DATETIME NOT NULL,\n`;
    for (const column of columns) {
        script += `${normalizeColumnName(column.name)} ${column.dataType},\n`
    }
    script += `primary key (deviceId,ts)\n)`;
    return script;
}

function scriptCreateSelectProc(columns: SQLColumn[], tableName: string) {
    let script = `create or alter procedure select_${tableName} as
    begin\n select deviceId as DeviceId, ts as EventTimestamp, `;
    columns.forEach((column, idx) => {
        script += `${normalizeColumnName(column.name)} as ${normalizeColumnName(column.displayName)}${(idx < (columns.length - 1)) ? ',' : ''} `
    });
    script += `\n from dbo.${tableName}\nend`;
    return script;
}



export default HttpTrigger;
