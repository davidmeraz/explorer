# Explorer 0.1.0

Explorador de archivos para Wayland, con interfaz Quickshell/Qt Quick y motor Rust. Está orientado a Arch Linux y Hyprland; no instala asociaciones de archivos ni modifica la configuración del compositor.

## Requisitos en Arch

- Una sesión Wayland (por ejemplo, Hyprland) y Quickshell disponible como `qs`. Quickshell puede instalarse desde AUR como `quickshell-git` o desde otra fuente compatible; no se presupone que esté en los repositorios oficiales habilitados.
- `rust` (incluye Cargo), para compilar el motor al iniciarlo; la primera compilación puede necesitar acceso a las dependencias de Cargo.
- `qt6-declarative` para Qt Quick y `/usr/lib/qt6/bin/qmllint`. El Quickshell instalado debe disponer de sus módulos Qt/Quickshell correspondientes.
- `python` para la comprobación IPC y `bash` para los scripts. `desktop-file-utils` es opcional para validar el lanzador.

## Inicio y pruebas

Desde este directorio:

```sh
./scripts/run.sh
./scripts/check.sh
```

El primer comando inicia la aplicación en la sesión gráfica; el segundo ejecuta `qmllint` de Qt 6, las pruebas Rust y un intercambio IPC real con el motor. `qmllint` puede emitir advertencias de tipos o importaciones; los errores causan fallo. Fuera de Arch se puede indicar el ejecutable Qt 6 con `QMLLINT=/ruta/a/qmllint ./scripts/check.sh`. Las pruebas no sustituyen la comprobación visual en una sesión Wayland.

## Menú de aplicaciones (opcional)

El vidrio sigue las preferencias Gema en `${XDG_CONFIG_HOME:-$HOME/.config}/gema/preferences.json`; opcionalmente `GEMA_SETTINGS_PATH` permite indicar otro archivo. Se usan las preferencias de acento, radio, blur y `darkText` sin modificar el archivo. La legibilidad y el desenfoque dependen también del compositor y del fondo.

```sh
./scripts/install-desktop.sh
```

No requiere privilegios: instala `explorer.desktop` en `${XDG_DATA_HOME:-$HOME/.local/share}/applications/` y un wrapper en `${XDG_DATA_HOME:-$HOME/.local/share}/explorer/run`. El menú puede tardar en actualizarse. El wrapper apunta a esta copia del proyecto: si se mueve, vuelve a ejecutar el instalador desde la nueva ubicación. No borres el proyecto mientras uses el lanzador. Opcionalmente, valida el archivo con `desktop-file-validate "$HOME/.local/share/applications/explorer.desktop"` (ajusta la ruta si usas `XDG_DATA_HOME`).

Para desinstalar solo la integración:

```sh
rm -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/applications/explorer.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/explorer/run"
rmdir -- "${XDG_DATA_HOME:-$HOME/.local/share}/explorer"  # si está vacío
```

Esto no elimina el proyecto ni los artefactos de compilación en `backend/target`.

### Atajo Hyprland opcional

Si lo deseas, añade manualmente a tu configuración de Hyprland (ajusta la ruta y evita conflictos):

```ini
bind = SUPER, E, exec, /home/USUARIO/.local/share/explorer/run
```

Usa la ruta real del wrapper mostrada por el instalador; consulta la sintaxis de Hyprland si contiene caracteres especiales. Recarga Hyprland después. El instalador no añade ni elimina este atajo.

## Atajos de la aplicación

- `Alt+Izquierda`: volver.
- `Alt+Arriba`: carpeta superior.
- `Ctrl+L`: seleccionar la ruta para editarla.
- `F5`: actualizar la carpeta.
- `Enter` en la lista: abrir la entrada seleccionada.
