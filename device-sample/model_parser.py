import json
from functools import reduce
from random import random, randint
from random_word import RandomWords


def get_random_vector():
    return {"x": random(), "y": random(), "z": random()}


def get_random_geopoint():
    return {"lat": random() * 30, "lon": random() * 10, "alt": 0}


class ModelParser:
    def __init__(self, file) -> None:
        self._file = file

    def parse(self):
        f = open(self._file, "r")
        self._model = json.loads(f.read())
        self._random = RandomWords()
        self._properties = self._parse_properties()
        self._telemetries = self._parse_telemetries()

    def _parse_component(self, component, capabilityType):
        items = []
        for content in component["schema"]["contents"]:
            if content["@type"] == "Component":
                items.append(self._parse_component(content, capabilityType))
            else:
                parsed = self._parse_capability(content, capabilityType)
                items.append(parsed) if parsed is not None else None
        return items

    def _parse_capability(self, capability, capabilityType):
        if (
            capability["@type"] == capabilityType
            or capabilityType in capability["@type"]
        ):
            if capability["schema"] == "string":
                return {
                    "name": capability["name"],
                    "get_value": self._random.get_random_word,
                }
            elif capability["schema"] == "integer":
                return {
                    "name": capability["name"],
                    "get_value": lambda: randint(0, 100),
                }
            elif capability["schema"] == "double":
                return {"name": capability["name"], "get_value": random}
            elif capability["schema"] == "vector":
                return {"name": capability["name"], "get_value": get_random_vector}
            elif capability["schema"] == "geopoint":
                return {"name": capability["name"], "get_value": get_random_geopoint}

    def get_model_id(self):
        if "capabilityModel" in self._model:
            return self._model["capabilityModel"]["@id"]
        else:
            return self._model["@id"]

    def _toMessageItem(self, obj, item):
        obj[item["name"]] = item["get_value"]()
        return obj

    def get_telemetries(self):
        res = []
        for component, telemetries in self._telemetries.items():
            if len(telemetries) > 0:
                if component == "default":
                    res.append((reduce(self._toMessageItem, telemetries, {}), None))
                else:
                    res.append(
                        (
                            reduce(self._toMessageItem, telemetries, {}),
                            {"$.sub": component},
                        )
                    )
        return res

    def get_properties(self):
        res = {}
        for component, properties in self._properties.items():
            if len(properties) > 0:
                if component == "default":
                    res.update(reduce(self._toMessageItem, properties, {}))
                else:
                    res[component] = {"__t": "c"}
                    res[component].update(reduce(self._toMessageItem, properties, {}))
                    print(res)
        return res

    def _parse_properties(self):
        properties = {"default": []}
        if "capabilityModel" in self._model:
            model = self._model["capabilityModel"]
        else:
            model = self._model

        for content in model["contents"]:
            if content["@type"] == "Component":
                capabilities = self._parse_component(content, "Property")
                properties[content["name"]] = (
                    capabilities if capabilities is not None else []
                )
            else:
                capability = self._parse_capability(content, "Property")
                properties["default"].append(
                    capability
                ) if capability is not None else None
        return properties

    def _parse_telemetries(self):
        telemetries = {"default": []}

        if "capabilityModel" in self._model:
            model = self._model["capabilityModel"]
        else:
            model = self._model

        for content in model["contents"]:
            if content["@type"] == "Component":
                capabilities = self._parse_component(content, "Telemetry")
                telemetries[content["name"]] = (
                    capabilities if capabilities is not None else []
                )
            else:
                capability = self._parse_capability(content, "Telemetry")
                telemetries["default"].append(
                    capability
                ) if capability is not None else None
        return telemetries
