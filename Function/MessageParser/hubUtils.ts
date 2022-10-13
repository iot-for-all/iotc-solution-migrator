import { Context } from '@azure/functions';
import { Registry, Twin } from 'azure-iothub';

const registry = Registry.fromConnectionString(process.env['IoTHubOwnerCS']);


export async function getTwin(context: Context, deviceId: string): Promise<Twin> {
    if (!registry) {
        context.log('IoTHub registry connection failed');
    }
    const twinResponse = await registry.getTwin(deviceId);
    return twinResponse.responseBody;
}

export async function setTwinTag(context: Context, twin: Twin, key: string, value: string) {
    await twin.update({
        tags: {
            [key]: value
        }
    })
}