#!/usr/bin/env bash
# Godot 4.7.1 + webes export sablon + szoftveres Vulkan letöltése egy friss Linux-gépre (pl. Claude Code felhőben).
set -euo pipefail
V=4.7.1
BIN="$HOME/godot-bin"
TPL="$HOME/.local/share/godot/export_templates/$V.stable"
mkdir -p "$BIN" "$TPL"
if [ ! -x "$BIN/godot" ]; then
  curl -sSL -o /tmp/g.zip "https://github.com/godotengine/godot/releases/download/$V-stable/Godot_v$V-stable_linux.x86_64.zip"
  unzip -q -o /tmp/g.zip -d "$BIN" && mv "$BIN"/Godot_v* "$BIN/godot" && rm /tmp/g.zip
fi
if [ "${1:-}" = "--web" ] && [ ! -f "$TPL/web_nothreads_release.zip" ]; then
  curl -sSL -o /tmp/t.tpz "https://github.com/godotengine/godot/releases/download/$V-stable/Godot_v$V-stable_export_templates.tpz"
  unzip -q -o -j /tmp/t.tpz templates/web_nothreads_release.zip templates/version.txt -d "$TPL" && rm /tmp/t.tpz
fi
if ! ls /usr/share/vulkan/icd.d/lvp_icd.json >/dev/null 2>&1; then
  (apt-get update -qq && apt-get install -y -qq mesa-vulkan-drivers libvulkan1 xvfb) >/dev/null
fi
"$BIN/godot" --headless --version
