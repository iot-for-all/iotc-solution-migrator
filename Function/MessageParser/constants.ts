export const MODEL_KEY = 'dt-dataschema';
export const COMPONENT_KEY = 'dt-subject';
export const MESSAGE_SOURCE_KEY = 'iothub-message-source';
export const DEVICE_ID_KEY = 'iothub-connection-device-id';
export const TIMESTAMP_KEY = 'EnqueuedTimeUtc';
export const MESSAGE_SCHEMA = 'iothub-message-schema';
export const OPERATION_TYPE = 'opType';
export const UNSET_MODELID_TAG = '$twin.tags.modelId';

export enum MessageSources {
    DEVICE_LIFECYCLE = 'deviceLifecycleEvents',
    TWIN_CHANGE = 'twinChangeEvents',
    DIGITAL_TWIN_CHANGE = 'digitalTwinChangeEvents',
    TELEMETRY = 'Telemetry'
}

export enum MessageOperationTypes {
    CREATE_DEVICE = 'createDeviceIdentity',
    DELETE_DEVICE = 'deleteDeviceIdentity'
}