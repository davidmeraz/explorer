pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sincronización en vivo con el tema Gema de Hyprland (~/.config/gema/preferences.json).
QtObject {
    id: gemaTheme
    property color accent: "#c4dcff"
    property int rounding: 18
    property bool blur: true
    property bool animations: true
    property bool darkText: false
    property int gemShape: 7
    property bool synced: false

    readonly property string preferencesPath: Quickshell.env("GEMA_SETTINGS_PATH")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/gema/preferences.json")

    function tintColor(baseColor, alphaMix) {
        const c = Qt.color(baseColor);
        const a = Qt.color(accent);
        return Qt.rgba(
            c.r * (1 - alphaMix) + a.r * alphaMix,
            c.g * (1 - alphaMix) + a.g * alphaMix,
            c.b * (1 - alphaMix) + a.b * alphaMix,
            c.a
        );
    }

    function accentAlpha(alpha) {
        const a = Qt.color(accent);
        return Qt.rgba(a.r, a.g, a.b, alpha);
    }

    function load() {
        try {
            const raw = prefsFile.text();
            if (!raw) return;
            const data = JSON.parse(raw);
            if (typeof data.accent === "string" && /^#[0-9a-fA-F]{6}$/.test(data.accent))
                accent = data.accent.toLowerCase();
            if (typeof data.rounding === "number" && isFinite(data.rounding))
                rounding = Math.max(8, Math.min(28, Math.round(data.rounding)));
            if (typeof data.blur === "boolean")
                blur = data.blur;
            if (typeof data.animations === "boolean")
                animations = data.animations;
            if (typeof data.darkText === "boolean")
                darkText = data.darkText;
            if (typeof data.gemShape === "number")
                gemShape = data.gemShape;
            synced = true;
        } catch (e) {}
    }

    readonly property FileView prefsFile: FileView {
        path: gemaTheme.preferencesPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: gemaTheme.load()
        onFileChanged: {
            reload();
            gemaTheme.load();
        }
    }

    Component.onCompleted: load()
}
