#!/bin/bash

set -e

# =============================
#   Clé SSH
# =============================

SSH_KEY_NAME="test"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_PUB_KEY_PATH="${SSH_KEY_PATH}.pub"

echo "Vérification de la clé SSH..."

if [ ! -f "$SSH_KEY_PATH" ] || [ ! -f "$SSH_PUB_KEY_PATH" ]; then
  echo "Clé SSH non trouvée : $SSH_KEY_PATH"
  echo "Génération d'une nouvelle paire de clés SSH..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
else
  echo "Clé SSH déjà présente : $SSH_KEY_PATH"
fi

# =============================
#   Terraform Init & Apply
# =============================

echo "Initialisation de Terraform..."
docker compose -f docker-compose.yml run --rm terraform init -input=false

echo "Déploiement Terraform..."
docker compose -f docker-compose.yml run --rm terraform apply -auto-approve

# =============================
#   Récupération des IPs publiques uniquement
# =============================

echo "Récupération des adresses IP..."

RAW_WEB_IPS=$(docker compose -f docker-compose.yml run --rm terraform output web_server_ips_public)
RAW_VPN_PUBLIC_IPS=$(docker compose -f docker-compose.yml run --rm terraform output vpn_ips_public)

WEB_IPS=$(echo "$RAW_WEB_IPS" | tr -d '[]" ,' | tr '\n' ' ')
VPN_PUBLIC_IPS=$(echo "$RAW_VPN_PUBLIC_IPS" | tr -d '[]" ,' | tr '\n' ' ')
# =============================
#   Génération de l'inventaire Ansible
# =============================

echo "Génération de l'inventaire Ansible..."

echo "[web]" > inventory.ini
for ip in $WEB_IPS; do
  echo "$ip ansible_user=debian ansible_ssh_private_key_file=$SSH_KEY_PATH" >> inventory.ini
done

echo "[vpn]" >> inventory.ini
for ip in $VPN_PUBLIC_IPS; do
  echo "$ip ansible_user=debian ansible_ssh_private_key_file=$SSH_KEY_PATH" >> inventory.ini
done

# =============================
#   Playbook Ansible
# =============================

echo "Attente de 3 secondes avant le lancement du playbook Ansible..."
sleep 3

echo "Exécution du playbook Ansible..."
export LC_ALL=C.UTF-8
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini install_services.yml

echo "Provisioning terminé avec succès !"
echo "Serveurs Web       : $WEB_IPS"
echo "Serveurs VPN Public: $VPN_PUBLIC_IPS"
