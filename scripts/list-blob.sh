#!/usr/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

# Connection string (auth)
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$SA_NAME" --resource-group "$RG" --query connectionString --output tsv)

function list_blob(){
echo "=== Conteneur api-logs (privé) ==="
az storage blob list \
  --container-name "api-logs" \
  --query          "[].{Nom:name, Taille:properties.contentLength}" \
  --output         table

echo ""
echo "=== Conteneur api-config (public) ==="
az storage blob list \
  --container-name "api-config" \
  --query          "[].{Nom:name, Taille:properties.contentLength}" \
  --output         table
}

function redundancy(){
# Lister les SKUs disponibles pour le storage à francecentral
az storage sku list \
  --query    "[].{SKU:name, Type:tier}" \
  --output   table | sort -u
}


function main(){
    list_blob
    redundancy
}

main