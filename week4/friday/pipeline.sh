#!/bin/bash
set -e

echo "=== Running Terraform ==="

cd terraform

terraform apply -auto-approve

API_IP=$(terraform output -raw api_server_ip)
PAYMENTS_IP=$(terraform output -raw payments_server_ip)
LOGS_IP=$(terraform output -raw logs_server_ip)

cd ..

echo "=== Generating inventory ==="

cat > ansible/inventory.ini <<EOF
[kijanikiosk]
api-staging ansible_host=$API_IP
payments-staging ansible_host=$PAYMENTS_IP
logs-staging ansible_host=$LOGS_IP

[kijanikiosk:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/kijanikiosk-key.pem
EOF

echo "=== Running Ansible ==="

cd ansible
ansible-playbook -i inventory.ini kijanikiosk.yml
