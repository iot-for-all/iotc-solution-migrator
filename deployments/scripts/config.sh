#!/bin/bash

OUTPUT={}

log(){
OUTPUT=$(echo $OUTPUT | jq -r "if has(\"$1\") then (.[\"$1\"] |= . +[\"$2\"]) else .|= . + {\"$1\":[\"$2\"]} end | tostring")
echo $OUTPUT > $AZ_SCRIPTS_OUTPUT_PATH
}

log "Deployment script" "Starting now"
# https://github.com/microsoft/WSL/issues/5991
echo "nameserver 8.8.8.8" > /etc/resolv.conf

mkdir -p /tmp/setup
cd /tmp/setup

apk update


apk add pwgen gnupg

# Install NodeJS
log "NodeJS" "Start installation"

curl -s -O https://unofficial-builds.nodejs.org/download/release/v14.4.0/node-v14.4.0-linux-x64-musl.tar.xz
tar xf node-v14.4.0-linux-x64-musl.tar.xz -C /usr --strip-components=1

log "NodeJS" "Installed. Node: $(node -v). NPM: $(npm -v)"

# Install dotnet and func tools
log "DotNet" "Start installation"
apk add bash icu-libs krb5-libs libgcc libintl libssl1.1 libstdc++ zlib
apk add libgdiplus --repository https://dl-3.alpinelinux.org/alpine/edge/testing/
curl -OLs https://download.visualstudio.microsoft.com/download/pr/b5e6c72e-457c-406c-a4a8-6a4fcdd5f50c/feaa81a666c8942064453fb3c456856b/dotnet-sdk-6.0.403-linux-musl-x64.tar.gz

mkdir -p $HOME/dotnet
tar zxf dotnet-sdk-6.0.403-linux-musl-x64.tar.gz -C $HOME/dotnet
export DOTNET_ROOT=$HOME/dotnet
export PATH=$PATH:$HOME/dotnet
log "DotNet" "Package extracted."

log "FuncTool" "Downloading."
curl -OLs https://github.com/Azure/azure-functions-core-tools/archive/v4.x.tar.gz
tar -xzvf v4.x.tar.gz
cd azure-functions-core-tools*
log "FuncTool" "Building."
dotnet publish src/Azure.Functions.Cli/Azure.Functions.Cli.csproj --runtime linux-musl-x64 --output /output

log "FuncTool" "Successfully built."

ln -s /output/func /usr/local/bin/func

log "IoT Central" "Fetching templates."
# Get IoT Central Info
TEMPLATES_RESP=$(curl -X GET -H "Authorization: $IOTC_API_KEY" ${IOTC_APP_URL}/api/deviceTemplates?api-version=2022-07-31)

if [ $(echo $TEMPLATES_RESP | jq 'has("value")') == "true" ]; then
   export TEMPLATES=$(echo $TEMPLATES_RESP | jq '.value | map(.capabilityModel["@id"])')
fi

log "IoT Central" "Templates: $TEMPLATES"
log "IoT Central" "Fetching SAS keys."

DPS_RESP=$(curl -X GET -H "Authorization: $IOTC_API_KEY" ${IOTC_APP_URL}/api/enrollmentGroups?api-version=2022-07-31)

declare -A SYMMETRIC_KEYS="($(echo $DPS_RESP | jq -r '.value[] | select(.type=="iot" and .attestation.type=="symmetricKey") | .attestation.symmetricKey | to_entries | map("[\(.key)]=\(.value)")| join(" ")'))"

log "IoT Central" "SAS keys fetched."

# Setup DPS
log "DPS" "Creating enrollment group."

az config set extension.use_dynamic_install=yes_without_prompt
az login --identity
az account set --subscription "$SUBSCRIPTION_ID"
az iot dps enrollment-group create -g "$RESOURCE_GROUP" --dps-name "$DPS_RESOURCE_NAME" --enrollment-id "$DPS_ENROLLMENT_NAME" --primary-key "${SYMMETRIC_KEYS[primaryKey]}" --secondary-key "${SYMMETRIC_KEYS[secondaryKey]}" --subscription "$SUBSCRIPTION_ID"

log "DPS" "Enrollment group created."


# Configure grafana
GRAFANA_TOKEN=$(az account get-access-token --resource "ce34e7e5-485f-4d76-964f-b3d2b16d1e4f" | jq -r '.accessToken')
log "Grafana" "Fetched token."

# Generate a grafana password ( 12 chars with capitals, numbers and symbols)
GRAFANA_PASSWORD=$(pwgen -c -n 12 1)

# Create Datasource
log "Grafana" "Creating datasource."

GRAFANA_DATASOURCE_RESP=$(curl -X POST -H "Authorization: Bearer ${GRAFANA_TOKEN}" -H "Content-Type: application/json" -d "{
        \"name\": \"IoTCSql\",
        \"type\": \"mssql\",
        \"typeName\": \"Microsoft SQL Server\",
        \"typeLogoUrl\": \"public/app/plugins/datasource/mssql/img/sql_server_logo.svg\",
        \"access\": \"proxy\",
        \"url\": \"$SQL_ENDPOINT\",
        \"user\": \"grafana\",
        \"database\": \"$SQL_DATABASE\",
        \"basicAuth\": false,
        \"isDefault\": false,
        \"jsonData\": {
            \"authenticationType\": \"SQL Server Authentication\",
            \"encrypt\": \"false\",
            \"serverName\": \"\",
            \"sslRootCertFile\": \"\",
            \"tlsSkipVerify\": false
        },
        \"secureJsonData\":{
            \"password\":\"$GRAFANA_PASSWORD\"
        },
        \"readOnly\": false
}" ${GRAFANA_ENDPOINT}/api/datasources)

GRAFANA_DATASOURCE_UID=$(echo $GRAFANA_DATASOURCE_RESP | jq -r '.datasource.uid')
log "Grafana" "Datasource created with id: '$GRAFANA_DATASOURCE_UID'."


# Add Azure function code
## Basically adding the right bindings to function.json
log "Function" "Cloning repository."

git clone "$REPO_URL"
cd iotc-solution-migrator/Function
git checkout "$REPO_BRANCH"
log "Function" "Running install"
npm install
log "Function" "Generating configuration"
npm run generate-config

log "Function" "Deploy function code."
# Deploy azure function
func azure functionapp publish "$FUNCTIONAPP_NAME" --subscription "$SUBSCRIPTION_ID" --typescript

log "Function" "Update settings."
# Update function settings
az functionapp config appsettings set --name $FUNCTIONAPP_NAME --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION_ID --settings "GRAFANA_ENDPOINT=$GRAFANA_ENDPOINT" "GRAFANA_TOKEN=$GRAFANA_TOKEN" "GRAFANA_DATASOURCE_UID=$GRAFANA_DATASOURCE_UID"

# Call the function to parse models
log "Configuration" "Calling function."
CONFIG_RESP=$(curl -X POST -H "Content-Type: application/json" -d "$(echo $TEMPLATES_RESP | jq -r '.value|tostring')" $FUNCTIONAPP_URL)
log "Configuration" "Response: $CONFIG_RESP"


SQL_CMD_BIN=/opt/mssql-tools18/bin/sqlcmd

log "SQL Server" "Installing mssql-tools."
curl https://packages.microsoft.com/keys/microsoft.asc  | gpg --import -
curl -OLs https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/msodbcsql18_18.1.1.1-1_amd64.apk
curl -OLs https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/mssql-tools18_18.1.1.1-1_amd64.apk

# Install the package(s)
echo yes | apk add --allow-untrusted msodbcsql18_18.1.1.1-1_amd64.apk
echo yes | apk add --allow-untrusted mssql-tools18_18.1.1.1-1_amd64.apk

log "SQL Server" "Tools installed."
$SQL_CMD_BIN -S "$SQL_ENDPOINT" -d "$SQL_DATABASE" -U "$SQL_USERNAME" -P "$SQL_PASSWORD" -Q "CREATE USER grafana WITH PASSWORD='$GRAFANA_PASSWORD'; GRANT CONNECT TO grafana; GRANT SELECT TO grafana"

# rm -rf /tmp/setup