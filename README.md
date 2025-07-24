# Vault + Kubernetes AuthN Demo with KIND

This repository sets up a local KIND cluster to demonstrate how Vault can authenticate using:

- Kubernetes Auth method (ServiceAccount tokens)
- JWT Auth method (using external JWKS)
- Projected ServiceAccountTokens with short TTLs and audience restrictions

You will run 3 example pods, each authenticating to Vault using one of the above methods.

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Vault CLI](https://developer.hashicorp.com/vault/downloads)

---

## Setup Instructions

### 1. Create KIND Cluster

```bash
kind create cluster -n sa-demo
```

### 2. Create Namespace & Install Vault

```bash
kubectl create ns vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault \
  -n vault \
  -f vault/values.yaml
```

### 3. Configure Vault (after Helm install) with Vault Setup README

Head to `vault/setup.md`. Then execute the Vault CLI command in the shell of the Vault Pod `vault-0`

This will:

- Enable `kubernetes` and `jwt` auth methods
- Configure the JWT method with the JWKS endpoint
- Create Vault policies and roles for each Pod

### 4. Deploy Pods & ServiceAccounts via Helm

```bash
helm upgrade --install demo .
```

### 5. JWT Auth Pod

#### 1. Read the ServiceAccount token

```sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

#### 2. Print the Token for tokens.md file

```sh
echo "$TOKEN"
```

#### 3. Decode & pretty-print the JWT payload

```sh
echo "---- Decoded Payload ----"
echo "$TOKEN" | jq -R '
  split(".")[1]
  | gsub("-"; "+")
  | gsub("_"; "/")
  | @base64d
  | fromjson
  | .issued_at  = (.iat | tonumber | todate)
  | .expires_at = (.exp | tonumber | todate)
  | del(.iat, .exp)
'
```

#### 4. Login to Vault via the JWT auth method and read secret

```sh
# Set Vault address correctly
export VAULT_ADDR=http://vault.vault.svc:8200

# Login with JWT
vault write auth/jwt/login role=jwt-auth-role jwt="$TOKEN"

# Save Vault token
VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=jwt-auth-role jwt="$TOKEN")

# Use the token to read the secret
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/jwt
```

---

### 6. Kubernetes Auth Pod

#### 1. Read the ServiceAccount token

```sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

#### 2. Print the Token for tokens.md file

```sh
echo "$TOKEN"
```

#### 3. Decode & pretty-print the JWT payload

```sh
echo "---- Decoded Payload ----"
echo "$TOKEN" | jq -R '
  split(".")[1]
  | gsub("-"; "+")
  | gsub("_"; "/")
  | @base64d
  | fromjson
  | .issued_at  = (.iat | tonumber | todate)
  | .expires_at = (.exp | tonumber | todate)
  | del(.iat, .exp)
'
```

#### 4. Login to Vault via the Kubernetes auth method and read secret

```sh
# Set Vault address correctly
export VAULT_ADDR=http://vault.vault.svc:8200

# Login with k8s
vault write auth/kubernetes/login role=k8s-auth-role jwt="$TOKEN"

# Save Vault token
VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login role=k8s-auth-role jwt="$TOKEN")

# Use the token to read the secret
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/k8s
```

---

### 7. Projected SA Token Pod

#### 1. Read the projected ServiceAccount token

```sh
# Check out the different token path
TOKEN=$(cat /var/run/secrets/projected/token)
```

#### 2. Print the Token for tokens.md file

```sh
echo "$TOKEN"
```

#### 3. Decode & pretty-print the JWT payload

```sh
echo "---- Decoded Payload ----"
echo "$TOKEN" | jq -R '
  split(".")[1]
  | gsub("-"; "+")
  | gsub("_"; "/")
  | @base64d
  | fromjson
  | .issued_at  = (.iat | tonumber | todate)
  | .expires_at = (.exp | tonumber | todate)
  | del(.iat, .exp)
'
```

#### 4. Login to Vault via the JWT auth method and read secret

```sh
# Set Vault address correctly
export VAULT_ADDR=http://vault.vault.svc:8200

# Login with Kubernetes auth
vault write auth/jwt/login role=projected-auth-role jwt="$TOKEN"

# Save Vault token
VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=projected-auth-role jwt="$TOKEN")

# Use the token to read the secret
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/projected
```

### 8. No Project SA Token Pod

#### 1. Read the ServiceAccount token

```sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

#### 2. Print the Token for tokens.md file

```sh
echo "$TOKEN"
```

#### 3. Decode & pretty-print the JWT payload

```sh
echo "---- Decoded Payload ----"
echo "$TOKEN" | jq -R '
  split(".")[1]
  | gsub("-"; "+")
  | gsub("_"; "/")
  | @base64d
  | fromjson
  | .issued_at  = (.iat | tonumber | todate)
  | .expires_at = (.exp | tonumber | todate)
  | del(.iat, .exp)
'
```

#### 4. Login to Vault via the JWT auth method and read secret

```sh
# Set Vault address correctly
export VAULT_ADDR=http://vault.vault.svc:8200

# Login with Kubernetes auth
vault write auth/jwt/login role=projected-auth-role jwt="$TOKEN"

# Save Vault token
VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=projected-auth-role jwt="$TOKEN")

# Use the token to read the secret
VAULT_TOKEN=$VAULT_TOKEN vault kv get secret/projected

# AUDIENCE IS NOT THE SAME!
```
