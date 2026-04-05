#!/bin/bash
set -euo pipefail
exec >> /var/log/user-data.log 2>&1

echo "=== $(date) Starting K3S bootstrap ==="

# Install K3S — write-kubeconfig-mode 644 so the ubuntu user can read it
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Wait until the node reports Ready before continuing
echo "Waiting for K3S node to become Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do
  sleep 5
done
echo "K3S node is Ready."

# Copy kubeconfig into ubuntu's home so 'kubectl' works without sudo
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

echo "=== $(date) K3S bootstrap complete ==="
