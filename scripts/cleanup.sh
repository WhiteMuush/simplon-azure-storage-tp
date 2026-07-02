#!/usr/bin/env bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

function clean-local(){
# Supprimer les fichiers locaux créés pendant le TP
rm -f /tmp/access-log.txt /tmp/config.json access-log.txt config.json
echo "✅ Fichiers locaux supprimés"
}

function delete-storage(){
# Supprime le storage account (supprime automatiquement tous les conteneurs et blobs)
az storage account delete \
  --name           "$SA_NAME" \
  --resource-group "$RG" \
  --yes
echo "✅ Storage account supprimé : $SA_NAME"
}

function verify(){
echo "▶ Storage accounts restants dans $RG :"
az storage account list \
  --resource-group "$RG" \
  --query          "[].name" \
  --output         table
}

function main(){
    clean-local
    delete-storage
    verify
}

main
