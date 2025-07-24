FROM alpine:3.20

# Install dependencies, jq, unzip, and bash
RUN apk add --no-cache \
  curl \
  bash \
  jq \
  unzip \
  \
  # Install yq (v4.x) binary
  && wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/download/v4.35.1/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq \
  \
  # Install Vault CLI
  && curl -sLo /tmp/vault.zip \
  https://releases.hashicorp.com/vault/1.16.2/vault_1.16.2_linux_amd64.zip \
  && unzip /tmp/vault.zip -d /usr/local/bin/ \
  && rm /tmp/vault.zip

ENTRYPOINT ["sleep", "3600"]
