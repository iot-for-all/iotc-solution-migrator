@description('Define the project name or prefix for all objects.')
@minLength(1)
@maxLength(11)
param projectName string = 'contoso'

@description('The SKU to use for the IoT Hub.')
param skuName string = 'S1'

@description('The number of IoT Hub units.')
param skuUnits int = 1

@description('Partitions used for the event stream.')
param d2cPartitions int = 4

var iotHubName = take('${projectName}hub${uniqueString(resourceGroup().id)}', 20)
var dpsName = take('${projectName}dps${uniqueString(resourceGroup().id)}', 20)


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

resource DPS 'Microsoft.Devices/provisioningServices@2021-10-15' = {
  name: dpsName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  properties: {
    iotHubs: [
      {
        connectionString: 'HostName=${IoTHub.properties.hostName};SharedAccessKeyName=iothubowner;SharedAccessKey=${IoTHub.listkeys().value[0].primaryKey}'
        location: location
      }
    ]
  }
}

var HubOwnerKey = IoTHub.listkeys().value[0].primaryKey
output ScopeId string = DPS.properties.idScope
output EventHubCS string = '${IoTHub.properties.eventHubEndpoints.events.endpoint};SharedAccessKeyName=iothubowner;SharedAccessKey=${HubOwnerKey}'

output HubOwnerCS string = 'HostName=${IoTHub.properties.hostName};SharedAccessKeyName=iothubowner;SharedAccessKey=${HubOwnerKey}'
output DPSName string = dpsName
