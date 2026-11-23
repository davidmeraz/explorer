import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "components"

FloatingWindow {
    id: window
    required property AppBridge bridge
    title: "Explorer"
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(480, 360)
    color: "transparent"
    visible: true
    BackgroundEffect.blurRegion: Region { item: GemaTheme.blur ? surface : null; radius: surface.radius }
    function openEntry(entry) {
        if (!entry || bridge.loading) return;
        if (entry.isDir) bridge.list(entry.path, bridge.showHidden, "navigate");
        else if (entry.isFile) {
            const url = "file://" + entry.path.split("/").map(s => encodeURIComponent(s)).join("/");
            if (!Qt.openUrlExternally(url)) bridge.error = "No se pudo abrir el archivo.";
        }
    }
    function sizeText(bytes) {
        if (bytes < 1024) return bytes + " B";
        let value = bytes / 1024;
        let units = ["KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (value >= 1024 && i < units.length - 1) { value /= 1024; ++i; }
        return value.toFixed(1) + " " + units[i];
    }
    MattePanel {
        id: surface
        anchors.fill: parent
        anchors.margins: 1
        radius: GemaTheme.rounding
        topColor: "#18ffffff"
        bottomColor: "#10ffffff"
        edgeColor: "#48ffffff"
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 1
                Text { text: "Explorer"; font.pixelSize: 25; font.bold: true; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
                Text { text: "Tus archivos, a mano  ·  v" + bridge.appVersion; font.pixelSize: 12; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
            }
            Item { Layout.fillWidth: true }
            Text { text: bridge.loading ? "Cargando…" : "EXPLORADOR DE ARCHIVOS"; font.pixelSize: 10; font.letterSpacing: 1; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            ActionButton { text: "Atrás"; enabled: bridge.ready && !bridge.loading && bridge.history.length > 0; onClicked: bridge.back() }
            ActionButton { text: "Inicio"; enabled: bridge.ready && !bridge.loading; onClicked: bridge.home() }
            ActionButton { text: "↑"; ToolTip.visible: hovered; ToolTip.text: "Carpeta superior"; enabled: bridge.ready && !bridge.loading && bridge.parentPath !== "" && bridge.parentPath !== bridge.path; onClicked: bridge.list(bridge.parentPath, bridge.showHidden, "navigate") }
            TextField {
                id: pathField
                Layout.fillWidth: true
                enabled: bridge.ready && !bridge.loading
                selectByMouse: true
                placeholderText: "Ruta absoluta"
                text: bridge.path
                color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
                onAccepted: bridge.list(text, bridge.showHidden, "navigate")
            }
            ActionButton { text: "↻"; ToolTip.visible: hovered; ToolTip.text: "Actualizar"; enabled: bridge.ready && !bridge.loading && bridge.path !== ""; onClicked: bridge.list(bridge.path, bridge.showHidden, "refresh") }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "CONTENIDO"; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
            Item { Layout.fillWidth: true }
            CheckBox {
                id: hiddenCheck
                text: "Mostrar ocultos"
                checked: bridge.showHidden
                enabled: bridge.ready && !bridge.loading && bridge.path !== ""
                onClicked: bridge.list(bridge.path, checked, "refresh")
                contentItem: Text { text: hiddenCheck.text; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; verticalAlignment: Text.AlignVCenter; leftPadding: hiddenCheck.indicator.width + 6; font.pixelSize: 12 }
            }
        }
        GlassPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff"
            clip: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Nombre"; Layout.fillWidth: true; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                    Text { text: "Tipo"; Layout.preferredWidth: 85; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                    Text { text: "Tamaño"; Layout.preferredWidth: 75; horizontalAlignment: Text.AlignRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                }
                ListView {
                    id: listing
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    focus: true
                    model: bridge.entries
                    currentIndex: -1
                    ScrollBar.vertical: ScrollBar { }
                    Keys.onReturnPressed: window.openEntry(bridge.entries[currentIndex])
                    Keys.onEnterPressed: window.openEntry(bridge.entries[currentIndex])
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: listing.width
                        height: 42
                        radius: 8
                        color: listing.currentIndex === index ? GemaTheme.accentAlpha(0.30) : (mouse.containsMouse ? "#18ffffff" : "transparent")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8
                            Text { text: row.modelData.isDir ? "▰" : "▤"; font.pixelSize: 18; color: row.modelData.isDir ? GemaTheme.accent : (GemaTheme.darkText ? "#263d50" : "#ffffff") }
                            Text { text: row.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; elide: Text.ElideMiddle; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 13 }
                            Text { text: row.modelData.isDir ? "Carpeta" : "Archivo"; Layout.preferredWidth: 85; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 12 }
                            Text { text: row.modelData.isDir ? "—" : window.sizeText(row.modelData.size); Layout.preferredWidth: 75; horizontalAlignment: Text.AlignRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 12 }
                        }
                        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { listing.currentIndex = row.index; listing.forceActiveFocus(); } onDoubleClicked: window.openEntry(row.modelData) }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: bridge.entries.length === 0
                        text: bridge.loading ? "Cargando carpeta…" : (bridge.path ? "Esta carpeta está vacía" : "Esperando al motor…")
                        color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 14
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: bridge.error ? bridge.error : (bridge.loading ? "Cargando…" : bridge.entries.length + " elementos" + (bridge.skipped ? " · " + bridge.skipped + (bridge.skipped === 1 ? " entrada omitida por error o nombre no UTF-8" : " entradas omitidas por error o nombre no UTF-8") : ""))
            textFormat: Text.PlainText
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            elide: Text.ElideRight
            font.pixelSize: 12
        }
    }
    Connections {
        target: bridge
        function onListingSucceeded() { pathField.text = bridge.path; listing.currentIndex = -1; }
        function onErrorChanged() {
            if (bridge.error) {
                pathField.text = bridge.path;
                hiddenCheck.checked = bridge.showHidden;
            }
        }
        function onShowHiddenChanged() { hiddenCheck.checked = bridge.showHidden; }
    }
    Shortcut { sequence: "Alt+Left"; onActivated: bridge.back() }
    Shortcut { sequence: "Alt+Up"; onActivated: { if (bridge.parentPath && bridge.parentPath !== bridge.path) bridge.list(bridge.parentPath, bridge.showHidden, "navigate"); } }
    Shortcut { sequence: "Ctrl+L"; onActivated: { pathField.forceActiveFocus(); pathField.selectAll(); } }
    Shortcut { sequence: "F5"; onActivated: { if (bridge.path) bridge.list(bridge.path, bridge.showHidden, "refresh"); } }
}
