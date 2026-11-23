#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home/carpeta" "$tmp/home/segunda" "$tmp/config"
touch "$tmp/home/archivo.txt" "$tmp/home/otro.txt"
log="$tmp/log"
if ! HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" GEMA_SETTINGS_PATH="$tmp/config/preferences.json" \
    timeout --foreground 30s qs --no-color -p "$root/smoke-ui.qml" >"$log" 2>&1; then
    cat "$log" >&2
    echo 'Smoke Wayland: qs falló o agotó el tiempo.' >&2
    exit 1
fi
if ! grep -q 'EXPLORER_SMOKE_OK' "$log" || grep -q 'SMOKE_ERROR' "$log"; then
    cat "$log" >&2
    echo 'Smoke Wayland: faltó el marcador de éxito.' >&2
    exit 1
fi
grep 'SMOKE_HYPRLAND:' "$log"
echo 'Smoke Wayland: UI y navegación verificadas.'
