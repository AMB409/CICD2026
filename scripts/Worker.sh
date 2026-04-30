#!/usr/bin/env bash
set -euo pipefail

# --- 1. PARAMETRES ---
CP_IP="${1:-}"
TOKEN="${2:-}"

if [ -z "${CP_IP}" ] || [ -z "${TOKEN}" ]; then
  echo "Usage: $0 <CONTROL_PLANE_IP> <NODE_TOKEN>"
  exit 1
fi

NODE_IP=$(hostname -I | awk '{print $1}')

echo "--- 2. NETTOYAGE ---"
[ -f /usr/local/bin/k3s-uninstall.sh ] && sudo /usr/local/bin/k3s-uninstall.sh
[ -f /usr/local/bin/k3s-agent-uninstall.sh ] && sudo /usr/local/bin/k3s-agent-uninstall.sh

sudo rm -rf /etc/rancher/k3s /var/lib/rancher/k3s
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -X

echo "--- 3. INSTALLATION EN MODE AGENT ---"
# Correction de l'URL (get.k3s.io) et tout sur une seule ligne
curl -sfL https://get.k3s.io | sudo K3S_URL="https://${CP_IP}:6443" K3S_TOKEN="${TOKEN}" sh -s - agent --node-ip "${NODE_IP}"

echo "--- 4. VERIFICATION ---"
sleep 10
echo "État de k3s-agent : "
systemctl is-active k3s-agent
