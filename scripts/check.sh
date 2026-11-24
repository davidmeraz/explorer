#!/usr/bin/env bash
# Validación QML, pruebas Rust y respuesta IPC del motor.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_root"
qmllint="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"
command -v "$qmllint" >/dev/null || { echo 'Falta qmllint de Qt 6; define QMLLINT con su ruta.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Falta python3.' >&2; exit 1; }
"$qmllint" -i ui/components/qmldir shell.qml ui/*.qml ui/components/*.qml
cargo test --locked --manifest-path backend/Cargo.toml
response="$(printf '{"version":2,"type":"app.check"}\n{"type":"app.check"}\n{"version":2,"type":"fs.list","data":{"path":"/","showHidden":false}}\n' | "$app_root/backend/run-backend.sh")"
python3 -c 'import json, sys
try:
    lines = sys.argv[1].rstrip("\n").split("\n")
    assert len(lines) == 4
    ready, event, error, listing = map(json.loads, lines)
    assert ready["version"] == 2 and ready["type"] == "app.ready"
    assert event["version"] == 2 and event["type"] == "app.checked"
    assert event["data"]["ok"] is True and event["data"]["engine"] == "rust"
    assert error["version"] == 2 and error["type"] == "error"
    assert listing["version"] == 2 and listing["type"] == "fs.listed"
    assert listing["data"]["path"] == "/" and isinstance(listing["data"]["skipped"], int)
except (ValueError, KeyError, TypeError, AssertionError) as exc:
    sys.exit("Respuesta IPC inválida: " + str(exc))' "$response"
echo "Explorer: QML, pruebas Rust e IPC verificados."
