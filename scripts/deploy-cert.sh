#!/usr/bin/env bash
# Certbot deploy hook: copy the issued Let's Encrypt cert into the project's
# certs/ directory so scripts/serve.mjs (running as the unprivileged user) can
# read it. Registered as --deploy-hook so renewals refresh it automatically.
set -euo pipefail

DOMAIN="${RENEWED_LINEAGE:-/etc/letsencrypt/live/37.187.131.157.sslip.io}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$PROJECT_DIR/certs"

if [ ! -f "$DOMAIN/fullchain.pem" ]; then
    echo "!! No certificate at $DOMAIN" >&2
    exit 1
fi

mkdir -p "$CERT_DIR"
install -m 644 "$DOMAIN/fullchain.pem" "$CERT_DIR/cert.pem"
install -m 600 "$DOMAIN/privkey.pem" "$CERT_DIR/key.pem"

# Keep ownership with the project owner so npm start can read the key.
OWNER="$(stat -c '%u:%g' "$PROJECT_DIR")"
chown "$OWNER" "$CERT_DIR/cert.pem" "$CERT_DIR/key.pem" 2>/dev/null || true

echo ">> Deployed certificate for $(basename "$DOMAIN") to $CERT_DIR"
