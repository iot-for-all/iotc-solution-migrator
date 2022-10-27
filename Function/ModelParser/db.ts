import { Context } from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { Connection, Request } from "tedious";

export async function connect(context: Context) {
    const cred = new DefaultAzureCredential({
        managedIdentityClientId: process.env['IDENTITY_CLIENT_ID'] || undefined
    });
    const token = (await cred.getToken("https://database.windows.net/.default")).token;
    const config = {
        server: process.env['SQL_ENDPOINT'],
        authentication: {
            type: 'azure-active-directory-access-token',
            options: {
                token
            }
        },
        options: {
            database: process.env["SQLDatabase"],
            encrypt: true,
            port: 1433
        }
    };
    const connection = new Connection(config);
    return new Promise<Connection>((resolve, reject) => {
        connection.on('connect', (err) => {
            if (err) {
                context.log(`Error connecting: ${err}`);
                reject(err);
            }
            else {
                context.log('Successfully connected to db');
                resolve(connection);
            }
        })
        connection.connect();
    });

}


export async function queryDatabase(context: Context, connection: Connection, script: string | null): Promise<string> {
    if (script === null) {
        return;
    }
    let ret = '';
    return new Promise<string>((resolve, reject) => {
        // Read all rows from table
        const request = new Request(script,
            (err, rowCount) => {
                if (err) {
                    context.log(err);
                    if (err.message.startsWith('There is already an object')) {
                        return resolve(err.message);
                    }
                    return reject(err);
                } else {
                    resolve(ret);
                }
            }
        );
        request.on('error', (err) => {
            if (err.message.startsWith('There is already an object')) {
                return resolve(err.message);
            }
            return reject(err);
        })
        request.on('columnMetadata', (columns) => {
            ret += columns.map(c => c.colName).join(',') + '\n';
        });

        request.on("row", columns => {
            columns.forEach((column, idx) => {
                ret += `${column.value}`
                if (idx < (columns.length - 1)) {
                    ret += ','
                }
                context.log(column.value);
            });
            ret += '\n';
        });

        connection.execSql(request);
    });
}