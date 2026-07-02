#!/usr/bin/env bash
# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

check-sa(){
az storage account show \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --query          "{nom:name, region:location, sku:sku.name, statut:provisioningState}" \
  --output         table
}

create-sa(){
az storage account create \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --location       "$LOCATION" \
  --sku            Standard_LRS \
  --kind           StorageV2 \
  --allow-blob-public-access true \
  --tags           $TAGS
}

  function main(){
    create-sa
    check-sa
  }

main