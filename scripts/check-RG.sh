#!/bin/bash

# Init .env
set -a; source "$(dirname "$0")/.env"; set +a

echo "OWNER        = $OWNER"
echo "RG           = $RG"
echo "SA_NAME      = $SA_NAME"

# That will check if you have already a RG
# If you have an error, create it manually on Azure 
# (Or check if I add a script that create it, idk )
az group show --name "$RG" --output table