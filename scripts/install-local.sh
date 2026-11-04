#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE_APP="$ROOT/dist/OwnWords.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/原話.app"

zsh "$ROOT/scripts/build-app.sh"
pkill -x LocalVoiceInputMac 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"
open "$INSTALLED_APP"

echo "$INSTALLED_APP"
