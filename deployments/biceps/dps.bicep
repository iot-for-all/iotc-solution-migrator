var location = resourceGroup().location
var skuName = 'S1'
var dpsName = 'contosodps'
var skuUnits = 1

resource DPS 'Microsoft.Devices/provisioningServices@2021-10-15' = {
  name: dpsName
  location: location
  sku: {
    name: skuName
    capacity: skuUnits
  }
  properties: {
  }
}
