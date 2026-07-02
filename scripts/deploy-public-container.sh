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

function deploy-public-api(){
az storage container create \
  --name        "api-config" \
  --public-access blob
}

function main(){
deploy-public-api
verif-container
}

main