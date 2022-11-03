import * as fs from 'fs/promises'
import * as path from 'path'

async function generateConfigFile(tables: string[]) {
    const filePath = path.join(__dirname, '../..', 'MessageParser', 'function.json');
    console.log(filePath);
    const configStr = (await fs.readFile(filePath)).toString();
    console.log(configStr);
    const config = JSON.parse(configStr);
    config.bindings = [...config.bindings, ...tables.map(table => ({
        name: table,
        type: 'sql',
        direction: "out",
        commandText: `dbo.${table}`,
        connectionStringSetting: 'SqlConnectionString'
    }))];
    config.bindings.find(binding => binding.type === 'eventHubTrigger').eventHubName = process.env['EVENTHUB_NAME']
    console.log(`Adding bindings: ${JSON.stringify(config.bindings)}`);
    await fs.writeFile(filePath, JSON.stringify(config, null, 2));

}

generateConfigFile(JSON.parse(process.env['TABLES']));