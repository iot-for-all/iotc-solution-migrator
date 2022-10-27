#!/bin/bash

mkdir -p /tmp/setup
cd /tmp/setup

apt-get update
apt-get install -y curl python3-pip git jq
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

curl -fsSL https://deb.nodesource.com/setup_lts.x | bash
apt-get install -y nodejs

node -v
npm -v

# Install func tools
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
apt-get update
apt-get install -y azure-functions-core-tools-4


pip install --upgrade pip
pip install -q mssql-cli

# Setup DPS
az config set extension.use_dynamic_install=yes_without_prompt
az login --identity
az account set --subscription "$SUBSCRIPTION_ID"
az iot dps enrollment-group create -g "$RESOURCE_GROUP" --dps-name "$DPS_RESOURCE_NAME" --enrollment-id "$DPS_ENROLLMENT_NAME" --primary-key "$DPS_ENROLLMENT_PRIMARY_KEY" --secondary-key "$DPS_ENROLLMENT_SECONDARY_KEY" --subscription "$SUBSCRIPTION_ID"

# Add Azure function code
## Basically adding the right bindings to function.json

git clone "$REPO_URL"
cd iotc-solution-migrator/Function
git checkout "$REPO_BRANCH"
npm install
npm run generate-config

# Deploy azure function
func azure functionapp publish "$FUNCTIONAPP_NAME" --subscription "$SUBSCRIPTION_ID" --typescript

rm -rf /tmp/setup