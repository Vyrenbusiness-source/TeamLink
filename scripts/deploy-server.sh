#!/usr/bin/env bash
# Baut und deployt den TeamLink Sync-Server auf einem Linux/macOS-Host.
# Voraussetzungen: Node.js >= 18, npm, rsync, ssh-Zugang zum Zielhost
#
# Verwendung:
#   ./scripts/deploy-server.sh [user@host] [remote-verzeichnis]
#
# Beispiel:
#   ./scripts/deploy-server.sh deploy@example.com /srv/teamlink
#
# Umgebungsvariablen (überschreiben Argumente):
#   DEPLOY_HOST       – SSH-Ziel  (z.B. deploy@example.com)
#   DEPLOY_DIR        – Verzeichnis auf dem Zielhost
#   DEPLOY_ENV_FILE   – Pfad zur lokalen .env-Datei (wird übertragen)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_DIR="$ROOT/sync-server"

DEPLOY_HOST="${DEPLOY_HOST:-${1:-}}"
DEPLOY_DIR="${DEPLOY_DIR:-${2:-/srv/teamlink}}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$SERVER_DIR/.env}"

# ---------------------------------------------------------------------------
# Vorbedingungen prüfen
# ---------------------------------------------------------------------------
if [ -z "$DEPLOY_HOST" ]; then
  echo "ERROR: Kein Deploy-Host angegeben." >&2
  echo "       Verwendung: $0 user@host [remote-verzeichnis]" >&2
  echo "       Oder: DEPLOY_HOST=user@host $0" >&2
  exit 1
fi

if ! command -v rsync &>/dev/null; then
  echo "ERROR: rsync fehlt — bitte installieren (z.B. brew install rsync)." >&2
  exit 1
fi

if [ ! -f "$DEPLOY_ENV_FILE" ]; then
  echo "ERROR: .env-Datei nicht gefunden: $DEPLOY_ENV_FILE" >&2
  echo "       Kopiere sync-server/.env.example → sync-server/.env und passe an." >&2
  exit 1
fi

echo "==> Ziel: $DEPLOY_HOST:$DEPLOY_DIR"

# ---------------------------------------------------------------------------
# Produktions-Dependencies lokal installieren (nur prod)
# ---------------------------------------------------------------------------
echo "==> npm ci --omit=dev"
cd "$SERVER_DIR"
npm ci --omit=dev --silent

# ---------------------------------------------------------------------------
# Dateien auf Zielhost synchronisieren (kein node_modules, kein .env)
# ---------------------------------------------------------------------------
echo "==> rsync → $DEPLOY_HOST:$DEPLOY_DIR/sync-server"
ssh "$DEPLOY_HOST" "mkdir -p $DEPLOY_DIR/sync-server/data"

rsync -az --delete \
  --exclude='node_modules' \
  --exclude='.env' \
  --exclude='tests' \
  --exclude='*.log' \
  "$SERVER_DIR/" \
  "$DEPLOY_HOST:$DEPLOY_DIR/sync-server/"

# ---------------------------------------------------------------------------
# .env sicher übertragen (chmod 600)
# ---------------------------------------------------------------------------
echo "==> .env übertragen"
rsync -az --chmod=600 \
  "$DEPLOY_ENV_FILE" \
  "$DEPLOY_HOST:$DEPLOY_DIR/sync-server/.env"

# ---------------------------------------------------------------------------
# Dependencies auf dem Zielhost installieren, Server neu starten
# ---------------------------------------------------------------------------
echo "==> Remote: npm ci + server restart"
ssh "$DEPLOY_HOST" bash <<REMOTE
  set -euo pipefail
  cd "$DEPLOY_DIR/sync-server"
  npm ci --omit=dev --silent

  # Versuche systemd, dann pm2, dann einfachen Neustart
  if systemctl is-active --quiet teamlink-server 2>/dev/null; then
    systemctl restart teamlink-server
    echo "   systemd: teamlink-server restarted"
  elif command -v pm2 &>/dev/null; then
    pm2 restart teamlink-server 2>/dev/null || \
      pm2 start src/index.js --name teamlink-server
    echo "   pm2: teamlink-server restarted"
  else
    echo "   WARNUNG: Kein Prozessmanager gefunden." \
         "Server manuell starten: node src/index.js"
  fi
REMOTE

# ---------------------------------------------------------------------------
# Health-Check
# ---------------------------------------------------------------------------
echo "==> Health-Check"
HEALTH_PORT="$(grep -E '^PORT=' "$DEPLOY_ENV_FILE" 2>/dev/null | cut -d= -f2 || echo 3000)"
HEALTH_PORT="${HEALTH_PORT:-3000}"

MAX_RETRIES=10
RETRY=0
until ssh "$DEPLOY_HOST" \
  "curl -sf http://localhost:$HEALTH_PORT/health > /dev/null" 2>/dev/null; do
  RETRY=$((RETRY + 1))
  if [ $RETRY -ge $MAX_RETRIES ]; then
    echo "ERROR: Server antwortet nach $MAX_RETRIES Versuchen nicht auf /health." >&2
    exit 1
  fi
  echo "   Warte auf Server… ($RETRY/$MAX_RETRIES)"
  sleep 2
done

echo "==> Deploy erfolgreich. Server läuft auf $DEPLOY_HOST:$HEALTH_PORT"
