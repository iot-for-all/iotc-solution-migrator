# iotc-solution-migrator
Migration from IoTC to IoT Hub with solution

## Requirements
1. Azure Subscription
2. Azure IoT Central application and API Key
3. Compatible IoT Central device templates (see [Prepare IoT Central Application and devices](#prepare-iot-central-application-and-devices).)

## 1. Fetch details.
In order to automate the migration process, the tool utilizes IoT Central API tokens to interact with an application.
Please create an API token or reuse an existing one with "App Administrator" role. 

Follow official instructions on how to create an API token in IoT Central [here](https://learn.microsoft.com/en-us/rest/api/iotcentral/authentication#api-token). 
## 2. Create resources
This repository contains an automated script which creates and configures all required Azure resources in one click.
Hit the "Deploy to Azure" button below to start provision the system and follow instructions to access dashboards.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fiot-for-all%2Fiotc-solution-migrator%2Fmain%2Fdeployments%2Fmain.json)


## Prepare IoT Central Application and devices.
This migration tool assumes the device templates in the application include the "Device Migration" component. You can download the DTDL component schema from [here](../raw/migration_component.json).

The device firmware must react to the "DeviceMove" command defined in the component above. A python sample is available in the [_device-sample_](./device_sample) folder.