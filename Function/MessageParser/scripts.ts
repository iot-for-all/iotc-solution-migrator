import * as fs from 'fs/promises'
import * as path from 'path'
import { modelToBindingName } from './utils';

async function generateConfigFile(templates: string[]) {
    const filePath = path.join(__dirname, '../..', 'MessageParser', 'function.json');
    const configStr = (await fs.readFile(filePath)).toString();
    const config = JSON.parse(configStr);
    config.bindings = [...config.bindings, ...templates.map(template => ({
        name: modelToBindingName(template),
        type: 'sql',
        direction: "out",
        commandText: `dbo.${modelToBindingName(template)}`,
        connectionStringSetting: 'SqlConnectionString'
    }))];
    config.bindings.find(binding => binding.type === 'eventHubTrigger').eventHubName = process.env['EVENTHUB_NAME']
    await fs.writeFile(filePath, JSON.stringify(config, null, 2));

}

generateConfigFile(JSON.parse(process.env['TEMPLATES']));