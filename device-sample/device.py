from iotc.aio import IoTCClient, IOTCConnectType, IOTCEvents
from iotc.models import Property
import asyncio
from random import randint


async def main():
    client = IoTCClient(
        "dev03",
        "0ne007BC5FD",
        IOTCConnectType.IOTC_CONNECT_SYMM_KEY,
        "PxHSX6ZEXD67gZXiouRbyVXNqKzfMF4Inc6IfJGn9P7DCrMyssHS0g3ZCqyfOnJmPC7bNqJeAua8YHSpkqWBZw==",
    )

    async def on_prop(property: Property):
        print(
            f"Received property {property.name} for device with value {property.value}"
        )

    client.set_model_id("dtmi:azureiot:PhoneAsADevice;2")
    client.on(IOTCEvents.IOTC_PROPERTIES, on_prop)
    await client.connect()
    while client.is_connected():
        await client.send_telemetry({"battery": randint(50, 100)}, {"$.sub": "sensors"})
        await client.send_property(
            {"device_info": {"__t": "c", "manufacturer": "Contoso"}}
        )
        await asyncio.sleep(10)


asyncio.run(main())
