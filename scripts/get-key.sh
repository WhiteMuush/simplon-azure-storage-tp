#!/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

# Catch the connection string ( key access )
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          connectionString \
  --output         tsv)

echo "Connection string récupérée ✅"