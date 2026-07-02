#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

get-key-storage(){
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)
}

create-storage(){
 az storage container create \
  --name       "api-logs" \
  --public-access off
}

verify-storage(){
az storage container list \
  --query "[].{Nom:name, Acces:properties.publicAccess || 'None'}" \
  --output table
}


function main(){
    get-key-storage
    create-storage
    verify-storage
}

main