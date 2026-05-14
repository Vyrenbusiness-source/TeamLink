#!/usr/bin/env bash
# Baut den TeamLink macOS DMG-Installer.
# Voraussetzungen: Flutter SDK, Xcode Command Line Tools, create-dmg (brew install create-dmg)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/desktop-client"
DIST="$ROOT/dist"
APP_NAME="TeamLink"
DMG_NAME="TeamLink-macOS.dmg"

if ! command -v flutter &>/dev/null; then
  echo "ERROR: flutter nicht im PATH — https://docs.flutter.dev/get-started/install/macos" >&2
  exit 1
fi

if ! command -v create-dmg &>/dev/null; then
  echo "ERROR: create-dmg fehlt — brew install create-dmg" >&2
  exit 1
fi

cd "$CLIENT"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build macos --release"
flutter build macos --release

APP_PATH="$CLIENT/build/macos/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: $APP_PATH nicht gefunden — Build fehlgeschlagen." >&2
  exit 1
fi

mkdir -p "$DIST"

echo "==> DMG erstellen"

ICNS="$CLIENT/assets/icons/app_icon.icns"
VOLICON_ARGS=()
if [ -f "$ICNS" ]; then
  VOLICON_ARGS=(--volicon "$ICNS")
fi

# create-dmg gibt 2 zurück wenn kein Code-Signing-Zertifikat vorhanden —
# die DMG-Datei wird dennoch korrekt erstellt.
create-dmg \
  --volname "$APP_NAME" \
  "${VOLICON_ARGS[@]+"${VOLICON_ARGS[@]}"}" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 175 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 425 190 \
  "$DIST/$DMG_NAME" \
  "$APP_PATH" \
  || { _ec=$?; [ "$_ec" -eq 2 ] || { echo "ERROR: create-dmg fehlgeschlagen (exit $_ec)." >&2; exit "$_ec"; }; }

if [ -f "$DIST/$DMG_NAME" ]; then
  echo "==> Installer: $DIST/$DMG_NAME"
else
  echo "ERROR: DMG wurde nicht erstellt." >&2
  exit 1
fi
