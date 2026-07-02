#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

# Connection string (auth)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)

function blob-update(){
az storage blob upload \
  --container-name "api-config" \
  --file           "config.json" \
  --name           "config.json" \
  --content-type   "application/json" \
  --overwrite
}

function main(){
    blob-update
}

main