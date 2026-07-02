#!/usr/bin/env bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

function url_container(){

CONFIG_URL=$(az storage blob url --container-name "api-config" --name "config.json" --output tsv)
echo "✅ config.json accessible publiquement : $CONFIG_URL"

}

function upload-files(){

# Upload des fichiers exemples
echo '2024-06-18 09:12:33 - GET /api/hello - 200 OK' > /tmp/access-log.txt
az storage blob upload --container-name "api-logs"   --file /tmp/access-log.txt --name "access-log.txt" --overwrite

echo '{"app":"AzureTech","version":"1.0","endpoints":["/api/hello"]}' > /tmp/config.json
az storage blob upload --container-name "api-config" --file /tmp/config.json   --name "config.json"    --overwrite --content-type "application/json"

}

function setup-container(){

echo ""
echo "▶ Création des conteneurs Blob..."

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          connectionString \
  --output         tsv)

az storage container create --name "api-logs"   --public-access off
az storage container create --name "api-config" --public-access blob

echo "✅ Conteneurs créés : api-logs (privé) / api-config (public)"

}

function main(){
    setup-container
    upload-files
    url_container
}

main