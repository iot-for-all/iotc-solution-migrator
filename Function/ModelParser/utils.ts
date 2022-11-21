import * as fs from 'fs/promises'
import * as path from 'path';
import { ShareServiceClient, ShareClient } from '@azure/storage-file-share';
import { Context } from '@azure/functions';

const FILE_CSTRING = process.env['WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'];
const SHARE_NAME = 'tables';
const SHARE_ALREADY_EXISTS = 'ShareAlreadyExists';

let fileClient: ShareClient;

export function modelToBindingName(modelId: string) {
    const [id, version] = modelId.split(';');
    const segments = id.split('dtmi:')[1];
    return `${segments.toLowerCase().replace(/:([\S])/, (_, c) => { return c.toUpperCase() })}${version}`;
}

async function _initFileClient(context: Context) {
    const shareServiceClient = ShareServiceClient.fromConnectionString(FILE_CSTRING);
    context.log('ShareClient initialized');
    const shareClient = shareServiceClient.getShareClient(SHARE_NAME);
    const resp = await shareClient.createIfNotExists();
    if (resp.succeeded || resp.errorCode === SHARE_ALREADY_EXISTS) {
        fileClient = shareClient;
    }
}

export async function writeTable(context: Context, name: string, content: string) {
    if (!fileClient) {
        await _initFileClient(context);
    }
    const tableClient = fileClient.rootDirectoryClient.getFileClient(name);
    await tableClient.create(content.length);
    await tableClient.uploadRange(content, 0, content.length);
}

export function normalizeColumnName(columnName: string) {
    columnName = columnName.replace(' ', '_');
    if (columnName.indexOf('.') >= 0) {
        return `[${columnName}]`;
    }
    return columnName;
}

export function getCapabilityName(fullName: string) {
    const segments = fullName.split('.');
    return segments[segments.length - 1];
}