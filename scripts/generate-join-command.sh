#!/bin/bash

# Generate new token
TOKEN_ID=$(openssl rand -hex 3)
TOKEN_SECRET=$(openssl rand -hex 8)
FULL_TOKEN="${TOKEN_ID}.${TOKEN_SECRET}"

# Create the bootstrap token secret
kubectl create secret generic bootstrap-token-${TOKEN_ID} \
  --type=bootstrap.kubernetes.io/token \
  --namespace=kube-system \
  --from-literal=token-id=${TOKEN_ID} \
  --from-literal=token-secret=${TOKEN_SECRET} \
  --from-literal=usage-bootstrap-authentication=true \
  --from-literal=usage-bootstrap-signing=true \
  --from-literal=auth-extra-groups=system:bootstrappers:kubeadm:default-node-token \
  --from-literal=expiration=$(date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+24 hours" +"%Y-%m-%dT%H:%M:%SZ")

# Print the join command
echo ""
echo "Run this command on your worker node:"
echo "kubeadm join 116.202.22.162:6443 --token ${TOKEN_ID}.${TOKEN_SECRET} --discovery-token-unsafe-skip-ca-verification"


