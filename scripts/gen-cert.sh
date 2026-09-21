#!/usr/bin/env bash
# Generate a self-signed TLS certificate for the Godot web host.
# Godot HTML5 exports require a "secure context" (HTTPS or localhost), so the
# server must speak HTTPS. This cert is self-signed; the browser will warn once
# and you accept it. Regenerate by deleting certs/ and re-running.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="${CERT_DIR:-$PROJECT_DIR/certs}"
CERT="$CERT_DIR/cert.pem"
KEY="$CERT_DIR/key.pem"

if [ -f "$CERT" ] && [ -f "$KEY" ]; then
    exit 0
fi

mkdir -p "$CERT_DIR"

HOST_IP="${HOST_IP:-37.187.131.157}"
EXTRA_SAN="${EXTRA_SAN:-}"

SAN="DNS:localhost,IP:127.0.0.1,IP:${HOST_IP}"
if [ -n "$EXTRA_SAN" ]; then
    SAN="${SAN},${EXTRA_SAN}"
fi

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$KEY" -out "$CERT" -days 825 \
    -subj "/CN=horrorscratcher" \
    -addext "subjectAltName=${SAN}" \
    -addext "basicConstraints=critical,CA:TRUE" \
    >/dev/null 2>&1

chmod 600 "$KEY"
echo ">> Generated self-signed cert: $CERT"
echo ">> SAN: $SAN"
