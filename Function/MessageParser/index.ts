import { AzureFunction, Context } from "@azure/functions"
import { COMPONENT_KEY, DEVICE_ID_KEY, MessageSources, MESSAGE_SOURCE_KEY, MODEL_KEY, OPERATION_TYPE, TIMESTAMP_KEY, UNSET_MODELID_TAG } from "./constants";
import { getTwin, setTwinTag } from "./hubUtils";
import { loadFiles, modelToBindingName } from "./utils";

let tables;
let modelsAssociations = {}; //in memory models associations since enrichments take times to propagate

const IoTHubTrigger: AzureFunction = async function (context: Context, IoTHubMessages: any[]): Promise<void> {
    if (!tables) {
        tables = await loadFiles();
    }
    IoTHubMessages.forEach(async (message, index) => {
        let { [COMPONENT_KEY]: messageComponent, [MODEL_KEY]: modelId, [DEVICE_ID_KEY]: deviceId, [TIMESTAMP_KEY]: timestamp, [MESSAGE_SOURCE_KEY]: messageSource } = context.bindingData.systemPropertiesArray[index];
        const { [OPERATION_TYPE]: opType } = context.bindingData.propertiesArray[index];
        context.log(`MessageSource: ${messageSource}, OperationType: ${opType}`);

        message = JSON.parse(message);

        let row = {
            deviceId,
            ts: timestamp
        };
        if (messageSource === MessageSources.TELEMETRY) {
            row = {
                ...row, ...(modelId ? tables[modelToBindingName(modelId)].reduce((obj, capability) => {
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
            context.bindings[modelToBindingName(modelId)] = row;
            return;
        }
        else if (messageSource === MessageSources.TWIN_CHANGE) {
            context.log(`Received twin update: ${JSON.stringify(message)}. Properties: ${JSON.stringify(context.bindingData.propertiesArray[index])}`);

            if (!message.properties || !message.properties.reported) {
                return;
            }
            modelId = context.bindingData.propertiesArray[index]['modelId'];
            if (modelId === UNSET_MODELID_TAG) {
                // search in lookup
                modelId = modelsAssociations[deviceId];
            }
            if (!modelId) {
                // skip message
                return;
            }
            const { reported: reportedProperties } = message.properties;
            const reportedKeys = Object.keys(reportedProperties).filter(r => r !== '$version' && r !== '$metadata');
            row = {
                ...row, ...(modelId ? tables[`${modelToBindingName(modelId)}_props`].reduce((obj, capability) => {
                    if (capability.indexOf('.') > 0) { // a component
                        const [componentName, capabilityName] = capability.split('.');
                        if (reportedKeys.includes(componentName) && reportedProperties[componentName]['__t'] === 'c' && reportedProperties[componentName][capabilityName]) {
                            obj[capability] = reportedProperties[componentName][capabilityName];
                        }
                        else {
                            obj[capability] = null
                        }
                    }
                    else {
                        if (reportedProperties[capability] && !reportedProperties[capability]['__t']) {
                            obj[capability] = reportedProperties[capability];
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
            context.bindings[`${modelToBindingName(modelId)}_props`] = row;
            return;
        }
        else if (messageSource === MessageSources.DIGITAL_TWIN_CHANGE) {
            if (Array.isArray(message) && message.find(msg => msg.path === '/$metadata/$model')) {
                modelId = message.find(msg => msg.path === '/$metadata/$model').value;
                // set the in-memory lookup table
                modelsAssociations[deviceId] = modelId;
                const twin = await getTwin(context, deviceId);
                await setTwinTag(context, twin, 'modelId', modelId);
            }
            return;
        }
        context.log(`Using model Id '${modelId}'`);
    });
};

export default IoTHubTrigger;
