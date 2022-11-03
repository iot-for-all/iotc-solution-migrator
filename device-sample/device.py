from iotc.aio import IoTCClient, IOTCConnectType, IOTCEvents
from iotc.models import Property
from sys import argv
import asyncio
from random import randint, random


async def main():
    client = IoTCClient(
        argv[1],
        "0ne008104A2",
        IOTCConnectType.IOTC_CONNECT_SYMM_KEY,
        "r0mxLzPr9gg5DfsaxVhOwKK2+8jEHNclmCeb9iACAyb2A7yHPDrB2/+PTmwnTAetvI6oQkwarWHxYbkIVLybEg==",
    )

    async def on_prop(property: Property):
        print(
            f"Received property {property.name} for device with value {property.value}"
        )

    client.set_model_id("dtmi:azureiot:PhoneAsADevice;2")
    client.on(IOTCEvents.IOTC_PROPERTIES, on_prop)
    await client.connect()
    while client.is_connected():
        await client.send_telemetry(
            {
                "battery": randint(50, 100),
                "accelerometer": {"x": random(), "y": random(), "z": random()},
            },
            {"$.sub": "sensors"},
        )
        await client.send_property(
            {"device_info": {"__t": "c", "processorManufacturer": "Contoso"}}
        )
        await asyncio.sleep(15)


asyncio.run(main())
