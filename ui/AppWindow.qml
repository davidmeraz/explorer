import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "components"

FloatingWindow {
    id: window
    required property AppBridge bridge
    title: "Explorer"
    property bool fitWorkArea: true
    property int attempts: 0
    property bool requestedFit: true
    implicitWidth: 900
    implicitHeight: 620
    function applyFit() {
        if (fitProcess.running) return;
        requestedFit = fitWorkArea;
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) { maximized = fitWorkArea; return; }
        const pid = Number(Quickshell.processId);
        if (!Number.isInteger(pid) || pid <= 0) { maximized = fitWorkArea; return; }
        fitProcess.command = ["hyprctl", "eval", `
for _, w in ipairs(hl.get_windows()) do
    if w.pid == ${pid} and w.title == "Explorer" and w.mapped then
        if not w.floating then
            hl.dispatch(hl.dsp.window.fullscreen({window=w, mode="maximized", action="${fitWorkArea ? "set" : "unset"}"}))
            return
        end
        local m, r = w.monitor, w.monitor.reserved
        local width, height = m.width, m.height
        if m.transform % 2 == 1 then width, height = height, width end
        width = math.floor(width / m.scale + 0.5) - r.left - r.right
        height = math.floor(height / m.scale + 0.5) - r.top - r.bottom
        local targetWidth = ${fitWorkArea ? "width" : "math.min(900, width)"}
        local targetHeight = ${fitWorkArea ? "height" : "math.min(620, height)"}
        local x = m.x + r.left + math.floor((width - targetWidth) / 2)
        local y = m.y + r.top + math.floor((height - targetHeight) / 2)
        hl.dispatch(hl.dsp.window.resize({window=w, x=targetWidth, y=targetHeight, relative=false}))
        hl.dispatch(hl.dsp.window.move({window=w, x=x, y=y, relative=false}))
        return
    end
end
error("window not mapped")`];
        fitProcess.running = true;
    }
    function toggleFit() {
        fitWorkArea = !fitWorkArea;
        attempts = 0;
        retry.restart();
    }
    Timer { id: retry; interval: 150; onTriggered: window.applyFit() }
    Process {
        id: fitProcess
        stderr: SplitParser { onRead: data => console.warn("Hyprland: " + data) }
        onExited: (exitCode, exitStatus) => {
            if (window.requestedFit !== window.fitWorkArea) { retry.restart(); return; }
            if (exitCode !== 0) {
                if (++window.attempts < 20) retry.restart();
                else window.maximized = window.fitWorkArea;
            }
        }
    }
    Component.onCompleted: retry.start()
    minimumSize: Qt.size(480, 360)
    color: "transparent"
    visible: true
    property bool gridMode: true
    property bool editingPath: false
    property string listedPath: ""
    readonly property alias searchField: search
    readonly property var filteredEntries: bridge.entries.filter(entry => entry.name.toLowerCase().includes(search.text.toLowerCase()))
    onFilteredEntriesChanged: Qt.callLater(() => { listing.currentIndex = -1; grid.currentIndex = -1; })
    readonly property alias gridView: grid
    readonly property alias listView: listing
    function switchView(useGrid) {
        const selected = gridMode ? grid.currentIndex : listing.currentIndex;
        gridMode = useGrid;
        if (useGrid) { grid.currentIndex = selected; grid.forceActiveFocus(); }
        else { listing.currentIndex = selected; listing.forceActiveFocus(); }
    }
    function fileLabel(name) {
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(dot + 1, dot + 6).toUpperCase() : "FILE";
    }
    function fileColor(name) {
        const ext = fileLabel(name);
        if (["JS", "TS", "QML", "JSON"].includes(ext)) return "#f1ce70";
        if (["RS", "C", "CPP", "H"].includes(ext)) return "#f39b83";
        if (["PY", "SH", "RB"].includes(ext)) return "#83cba9";
        if (["PNG", "JPG", "SVG", "WEBP"].includes(ext)) return "#d6a2ec";
        return "#91bdf0";
    }
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
            ActionButton { text: window.fitWorkArea ? "Restaurar" : "Maximizar"; Accessible.name: text + " ventana"; onClicked: window.toggleFit() }
        }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: search
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: "Buscar por nombre en esta carpeta (Ctrl+F)"
                Accessible.name: "Buscar por nombre en esta carpeta"
                selectByMouse: true
                color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
                Keys.onEscapePressed: (event) => { clear(); event.accepted = true; }
            }
            ActionButton { text: "Limpiar búsqueda"; enabled: search.text.length > 0; onClicked: { search.clear(); search.forceActiveFocus(); } }
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
                visible: window.editingPath
                enabled: bridge.ready && !bridge.loading
                selectByMouse: true
                placeholderText: "Ruta absoluta"
                text: bridge.path
                color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
                onAccepted: { const target = text; window.editingPath = false; bridge.list(target, bridge.showHidden, "navigate"); }
                onActiveFocusChanged: if (!activeFocus && window.editingPath) { text = bridge.path; window.editingPath = false; }
                Keys.onEscapePressed: { text = bridge.path; window.editingPath = false; }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 36
                visible: !window.editingPath
                contentWidth: crumbs.implicitWidth
                contentHeight: availableHeight
                Component.onCompleted: contentItem.contentX = Math.max(0, contentWidth - availableWidth)
                onContentWidthChanged: contentItem.contentX = Math.max(0, contentWidth - availableWidth)
                onAvailableWidthChanged: contentItem.contentX = Math.max(0, contentWidth - availableWidth)
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                Row {
                    id: crumbs
                    ActionButton { text: "/"; onClicked: bridge.list("/", bridge.showHidden, "navigate") }
                    Repeater {
                        model: bridge.path.split("/").filter(s => s.length > 0)
                        ActionButton {
                            required property string modelData
                            required property int index
                            text: "› " + modelData
                            enabled: bridge.ready && !bridge.loading
                            onClicked: bridge.list("/" + bridge.path.split("/").filter(s => s.length > 0).slice(0, index + 1).join("/"), bridge.showHidden, "navigate")
                        }
                    }
                }
            }
            ActionButton { text: "↻"; ToolTip.visible: hovered; ToolTip.text: "Actualizar"; enabled: bridge.ready && !bridge.loading && bridge.path !== ""; onClicked: bridge.list(bridge.path, bridge.showHidden, "refresh") }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "CONTENIDO"; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
            Item { Layout.fillWidth: true }
            ActionButton { text: "Cuadrícula"; enabled: !window.gridMode; onClicked: window.switchView(true) }
            ActionButton { text: "Lista"; enabled: window.gridMode; onClicked: window.switchView(false) }
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
                    visible: !window.gridMode
                    Text { text: "Nombre"; Layout.fillWidth: true; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                    Text { text: "Tipo"; Layout.preferredWidth: 85; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                    Text { text: "Tamaño"; Layout.preferredWidth: 75; horizontalAlignment: Text.AlignRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                }
                ListView {
                    id: listing
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !window.gridMode
                    clip: true
                    focus: true
                    model: window.filteredEntries
                    currentIndex: -1
                    ScrollBar.vertical: ScrollBar { }
                    Keys.onReturnPressed: window.openEntry(window.filteredEntries[currentIndex])
                    Keys.onEnterPressed: window.openEntry(window.filteredEntries[currentIndex])
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
                        visible: window.filteredEntries.length === 0
                        text: bridge.loading ? "Cargando carpeta…" : (search.text ? "Sin coincidencias" : (bridge.path ? "Esta carpeta está vacía" : "Esperando al motor…"))
                        color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 14
                    }
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: window.gridMode
                    focus: window.gridMode
                    clip: true
                    cellWidth: width / Math.max(1, Math.floor(width / 130))
                    cellHeight: 132
                    model: window.filteredEntries
                    currentIndex: -1
                    ScrollBar.vertical: ScrollBar { }
                    Keys.onReturnPressed: window.openEntry(window.filteredEntries[currentIndex])
                    Keys.onEnterPressed: window.openEntry(window.filteredEntries[currentIndex])
                    delegate: ExplorerIconCard {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth - 6
                        height: grid.cellHeight - 6
                        path: modelData.path
                        name: modelData.name
                        directory: modelData.isDir
                        itemAccent: directory ? GemaTheme.accent : window.fileColor(name)
                        langLabel: directory ? "" : window.fileLabel(name)
                        focusPolicy: Qt.NoFocus
                        selected: grid.currentIndex === index
                        onClicked: { grid.currentIndex = index; grid.forceActiveFocus(); }
                        onDoubleClicked: window.openEntry(modelData)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: window.filteredEntries.length === 0
                        text: bridge.loading ? "Cargando carpeta…" : (search.text ? "Sin coincidencias" : (bridge.path ? "Esta carpeta está vacía" : "Esperando al motor…"))
                        color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: bridge.error ? bridge.error : (bridge.loading ? "Cargando…" : window.filteredEntries.length + " elementos" + (search.text ? " de " + bridge.entries.length + " · búsqueda activa" : "") + (bridge.skipped ? " · " + bridge.skipped + (bridge.skipped === 1 ? " entrada omitida por error o nombre no UTF-8" : " entradas omitidas por error o nombre no UTF-8") : ""))
            textFormat: Text.PlainText
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            elide: Text.ElideRight
            font.pixelSize: 12
        }
    }
    Connections {
        target: bridge
        function onListingSucceeded() { if (window.listedPath !== bridge.path) search.clear(); window.listedPath = bridge.path; window.editingPath = false; pathField.text = bridge.path; listing.currentIndex = -1; grid.currentIndex = -1; }
        function onErrorChanged() {
            if (bridge.error) {
                window.editingPath = false;
                pathField.text = bridge.path;
                hiddenCheck.checked = bridge.showHidden;
            }
        }
        function onShowHiddenChanged() { hiddenCheck.checked = bridge.showHidden; }
    }
    Shortcut { sequence: "Alt+Left"; onActivated: bridge.back() }
    Shortcut { sequence: "Alt+Up"; onActivated: { if (bridge.parentPath && bridge.parentPath !== bridge.path) bridge.list(bridge.parentPath, bridge.showHidden, "navigate"); } }
    Shortcut { sequence: "Ctrl+L"; enabled: bridge.ready && !bridge.loading; onActivated: { pathField.text = bridge.path; window.editingPath = true; pathField.forceActiveFocus(); pathField.selectAll(); } }
    Shortcut { sequence: "Ctrl+F"; onActivated: { search.forceActiveFocus(); search.selectAll(); } }
    Shortcut { sequence: "Ctrl+1"; onActivated: window.switchView(true) }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.switchView(false) }
    Shortcut { sequence: "F5"; onActivated: { if (bridge.path) bridge.list(bridge.path, bridge.showHidden, "refresh"); } }
}
