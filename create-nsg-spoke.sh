#!/usr/bin/env bash
#
# create-nsg-spoke.sh
# Crée les NSG (nsg-snet-aci, nsg-snet-data, nsg-snet-pep) avec leurs étiquettes
# et les associe à leurs sous-réseaux respectifs dans le Spoke VNet.
#
# Prérequis : être connecté (az login) et sur le bon abonnement (az account show).
# Exécution : Azure Cloud Shell (Bash), WSL, ou Git Bash.

set -euo pipefail

# ------------------------- Variables -------------------------
RG="rg-4sky-network"
VNET="vnet-4sky-spoke"
LOC="germanywestcentral"

# Étiquettes communes (le tag 'project' est obligatoire via Azure Policy)
TAGS=(project=4sky-hybrid-lab env=lab owner=daryl costCenter=IT role=security)

# Sous-réseaux à sécuriser (nom sans le préfixe 'snet-')
# -> génère nsg-snet-aci, nsg-snet-data, nsg-snet-pep
SUBNETS=(aci data pep)
# ------------------------------------------------------------

echo "Abonnement actif :"
az account show --query "{Nom:name, Id:id}" --output table
echo

for s in "${SUBNETS[@]}"; do
  NSG="nsg-snet-${s}"
  SUBNET="snet-${s}"

  echo "==> Création du NSG ${NSG}"
  az network nsg create \
    --resource-group "$RG" \
    --name "$NSG" \
    --location "$LOC" \
    --tags "${TAGS[@]}" \
    --output none

  echo "==> Association de ${NSG} au sous-réseau ${SUBNET}"
  az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name "$SUBNET" \
    --network-security-group "$NSG" \
    --output none

  echo "    OK : ${NSG} associé à ${SUBNET}"
  echo
done

echo "======================= Vérification ======================="
az network vnet subnet list \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --query "[?networkSecurityGroup!=null].{SousReseau:name, NSG:networkSecurityGroup.id}" \
  --output table
