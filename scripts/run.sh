#!/usr/bin/env bash
# Lanzador de aplicación Gema UI Kit en Quickshell.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec qs --no-duplicate --path "$app_root/shell.qml" "$@"
