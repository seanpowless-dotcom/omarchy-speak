#!/bin/bash
# Install omarchy-speak into ~/.local/bin and set up the user service.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

install -Dm755 "$SRC/bin/omarchy-speak"     "$BIN/omarchy-speak"
install -Dm755 "$SRC/bin/omarchy-speak-ctl" "$BIN/omarchy-speak-ctl"
echo "installed → $BIN/omarchy-speak{,-ctl}"

[[ -f "$HOME/.config/omarchy-speak/config.json" ]] \
  || "$BIN/omarchy-speak" --init-config

install -Dm644 "$SRC/systemd/omarchy-speak.service" \
  "$HOME/.config/systemd/user/omarchy-speak.service"
systemctl --user daemon-reload
echo "service installed. enable with:"
echo "  systemctl --user enable --now omarchy-speak"
echo
echo "then add the keybindings from $SRC/hypr/speak.lua"
echo "to ~/.config/hypr/bindings.lua"
