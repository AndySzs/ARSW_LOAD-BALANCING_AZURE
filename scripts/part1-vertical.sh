#!/bin/bash
# Parte 1 - Escalabilidad vertical (ejecutar en Azure Cloud Shell)
set -e

RG=SCALABILITY_LAB
LOC=${LOC:-brazilsouth}
VM=VERTICAL-SCALABILITY

az group create -n $RG -l $LOC -o table

az vm create -g $RG -n $VM \
  --image Ubuntu2204 \
  --size Standard_D2s_v4 \
  --admin-username scalability_lab \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  -o table

# Inbound port rule para el puerto 3000
az vm open-port -g $RG -n $VM --port 3000 --priority 1010 -o none

# Instalar y arrancar la FibonacciApp dentro de la VM
[ -f setup-app.sh ] || curl -fsSL https://raw.githubusercontent.com/AndySzs/ARSW_LOAD-BALANCING_AZURE/main/scripts/setup-app.sh -o setup-app.sh
az vm run-command invoke -g $RG -n $VM --command-id RunShellScript --scripts @setup-app.sh --query "value[0].message" -o tsv

IP=$(az vm show -d -g $RG -n $VM --query publicIps -o tsv)
echo "Endpoint: http://$IP:3000/fibonacci/6"

# --- Escalamiento vertical (paso 10) ---
# az vm resize -g $RG -n $VM --size Standard_D4s_v4
# --- Volver al tamaño inicial (paso 13) ---
# az vm resize -g $RG -n $VM --size Standard_D2s_v4
