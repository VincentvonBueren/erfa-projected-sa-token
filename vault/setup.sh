#!/bin/bash

set -euo pipefail

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
: "${KUBERNETES_SERVICE_HOST:=$(kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}')}"
: "${KUBERNETES_SERVICE_PORT:=443}"


# Port-forward Vault for local access
echo "[+] Port-forwarding Vault..."
kubectl -n vault port-forward svc/vault 8200:8200 &
sleep 5

# Enable Kubernetes auth method
echo "[+] Enabling Kubernetes auth method..."
vault auth enable kubernetes || true

# Configure Kubernetes auth method
vault write auth/kubernetes/config \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
  kubernetes_ca_cert="@var/run/secrets/kubernetes.io/serviceaccount/ca.crt" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"

# Enable JWT auth method
echo "[+] Enabling JWT auth method..."
vault auth enable jwt || true

# Configure JWT auth method with JWKS endpoint
vault write auth/jwt/config \
  jwks_url="https://kubernetes.default.svc/openid/v1/jwks"  \
  bound_issuer="https://kubernetes.default.svc.cluster.local" \
  jwks_ca_pem="$(kubectl get configmap -n kube-system kube-root-ca.crt -o jsonpath='{.data.ca\.crt}')"

# Create policies
vault policy write jwt-policy - <<EOF
path "secret/data/jwt" {
  capabilities = ["read"]
}
EOF

vault policy write k8s-policy - <<EOF
path "secret/data/k8s" {
  capabilities = ["read"]
}
EOF

vault policy write projected-policy - <<EOF
path "secret/data/projected" {
  capabilities = ["read"]
}
EOF

# Create roles
vault write auth/kubernetes/role/k8s-auth-role \
  bound_service_account_names="k8s-auth-sa" \
  bound_service_account_namespaces="demo" \
  policies="k8s-policy" \
  ttl="30m"

vault write auth/jwt/role/projected-auth-role \
  policies="projected-policy" \
  role_type="jwt" \
  user_claim="sub" \
  bound_audiences="vault" \
  bound_subject="system:serviceaccount:demo:projected-auth-sa" \
  ttl="10m"

vault write auth/jwt/role/jwt-auth-role \
  role_type="jwt" \
  user_claim="sub" \
  bound_audiences="https://kubernetes.default.svc.cluster.local" \
  bound_subject="system:serviceaccount:demo:jwt-auth-sa" \
  policies="jwt-policy" \

# Write secrets to Vault
echo "[+] Writing secrets to Vault..."
vault kv put secret/jwt value="hello from jwt"
vault kv put secret/k8s value="hello from k8s"
vault kv put secret/projected value="hello from projected"


echo "[✓] Vault configuration complete."