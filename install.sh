#!/bin/bash
# Install omarchy-speak into ~/.local/bin and set up the user service.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

install -Dm755 "$SRC/bin/omarchy-speak"        "$BIN/omarchy-speak"
install -Dm755 "$SRC/bin/omarchy-speak-ctl"    "$BIN/omarchy-speak-ctl"
install -Dm755 "$SRC/bin/omarchy-speak-picker" "$BIN/omarchy-speak-picker"
install -Dm755 "$SRC/bin/omarchy-speak-ui"     "$BIN/omarchy-speak-ui"
echo "installed → $BIN/omarchy-speak{,-ctl,-picker,-ui}"

# kokoro-onnx is a pip package, so it usually lives in a venv rather than in
# the system python. Point the wrapper at that venv if it exists; otherwise
# leave the portable shebang, which works when kokoro-onnx is importable
# system-wide (an AUR/distro install, say).
KOKORO_VENV="$HOME/.local/share/omarchy-speak/venv/bin/python"
install -Dm755 "$SRC/bin/omarchy-speak-kokoro" "$BIN/omarchy-speak-kokoro"
if [[ -x "$KOKORO_VENV" ]]; then
  sed -i "1s|.*|#!$KOKORO_VENV|" "$BIN/omarchy-speak-kokoro"
  echo "kokoro wrapper pointed at $KOKORO_VENV"
fi

# Optional Omarchy bar module. Installing the script is harmless on its own --
# it does nothing until an entry is added to shell.json -- so it goes in
# whenever the directory it belongs to already exists.
if [[ -d "$HOME/.config/omarchy" ]]; then
  install -Dm755 "$SRC/omarchy/bar/scripts/speak-status" \
    "$HOME/.config/omarchy/bar/scripts/speak-status"
  echo "bar module installed → add it to shell.json; see omarchy/README.md"
fi

[[ -f "$HOME/.config/omarchy-speak/config.json" ]] \
  || "$BIN/omarchy-speak" --init-config

install -Dm644 "$SRC/systemd/omarchy-speak.service" \
  "$HOME/.config/systemd/user/omarchy-speak.service"

# Optional: warm kokoro worker. Only useful once kokoro is installed.
if [[ -x "$BIN/omarchy-speak-kokoro" ]]; then
  install -Dm644 "$SRC/systemd/omarchy-speak-kokoro.service" \
    "$HOME/.config/systemd/user/omarchy-speak-kokoro.service"
  echo "kokoro worker unit installed (enable to skip the model load per utterance)"
fi

systemctl --user daemon-reload
echo "service installed. enable with:"
echo "  systemctl --user enable --now omarchy-speak"
echo
echo "then add the keybindings from $SRC/hypr/speak.lua"
echo "to ~/.config/hypr/bindings.lua"
