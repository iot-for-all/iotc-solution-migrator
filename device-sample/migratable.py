from asyncio import CancelledError
import asyncio
from sys import argv
from os import remove
from random import randint
from iotc.aio import IoTCClient
from json import dumps, loads
from iotc import (
    IOTCConnectType,
    Storage,
    Command,
    Property,
    CredentialsCache,
    IOTCEvents,
    IOTCLogLevel,
)
from model_parser import ModelParser

terminate = False
_initialize = True
_model_parser = None
client = None


class FileStorage(Storage):
    def __init__(self, device_id: str):
        self._filename = f"{device_id}.cred.json"
        super().__init__()

    def persist(self, credentials: CredentialsCache):
        file = open(self._filename, "w+")
        file.write(dumps(credentials.todict()))
        file.close()

    def retrieve(self):
        try:
            file = open(self._filename, "r")
            credentials = CredentialsCache.from_dict(loads(file.read()))
            file.close()
            return credentials
        except:
            return None

    def clear(self):
        try:
            remove(self._filename)
        except:
            print("Cannot clear credentials")


def keyboard_monitor(tasks_to_kill):
    global terminate
    while not terminate:
        selection = input("Press Q to quit\n")
        if selection == "Q" or selection == "q":
            print("Quitting...")
            for task in tasks_to_kill:
                task.cancel()
            terminate = True


async def executor(device_id: str, group_key: str, storage: Storage, on_cmd, on_prop):
    global _initialize
    global client
    global _model_parser
    while not terminate:
        if _initialize:
            client = IoTCClient(
                device_id=device_id,
                scope_id=_scope_id,
                cred_type=IOTCConnectType.IOTC_CONNECT_SYMM_KEY,
                key_or_cert=group_key,
            )
            # client.set_log_level(IOTCLogLevel.IOTC_LOGGING_ALL)
            client.set_model_id(_model_parser.get_model_id())
            client.on(IOTCEvents.IOTC_COMMAND, on_cmd)
            client.on(IOTCEvents.IOTC_PROPERTIES, on_prop)
            try:
                print(f"Connecting to DPS with scope {_scope_id}")
                await client.connect()
                await client.send_property(_model_parser.get_properties())
                _initialize = False
            except Exception as e:
                print(e)
        elif not client.terminated() and client.is_connected():
            try:
                telemetries = _model_parser.get_telemetries()
                for telemetry in telemetries:
                    await client.send_telemetry(telemetry[0], telemetry[1])
                
                await asyncio.sleep(15)
            except CancelledError:
                await client.disconnect()
        else:
            pass


async def main(device_id: str, scope_id: str, group_key: str):
    storage = FileStorage(device_id=device_id)
    global _scope_id
    global _template_id
    global _model_parser
    _scope_id = scope_id
    _template_id = None

    _model_parser = ModelParser("migratable_model.json")
    _model_parser.parse()

    async def on_cmd(command: Command):
        global client
        global _scope_id
        global _initialize
        global _template_id

        print(f"Received command with name {command.name}")
        if command.name == "DeviceMove":
            print(
                f"Received migration command for device '{device_id}'. Moving to {command.value}"
            )
            # change scopeId and restart
            _scope_id = command.value["idScope"]

            if "deviceTemplateId" in command.value:
                _template_id = command.value["deviceTemplateId"]

            await command.reply()
            await client.disconnect()
            client = None
            storage.clear()
            _initialize = True

    async def on_prop(property: Property):
        print(
            f"Received property {property.name} for device {device_id} with value {property.value}"
        )
        return True

    main_loop = asyncio.create_task(
        executor(
            device_id=device_id,
            group_key=group_key,
            storage=storage,
            on_cmd=on_cmd,
            on_prop=on_prop,
        )
    )
    keyboard_loop = asyncio.get_running_loop().run_in_executor(
        None, keyboard_monitor, [main_loop]
    )
    try:
        await asyncio.gather(main_loop, keyboard_loop)
    except asyncio.CancelledError:
        pass  # ignore the cancel actions on twin_listener and direct_method_listener
    print("Exiting...")


asyncio.run(
    main(
        device_id=argv[1],
        scope_id=argv[2],
        group_key=argv[3],
    )
)
