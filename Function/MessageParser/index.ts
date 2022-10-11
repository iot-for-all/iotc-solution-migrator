import { AzureFunction, Context } from "@azure/functions"
import { COMPONENT_KEY, DEVICE_ID_KEY, MODEL_KEY, TIMESTAMP_KEY } from "./constants";
import { loadFiles, modelToBindingName } from "./utils";

let tables;

const IoTHubTrigger: AzureFunction = async function (context: Context, IoTHubMessages: any[]): Promise<void> {
    // context.log(`Eventhub trigger function called for message array: ${IoTHubMessages}`);
    if (!tables) {
        tables = await loadFiles();
        context.log(JSON.stringify(tables));
    }
    IoTHubMessages.forEach((message, index) => {
        const { [COMPONENT_KEY]: messageComponent, [MODEL_KEY]: modelId, [DEVICE_ID_KEY]: deviceId, [TIMESTAMP_KEY]: timestamp } = context.bindingData.systemPropertiesArray[index];
        context.log(`Model: ${modelId}, Component:${messageComponent}, Message:${message}`);
        message = JSON.parse(message);
        const row = {
            deviceId,
            ts: timestamp,
            ...(modelId ? tables[modelToBindingName(modelId)].reduce((obj, capability) => {
                if (capability.indexOf('.') > 0) { // a component
                    const [componentName, capabilityName] = capability.split('.');
                    if (componentName === messageComponent && message[capabilityName]) {
                        obj[capability] = message[capabilityName];
                    }
                    else {
                        obj[capability] = null
                    }
                }
                else {
                    if (message[capability]) {
                        obj[capability] = message[capability];
                    }
                    else {
                        obj[capability] = null
                    }
                }
                return obj;
            }, {})
                : message
            )
        }
        context.log(`Writing: ${JSON.stringify(row)}`);
        context.bindings[modelToBindingName(modelId)] = row;
    });
};

export default IoTHubTrigger;
