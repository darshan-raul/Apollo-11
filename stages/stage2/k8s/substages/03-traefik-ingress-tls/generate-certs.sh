#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="$(mktemp -d)"
trap 'rm -rf "$CERT_DIR"' EXIT

echo "Generating self-signed certificate for *.apollo.local..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/tls.key" \
  -out "${CERT_DIR}/tls.crt" \
  -subj "/CN=*.apollo.local" \
  -addext "subjectAltName=DNS:*.apollo.local,DNS:apollo.local" >/dev/null 2>&1

for ns in apollo-airlines-apps apollo-airlines-ui; do
  if kubectl get namespace "$ns" &>/dev/null; then
    kubectl create secret tls apollo-tls-secret \
      --cert="${CERT_DIR}/tls.crt" \
      --key="${CERT_DIR}/tls.key" \
      -n "$ns" --dry-run=client -o yaml | kubectl apply -f -
    echo "Configured secret apollo-tls-secret in namespace $ns"
  fi
done
