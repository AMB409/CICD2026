#!/usr/bin/env bash
set -euo pipefail

# --- PARAMÈTRE OBLIGATOIRE ---
TEAM_ID="${1:-}"
if [ -z "${TEAM_ID}" ]; then
  echo "Usage: $0 <TEAM_ID>"
  exit 1
fi

# --- DÉTECTION DE L'IP ---
NODE_IP=$(hostname -I | awk '{print $1}')
if [ -z "${NODE_IP}" ]; then
  echo "Erreur: impossible de détecter l'adresse IP du nœud."
  exit 1
fi

# Si K3s est déjà installé, on lance le script de désinstallation officiel.
echo "--- 1. Désinstallation complète si k3s existe déjà ---"
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    sudo /usr/local/bin/k3s-uninstall.sh
fi

sudo rm -rf /etc/rancher/k3s /var/lib/rancher/k3s "$HOME/.kube"

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X

# INSTALL_K3S_EXEC permet de passer des arguments au service K3s 
echo "--- 2. Installation de k3s (control-plane) ---"
  curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="\
  server \
  --node-ip ${NODE_IP} \
  --advertise-address ${NODE_IP} \
  --tls-san ${NODE_IP} \
  --disable traefik \
  --write-kubeconfig-mode 644" \
  sh -s -


# On attend que K3s finisse de générer les certificats et les fichiers de config.
echo "--- 3. Attente que k3s soit prêt ---"
for i in {1..20}; do
  if sudo kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Par défaut, K3s crée une config accessible uniquement en root.
# On la copie dans le répertoire de l'utilisateur pour simplifier l'usage.
echo "--- 4. Configuration du kubeconfig utilisateur ---"
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"

# Par défaut, le fichier pointe sur 127.0.0.1. 
# On le remplace par l'IP réelle pour permettre l'accès réseau extérieur.
sed -i "s/127.0.0.1/${NODE_IP}/g" "$HOME/.kube/config"

# Affiche l'état des nœuds pour confirmer que le control-plane est opérationnel.
echo "--- 5. Installation terminée ---"
kubectl get nodes
echo "API Server : https://${NODE_IP}:6443"
echo "Kubeconfig : ~/.kube/config"
