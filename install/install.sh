#!/usr/bin/env bash
set -euo pipefail

FLARE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HS_MODULES="${HOME}/.hammerspoon"

echo "Installing Flare..."

# Check for Hammerspoon
if [[ ! -d "$HS_MODULES" ]]; then
  echo "Error: ~/.hammerspoon not found. Install Hammerspoon first:"
  echo "  brew install --cask hammerspoon"
  exit 1
fi

# Check for hs CLI
if ! command -v hs &>/dev/null; then
  echo "Warning: 'hs' CLI not found on PATH."
  echo "Enable it in Hammerspoon > Preferences > Enable CLI."
fi

# Symlink Lua module
mkdir -p "${HS_MODULES}/flare"
for f in init.lua flare.lua animations.lua http.lua; do
  ln -sfn "${FLARE_DIR}/flare/${f}" "${HS_MODULES}/flare/${f}"
done
echo "Linked Lua module to ${HS_MODULES}/flare/"

# Symlink CLI
ln -sfn "${FLARE_DIR}/cli/flare" /usr/local/bin/flare
chmod +x "${FLARE_DIR}/cli/flare"
echo "Linked CLI to /usr/local/bin/flare"

# Add require line to init.lua if not present
INIT_FILE="${HS_MODULES}/init.lua"
touch "$INIT_FILE"
if ! grep -q 'require.*flare' "$INIT_FILE" 2>/dev/null; then
  echo 'require("flare")' >>"$INIT_FILE"
  echo "Added require(\"flare\") to ${INIT_FILE}"
else
  echo "require(\"flare\") already in ${INIT_FILE}"
fi

echo ""
echo "Done. Reload Hammerspoon to activate Flare."
