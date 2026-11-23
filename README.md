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

Con una sesión Wayland disponible, `quickshell -p card-smoke.qml` instancia la tarjeta real y comprueba su selección y cambio de tipo; debe aparecer `CARD_TEST_OK` en el registro.

## Interfaz y procedencia

Smoke opcional de la UI real en una sesión Wayland (requiere `qs`, el módulo QML `QtTest`, `timeout` y el backend compilable): `bash scripts/smoke-wayland.sh`. Usa HOME y configuración temporales con una carpeta y un archivo de prueba; comprueba los delegates, clic en lista, selección y foco al cambiar de vista y navegación con Enter, sin abrir archivos externos. Sale con error si falla la comprobación o vence el tiempo.

La cuadrícula de tarjetas grandes es la vista inicial; los botones permiten cambiar a lista. Un clic selecciona, doble clic o Enter abre, y las migas permiten navegar a cualquier carpeta antecesora. Se conservan el historial, la edición de ruta, el refresco y la opción de mostrar ocultos. Los documentos muestran etiqueta y color según su extensión.

El arte vectorial QML de carpetas de cristal y documentos doblados de `ui/components/ExplorerIconCard.qml` está adaptado de `ui/components/windows/ExplorerIconCard.qml` de Agent Shell. Las migas y los modos de vista se inspiran en `ui/components/windows/ProjectExplorerWindow.qml` del mismo proyecto; la integración y la paleta por extensión están adaptadas a Explorer y GemaTheme.

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
- `Ctrl+1`: cuadrícula de iconos grandes.
- `Ctrl+2`: lista.
- `F5`: actualizar la carpeta.
- `Enter` en la cuadrícula o lista: abrir la entrada seleccionada; flechas para seleccionarla.
