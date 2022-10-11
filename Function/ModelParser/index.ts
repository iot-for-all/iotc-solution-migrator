import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { DTDLCapability, DTDLComponent, DTDLModel, SQLColumn, SQLDataType } from './types';
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
            res = [...res,
            ...(parsed ? [parsed] : [])
            ]
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
            res = [...res,
            ...(parsed ? [parsed] : [])
            ]
        }
    }
    return res;
}

function parseCapability(context: Context, capability: DTDLCapability, component?: DTDLComponent): SQLColumn {
    if (capability['@type'] === 'Command') {
        return undefined;
    }
    if ((capability['@type'] === 'Property' || capability['@type'].includes('Property')) && capability['writable']) {
        return undefined;
    }
    let dataType: SQLDataType;
    switch (capability['schema']) {
        case 'integer':
            dataType = 'int'
            break;
        case 'double':
            dataType = 'float'
            break;
        case 'string':
            dataType = 'nvarchar(max)'
            break;
        default:
            dataType = 'nvarchar(max)'
            break;
    }
    return {
        name: component ? `${component.name}.${capability.name}` : capability.name,
        displayName: component ? `${component.displayName || component.displayName['en']}.${capability.displayName || capability.displayName['en']}` : (capability.displayName || capability.displayName['en']), // fixed for now
        dataType
    };
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
