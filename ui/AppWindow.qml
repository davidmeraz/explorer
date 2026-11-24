pragma ComponentBehavior: Bound
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
    property bool gridMode: true
    property bool editingPath: false
    property string listedPath: ""
    property string uiError: ""
    readonly property alias searchField: search
    readonly property var filteredEntries: window.bridge.entries.filter(entry => entry.name.toLowerCase().includes(search.text.toLowerCase()))
    readonly property alias gridView: grid
    readonly property alias listView: listing
    readonly property alias placesView: placesList
    property bool sidebarOpen: true
    property bool sidebarManual: false
    property string clipboardPath: ""
    property string clipboardName: ""
    property string clipboardMode: ""
    property string statusMessage: ""
    property var contextEntry: null
    readonly property bool modalOpen: mkdirDialog.visible || renameDialog.visible || trashDialog.visible
    readonly property bool textInputFocused: search.activeFocus || pathField.activeFocus || mkdirInput.activeFocus || renameInput.activeFocus
    readonly property bool canMutate: window.bridge.ready && !window.bridge.busy && !window.textInputFocused && !window.modalOpen
    Timer { id: statusTimer; interval: 3200; onTriggered: window.statusMessage = "" }
    TextEdit { id: clipboardText; visible: false }
    function showStatus(msg) {
        window.statusMessage = msg;
        statusTimer.restart();
    }
    function copyPath(p) {
        clipboardText.text = p;
        clipboardText.selectAll();
        clipboardText.copy();
        window.showStatus("Ruta copiada");
    }
    function selectedEntry() {
        const i = window.gridMode ? grid.currentIndex : listing.currentIndex;
        return i >= 0 && i < window.filteredEntries.length ? window.filteredEntries[i] : null;
    }
    function setClipboard(entry, mode) {
        if (!entry) return;
        window.clipboardPath = entry.path;
        window.clipboardName = entry.name;
        window.clipboardMode = mode;
        window.showStatus(mode === "cut" ? "Cortado: " + entry.name : "Copiado: " + entry.name);
    }
    function pasteClipboard() {
        if (window.clipboardPath === "" || window.bridge.path === "") return;
        if (window.clipboardMode === "cut") window.bridge.moveEntry(window.clipboardPath, window.bridge.path);
        else window.bridge.copyEntry(window.clipboardPath, window.bridge.path);
    }
    function validName(text) {
        const t = text.trim();
        return t.length > 0 && t !== "." && t !== ".." && !t.includes("/");
    }
    function openMkdirDialog() {
        if (window.bridge.path === "") return;
        mkdirDialog.open();
    }
    function openRenameDialog(entry) {
        if (!entry) return;
        renameDialog.targetEntry = entry;
        renameDialog.open();
    }
    function openTrashDialog(entry) {
        if (!entry) return;
        trashDialog.targetEntry = entry;
        trashDialog.open();
    }
    function openContextMenu(entry, targetItem, x, y) {
        window.contextEntry = entry;
        if (entry) entryMenu.popup(targetItem, x, y);
        else folderMenu.popup(targetItem, x, y);
    }
    component GlassMenuItem: MenuItem {
        id: glassItem
        implicitWidth: 210
        implicitHeight: 34
        contentItem: Text {
            text: glassItem.text
            textFormat: Text.PlainText
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            opacity: glassItem.enabled ? 1 : 0.5
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            font.pixelSize: 13
        }
        background: Rectangle { radius: 8; color: glassItem.highlighted ? GemaTheme.accentAlpha(0.28) : "transparent" }
    }
    onWidthChanged: { if (!window.sidebarManual) window.sidebarOpen = window.width >= 680; }
    function placeIcon(kind) {
        const icons = {home: "⌂", desktop: "◫", documents: "▤", downloads: "↓", pictures: "◩", music: "♪", videos: "▷", trash: "⌫", root: "/", mount: "⛁"};
        return icons[kind] || "▰";
    }
    function dateText(epochSec) {
        if (!epochSec || epochSec <= 0) return "—";
        const d = new Date(epochSec * 1000);
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes());
    }
    function switchView(useGrid) {
        const selected = window.gridMode ? grid.currentIndex : listing.currentIndex;
        window.gridMode = useGrid;
        if (useGrid) { grid.currentIndex = selected; grid.forceActiveFocus(); }
        else { listing.currentIndex = selected; listing.forceActiveFocus(); }
    }
    function fileLabel(name) {
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(dot + 1, dot + 6).toUpperCase() : "FILE";
    }
    function fileColor(name) {
        const ext = window.fileLabel(name);
        if (["JS", "TS", "QML", "JSON"].includes(ext)) return "#f1ce70";
        if (["RS", "C", "CPP", "H"].includes(ext)) return "#f39b83";
        if (["PY", "SH", "RB"].includes(ext)) return "#83cba9";
        if (["PNG", "JPG", "SVG", "WEBP"].includes(ext)) return "#d6a2ec";
        return "#91bdf0";
    }
    BackgroundEffect.blurRegion: Region { item: GemaTheme.blur ? surface : null; radius: surface.radius }
    function openEntry(entry) {
        if (!entry || window.bridge.busy) return;
        window.uiError = "";
        if (entry.isDir) window.bridge.list(entry.path, window.bridge.showHidden, "navigate");
        else if (entry.isFile) {
            const url = "file://" + entry.path.split("/").map(s => encodeURIComponent(s)).join("/");
            if (!Qt.openUrlExternally(url)) window.uiError = "No se pudo abrir el archivo.";
        }
    }
    function startEditPath() {
        pathField.text = window.bridge.path;
        window.editingPath = true;
        pathField.forceActiveFocus();
        pathField.selectAll();
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
                Text { text: "Tus archivos, a mano  ·  v" + window.bridge.appVersion; font.pixelSize: 12; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
            }
            Item { Layout.fillWidth: true }
            Text { visible: window.width >= 600; text: window.bridge.loading ? "Cargando…" : "EXPLORADOR DE ARCHIVOS"; font.pixelSize: 10; font.letterSpacing: 1; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
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
                onTextChanged: window.uiError = ""
                Keys.onEscapePressed: (event) => { search.clear(); event.accepted = true; }
            }
            ActionButton { text: "Limpiar búsqueda"; enabled: search.text.length > 0; onClicked: { search.clear(); search.forceActiveFocus(); } }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            ActionButton { id: sidebarBtn; text: "☰"; ToolTip.visible: sidebarBtn.hovered; ToolTip.text: "Lugares (Ctrl+B)"; onClicked: { window.sidebarManual = true; window.sidebarOpen = !window.sidebarOpen; } }
            ActionButton { text: "Atrás"; enabled: window.bridge.canBack; onClicked: window.bridge.back() }
            ActionButton { text: "Adelante"; enabled: window.bridge.canForward; onClicked: window.bridge.forward() }
            ActionButton { text: "Inicio"; enabled: window.bridge.ready && !window.bridge.busy; onClicked: window.bridge.home() }
            ActionButton { id: upBtn; text: "↑"; ToolTip.visible: upBtn.hovered; ToolTip.text: "Carpeta superior"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.parentPath !== "" && window.bridge.parentPath !== window.bridge.path; onClicked: window.bridge.list(window.bridge.parentPath, window.bridge.showHidden, "navigate") }
            TextField {
                id: pathField
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: window.editingPath
                enabled: window.bridge.ready && !window.bridge.busy
                selectByMouse: true
                placeholderText: "Ruta absoluta"
                text: window.bridge.path
                color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
                onAccepted: { const target = pathField.text; window.editingPath = false; window.bridge.list(target, window.bridge.showHidden, "navigate"); }
                onActiveFocusChanged: if (!pathField.activeFocus && window.editingPath) { pathField.text = window.bridge.path; window.editingPath = false; }
                Keys.onEscapePressed: { pathField.text = window.bridge.path; window.editingPath = false; }
            }
            Flickable {
                id: crumbsFlickable
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 36
                visible: !window.editingPath
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: Math.max(crumbs.implicitWidth, crumbsFlickable.width)
                contentHeight: crumbsFlickable.height
                function scrollToEnd() { crumbsFlickable.contentX = Math.max(0, crumbsFlickable.contentWidth - crumbsFlickable.width); }
                Component.onCompleted: crumbsFlickable.scrollToEnd()
                onContentWidthChanged: crumbsFlickable.scrollToEnd()
                onWidthChanged: crumbsFlickable.scrollToEnd()
                MouseArea {
                    // Espacio vacío de la barra: clic para editar la ruta.
                    width: crumbsFlickable.contentWidth
                    height: crumbsFlickable.height
                    enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                    onClicked: window.startEditPath()
                }
                Row {
                    id: crumbs
                    ActionButton { text: "/"; enabled: window.bridge.ready && !window.bridge.busy; onClicked: window.bridge.list("/", window.bridge.showHidden, "navigate") }
                    Repeater {
                        model: window.bridge.path.split("/").filter(s => s.length > 0)
                        ActionButton {
                            id: crumb
                            required property string modelData
                            required property int index
                            text: "› " + crumb.modelData
                            enabled: window.bridge.ready && !window.bridge.busy
                            onClicked: window.bridge.list("/" + window.bridge.path.split("/").filter(s => s.length > 0).slice(0, crumb.index + 1).join("/"), window.bridge.showHidden, "navigate")
                        }
                    }
                }
            }
            ActionButton { id: editBtn; text: "✎"; ToolTip.visible: editBtn.hovered; ToolTip.text: "Editar ruta (Ctrl+L)"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""; onClicked: window.startEditPath() }
            ActionButton { id: refreshBtn; text: "↻"; ToolTip.visible: refreshBtn.hovered; ToolTip.text: "Actualizar"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""; onClicked: { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); } }
            ActionButton { id: newFolderBtn; text: "+"; horizontalPadding: 10; ToolTip.visible: newFolderBtn.hovered; ToolTip.text: "Nueva carpeta (Ctrl+Shift+N)"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""; onClicked: window.openMkdirDialog() }
            ActionButton { id: termBtn; text: ">_"; horizontalPadding: 10; ToolTip.visible: termBtn.hovered; ToolTip.text: "Abrir terminal aquí"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""; onClicked: window.bridge.openTerminal(window.bridge.path) }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { visible: window.width >= 760; text: "CONTENIDO"; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
            Item { Layout.fillWidth: true }
            GlassComboBox {
                id: sortCombo
                implicitWidth: 112
                implicitHeight: 34
                model: [{"key": "name", "label": "Nombre"}, {"key": "mtime", "label": "Fecha"}, {"key": "size", "label": "Tamaño"}, {"key": "type", "label": "Tipo"}]
                textRole: "label"
                valueRole: "key"
                currentIndex: Math.max(0, sortCombo.indexOfValue(window.bridge.sortBy))
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onActivated: window.bridge.setSort(String(sortCombo.currentValue), window.bridge.sortDesc)
            }
            ActionButton {
                id: sortDirBtn
                text: window.bridge.sortDesc ? "↓" : "↑"
                ToolTip.visible: sortDirBtn.hovered
                ToolTip.text: window.bridge.sortDesc ? "Orden descendente" : "Orden ascendente"
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: window.bridge.setSort(window.bridge.sortBy, !window.bridge.sortDesc)
            }
            ActionButton { text: "Cuadrícula"; enabled: !window.gridMode; onClicked: window.switchView(true) }
            ActionButton { text: "Lista"; enabled: window.gridMode; onClicked: window.switchView(false) }
            CheckBox {
                id: hiddenCheck
                text: "Mostrar ocultos"
                checked: window.bridge.showHidden
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: window.bridge.list(window.bridge.path, hiddenCheck.checked, "refresh")
                contentItem: Text { text: hiddenCheck.text; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; verticalAlignment: Text.AlignVCenter; leftPadding: hiddenCheck.indicator.width + 6; font.pixelSize: 12 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            GlassPanel {
                Layout.preferredWidth: window.width < 680 ? 150 : 185
                Layout.fillHeight: true
                visible: window.sidebarOpen
                topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff"
                clip: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    Text { text: "LUGARES"; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.bold: true; font.pixelSize: 11; font.letterSpacing: 1 }
                    ListView {
                        id: placesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: window.bridge.places
                        ScrollBar.vertical: ScrollBar { }
                        delegate: Rectangle {
                            id: placeRow
                            required property var modelData
                            required property int index
                            width: placesList.width
                            height: 34
                            radius: 8
                            color: window.bridge.path === placeRow.modelData.path ? GemaTheme.accentAlpha(0.30) : (placeMouse.containsMouse ? "#18ffffff" : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 8
                                Text { text: window.placeIcon(placeRow.modelData.kind); font.pixelSize: 15; color: GemaTheme.darkText ? "#263d50" : "#ffffff" }
                                Text { text: placeRow.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 13 }
                            }
                            MouseArea {
                                id: placeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: window.bridge.ready && !window.bridge.busy
                                onClicked: { window.uiError = ""; window.bridge.list(placeRow.modelData.path, window.bridge.showHidden, "navigate"); }
                            }
                        }
                    }
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
                        Text { text: "Modificado"; visible: window.width >= 760; Layout.preferredWidth: 125; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                        Text { text: "Tipo"; Layout.preferredWidth: 85; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                        Text { text: "Tamaño"; Layout.preferredWidth: 75; horizontalAlignment: Text.AlignRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 11 }
                    }
                    ListView {
                        id: listing
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !window.gridMode
                        clip: true
                        focus: !window.gridMode
                        model: window.filteredEntries
                        currentIndex: -1
                        onModelChanged: listing.currentIndex = -1
                        ScrollBar.vertical: ScrollBar { }
                        Keys.onReturnPressed: window.openEntry(window.filteredEntries[listing.currentIndex])
                        Keys.onEnterPressed: window.openEntry(window.filteredEntries[listing.currentIndex])
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            width: listing.width
                            height: 42
                            radius: 8
                            color: listing.currentIndex === row.index ? GemaTheme.accentAlpha(0.30) : (mouse.containsMouse ? "#18ffffff" : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 8
                                Text { text: row.modelData.isDir ? "▰" : "▤"; font.pixelSize: 18; color: row.modelData.isDir ? GemaTheme.accent : (GemaTheme.darkText ? "#263d50" : "#ffffff") }
                                Text { text: row.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideMiddle; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 13 }
                                Text { text: window.dateText(row.modelData.mtime); visible: window.width >= 760; Layout.preferredWidth: 125; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 12 }
                                Text { text: row.modelData.isDir ? "Carpeta" : "Archivo"; Layout.preferredWidth: 85; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 12 }
                                Text { text: row.modelData.isDir ? "—" : window.sizeText(row.modelData.size); Layout.preferredWidth: 75; horizontalAlignment: Text.AlignRight; color: GemaTheme.darkText ? "#263d50" : "#ffffff"; font.pixelSize: 12 }
                            }
                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    listing.currentIndex = row.index;
                                    listing.forceActiveFocus();
                                    if (mouse.button === Qt.RightButton) window.openContextMenu(row.modelData, row, mouse.x, mouse.y);
                                }
                                onDoubleClicked: (mouse) => { if (mouse.button === Qt.LeftButton) window.openEntry(row.modelData); }
                            }
                        }
                        MouseArea {
                            z: -1
                            parent: listing
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: (mouse) => window.openContextMenu(null, listing, mouse.x, mouse.y)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: window.filteredEntries.length === 0
                            text: window.bridge.loading ? "Cargando carpeta…" : (search.text ? "Sin coincidencias" : (window.bridge.path ? "Esta carpeta está vacía" : "Esperando al motor…"))
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
                        cellWidth: grid.width / Math.max(1, Math.floor(grid.width / 130))
                        cellHeight: 132
                        model: window.filteredEntries
                        currentIndex: -1
                        onModelChanged: grid.currentIndex = -1
                        ScrollBar.vertical: ScrollBar { }
                        Keys.onReturnPressed: window.openEntry(window.filteredEntries[grid.currentIndex])
                        Keys.onEnterPressed: window.openEntry(window.filteredEntries[grid.currentIndex])
                        delegate: ExplorerIconCard {
                            id: card
                            required property var modelData
                            required property int index
                            width: grid.cellWidth - 6
                            height: grid.cellHeight - 6
                            path: card.modelData.path
                            name: card.modelData.name
                            directory: card.modelData.isDir
                            itemAccent: card.directory ? GemaTheme.accent : window.fileColor(card.name)
                            langLabel: card.directory ? "" : window.fileLabel(card.name)
                            focusPolicy: Qt.NoFocus
                            selected: grid.currentIndex === card.index
                            onClicked: { grid.currentIndex = card.index; grid.forceActiveFocus(); }
                            onDoubleClicked: window.openEntry(card.modelData)
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: (mouse) => { grid.currentIndex = card.index; grid.forceActiveFocus(); window.openContextMenu(card.modelData, card, mouse.x, mouse.y); }
                            }
                        }
                        MouseArea {
                            z: -1
                            parent: grid
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: (mouse) => window.openContextMenu(null, grid, mouse.x, mouse.y)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: window.filteredEntries.length === 0
                            text: window.bridge.loading ? "Cargando carpeta…" : (search.text ? "Sin coincidencias" : (window.bridge.path ? "Esta carpeta está vacía" : "Esperando al motor…"))
                            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: (window.bridge.error || window.uiError || window.statusMessage) ? (window.bridge.error || window.uiError || window.statusMessage) : (window.bridge.loading ? "Cargando…" : (window.bridge.mutating ? "Procesando…" : window.filteredEntries.length + " elementos" + (search.text ? " de " + window.bridge.entries.length + " · búsqueda activa" : "") + (window.bridge.skipped ? " · " + window.bridge.skipped + (window.bridge.skipped === 1 ? " entrada omitida por error o nombre no UTF-8" : " entradas omitidas por error o nombre no UTF-8") : "") + (window.clipboardPath !== "" ? " · Portapapeles (" + (window.clipboardMode === "cut" ? "cortar" : "copiar") + "): " + window.clipboardName : "")))
            textFormat: Text.PlainText
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            elide: Text.ElideRight
            font.pixelSize: 12
        }
    }
    Connections {
        target: window.bridge
        function onListingSucceeded() { window.uiError = ""; if (window.listedPath !== window.bridge.path) search.clear(); window.listedPath = window.bridge.path; window.editingPath = false; pathField.text = window.bridge.path; listing.currentIndex = -1; grid.currentIndex = -1; crumbsFlickable.scrollToEnd(); sortCombo.currentIndex = Math.max(0, sortCombo.indexOfValue(window.bridge.sortBy)); }
        function onErrorChanged() {
            sortCombo.currentIndex = Math.max(0, sortCombo.indexOfValue(window.bridge.sortBy));
            if (window.bridge.error) {
                window.uiError = "";
                window.editingPath = false;
                pathField.text = window.bridge.path;
                hiddenCheck.checked = window.bridge.showHidden;
            }
        }
        function onShowHiddenChanged() { hiddenCheck.checked = window.bridge.showHidden; }
        function onMutationSucceeded(action, sourcePath, targetPath) {
            window.uiError = "";
            if (action === "move") { window.clipboardPath = ""; window.clipboardName = ""; window.clipboardMode = ""; }
            if (window.clipboardPath !== "" && sourcePath !== "" && (window.clipboardPath === sourcePath || window.clipboardPath.startsWith(sourcePath + "/"))) {
                if (action === "trash") {
                    window.clipboardPath = ""; window.clipboardName = ""; window.clipboardMode = "";
                } else if (action === "rename") {
                    if (!targetPath) {
                        window.clipboardPath = ""; window.clipboardName = ""; window.clipboardMode = "";
                    } else if (window.clipboardPath === sourcePath) {
                        window.clipboardPath = targetPath;
                        window.clipboardName = targetPath.slice(targetPath.lastIndexOf("/") + 1);
                    } else {
                        window.clipboardPath = targetPath + window.clipboardPath.slice(sourcePath.length);
                    }
                }
            }
            const messages = {mkdir: "Carpeta creada", rename: "Renombrado", trash: "Movido a la papelera", copy: "Copiado", move: "Movido"};
            if (messages[action]) window.showStatus(messages[action]);
        }
        function onStatusNotice(message) { window.showStatus(message); }
    }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== "" && !window.modalOpen; onActivated: window.openMkdirDialog() }
    Shortcut { sequence: "F2"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.openRenameDialog(window.selectedEntry()) }
    Shortcut { sequence: "Delete"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.openTrashDialog(window.selectedEntry()) }
    Shortcut { sequence: "Ctrl+C"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.setClipboard(window.selectedEntry(), "copy") }
    Shortcut { sequence: "Ctrl+X"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.setClipboard(window.selectedEntry(), "cut") }
    Shortcut { sequence: "Ctrl+V"; enabled: window.canMutate && window.clipboardPath !== "" && window.bridge.path !== ""; onActivated: window.pasteClipboard() }
    Menu {
        id: entryMenu
        parent: surface
        padding: 6
        background: MattePanel { overlay: true; radius: 12 }
        GlassMenuItem { text: "Abrir"; onTriggered: window.openEntry(window.contextEntry) }
        GlassMenuItem { text: "Copiar"; onTriggered: window.setClipboard(window.contextEntry, "copy") }
        GlassMenuItem { text: "Cortar"; onTriggered: window.setClipboard(window.contextEntry, "cut") }
        GlassMenuItem { text: "Renombrar"; enabled: !window.bridge.busy; onTriggered: window.openRenameDialog(window.contextEntry) }
        GlassMenuItem { text: "Copiar ruta"; onTriggered: window.copyPath(window.contextEntry ? window.contextEntry.path : "") }
        GlassMenuItem { text: "Mover a papelera"; enabled: !window.bridge.busy; onTriggered: window.openTrashDialog(window.contextEntry) }
    }
    Menu {
        id: folderMenu
        parent: surface
        padding: 6
        background: MattePanel { overlay: true; radius: 12 }
        GlassMenuItem { text: "Nueva carpeta"; enabled: !window.bridge.busy && window.bridge.path !== ""; onTriggered: window.openMkdirDialog() }
        GlassMenuItem { text: "Pegar"; enabled: window.clipboardPath !== "" && !window.bridge.busy; onTriggered: window.pasteClipboard() }
        GlassMenuItem { text: "Copiar ruta de carpeta"; onTriggered: window.copyPath(window.bridge.path) }
        GlassMenuItem { text: "Abrir terminal aquí"; onTriggered: window.bridge.openTerminal(window.bridge.path) }
        GlassMenuItem { text: "Actualizar"; enabled: !window.bridge.busy && window.bridge.path !== ""; onTriggered: { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); } }
    }
    GlassDialog {
        id: mkdirDialog
        parent: surface
        title: "Nueva carpeta"
        anchors.centerIn: Overlay.overlay
        width: Math.min(420, window.width - 40)
        onOpened: { mkdirInput.text = ""; mkdirInput.forceActiveFocus(); }
        function submit() {
            if (!window.validName(mkdirInput.text)) return;
            window.bridge.mkdir(window.bridge.path, mkdirInput.text.trim());
            mkdirDialog.close();
        }
        contentItem: TextField {
            id: mkdirInput
            placeholderText: "Nombre de la carpeta"
            selectByMouse: true
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
            onAccepted: mkdirDialog.submit()
        }
        footer: Item {
            implicitHeight: 64
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; onClicked: mkdirDialog.close() }
                ActionButton { text: "Crear"; accent: true; enabled: window.validName(mkdirInput.text); onClicked: mkdirDialog.submit() }
            }
        }
    }
    GlassDialog {
        id: renameDialog
        parent: surface
        property var targetEntry: null
        title: "Renombrar"
        anchors.centerIn: Overlay.overlay
        width: Math.min(420, window.width - 40)
        onOpened: { renameInput.text = renameDialog.targetEntry ? renameDialog.targetEntry.name : ""; renameInput.forceActiveFocus(); renameInput.selectAll(); }
        function submit() {
            if (!renameDialog.targetEntry || !window.validName(renameInput.text)) return;
            window.bridge.renameEntry(renameDialog.targetEntry.path, renameInput.text.trim());
            renameDialog.close();
        }
        contentItem: TextField {
            id: renameInput
            placeholderText: "Nuevo nombre"
            selectByMouse: true
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            background: GlassPanel { topColor: "#18ffffff"; bottomColor: "#10ffffff"; edgeColor: "#48ffffff" }
            onAccepted: renameDialog.submit()
        }
        footer: Item {
            implicitHeight: 64
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; onClicked: renameDialog.close() }
                ActionButton { text: "Renombrar"; accent: true; enabled: window.validName(renameInput.text); onClicked: renameDialog.submit() }
            }
        }
    }
    GlassDialog {
        id: trashDialog
        parent: surface
        property var targetEntry: null
        title: "Mover a la papelera"
        anchors.centerIn: Overlay.overlay
        width: Math.min(420, window.width - 40)
        contentItem: Text {
            text: "¿Mover «" + (trashDialog.targetEntry ? trashDialog.targetEntry.name : "") + "» a la papelera?"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            font.pixelSize: 14
        }
        footer: Item {
            implicitHeight: 64
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; onClicked: trashDialog.close() }
                ActionButton {
                    text: "Mover a papelera"
                    accent: true
                    onClicked: {
                        if (trashDialog.targetEntry) window.bridge.trashEntry(trashDialog.targetEntry.path);
                        trashDialog.close();
                    }
                }
            }
        }
    }
    Shortcut { sequence: "Alt+Left"; onActivated: window.bridge.back() }
    Shortcut { sequence: "Alt+Right"; onActivated: window.bridge.forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: { if (window.bridge.parentPath && window.bridge.parentPath !== window.bridge.path) window.bridge.list(window.bridge.parentPath, window.bridge.showHidden, "navigate"); } }
    Shortcut { sequence: "Ctrl+L"; enabled: window.bridge.ready && !window.bridge.busy; onActivated: window.startEditPath() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { search.forceActiveFocus(); search.selectAll(); } }
    Shortcut { sequence: "Ctrl+1"; onActivated: window.switchView(true) }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.switchView(false) }
    Shortcut { sequence: "Ctrl+B"; onActivated: { window.sidebarManual = true; window.sidebarOpen = !window.sidebarOpen; } }
    Shortcut { sequence: "F5"; onActivated: { if (window.bridge.path) { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); } } }
}
