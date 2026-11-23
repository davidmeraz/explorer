#!/usr/bin/env bash
# Instala un lanzador de menú únicamente para el usuario actual.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
case "$data_home" in /*) ;; *) echo 'XDG_DATA_HOME debe ser absoluto.' >&2; exit 1;; esac
# Los saltos de línea no son representables de forma fiable en un archivo desktop.
case "$data_home$app_root" in *$'\n'*|*$'\r'*) echo 'Las rutas no pueden contener saltos de línea.' >&2; exit 1;; esac
wrapper="$data_home/explorer/run"
mkdir -p -- "$data_home/explorer" "$data_home/applications"
{
    printf '#!/usr/bin/env bash\n'
    printf 'exec %q "$@"\n' "$app_root/scripts/run.sh"
} > "$wrapper"
chmod 755 "$wrapper"
# Exec sigue las reglas de Desktop Entry, no las del shell. Escapar también %
# para que no se interprete como código de campo.
exec_path=${wrapper//\\/\\\\\\\\}
exec_path=${exec_path//\"/\\\\\"}
exec_path=${exec_path//\$/\\\\\$}
exec_path=${exec_path//\`/\\\\\`}
exec_path=${exec_path//%/%%}
{
    printf '[Desktop Entry]\nType=Application\nName=Explorer\n'
    printf 'Comment=Explorador de archivos\nExec="%s"\n' "$exec_path"
    printf 'Terminal=false\nCategories=Utility;FileManager;\n'
} > "$data_home/applications/explorer.desktop"
echo "Instalado: $data_home/applications/explorer.desktop"
echo "Lanzador: $wrapper"
