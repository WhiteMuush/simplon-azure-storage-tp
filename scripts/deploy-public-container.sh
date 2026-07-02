#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

# Connection string (auth)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)

function verif-container(){
az storage container list \
  --query "[].{Nom:name, Acces:properties.publicAccess || 'None'}" \
  --output table
}

function verif-public-access(){
CONFIG_URL=$(az storage blob url \
  --container-name "api-config" \
  --name           "config.json" \
  --output         tsv)

echo "URL publique : $CONFIG_URL"
curl -s "$CONFIG_URL"

}

function deploy-public-api(){
az storage container create \
  --name        "api-config" \
  --public-access blob
}


function main(){
deploy-public-api
verif-container
verif-public-access
}

main