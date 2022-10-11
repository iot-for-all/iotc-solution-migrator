#!/bin/bash

WORKING_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PRINT_USAGE() {
    printf '\n%s\n' ""
    printf "deploy-resources [${MAG_COLOR}options${DEFAULT_COLOR}]\n"
    printf '\n%s\n' ""
    printf "${MAG_COLOR}options${DEFAULT_COLOR}:\n"
    printf '\n%s\n'  "     --subscription=[n]    Sets the subscription where to create resources. Otherwise it will prompt ask."
    printf '\n%s\n'  "     --resource-group=[n]    Sets the resource group where to create resources. Otherwise it will prompt ask. If not existing, the script will create it."
    printf '\n%s\n'  "     --private-key=[n]   Sets Azure DevOps repo access key. Otherwise, it will prompt ask"
    printf '\n%s\n'  "     --pat-token=[n]     Sets Azure DevOps user token. Otherwise, it will prompt ask."
    printf '\n%s\n'  ""
}


RESOURCE_GROUP=
RESOURCE_GROUP_IS_SET=0
SUBSCRIPTION=
SUBSCRIPTION_IS_SET=0
IOT_HUB_NAME=
IOT_HUB_NAME_IS_SET=0
DPS_NAME=
DPS_NAME_IS_SET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
    --resource-group=*)
        RESOURCE_GROUP_IS_SET=1
        RESOURCE_GROUP=$1
        RESOURCE_GROUP=${RESOURCE_GROUP:17}
        ;;
    --subscription=*)
        SUBSCRIPTION_IS_SET=1
        SUBSCRIPTION=$1
        SUBSCRIPTION=${SUBSCRIPTION:15}
        ;;
    --iot-hub=*)
        IOT_HUB_NAME_IS_SET=1
        IOT_HUB_NAME=$1
        IOT_HUB_NAME=${IOT_HUB_NAME:10}
        ;;
    --dps=*)
        DPS_NAME_IS_SET=1
        DPS_NAME=$1
        DPS_NAME=${DPS_NAME:6}
        ;;

    -h | --help)
        PRINT_USAGE
        exit 0
        ;;

    *)
        echo "Unknown option $1"
        PRINT_USAGE
        exit 1
        ;;
    esac

    shift
done

if [ $SUBSCRIPTION_IS_SET -ne 1 ]; then
    printf '\n%s' ""
    read -p "Please provide a subscription:" SUBSCRIPTION
fi

if [ $RESOURCE_GROUP_IS_SET -ne 1 ]; then
    printf '\n%s' ""
    read -p "Please provide a resource group:" RESOURCE_GROUP
fi

if [ $IOT_HUB_NAME_IS_SET -ne 1 ]; then
    printf '\n%s' ""
    read -p "Please provide an IoT Hub name:" IOT_HUB_NAME
fi

if [ $DPS_NAME_IS_SET -ne 1 ]; then
    printf '\n%s' ""
    read -p "Please provide a DPS (Device Provisioning Service) name:" DPS_NAME
fi

# deploy iothub and dps
HUB_DPS=`az deployment group create --resource-group $RESOURCE_GROUP --subscription $SUBSCRIPTION -f $WORKING_DIR/iothub-dps.json -p hubName="$IOT_HUB_NAME" dpsName="$DPS_NAME" -o tsv`
echo $HUB_DPS