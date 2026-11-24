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
response="$(printf '{"version":2,"type":"app.check"}\n{"type":"app.check"}\n{"version":2,"type":"fs.places"}\n{"version":2,"type":"fs.list","data":{"path":"/","showHidden":false,"sortBy":"mtime","sortDesc":true}}\n' | "$app_root/backend/run-backend.sh")"
python3 -c 'import json, sys
try:
    lines = sys.argv[1].rstrip("\n").split("\n")
    assert len(lines) == 5
    ready, event, error, places, listing = map(json.loads, lines)
    assert ready["version"] == 2 and ready["type"] == "app.ready"
    assert event["version"] == 2 and event["type"] == "app.checked"
    assert event["data"]["ok"] is True and event["data"]["engine"] == "rust"
    assert error["version"] == 2 and error["type"] == "error"
    assert places["version"] == 2 and places["type"] == "fs.places"
    assert isinstance(places["data"]["places"], list)
    assert any(p["path"] == "/" for p in places["data"]["places"])
    assert listing["version"] == 2 and listing["type"] == "fs.listed"
    assert listing["data"]["path"] == "/" and isinstance(listing["data"]["skipped"], int)
    assert listing["data"]["sortBy"] == "mtime" and listing["data"]["sortDesc"] is True
    assert all(type(e["mtime"]) is int for e in listing["data"]["entries"])
except (ValueError, KeyError, TypeError, AssertionError) as exc:
    sys.exit("Respuesta IPC inválida: " + str(exc))' "$response"
python3 - "$app_root/backend/target/release/gema-backend" <<'PY'
import json, os, pathlib, subprocess, sys, tempfile
with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    data = root / 'data'
    data.mkdir()
    env = dict(os.environ, XDG_DATA_HOME=str(data))
    proc = subprocess.Popen([sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
    assert json.loads(proc.stdout.readline())['type'] == 'app.ready'
    def request(kind, data):
        proc.stdin.write(json.dumps({'version': 2, 'type': kind, 'data': data}) + '\n')
        proc.stdin.flush()
        result = json.loads(proc.stdout.readline())
        assert result['type'] == 'fs.mutated', result
        return result['data']
    request('fs.mkdir', {'parent': tmp, 'name': 'uno'})
    request('fs.rename', {'path': str(root / 'uno'), 'newName': 'dos'})
    copy = request('fs.copy', {'source': str(root / 'dos'), 'destDir': tmp})
    trashed = request('fs.trash', {'path': copy['targetPath']})
    assert pathlib.Path(trashed['targetPath']).is_dir()
    assert list((data / 'Trash' / 'info').glob('*.trashinfo'))
    proc.stdin.close()
    assert proc.wait(timeout=10) == 0
PY
echo "Explorer: QML, pruebas Rust e IPC verificados."
