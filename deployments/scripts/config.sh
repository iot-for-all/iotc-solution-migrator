#!/bin/bash

mkdir -p /tmp/setup
cd /tmp/setup

apk update

# Install NodeJS
apk add nodejs npm pwgen gnupg

node -v
npm -v

# Install func tools
curl -OL https://github.com/Azure/azure-functions-core-tools/releases/download/4.0.4865/Azure.Functions.Cli.linux-x64.4.0.4865.zip
unzip -d azure-functions-cli Azure.Functions.Cli.linux-x64.*.zip
ln -s azure-functions-cli/func /usr/local/bin/func
ln -s azure-functions-cli/gozip /usr/local/bin/gozip

# Get IoT Central Info
TEMPLATES_RESP=$(curl -X GET -H "Authorization: $IOTC_API_KEY" ${IOTC_APP_URL}/api/deviceTemplates?api-version=2022-07-31)

if [ $(echo $TEMPLATES_RESP | jq 'has("value")') == "true" ]; then
    TEMPLATE_IDS=$(echo $TEMPLATES_RESP | jq '.value | map(."@id")')
fi

declare -A SYMMETRIC_KEYS
DPS_RESP=$(curl -X GET -H "Authorization: $IOTC_API_KEY" ${IOTC_APP_URL}/api/enrollmentGroups?api-version=2022-07-31)

read SYMMETRIC_KEYS[PRIMARY_KEY] SYMMETRIC_KEYS[SECONDARY_KEY] <<< 
$(echo $DPS_RESP | jq -r '.value[] | select(.type=="iot" and .attestation.type=="symmetricKey") | .attestation.symmetricKey | to_entries | map("\(.value|tostring)")|.[]')


if [ $(echo $DPS_RESP | jq 'has("value")') == "true" ]; then
    export TEMPLATES=$(echo $TEMPLATES_RESP | jq '.value | map(."@id")')
fi

# Setup DPS
az config set extension.use_dynamic_install=yes_without_prompt
az login --identity
az account set --subscription "$SUBSCRIPTION_ID"
az iot dps enrollment-group create -g "$RESOURCE_GROUP" --dps-name "$DPS_RESOURCE_NAME" --enrollment-id "$DPS_ENROLLMENT_NAME" --primary-key "${SYMMETRIC_KEYS[PRIMARY_KEY]}" --secondary-key "${SYMMETRIC_KEYS[SECONDARY_KEY]}" --subscription "$SUBSCRIPTION_ID"

# Add Azure function code
## Basically adding the right bindings to function.json

git clone "$REPO_URL"
cd iotc-solution-migrator/Function
git checkout "$REPO_BRANCH"
npm install
npm run generate-config

# Deploy azure function
func azure functionapp publish "$FUNCTIONAPP_NAME" --subscription "$SUBSCRIPTION_ID" --typescript

# Call the function to parse models
curl -X POST -H "Content-Type: application/json" -d $(echo $TEMPLATES_RESP | jq '.value|tostring') $FUNCTIONAPP_URL

# Configure grafana
GRAFANA_TOKEN=$(az account get-access-token --resource "ce34e7e5-485f-4d76-964f-b3d2b16d1e4f" | jq '.accessToken')

# Generate a grafana password ( 12 chars with capitals, numbers and symbols)
GRAFANA_PASSWORD=$(pwgen -c -n -y 12 1)

# Create Datasource
curl -X POST -H "Authorization: Bearer ${GRAFANA_TOKEN}" -H "Content-Type: application/json" -d "{
        'name': 'IoTCSql',
        'type': 'mssql',
        'typeName': 'Microsoft SQL Server',
        'typeLogoUrl': 'public/app/plugins/datasource/mssql/img/sql_server_logo.svg',
        'access': 'proxy',
        'url': '$SQL_ENDPOINT',
        'user': 'grafana',
        'database': '$SQL_DATABASE',
        'basicAuth': false,
        'isDefault': false,
        'jsonData': {
            'authenticationType': 'SQL Server Authentication',
            'encrypt': 'false',
            'serverName': '',
            'sslRootCertFile': '',
            'tlsSkipVerify': false
        },
        'secureJsonData':{
            'password':'$GRAFANA_PASSWORD'
        },
        'readOnly': false
}" ${GRAFANA_ENDPOINT}/api/datasource


SQL_CMD_BIN=/opt/mssql-tools18/bin/sqlcmd

curl https://packages.microsoft.com/keys/microsoft.asc  | gpg --import -
curl -O https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/msodbcsql18_18.1.1.1-1_amd64.apk
curl -O https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/mssql-tools18_18.1.1.1-1_amd64.apk

# Install the package(s)
echo yes | apk add --allow-untrusted msodbcsql18_18.1.1.1-1_amd64.apk
echo yes | apk add --allow-untrusted mssql-tools18_18.1.1.1-1_amd64.apk

$SQL_CMD_BIN -S "$SQL_ENDPOINT" -d "$SQL_DATABASE" -U "$SQL_USERNAME" -P "$SQL_PASSWORD" -Q "CREATE USER grafana WITH PASSWORD $GRAFANA_PASSWORD; GRANT CONNECT TO grafana; GRANT SELECT TO grafana"


jq -c "{\"grafana\":{\"password\":\"$GRAFANA_PASSWORD\"}}" > $AZ_SCRIPTS_OUTPUT_PATH

rm -rf /tmp/setup