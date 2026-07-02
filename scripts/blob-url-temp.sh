#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

# Connection string (auth)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)

sas-key(){
# Générer une SAS valable 1 heure
EXPIRY=$(date -u -d "+1 hour" '+%Y-%m-%dT%H:%MZ' 2>/dev/null)

SAS_URL=$(az storage blob generate-sas \
  --container-name "api-logs" \
  --name           "access-log.txt" \
  --permissions    r \
  --expiry         "$EXPIRY" \
  --full-uri \
  --output         tsv)

echo "SAS URL (valable 1h) :"
echo "$SAS_URL"

}

function main(){
sas-key
}

main