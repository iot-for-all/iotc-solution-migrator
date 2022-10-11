import * as fs from 'fs/promises'
import * as path from 'path';
import { ShareServiceClient } from '@azure/storage-file-share';
import { DefaultAzureCredential } from '@azure/identity';

const FILE_CSTRING = process.env['WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'];

export function modelToBindingName(modelId: string) {
    const [id, version] = modelId.split(';');
    const segments = id.split('dtmi:')[1];
    return `${segments.toLowerCase().replace(/:([\S])/, (_, c) => { return c.toUpperCase() })}${version}`;
}

export async function readTables() {
    const tables = {};
    const content = await fs.readdir(path.join(__dirname, 'tables'));
    for (const file of content) {
        tables[file.split('.json')[0]] = JSON.parse(await fs.readFile(path.join(__dirname, 'tables', file), 'utf8'));
    }
    return tables;
}

export async function loadFiles() {
    let tables = {};
    const shareClient = ShareServiceClient.fromConnectionString(FILE_CSTRING);
    const directoryClient = shareClient.getShareClient('tables').rootDirectoryClient;

    let dirIter = directoryClient.listFilesAndDirectories();
    for await (const item of dirIter) {
        const fileClient = directoryClient.getFileClient(item.name);
        tables[item.name.split('.json')[0]] = JSON.parse((await fileClient.downloadToBuffer()).toString());
    }
    return tables;
}