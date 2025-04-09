#!/bin/bash

# Récupérer l'adresse IP avec Terraform
IP=$(docker compose -f docker-compose.yml run --rm terraform output -raw web_server_ip)

# Générer le fichier d'inventaire pour Ansible
cat <<EOF > inventory.ini
[web]
$IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/test
EOF

echo "Inventaire Ansible généré avec IP: $IP"
