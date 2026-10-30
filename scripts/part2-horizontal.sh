#!/bin/bash
# Parte 2 - Escalabilidad horizontal (ejecutar en Azure Cloud Shell)
# Uso: ./part2-horizontal.sh        -> crea LB + VM1, VM2, VM3
#      ./part2-horizontal.sh 4      -> agrega VM4
set -e

RG=SCALABILITY_LAB_2
LOC=${LOC:-brazilsouth}
VNET=SCALABILITY_VNET
SUBNET=default
NSG=SCALABILITY_NSG
LB=SCALABILITY_LB
POOL=SCALABILITY_BACKEND_POOL
PROBE=SCALABILITY_HEALTH_PROBE
RULE=SCALABILITY_LB_RULE

create_vm () {
  local N=$1 ZONE=$2 SIZE=${3:-Standard_D2s_v4} PIP=${4:-yes} IPARG=""
  # Azure for Students: máximo 3 IPs públicas por región (1 del LB + VM1 + VM2)
  if [ "$PIP" == "yes" ]; then
    az network public-ip create -g $RG -n VM$N-IP --sku Standard --zone 1 2 3 -o none
    IPARG="--public-ip-address VM$N-IP"
  fi
  az network nic create -g $RG -n VM$N-NIC --vnet-name $VNET --subnet $SUBNET \
    --network-security-group $NSG $IPARG \
    --lb-name $LB --lb-address-pools $POOL -o none
  az vm create -g $RG -n VM$N --zone $ZONE --nics VM$N-NIC \
    --image Ubuntu2204 --size $SIZE \
    --admin-username vm$N --generate-ssh-keys -o table
  az vm run-command invoke -g $RG -n VM$N --command-id RunShellScript \
    --scripts @setup-app.sh --query "value[0].message" -o tsv
}

[ -f setup-app.sh ] || curl -fsSL https://raw.githubusercontent.com/AndySzs/ARSW_LOAD-BALANCING_AZURE/main/scripts/setup-app.sh -o setup-app.sh

if [ "$1" == "4" ]; then
  create_vm 4 1 Standard_D2_v4 no   # supera la cuota de 6 vCPU de Azure for Students
  exit 0
fi

az group create -n $RG -l $LOC -o table

# 1. Load Balancer público Standard con IP zone-redundant
az network public-ip create -g $RG -n LB-PUBLIC-IP --sku Standard --zone 1 2 3 -o none
az network lb create -g $RG -n $LB --sku Standard \
  --public-ip-address LB-PUBLIC-IP --frontend-ip-name LB-FRONTEND \
  --backend-pool-name $POOL -o none

# 2. Health probe TCP sobre el puerto 3000
az network lb probe create -g $RG --lb-name $LB -n $PROBE \
  --protocol Tcp --port 3000 --interval 5 -o none

# 3. Load balancing rule 80 -> 3000, sin persistencia de sesión
az network lb rule create -g $RG --lb-name $LB -n $RULE \
  --protocol Tcp --frontend-port 80 --backend-port 3000 \
  --frontend-ip-name LB-FRONTEND --backend-pool-name $POOL \
  --probe-name $PROBE --load-distribution Default \
  --idle-timeout 4 -o none
# Nota: la regla deja el SNAT implícito activo; así la VM3 (sin IP pública) sale a Internet
# por la IP del balanceador. Una outbound rule explícita no se puede usar porque Azure no la
# permite cuando hay VMs del pool con IP pública propia (NicWithPublicIpCannotReferencePoolWithOutboundRule).

# 4. Virtual Network + Subnet
az network vnet create -g $RG -n $VNET --address-prefix 10.0.0.0/16 \
  --subnet-name $SUBNET --subnet-prefix 10.0.0.0/24 -o none

# 5. Network Security Group (22 y 3000)
az network nsg create -g $RG -n $NSG -o none
az network nsg rule create -g $RG --nsg-name $NSG -n SSH --priority 1000 \
  --destination-port-ranges 22 --access Allow --protocol Tcp -o none
az network nsg rule create -g $RG --nsg-name $NSG -n PORT_3000 --priority 1010 \
  --destination-port-ranges 3000 --access Allow --protocol Tcp -o none

# 6. VMs en 3 zonas de disponibilidad (2 vCPU c/u = 6 vCPU, el tope de la suscripción)
create_vm 1 1
create_vm 2 2
create_vm 3 3 Standard_D2_v4 no   # otra familia (cuota DSv4 = 4 vCPU) y sin IP pública

LBIP=$(az network public-ip show -g $RG -n LB-PUBLIC-IP --query ipAddress -o tsv)
echo "Endpoint del balanceador: http://$LBIP/fibonacci/6"
