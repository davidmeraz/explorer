#!/usr/bin/env bash
set -euo pipefail
backend_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$backend_dir"
# Cargo comprueba todas las dependencias y evita recompilar si no hay cambios.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$backend_dir/target}"
if ! command -v cargo >/dev/null 2>&1; then
    echo '{"version":2,"type":"error","data":{"message":"Instala cargo para compilar el motor Rust."}}'
    exit 1
fi
cargo build --quiet --locked
exec "$CARGO_TARGET_DIR/debug/gema-backend"
