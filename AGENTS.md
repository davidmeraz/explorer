# Explorer · Gema UI Kit App

Aplicación de escritorio nativa para **Hyprland / Wayland** construida con el stack **Gema UI Kit**:

- **Estilo visual:** Matte Transparent Glassmorphism (`MattePanel`, `GlassPanel`, `WaterReflection`, `ActionButton`, `GlassDialog`, `GlassComboBox`, `GemaTheme`) en `ui/components/`, con vidrio mate transparente sin capa oscura y desenfoque real del compositor (`BackgroundEffect.blurRegion`).
- **Frontend:** Quickshell + QtQuick 6 QML (`shell.qml`, `ui/AppWindow.qml`, `ui/AppBridge.qml`).
- **Motor Backend:** Rust (`backend/src/main.rs`) conectado por `stdin`/`stdout` mediante JSON-Lines v2 (`{"version": 2, "type": "...", "data": {...}}`).
- **Probar aplicación:** `./scripts/check.sh`
- **Iniciar aplicación:** `./scripts/run.sh`
