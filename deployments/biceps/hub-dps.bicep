@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The storage account name.')
param storageAccountName string

@description('The storage resource Id')
param storageId string

@description('The SKU to use for the IoT Hub.')
param skuName string = 'S1'

@description('The number of IoT Hub units.')
param skuUnits int = 1

@description('Partitions used for the event stream.')
param d2cPartitions int = 4

@description('The Enrollment group primary key')
@secure()
param primaryKey string

@description('The Enrollment group secondary key')
@secure()
param secondaryKey string

var iotHubName = '${projectName}hub${uniqueString(resourceGroup().id)}'
var dpsName = '${projectName}dps${uniqueString(resourceGroup().id)}'
var dpsScript = '${projectName}dps${uniqueString(resourceGroup().id)}script'
var userId = '${projectName}id${uniqueString(resourceGroup().id)}'
var enrollmentGroupId = '${projectName}dps${uniqueString(resourceGroup().id)}eg'
param location string = resourceGroup().location

resource IoTHub 'Microsoft.Devices/IotHubs@2021-07-02' = {
  name: iotHubName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  properties: {
    eventHubEndpoints: {
      events: {
        retentionTimeInDays: 1
        partitionCount: d2cPartitions
      }
    }
    routing: {
      routes: [
        {
          name: 'DeviceTwin'
          source: 'TwinChangeEvents'
          endpointNames: [
            'events'
          ]
          isEnabled: true
        }
        {
          name: 'DigitalTwinChange'
          source: 'DigitalTwinChangeEvents'
          endpointNames: [
            'events'
          ]
          isEnabled: true
        }
      ]
      enrichments: [ {
          endpointNames: [
            'events'
          ]
          key: 'modelId'
          value: '$twin.tags.modelId'
        } ]
    }
  }
}

resource DPS 'Microsoft.Devices/provisioningServices@2022-02-05' = {
  name: dpsName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  properties: {
    allocationPolicy: 'Hashed'
    iotHubs: [
      {
        connectionString: 'HostName=${IoTHub.properties.hostName};SharedAccessKeyName=iothubowner;SharedAccessKey=${IoTHub.listkeys().value}'
        location: location
      }
    ]
  }
}

resource UserIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: userId
  location: location
}

resource DPSEnrollmentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzureCLI'
  location: location
  name: dpsScript
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UserIdentity.id}': {}
    }
  }
  properties: {
    storageAccountSettings: {
      storageAccountKey: listKeys(storageId, '2022-05-01').keys[0].value
      storageAccountName: storageAccountName
    }
    azCliVersion: '2.28.0'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    scriptContent: 'az iot dps enrollment-group create -g ${resourceGroup().name} --dps-name ${dpsName} --enrollment-id ${enrollmentGroupId} --primary-key ${primaryKey} --secondary-key ${secondaryKey}'
  }
}

output ScopeId string = DPS.properties.idScope
output EventHubCS string = IoTHub.properties.eventHubEndpoints.events.endpoint

var HubOwnerKey = IoTHub.listkeys().value[0].primaryKey
output HubOwnerCS string = 'HostName=${IoTHub.properties.hostName};SharedAccessKeyName=iothubowner;SharedAccessKey=${HubOwnerKey}'
