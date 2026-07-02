#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

get-key-storage(){
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)
}

function url_blob(){
URL=$(az storage blob url \
  --container-name "api-logs" \
  --name           "access-log.txt" \
  --output         tsv)

echo "$URL"
curl -s "$URL"
}


function main(){
get-key-storage
url_blob
}

main