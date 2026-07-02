#!/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

echo "OWNER        = $OWNER"
echo "RG           = $RG"
echo "SA_NAME      = $SA_NAME"

az group show --name "$RG" --output table