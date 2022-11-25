# Sample python device

## Setup
```sh
pip install -r requirements.txt
```

## Run
Single device:
```sh
python migratable.py "<DEVICE_ID>" "<SCOPE_ID>" "<SAS_GROUP_KEY>"

# ctrl+c to kill
```


Multiple devices:

#### bash
```bash
./sim.sh "<DEVICE_ID_PREFIX>" "<SCOPE_ID>" "<SAS_GROUP_KEY>" <NUM_OF_DEVICES_TO_SIMULATE>

# press 'q' to quit
```