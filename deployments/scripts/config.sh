#!/bin/bash
apt-get update
apt-get install -y curl python3-pip
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

pip install --upgrade pip
pip install -q mssql-cli

# Setup DPS
az config set extension.use_dynamic_install=yes_without_prompt
az login --identity
az iot dps enrollment-group create -g "$RESOURCE_GROUP" --dps-name "$DPSName" --enrollment-id "$ENROLLMENT_GROUP_ID" --primary-key "$ENROLLMENT_PRIMARY_KEY" --secondary-key "$ENROLLMENT_SECONDARY_KEY" --subscription "$SUBSCRIPTION_ID"

# setup sql server
