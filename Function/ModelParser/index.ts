import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { DTDLCapability, DTDLComponent, DTDLModel, DTDLSchema, SQLColumn, SQLConfig, SQLDataType, SQLItem } from './types';
import { modelToBindingName, normalizeColumnName, writeTable } from './utils';
import { Connection } from 'tedious';
import { queryDatabase, connect } from './db';
import { createComponentDashboard, createFolder } from './grafana';

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
        let body = '';
        for (const modelDefinition of req.body) {
            try {
                const model = modelDefinition.capabilityModel;
                const config = parse(context, model);
                const tableName = modelToBindingName(model['@id']);
                const scriptCreate = scriptCreateTable(config, tableName);
                // const scriptSPTelemetry = scriptCreateSelectProc(config.telemetry, tableName);
                // const scriptSPProperties = scriptCreateSelectProc(config.properties, `${tableName}_props`);

                body += await queryDatabase(context, sqlConnection, scriptCreate);
                // body += await queryDatabase(context, sqlConnection, scriptSPTelemetry);
                // body += await queryDatabase(context, sqlConnection, scriptSPProperties);

                await writeTable(context, `${tableName}.json`, JSON.stringify(Object.keys(config).flatMap(c => config[c].telemetry.map(c => c.name))));
                body += `Created table ${tableName} for model ${model['@id']}\n`
                await writeTable(context, `${tableName}_props.json`, JSON.stringify(Object.keys(config).flatMap(c => config[c].properties.map(c => c.name))));
                body += `Created table ${tableName}_props for model ${model['@id']}\n`

                const folderUid = await createFolder(model.displayName || model.displayName['en']);
                body += JSON.stringify(config);
                for (const component in config) {
                    await createComponentDashboard({
                        componentDisplayName: config[component].displayName,
                        componentName: component,
                        folderUid,
                        tableName,
                        columns: config[component]
                    })
                }

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
                        body: `${err.message}\n${err.stack}`
                    }
                }
                return;
            }
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
    let res: SQLConfig = {};
    for (const capability of modelData.contents) {
        if (capability['@type'] === 'Component') {
            // component
            const { name, ...component } = parseComponent(context, capability as DTDLComponent);
            res[name] = component;
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability);
            res['default'] = {
                ...res['default'],
                displayName: 'Default',
                telemetry: [...(res['default'] ? res['default'].telemetry : []), ...parsed.telemetry],
                properties: [...(res['default'] ? res['default'].properties : []), ...parsed.properties]
            };
        }
    }
    return res;
}

function parseComponent(context: Context, component: DTDLComponent): SQLItem {
    let res: SQLItem = {
        name: component.name,
        displayName: component.displayName || component.displayName['en'],
        telemetry: [],
        properties: []
    }
    for (const capability of component['schema'].contents) {
        if (capability['@type'] === 'Component') {
            const { name, ...component } = parseComponent(context, capability as DTDLComponent);
            res = {
                ...res,
                telemetry: [...res.telemetry, ...component.telemetry],
                properties: [...res.properties, ...component.properties]
            }
        }
        else {
            const parsed = parseCapability(context, capability as DTDLCapability, component);
            res = {
                ...res,
                telemetry: [...res.telemetry, ...parsed.telemetry],
                properties: [...res.properties, ...parsed.properties]
            }
        }
    }
    return res;
}

function getSqlDataType(schemaType: string): SQLDataType {
    switch (schemaType) {
        case 'integer':
            return 'int'
        case 'double':
            return 'float';
        case 'vector':
            return 'float';
        case 'geopoint':
            return 'float';
        default:
            return 'nvarchar(max)'
    }
}

function parseSchema(schema: DTDLSchema, capabilityName: string, capabilityDisplayName: string, component?: DTDLComponent): SQLColumn[] {
    const name = component ? `${component.name}.${capabilityName}` : capabilityName;
    // const displayName = component ? `${component.displayName || component.displayName['en']}.${capabilityDisplayName}` : (capabilityDisplayName); // fixed for now
    const displayName = capabilityDisplayName; // fixed for now
    if (schema['@type']) {
        switch (schema['@type'].toLowerCase()) {
            case 'object':
                return parseObjectSchema(schema, name, displayName);
        }
    }
    else {
        const dataType = getSqlDataType(schema as string);
        switch (schema) {
            case 'vector':
                return [{
                    name: `${name}.x`,
                    displayName: `${displayName}.X`,
                    dataType,
                    parentName: name,
                    parentDisplayName: displayName
                }, {
                    name: `${name}.y`,
                    displayName: `${displayName}.Y`,
                    dataType,
                    parentName: name,
                    parentDisplayName: displayName
                },
                {
                    name: `${name}.z`,
                    displayName: `${displayName}.Z`,
                    dataType,
                    parentName: name,
                    parentDisplayName: displayName
                }];
            case 'geopoint':
                return [{
                    name: `${name}.lat`,
                    displayName: `${displayName}.Latitude`,
                    dataType,
                    isLocation: true,
                    parentName: name,
                    parentDisplayName: displayName
                }, {
                    name: `${name}.lon`,
                    displayName: `${displayName}.Longitude`,
                    isLocation: true,
                    dataType,
                    parentName: name,
                    parentDisplayName: displayName
                },
                {
                    name: `${name}.alt`,
                    displayName: `${displayName}.Altitude`,
                    isLocation: true,
                    dataType,
                    parentName: name,
                    parentDisplayName: displayName
                }];
            default:
                return [{
                    name,
                    displayName,
                    dataType
                }];
        }
    }

}

function parseObjectSchema(schema: DTDLSchema, name: string, displayName: string, component?: DTDLComponent): SQLColumn[] {
    return schema['fields'].map((field) => ({
        displayName: `${displayName} ${field.displayName}`,
        name: `${name}.${field.name}`,
        dataType: getSqlDataType(field.schema)
    }));
}

function parseCapability(context: Context, capability: DTDLCapability, component?: DTDLComponent): SQLItem {
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

    if (capability['@type'] === 'Property' || capability['@type'].includes('Property')) {
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
    for (const component in config) {
        for (const column of config[component].telemetry) {
            scripts += `${normalizeColumnName(column.name)} ${column.dataType},\n`
        }
    }
    scripts += `primary key (deviceId,ts)\n)\n`;
    scripts += `create table dbo.${tableName}_props(\ndeviceId NVARCHAR(50) NOT NULL,\nts DATETIME NOT NULL,\nversion int,\n`;
    for (const component in config) {
        for (const column of config[component].properties) {
            scripts += `${normalizeColumnName(column.name)} ${column.dataType},\n`
        }
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
