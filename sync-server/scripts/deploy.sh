#!/usr/bin/env bash
# Usage: bash scripts/deploy.sh
# Voraussetzungen: Node.js >= 18, optional pm2 (npm i -g pm2)
# Legt beim ersten Aufruf .env aus .env.example an (Werte prüfen!).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SERVER_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — review values before production use."
fi

npm ci --omit=dev

mkdir -p data

if command -v pm2 &>/dev/null; then
  pm2 restart teamlink-server --update-env 2>/dev/null || \
    pm2 start src/index.js --name teamlink-server
  pm2 save
else
  echo "pm2 not found — starting with node. Install pm2 for process supervision."
  NODE_ENV=production node src/index.js
fi
