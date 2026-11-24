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
    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(480, 360)
    color: "transparent"
    visible: true

    property bool gridMode: true
    property bool editingPath: false
    property string listedPath: ""
    property string uiError: ""
    readonly property int defaultGridSize: 138
    readonly property int minGridSize: 92
    readonly property int maxGridSize: 380
    property int gridItemSize: defaultGridSize
    readonly property int defaultListRowHeight: 40
    readonly property int minListRowHeight: 30
    readonly property int maxListRowHeight: 82
    property int listRowHeight: defaultListRowHeight
    property real wheelAccumulator: 0
    readonly property int zoomPercent: window.gridMode
        ? Math.round((window.gridItemSize / window.defaultGridSize) * 100)
        : Math.round((window.listRowHeight / window.defaultListRowHeight) * 100)
    readonly property alias searchField: search
    readonly property var filteredEntries: window.bridge.entries.filter(entry => entry.name.toLowerCase().includes(search.text.toLowerCase()))
    readonly property var pathSegments: window.bridge.path.split("/").filter(s => s.length > 0)
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
    property bool contextMenuOpen: false
    property real contextMenuX: 0
    property real contextMenuY: 0

    readonly property var currentEntry: {
        const i = window.gridMode ? grid.currentIndex : listing.currentIndex;
        return i >= 0 && i < window.filteredEntries.length ? window.filteredEntries[i] : null;
    }
    readonly property bool modalOpen: mkdirDialog.visible || renameDialog.visible || trashDialog.visible || infoDialog.visible
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
        window.showStatus("Ruta copiada al portapapeles");
    }
    function selectedEntry() {
        return window.currentEntry;
    }
    function setClipboard(entry, mode) {
        if (!entry) return;
        window.clipboardPath = entry.path;
        window.clipboardName = entry.name;
        window.clipboardMode = mode;
        window.showStatus(mode === "cut" ? "Cortado: " + entry.name : "Copiado: " + entry.name);
    }
    function clearClipboard() {
        window.clipboardPath = "";
        window.clipboardName = "";
        window.clipboardMode = "";
    }
    function pasteClipboard() {
        window.pasteInto(window.bridge.path);
    }
    function pasteInto(destDir) {
        if (window.clipboardPath === "" || !destDir) return;
        if (window.clipboardMode === "cut") window.bridge.moveEntry(window.clipboardPath, destDir);
        else window.bridge.copyEntry(window.clipboardPath, destDir);
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
    function openInfoDialog(entry) {
        const target = entry ? entry.path : window.bridge.path;
        if (!target) return;
        infoDialog.targetEntry = entry || null;
        infoDialog.targetPath = target;
        infoDialog.infoData = null;
        window.bridge.statEntry(target);
        infoDialog.open();
    }
    function openContextMenu(entry, targetItem, x, y) {
        window.contextEntry = entry || null;
        const pt = targetItem.mapToItem(surface, x, y);
        window.contextMenuX = pt.x;
        window.contextMenuY = pt.y;
        window.contextMenuOpen = true;
        contextMenuLayer.forceActiveFocus();
    }
    function closeContextMenu() {
        window.contextMenuOpen = false;
    }
    function toggleSort(columnKey) {
        if (!window.bridge.ready || window.bridge.busy || window.bridge.path === "") return;
        const nextDesc = window.bridge.sortBy === columnKey ? !window.bridge.sortDesc : false;
        window.bridge.setSort(columnKey, nextDesc);
    }
    function adjustZoom(deltaSteps) {
        if (deltaSteps === 0) return;
        if (window.gridMode) {
            const next = Math.max(window.minGridSize, Math.min(window.maxGridSize, window.gridItemSize + deltaSteps * 22));
            if (next !== window.gridItemSize) {
                window.gridItemSize = next;
                window.showStatus("Tamaño de vista: " + window.zoomPercent + "%");
            }
        } else {
            const next = Math.max(window.minListRowHeight, Math.min(window.maxListRowHeight, window.listRowHeight + deltaSteps * 6));
            if (next !== window.listRowHeight) {
                window.listRowHeight = next;
                window.showStatus("Tamaño de lista: " + window.zoomPercent + "%");
            }
        }
    }
    function resetZoom() {
        if (window.gridMode) window.gridItemSize = window.defaultGridSize;
        else window.listRowHeight = window.defaultListRowHeight;
        window.showStatus("Tamaño restablecido (100%)");
    }
    function handleZoomWheel(event) {
        const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
        if (dy === 0) return;
        event.accepted = true;
        if (Math.abs(dy) >= 120) {
            window.wheelAccumulator = 0;
            window.adjustZoom(dy > 0 ? Math.round(dy / 120) : -Math.round(-dy / 120));
            return;
        }
        window.wheelAccumulator += dy;
        const threshold = 80;
        if (Math.abs(window.wheelAccumulator) >= threshold) {
            const steps = window.wheelAccumulator > 0 ? 1 : -1;
            window.wheelAccumulator = 0;
            window.adjustZoom(steps);
        }
    }

    onWidthChanged: { if (!window.sidebarManual) window.sidebarOpen = window.width >= 680; }

    function placeIcon(kind) {
        const icons = {
            home: "home",
            desktop: "desktop",
            documents: "documents",
            downloads: "downloads",
            pictures: "pictures",
            music: "music",
            videos: "videos",
            trash: "trash",
            root: "root",
            mount: "mount"
        };
        return icons[kind] || "folder";
    }
    function placeGroup(kind) {
        if (kind === "mount") return 2;
        if (kind === "trash" || kind === "root") return 1;
        return 0;
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
    function isImageFile(name) {
        const ext = window.fileLabel(name);
        return ["PNG", "JPG", "JPEG", "WEBP", "GIF", "BMP", "ICO", "SVG", "TIF", "TIFF", "AVIF"].includes(ext);
    }
    function isVideoFile(name) {
        const ext = window.fileLabel(name);
        return ["MP4", "MKV", "WEBM", "AVI", "MOV", "M4V", "FLV", "WMV", "OGV", "TS", "M2TS", "MPG", "MPEG", "3GP"].includes(ext);
    }
    function durationText(seconds) {
        if (!seconds || seconds <= 0) return "";
        const total = Math.floor(seconds);
        const hrs = Math.floor(total / 3600);
        const mins = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return hrs > 0 ? (hrs + ":" + pad(mins) + ":" + pad(secs)) : (pad(mins) + ":" + pad(secs));
    }
    function fileIcon(name) {
        const ext = window.fileLabel(name);
        if (["JS", "TS", "QML", "JSON", "RS", "C", "CPP", "H", "PY", "SH", "RB", "GO", "TOML", "YAML", "YML", "HTML", "CSS"].includes(ext)) return "code";
        if (["PNG", "JPG", "JPEG", "SVG", "WEBP", "GIF", "BMP", "ICO", "TIF", "TIFF", "AVIF"].includes(ext)) return "pictures";
        if (["MP3", "FLAC", "WAV", "OGG", "OPUS", "M4A"].includes(ext)) return "music";
        if (window.isVideoFile(name)) return "videos";
        if (["ZIP", "TAR", "GZ", "XZ", "7Z", "ZST", "DEB", "RPM"].includes(ext)) return "box";
        if (["MD", "TXT", "PDF", "DOC", "DOCX", "LOG"].includes(ext)) return "documents";
        return "file";
    }
    function fileColor(name) {
        const ext = window.fileLabel(name);
        if (["JS", "TS", "QML", "JSON"].includes(ext)) return "#f1ce70";
        if (["RS", "C", "CPP", "H"].includes(ext)) return "#f39b83";
        if (["PY", "SH", "RB", "GO"].includes(ext)) return "#83cba9";
        if (["PNG", "JPG", "JPEG", "SVG", "WEBP", "GIF", "BMP", "ICO", "AVIF"].includes(ext)) return "#d6a2ec";
        if (["MP3", "FLAC", "WAV", "OGG", "OPUS", "M4A"].includes(ext) || window.isVideoFile(name)) return "#f0a6ca";
        if (["ZIP", "TAR", "GZ", "XZ", "7Z", "ZST"].includes(ext)) return "#e8b474";
        return "#91bdf0";
    }
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
        const units = ["KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (value >= 1024 && i < units.length - 1) { value /= 1024; ++i; }
        return value.toFixed(1) + " " + units[i];
    }
    function exactBytesText(bytes) {
        return String(Math.max(0, Math.floor(bytes || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ",") + " bytes";
    }
    function kindDescription(name, isDir) {
        if (isDir) return "Carpeta";
        const ext = window.fileLabel(name);
        if (window.isImageFile(name)) return "Imagen " + ext;
        if (window.isVideoFile(name)) return "Vídeo " + ext;
        if (["MP3", "FLAC", "WAV", "OGG", "OPUS", "M4A"].includes(ext)) return "Audio " + ext;
        if (["ZIP", "TAR", "GZ", "XZ", "7Z", "ZST"].includes(ext)) return "Archivo comprimido " + ext;
        if (["JS", "TS", "QML", "JSON", "RS", "C", "CPP", "H", "PY", "SH", "GO", "TOML", "YAML", "YML"].includes(ext)) return "Código " + ext;
        if (ext === "FILE") return "Archivo";
        return "Archivo " + ext;
    }

    component ContextAction: Rectangle {
        id: actionRow
        property string iconName: ""
        property string text: ""
        property string shortcutHint: ""
        property bool destructive: false
        property bool actionEnabled: true
        signal triggered()

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        color: (rowArea.containsMouse && actionRow.actionEnabled)
               ? (actionRow.destructive ? "#36f38ba8" : GemaTheme.accentAlpha(0.28))
               : "transparent"
        Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            GlassIcon {
                visible: actionRow.iconName.length > 0
                name: actionRow.iconName
                size: 14
                color: actionRow.destructive
                       ? GemaTheme.dangerColor
                       : (rowArea.containsMouse && actionRow.actionEnabled ? GemaTheme.accent : GemaTheme.mutedColor)
                opacity: actionRow.actionEnabled ? 1.0 : 0.38
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: actionRow.text
                textFormat: Text.PlainText
                color: actionRow.destructive ? GemaTheme.dangerColor : GemaTheme.textColor
                opacity: actionRow.actionEnabled ? 1.0 : 0.42
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 13
                font.weight: (rowArea.containsMouse && actionRow.actionEnabled) ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                visible: actionRow.shortcutHint.length > 0
                text: actionRow.shortcutHint
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                opacity: actionRow.actionEnabled ? 0.82 : 0.32
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: actionRow.actionEnabled
            cursorShape: actionRow.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                window.closeContextMenu();
                actionRow.triggered();
            }
        }
    }

    component ContextDivider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 3
        Layout.bottomMargin: 3
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        implicitHeight: 1
        color: "#22ffffff"
    }

    component InfoRow: ColumnLayout {
        id: metaRow
        property string label: ""
        property string value: ""
        property bool showDivider: true
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 7
            Layout.bottomMargin: 7
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 12

            Text {
                Layout.preferredWidth: 112
                text: metaRow.label
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: metaRow.value
                textFormat: Text.PlainText
                color: GemaTheme.textColor
                font.pixelSize: 12
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            visible: metaRow.showDivider
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            implicitHeight: 1
            color: "#18ffffff"
        }
    }

    component EmptyState: Item {
        id: emptyRoot
        anchors.fill: parent
        property bool searching: search.text.length > 0
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10
            GlassPanel {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 52
                implicitHeight: 52
                radius: 26
                topColor: GemaTheme.accentAlpha(0.16)
                bottomColor: "#140a0e18"
                edgeColor: GemaTheme.accentAlpha(0.36)
                GlassIcon {
                    anchors.centerIn: parent
                    name: window.bridge.loading ? "refresh" : (emptyRoot.searching ? "search" : "folder-open")
                    size: 22
                    color: GemaTheme.accent
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: window.bridge.loading
                      ? "Cargando carpeta…"
                      : (emptyRoot.searching
                         ? "Sin coincidencias para «" + search.text + "»"
                         : (window.bridge.path ? "Esta carpeta está vacía" : "Conectando con el motor…"))
                textFormat: Text.PlainText
                color: GemaTheme.textColor
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: !window.bridge.loading && window.bridge.path.length > 0
                text: emptyRoot.searching
                      ? "Prueba con otro término o limpia el filtro."
                      : "Usa Nueva carpeta (Ctrl+Shift+N) o pega elementos aquí."
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                font.pixelSize: 12
            }
            ActionButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: emptyRoot.searching && !window.bridge.loading
                iconName: "x"
                text: "Limpiar búsqueda"
                accent: true
                onClicked: { search.clear(); search.forceActiveFocus(); }
            }
        }
    }

    BackgroundEffect.blurRegion: Region { item: GemaTheme.blur ? surface : null; radius: surface.radius }

    MattePanel {
        id: surface
        anchors.fill: parent
        anchors.margins: 1
        radius: GemaTheme.rounding
        topColor: "#18ffffff"
        bottomColor: "#0effffff"
        edgeColor: "#46ffffff"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 12
        spacing: 10

        // === BARRA SUPERIOR UNIFICADA: MARCA + NAVEGACIÓN + RUTA + BÚSQUEDA ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Identidad compacta de la app.
            RowLayout {
                spacing: 8
                GlassPanel {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: GemaTheme.controlRadius
                    topColor: GemaTheme.accentAlpha(0.28)
                    bottomColor: GemaTheme.accentAlpha(0.12)
                    edgeColor: GemaTheme.accentAlpha(0.62)
                    GlassIcon {
                        anchors.centerIn: parent
                        name: "folder"
                        size: 16
                        color: GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff"
                    }
                }
                Text {
                    visible: window.width >= 680
                    text: "Explorer"
                    color: GemaTheme.textColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.letterSpacing: -0.2
                    style: GemaTheme.darkText ? Text.Normal : Text.Raised
                    styleColor: "#50000000"
                }
                Rectangle {
                    visible: window.width >= 960
                    implicitWidth: verText.implicitWidth + 12
                    implicitHeight: 20
                    radius: 10
                    color: GemaTheme.accentAlpha(0.16)
                    border.width: 1
                    border.color: GemaTheme.accentAlpha(0.32)
                    Text {
                        id: verText
                        anchors.centerIn: parent
                        text: "v" + window.bridge.appVersion
                        color: GemaTheme.accent
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                visible: window.width >= 680
                implicitWidth: 1
                implicitHeight: 20
                color: "#24ffffff"
            }

            // Controles de navegación con iconografía unificada.
            RowLayout {
                spacing: 4
                ActionButton {
                    id: sidebarBtn
                    iconName: "sidebar"
                    ghost: !window.sidebarOpen
                    implicitWidth: 34
                    implicitHeight: 34
                    toolTipText: window.sidebarOpen ? "Ocultar lugares (Ctrl+B)" : "Mostrar lugares (Ctrl+B)"
                    onClicked: { window.sidebarManual = true; window.sidebarOpen = !window.sidebarOpen; }
                }
                ActionButton {
                    id: backBtn
                    iconName: "arrow-left"
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.canBack
                    toolTipText: "Atrás (Alt+←)"
                    onClicked: window.bridge.back()
                }
                ActionButton {
                    id: forwardBtn
                    iconName: "arrow-right"
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.canForward
                    toolTipText: "Adelante (Alt+→)"
                    onClicked: window.bridge.forward()
                }
                ActionButton {
                    id: upBtn
                    iconName: "arrow-up"
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.ready && !window.bridge.busy && window.bridge.parentPath !== "" && window.bridge.parentPath !== window.bridge.path
                    toolTipText: "Carpeta superior (Alt+↑)"
                    onClicked: window.bridge.list(window.bridge.parentPath, window.bridge.showHidden, "navigate")
                }
                ActionButton {
                    id: homeNavBtn
                    visible: !window.sidebarOpen
                    iconName: "home"
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.ready && !window.bridge.busy
                    toolTipText: "Ir a Inicio"
                    onClicked: window.bridge.home()
                }
            }

            // Barra de ruta / breadcrumbs en una sola cápsula de cristal.
            GlassPanel {
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                implicitHeight: 36
                radius: GemaTheme.controlRadius
                highlighted: window.editingPath
                topColor: window.editingPath ? "#20ffffff" : (GemaTheme.darkText ? "#22ffffff" : "#180b0f1a")
                bottomColor: GemaTheme.darkText ? "#14ffffff" : "#1e080c15"
                edgeColor: window.editingPath ? GemaTheme.accentAlpha(0.75) : "#30ffffff"

                TextField {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    visible: window.editingPath
                    enabled: window.bridge.ready && !window.bridge.busy
                    selectByMouse: true
                    placeholderText: "Escribir ruta absoluta…"
                    placeholderTextColor: GemaTheme.placeholderColor
                    text: window.bridge.path
                    color: GemaTheme.textColor
                    selectionColor: GemaTheme.accentAlpha(0.45)
                    selectedTextColor: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    background: null
                    onAccepted: {
                        const target = pathField.text;
                        window.editingPath = false;
                        window.bridge.list(target, window.bridge.showHidden, "navigate");
                    }
                    onActiveFocusChanged: if (!pathField.activeFocus && window.editingPath) { pathField.text = window.bridge.path; window.editingPath = false; }
                    Keys.onEscapePressed: { pathField.text = window.bridge.path; window.editingPath = false; }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 4
                    spacing: 2
                    visible: !window.editingPath

                    Flickable {
                        id: crumbsFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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
                            width: crumbsFlickable.contentWidth
                            height: crumbsFlickable.height
                            cursorShape: Qt.IBeamCursor
                            enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                            onClicked: window.startEditPath()
                        }

                        Row {
                            id: crumbs
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            // Segmento raíz "/".
                            Rectangle {
                                id: rootCrumb
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 7
                                color: rootCrumbMouse.containsMouse ? "#24ffffff" : (window.pathSegments.length === 0 ? GemaTheme.accentAlpha(0.24) : "transparent")
                                Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }
                                GlassIcon {
                                    anchors.centerIn: parent
                                    name: "root"
                                    size: 13
                                    color: window.pathSegments.length === 0 ? GemaTheme.accent : GemaTheme.mutedColor
                                }
                                MouseArea {
                                    id: rootCrumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: window.bridge.ready && !window.bridge.busy
                                    onClicked: window.bridge.list("/", window.bridge.showHidden, "navigate")
                                }
                                GlassToolTip { visible: rootCrumbMouse.containsMouse; text: "Sistema (/)" }
                            }

                            Repeater {
                                model: window.pathSegments
                                Row {
                                    id: crumbItem
                                    required property string modelData
                                    required property int index
                                    readonly property bool isCurrent: crumbItem.index === window.pathSegments.length - 1
                                    spacing: 2

                                    GlassIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "chevron-right"
                                        size: 12
                                        color: GemaTheme.subtleColor
                                        opacity: 0.65
                                    }

                                    Rectangle {
                                        implicitWidth: crumbLabel.implicitWidth + 16
                                        implicitHeight: 26
                                        radius: 7
                                        color: crumbMouse.containsMouse
                                               ? "#24ffffff"
                                               : (crumbItem.isCurrent ? GemaTheme.accentAlpha(0.22) : "transparent")
                                        border.width: crumbItem.isCurrent ? 1 : 0
                                        border.color: GemaTheme.accentAlpha(0.35)
                                        Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                                        Text {
                                            id: crumbLabel
                                            anchors.centerIn: parent
                                            text: crumbItem.modelData
                                            textFormat: Text.PlainText
                                            color: crumbItem.isCurrent ? GemaTheme.textColor : GemaTheme.mutedColor
                                            font.pixelSize: 13
                                            font.weight: crumbItem.isCurrent ? Font.DemiBold : Font.Normal
                                        }

                                        MouseArea {
                                            id: crumbMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: window.bridge.ready && !window.bridge.busy
                                            onClicked: window.bridge.list("/" + window.pathSegments.slice(0, crumbItem.index + 1).join("/"), window.bridge.showHidden, "navigate")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ActionButton {
                        id: editBtn
                        iconName: "edit"
                        iconSize: 13
                        ghost: true
                        implicitWidth: 28
                        implicitHeight: 28
                        cornerRadius: 7
                        toolTipText: "Editar ruta (Ctrl+L)"
                        enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                        onClicked: window.startEditPath()
                    }
                }
            }

            // Buscador compacto integrado con icono y botón limpiar inline.
            GlassPanel {
                Layout.preferredWidth: window.width >= 960 ? 245 : (window.width >= 720 ? 195 : 145)
                Layout.minimumWidth: 120
                implicitHeight: 36
                radius: GemaTheme.controlRadius
                highlighted: search.activeFocus
                topColor: search.activeFocus ? "#22ffffff" : (GemaTheme.darkText ? "#22ffffff" : "#180b0f1a")
                bottomColor: GemaTheme.darkText ? "#14ffffff" : "#1e080c15"
                edgeColor: search.activeFocus ? GemaTheme.accentAlpha(0.76) : "#30ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    spacing: 6

                    GlassIcon {
                        name: "search"
                        size: 14
                        color: search.activeFocus || search.text.length > 0 ? GemaTheme.accent : GemaTheme.subtleColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: search
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        placeholderText: window.width >= 820 ? "Buscar… (Ctrl+F)" : "Buscar…"
                        placeholderTextColor: GemaTheme.placeholderColor
                        Accessible.name: "Buscar por nombre en esta carpeta"
                        selectByMouse: true
                        color: GemaTheme.textColor
                        selectionColor: GemaTheme.accentAlpha(0.45)
                        selectedTextColor: "#ffffff"
                        font.pixelSize: 13
                        leftPadding: 0
                        rightPadding: 0
                        verticalAlignment: Text.AlignVCenter
                        background: null
                        onTextChanged: window.uiError = ""
                        Keys.onEscapePressed: (event) => { search.clear(); event.accepted = true; }
                    }

                    ActionButton {
                        visible: search.text.length > 0
                        iconName: "x"
                        iconSize: 13
                        ghost: true
                        implicitWidth: 26
                        implicitHeight: 26
                        cornerRadius: 7
                        toolTipText: "Limpiar búsqueda (Esc)"
                        onClicked: { search.clear(); search.forceActiveFocus(); }
                    }
                }
            }
        }

        // === BARRA DE ACCIONES Y CONTROLES DE VISTA ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ActionButton {
                id: newFolderBtn
                iconName: "folder-plus"
                text: window.width >= 760 ? "Nueva carpeta" : ""
                toolTipText: "Nueva carpeta (Ctrl+Shift+N)"
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: window.openMkdirDialog()
            }

            ActionButton {
                id: termBtn
                iconName: "terminal"
                text: window.width >= 840 ? "Terminal" : ""
                toolTipText: "Abrir terminal en esta carpeta"
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: window.bridge.openTerminal(window.bridge.path)
            }

            ActionButton {
                id: refreshBtn
                iconName: "refresh"
                ghost: true
                implicitWidth: 34
                toolTipText: "Actualizar (F5)"
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); }
            }

            // Píldora contextual para pegar cuando el portapapeles está activo.
            GlassPanel {
                visible: window.clipboardPath !== ""
                implicitHeight: 34
                implicitWidth: clipRow.implicitWidth + 8
                Layout.maximumWidth: 240
                radius: GemaTheme.controlRadius
                topColor: GemaTheme.accentAlpha(0.24)
                bottomColor: GemaTheme.accentAlpha(0.12)
                edgeColor: GemaTheme.accentAlpha(0.55)

                RowLayout {
                    id: clipRow
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 2
                    ActionButton {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        ghost: true
                        iconName: "clipboard"
                        iconSize: 13
                        text: (window.clipboardMode === "cut" ? "Mover: " : "Pegar: ") + window.clipboardName
                        toolTipText: "Pegar aquí (Ctrl+V)"
                        enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                        onClicked: window.pasteClipboard()
                    }
                    ActionButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        cornerRadius: 6
                        ghost: true
                        iconName: "x"
                        iconSize: 12
                        toolTipText: "Vaciar portapapeles"
                        onClicked: window.clearClipboard()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Selector de ordenación + dirección.
            GlassComboBox {
                id: sortCombo
                implicitWidth: 108
                implicitHeight: 34
                model: [
                    {"key": "name", "label": "Nombre"},
                    {"key": "mtime", "label": "Fecha"},
                    {"key": "size", "label": "Tamaño"},
                    {"key": "type", "label": "Tipo"}
                ]
                textRole: "label"
                valueRole: "key"
                currentIndex: Math.max(0, sortCombo.indexOfValue(window.bridge.sortBy))
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onActivated: window.bridge.setSort(String(sortCombo.currentValue), window.bridge.sortDesc)
            }

            ActionButton {
                id: sortDirBtn
                iconName: window.bridge.sortDesc ? "sort-desc" : "sort-asc"
                implicitWidth: 34
                toolTipText: window.bridge.sortDesc ? "Orden descendente (clic para invertir)" : "Orden ascendente (clic para invertir)"
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                onClicked: window.bridge.setSort(window.bridge.sortBy, !window.bridge.sortDesc)
            }

            // Control segmentado para cambiar entre Cuadrícula y Lista (estado activo claro).
            GlassPanel {
                implicitHeight: 34
                implicitWidth: viewSwitchRow.implicitWidth + 6
                radius: GemaTheme.controlRadius + 1
                reflective: false
                topColor: GemaTheme.darkText ? "#1effffff" : "#1a0a0e18"
                bottomColor: GemaTheme.darkText ? "#12ffffff" : "#1c080b14"
                edgeColor: "#2effffff"

                RowLayout {
                    id: viewSwitchRow
                    anchors.centerIn: parent
                    spacing: 2

                    ActionButton {
                        iconName: "grid"
                        iconSize: 14
                        text: window.width >= 760 ? "Cuadrícula" : ""
                        active: window.gridMode
                        ghost: !window.gridMode
                        implicitHeight: 28
                        horizontalPadding: window.width >= 760 ? 10 : 8
                        cornerRadius: Math.max(6, GemaTheme.controlRadius - 2)
                        toolTipText: "Vista en cuadrícula (Ctrl+1)"
                        onClicked: window.switchView(true)
                    }
                    ActionButton {
                        iconName: "list"
                        iconSize: 14
                        text: window.width >= 760 ? "Lista" : ""
                        active: !window.gridMode
                        ghost: window.gridMode
                        implicitHeight: 28
                        horizontalPadding: window.width >= 760 ? 10 : 8
                        cornerRadius: Math.max(6, GemaTheme.controlRadius - 2)
                        toolTipText: "Vista en lista (Ctrl+2)"
                        onClicked: window.switchView(false)
                    }
                }
            }

            // Interruptor glass para archivos ocultos.
            CheckBox {
                id: hiddenCheck
                checked: window.bridge.showHidden
                enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== ""
                hoverEnabled: true
                implicitHeight: 34
                leftPadding: 10
                rightPadding: 10
                topPadding: 0
                bottomPadding: 0
                onClicked: window.bridge.list(window.bridge.path, hiddenCheck.checked, "refresh")

                indicator: Item { width: 0; height: 0 }

                background: GlassPanel {
                    radius: GemaTheme.controlRadius
                    topColor: hiddenCheck.checked
                              ? GemaTheme.accentAlpha(hiddenCheck.hovered ? 0.36 : 0.26)
                              : (hiddenCheck.hovered ? "#22ffffff" : "#15ffffff")
                    bottomColor: hiddenCheck.checked ? GemaTheme.accentAlpha(0.14) : "#0cffffff"
                    edgeColor: hiddenCheck.checked
                               ? GemaTheme.accentAlpha(0.72)
                               : (hiddenCheck.hovered ? GemaTheme.accentAlpha(0.48) : "#30ffffff")
                    opacity: hiddenCheck.enabled ? 1.0 : 0.55
                }

                contentItem: RowLayout {
                    spacing: 7
                    GlassIcon {
                        name: hiddenCheck.checked ? "eye" : "eye-off"
                        size: 14
                        color: hiddenCheck.checked ? GemaTheme.accent : GemaTheme.mutedColor
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        visible: window.width >= 660
                        text: "Ocultos"
                        textFormat: Text.PlainText
                        color: hiddenCheck.checked ? GemaTheme.textColor : GemaTheme.mutedColor
                        font.pixelSize: 13
                        font.weight: hiddenCheck.checked ? Font.DemiBold : Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter
                    }
                    // Mini switch translúcido.
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 15
                        radius: 7.5
                        color: hiddenCheck.checked ? GemaTheme.accentAlpha(0.55) : "#22ffffff"
                        border.width: 1
                        border.color: hiddenCheck.checked ? GemaTheme.accentAlpha(0.85) : "#34ffffff"
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                        Rectangle {
                            width: 11
                            height: 11
                            radius: 5.5
                            y: 2
                            x: hiddenCheck.checked ? 13 : 2
                            color: hiddenCheck.checked ? "#ffffff" : GemaTheme.mutedColor
                            Behavior on x { NumberAnimation { duration: GemaTheme.animDuration; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                GlassToolTip {
                    visible: hiddenCheck.hovered
                    text: hiddenCheck.checked ? "Ocultar archivos que empiezan con punto" : "Mostrar archivos ocultos"
                }
            }
        }

        // === ESPACIO PRINCIPAL: BARRA LATERAL DE LUGARES + PANEL DE CONTENIDO ===
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Barra lateral de lugares.
            GlassPanel {
                Layout.preferredWidth: window.width < 720 ? 172 : 204
                Layout.fillHeight: true
                visible: window.sidebarOpen
                topColor: GemaTheme.darkText ? "#22ffffff" : "#14ffffff"
                bottomColor: GemaTheme.darkText ? "#14ffffff" : "#180a0e18"
                edgeColor: "#32ffffff"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "LUGARES"
                        color: GemaTheme.subtleColor
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                        leftPadding: 8
                        topPadding: 2
                        bottomPadding: 2
                    }

                    ListView {
                        id: placesList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: window.bridge.places
                        ScrollBar.vertical: GlassScrollBar {}

                        delegate: Item {
                            id: placeDelegate
                            required property var modelData
                            required property int index
                            readonly property bool isActive: window.bridge.path === placeDelegate.modelData.path
                            readonly property bool needsSeparator: {
                                if (placeDelegate.index <= 0) return false;
                                const prev = window.bridge.places[placeDelegate.index - 1];
                                if (!prev) return false;
                                return window.placeGroup(placeDelegate.modelData.kind) !== window.placeGroup(prev.kind);
                            }

                            width: placesList.width
                            height: needsSeparator ? 46 : 35

                            Rectangle {
                                visible: placeDelegate.needsSeparator
                                anchors.top: parent.top
                                anchors.topMargin: 5
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                height: 1
                                color: "#1effffff"
                            }

                            Rectangle {
                                id: placeRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 35
                                radius: 9
                                color: placeDelegate.isActive
                                       ? GemaTheme.accentAlpha(0.24)
                                       : (placeMouse.containsMouse ? "#1affffff" : "transparent")
                                border.width: placeDelegate.isActive ? 1 : 0
                                border.color: GemaTheme.accentAlpha(0.44)
                                Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                                // Indicador vertical luminoso para el lugar activo.
                                Rectangle {
                                    visible: placeDelegate.isActive
                                    anchors.left: parent.left
                                    anchors.leftMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 16
                                    radius: 1.5
                                    color: GemaTheme.accent
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    GlassIcon {
                                        name: window.placeIcon(placeDelegate.modelData.kind)
                                        size: 15
                                        color: placeDelegate.isActive
                                               ? GemaTheme.accent
                                               : (placeMouse.containsMouse ? GemaTheme.textColor : GemaTheme.mutedColor)
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Text {
                                        text: placeDelegate.modelData.name
                                        textFormat: Text.PlainText
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                        color: placeDelegate.isActive ? GemaTheme.textColor : (placeMouse.containsMouse ? GemaTheme.textColor : GemaTheme.mutedColor)
                                        font.pixelSize: 13
                                        font.weight: placeDelegate.isActive ? Font.DemiBold : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: placeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: window.bridge.ready && !window.bridge.busy
                                    onClicked: {
                                        window.uiError = "";
                                        window.bridge.list(placeDelegate.modelData.path, window.bridge.showHidden, "navigate");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Panel principal de archivos y carpetas.
            GlassPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topColor: GemaTheme.darkText ? "#1effffff" : "#140c101b"
                bottomColor: GemaTheme.darkText ? "#12ffffff" : "#20080b14"
                edgeColor: "#32ffffff"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // Encabezado interactivo de columnas en vista Lista.
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        visible: !window.gridMode

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    Text {
                                        text: "NOMBRE"
                                        color: window.bridge.sortBy === "name" ? GemaTheme.accent : GemaTheme.subtleColor
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }
                                    GlassIcon {
                                        visible: window.bridge.sortBy === "name"
                                        name: window.bridge.sortDesc ? "chevron-down" : "chevron-up"
                                        size: 12
                                        color: GemaTheme.accent
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.toggleSort("name")
                                }
                            }

                            Item {
                                visible: window.width >= 760
                                Layout.preferredWidth: 136
                                Layout.fillHeight: true
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    Text {
                                        text: "MODIFICADO"
                                        color: window.bridge.sortBy === "mtime" ? GemaTheme.accent : GemaTheme.subtleColor
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }
                                    GlassIcon {
                                        visible: window.bridge.sortBy === "mtime"
                                        name: window.bridge.sortDesc ? "chevron-down" : "chevron-up"
                                        size: 12
                                        color: GemaTheme.accent
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.toggleSort("mtime")
                                }
                            }

                            Item {
                                Layout.preferredWidth: 102
                                Layout.fillHeight: true
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    Text {
                                        text: "TIPO"
                                        color: window.bridge.sortBy === "type" ? GemaTheme.accent : GemaTheme.subtleColor
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }
                                    GlassIcon {
                                        visible: window.bridge.sortBy === "type"
                                        name: window.bridge.sortDesc ? "chevron-down" : "chevron-up"
                                        size: 12
                                        color: GemaTheme.accent
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.toggleSort("type")
                                }
                            }

                            Item {
                                Layout.preferredWidth: 84
                                Layout.fillHeight: true
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    Item { Layout.fillWidth: true }
                                    GlassIcon {
                                        visible: window.bridge.sortBy === "size"
                                        name: window.bridge.sortDesc ? "chevron-down" : "chevron-up"
                                        size: 12
                                        color: GemaTheme.accent
                                    }
                                    Text {
                                        text: "TAMAÑO"
                                        color: window.bridge.sortBy === "size" ? GemaTheme.accent : GemaTheme.subtleColor
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1.0
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.toggleSort("size")
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#22ffffff"
                        }
                    }

                    // === VISTA LISTA ===
                    ListView {
                        id: listing
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !window.gridMode
                        clip: true
                        focus: !window.gridMode
                        spacing: 2
                        model: window.filteredEntries
                        currentIndex: -1
                        onModelChanged: listing.currentIndex = -1
                        ScrollBar.vertical: GlassScrollBar {}
                        Keys.onReturnPressed: window.openEntry(window.filteredEntries[listing.currentIndex])
                        Keys.onEnterPressed: window.openEntry(window.filteredEntries[listing.currentIndex])

                        WheelHandler {
                            acceptedModifiers: Qt.ControlModifier
                            onWheel: (event) => window.handleZoomWheel(event)
                        }

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: listing.currentIndex === row.index
                            readonly property bool isImage: !row.modelData.isDir && window.isImageFile(row.modelData.name)
                            readonly property bool isVideo: !row.modelData.isDir && window.isVideoFile(row.modelData.name)
                            readonly property var videoInfo: row.isVideo ? (window.bridge.videoThumbs[row.modelData.path] || null) : null
                            readonly property string thumbFile: row.isImage ? row.modelData.path : (row.videoInfo ? row.videoInfo.thumbPath : "")
                            readonly property string videoDur: (row.videoInfo && row.videoInfo.duration > 0) ? window.durationText(row.videoInfo.duration) : ""
                            readonly property int thumbBoxSize: Math.max(22, window.listRowHeight - 12)
                            readonly property color itemTone: row.modelData.isDir ? GemaTheme.accent : window.fileColor(row.modelData.name)
                            width: listing.width
                            height: window.listRowHeight
                            radius: 9
                            color: row.isSelected
                                   ? GemaTheme.accentAlpha(0.26)
                                   : (mouse.containsMouse ? "#18ffffff" : "transparent")
                            border.width: row.isSelected ? 1 : 0
                            border.color: GemaTheme.accentAlpha(0.50)
                            Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    implicitWidth: row.thumbBoxSize
                                    implicitHeight: row.thumbBoxSize
                                    radius: row.thumbBoxSize >= 44 ? 8 : 7
                                    color: Qt.rgba(row.itemTone.r, row.itemTone.g, row.itemTone.b, row.modelData.isDir ? 0.22 : 0.16)
                                    border.width: row.thumbFile.length > 0 && listThumb.ready ? 0 : 1
                                    border.color: Qt.rgba(row.itemTone.r, row.itemTone.g, row.itemTone.b, 0.42)
                                    Layout.alignment: Qt.AlignVCenter

                                    GlassThumbnail {
                                        id: listThumb
                                        visible: row.thumbFile.length > 0
                                        anchors.fill: parent
                                        filePath: row.thumbFile
                                        cornerRadius: row.thumbBoxSize >= 44 ? 8 : 6
                                        decodeSize: 320
                                    }

                                    Rectangle {
                                        visible: row.isVideo && listThumb.ready
                                        anchors.centerIn: parent
                                        width: Math.max(14, Math.min(24, Math.round(row.thumbBoxSize * 0.48)))
                                        height: width
                                        radius: width / 2
                                        color: "#b80b0f18"
                                        border.width: 1
                                        border.color: "#58ffffff"
                                        GlassIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            name: "play"
                                            size: Math.max(7, Math.round(parent.width * 0.46))
                                            strokeWidth: 1.5
                                            color: "#ffffff"
                                        }
                                    }

                                    GlassIcon {
                                        visible: row.thumbFile.length === 0 || !listThumb.ready
                                        anchors.centerIn: parent
                                        name: row.modelData.isDir ? "folder" : window.fileIcon(row.modelData.name)
                                        size: Math.min(20, Math.max(13, Math.round(row.thumbBoxSize * 0.52)))
                                        color: row.itemTone
                                    }
                                }

                                Text {
                                    text: row.modelData.name
                                    textFormat: Text.PlainText
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideMiddle
                                    color: GemaTheme.textColor
                                    font.pixelSize: window.listRowHeight >= 56 ? 14 : (window.listRowHeight <= 34 ? 12 : 13)
                                    font.weight: row.isSelected ? Font.DemiBold : (row.modelData.isDir ? Font.Medium : Font.Normal)
                                }

                                Text {
                                    text: window.dateText(row.modelData.mtime)
                                    visible: window.width >= 760
                                    Layout.preferredWidth: 136
                                    color: row.isSelected ? GemaTheme.mutedColor : GemaTheme.subtleColor
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: row.modelData.isDir ? "Carpeta" : (row.videoDur.length > 0 ? (window.fileLabel(row.modelData.name) + " · " + row.videoDur) : window.fileLabel(row.modelData.name))
                                    Layout.preferredWidth: 102
                                    elide: Text.ElideRight
                                    color: row.modelData.isDir ? (row.isSelected ? GemaTheme.mutedColor : GemaTheme.subtleColor) : row.itemTone
                                    font.pixelSize: 11
                                    font.weight: row.modelData.isDir ? Font.Normal : Font.Medium
                                }

                                Text {
                                    text: row.modelData.isDir ? "—" : window.sizeText(row.modelData.size)
                                    Layout.preferredWidth: 84
                                    horizontalAlignment: Text.AlignRight
                                    color: row.isSelected ? GemaTheme.mutedColor : GemaTheme.subtleColor
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouseEvent) => {
                                    listing.currentIndex = row.index;
                                    listing.forceActiveFocus();
                                    if (mouseEvent.button === Qt.RightButton) window.openContextMenu(row.modelData, row, mouseEvent.x, mouseEvent.y);
                                }
                                onDoubleClicked: (mouseEvent) => { if (mouseEvent.button === Qt.LeftButton) window.openEntry(row.modelData); }
                            }
                        }

                        MouseArea {
                            z: -1
                            parent: listing
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouseEvent) => {
                                if (mouseEvent.button === Qt.RightButton) window.openContextMenu(null, listing, mouseEvent.x, mouseEvent.y);
                                else listing.currentIndex = -1;
                            }
                        }

                        EmptyState { visible: window.filteredEntries.length === 0 }
                    }

                    // === VISTA CUADRÍCULA ===
                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: -4
                        visible: window.gridMode
                        focus: window.gridMode
                        clip: true
                        cellWidth: Math.floor(grid.width / Math.max(1, Math.floor(grid.width / window.gridItemSize)))
                        cellHeight: Math.max(106, Math.round(window.gridItemSize * 0.84) + 26)
                        model: window.filteredEntries
                        currentIndex: -1
                        onModelChanged: grid.currentIndex = -1
                        ScrollBar.vertical: GlassScrollBar {}
                        Keys.onReturnPressed: window.openEntry(window.filteredEntries[grid.currentIndex])
                        Keys.onEnterPressed: window.openEntry(window.filteredEntries[grid.currentIndex])

                        WheelHandler {
                            acceptedModifiers: Qt.ControlModifier
                            onWheel: (event) => window.handleZoomWheel(event)
                        }

                        delegate: ExplorerIconCard {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property var videoInfo: (!card.directory && window.isVideoFile(card.name))
                                                             ? (window.bridge.videoThumbs[card.path] || null)
                                                             : null
                            width: grid.cellWidth - 8
                            height: grid.cellHeight - 8
                            path: card.modelData.path
                            name: card.modelData.name
                            directory: card.modelData.isDir
                            imagePreview: !card.directory && window.isImageFile(card.name)
                            videoPreview: !card.directory && window.isVideoFile(card.name)
                            previewSourcePath: card.videoInfo ? card.videoInfo.thumbPath : (card.imagePreview ? card.path : "")
                            durationLabel: (card.videoInfo && card.videoInfo.duration > 0) ? window.durationText(card.videoInfo.duration) : ""
                            itemAccent: card.directory ? GemaTheme.accent : window.fileColor(card.name)
                            langLabel: card.directory ? "" : window.fileLabel(card.name)
                            detailText: card.directory
                                        ? card.path
                                        : ((card.durationLabel.length > 0 ? (card.durationLabel + "  ·  ") : "")
                                           + window.sizeText(card.modelData.size) + "  ·  " + window.dateText(card.modelData.mtime))
                            focusPolicy: Qt.NoFocus
                            selected: grid.currentIndex === card.index
                            onClicked: { grid.currentIndex = card.index; grid.forceActiveFocus(); }
                            onDoubleClicked: window.openEntry(card.modelData)
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: (mouseEvent) => {
                                    grid.currentIndex = card.index;
                                    grid.forceActiveFocus();
                                    window.openContextMenu(card.modelData, card, mouseEvent.x, mouseEvent.y);
                                }
                            }
                        }

                        MouseArea {
                            z: -1
                            parent: grid
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouseEvent) => {
                                if (mouseEvent.button === Qt.RightButton) window.openContextMenu(null, grid, mouseEvent.x, mouseEvent.y);
                                else grid.currentIndex = -1;
                            }
                        }

                        EmptyState { visible: window.filteredEntries.length === 0 }
                    }
                }
            }
        }

        // === BARRA DE ESTADO INFERIOR ===
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 8

            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: (window.bridge.error || window.uiError)
                       ? GemaTheme.dangerColor
                       : (window.statusMessage || window.bridge.loading || window.bridge.mutating)
                         ? GemaTheme.accent
                         : GemaTheme.accentAlpha(0.55)
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: {
                    if (window.bridge.error || window.uiError) return window.bridge.error || window.uiError;
                    if (window.statusMessage) return window.statusMessage;
                    if (window.bridge.loading) return "Cargando carpeta…";
                    if (window.bridge.mutating) return "Procesando operación…";
                    const count = window.filteredEntries.length;
                    let summary = count + (count === 1 ? " elemento" : " elementos");
                    if (search.text.length > 0) summary += " de " + window.bridge.entries.length + " · filtro activo";
                    if (window.currentEntry) {
                        summary += "  ·  " + window.currentEntry.name;
                        const vInfo = !window.currentEntry.isDir ? (window.bridge.videoThumbs[window.currentEntry.path] || null) : null;
                        if (vInfo && vInfo.duration > 0) summary += "  ·  " + window.durationText(vInfo.duration);
                        summary += window.currentEntry.isDir ? " (Carpeta)" : ("  ·  " + window.sizeText(window.currentEntry.size));
                    }
                    if (window.bridge.skipped > 0) {
                        summary += "  ·  " + window.bridge.skipped + (window.bridge.skipped === 1 ? " entrada omitida" : " entradas omitidas");
                    }
                    return summary;
                }
                textFormat: Text.PlainText
                color: (window.bridge.error || window.uiError) ? GemaTheme.dangerColor : GemaTheme.mutedColor
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: (window.bridge.error || window.uiError || window.statusMessage) ? Font.Medium : Font.Normal
            }

            Rectangle {
                id: zoomPill
                visible: window.zoomPercent !== 100
                implicitWidth: zoomLabel.implicitWidth + 14
                implicitHeight: 20
                radius: 10
                color: zoomPillMouse.containsMouse ? GemaTheme.accentAlpha(0.28) : GemaTheme.accentAlpha(0.16)
                border.width: 1
                border.color: GemaTheme.accentAlpha(0.42)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                Text {
                    id: zoomLabel
                    anchors.centerIn: parent
                    text: window.zoomPercent + "%"
                    textFormat: Text.PlainText
                    color: GemaTheme.accent
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: zoomPillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.resetZoom()
                }

                GlassToolTip {
                    visible: zoomPillMouse.containsMouse
                    text: "Zoom de vista (" + window.zoomPercent + "%) · Clic o Ctrl+0 para restablecer"
                }
            }

            Text {
                visible: window.width >= 760
                text: "Ctrl+Scroll zoom  ·  Ctrl+F buscar  ·  Ctrl+L ruta  ·  F2 renombrar"
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                opacity: 0.72
                font.pixelSize: 11
            }
        }
    }

    Connections {
        target: window.bridge
        function onListingSucceeded() {
            window.closeContextMenu();
            window.uiError = "";
            if (window.listedPath !== window.bridge.path) search.clear();
            window.listedPath = window.bridge.path;
            window.editingPath = false;
            pathField.text = window.bridge.path;
            listing.currentIndex = -1;
            grid.currentIndex = -1;
            crumbsFlickable.scrollToEnd();
            sortCombo.currentIndex = Math.max(0, sortCombo.indexOfValue(window.bridge.sortBy));
            const videos = window.bridge.entries
                .filter(entry => !entry.isDir && window.isVideoFile(entry.name))
                .map(entry => entry.path);
            window.bridge.requestVideoThumbs(videos);
        }
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
            if (action === "move") window.clearClipboard();
            if (window.clipboardPath !== "" && sourcePath !== "" && (window.clipboardPath === sourcePath || window.clipboardPath.startsWith(sourcePath + "/"))) {
                if (action === "trash") {
                    window.clearClipboard();
                } else if (action === "rename") {
                    if (!targetPath) {
                        window.clearClipboard();
                    } else if (window.clipboardPath === sourcePath) {
                        window.clipboardPath = targetPath;
                        window.clipboardName = targetPath.slice(targetPath.lastIndexOf("/") + 1);
                    } else {
                        window.clipboardPath = targetPath + window.clipboardPath.slice(sourcePath.length);
                    }
                }
            }
            const messages = {mkdir: "Carpeta creada", rename: "Elemento renombrado", trash: "Movido a la papelera", copy: "Copiado correctamente", move: "Movido correctamente"};
            if (messages[action]) window.showStatus(messages[action]);
        }
        function onStatusNotice(message) { window.showStatus(message); }
        function onEntryInfoReady(info) {
            if (info && info.path === infoDialog.targetPath) infoDialog.infoData = info;
        }
    }

    // === ATAJOS DE TECLADO ===
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: window.bridge.ready && !window.bridge.busy && window.bridge.path !== "" && !window.modalOpen; onActivated: window.openMkdirDialog() }
    Shortcut { sequence: "F2"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.openRenameDialog(window.selectedEntry()) }
    Shortcut { sequence: "Delete"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.openTrashDialog(window.selectedEntry()) }
    Shortcut { sequence: "Ctrl+C"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.setClipboard(window.selectedEntry(), "copy") }
    Shortcut { sequence: "Ctrl+X"; enabled: window.canMutate && window.selectedEntry() !== null; onActivated: window.setClipboard(window.selectedEntry(), "cut") }
    Shortcut { sequence: "Ctrl+V"; enabled: window.canMutate && window.clipboardPath !== "" && window.bridge.path !== ""; onActivated: window.pasteClipboard() }
    Shortcut { sequence: "Ctrl+I"; enabled: window.bridge.ready && !window.modalOpen && !window.textInputFocused && window.bridge.path !== ""; onActivated: window.openInfoDialog(window.selectedEntry()) }
    Shortcut { sequence: "Alt+Return"; enabled: window.bridge.ready && !window.modalOpen && !window.textInputFocused && window.bridge.path !== ""; onActivated: window.openInfoDialog(window.selectedEntry()) }
    Shortcut { sequence: "Alt+Left"; onActivated: window.bridge.back() }
    Shortcut { sequence: "Alt+Right"; onActivated: window.bridge.forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: { if (window.bridge.parentPath && window.bridge.parentPath !== window.bridge.path) window.bridge.list(window.bridge.parentPath, window.bridge.showHidden, "navigate"); } }
    Shortcut { sequence: "Ctrl+L"; enabled: window.bridge.ready && !window.bridge.busy; onActivated: window.startEditPath() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { search.forceActiveFocus(); search.selectAll(); } }
    Shortcut { sequence: "Ctrl+1"; onActivated: window.switchView(true) }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.switchView(false) }
    Shortcut { sequence: "Ctrl+B"; onActivated: { window.sidebarManual = true; window.sidebarOpen = !window.sidebarOpen; } }
    Shortcut { sequence: "Ctrl++"; onActivated: window.adjustZoom(1) }
    Shortcut { sequence: "Ctrl+="; onActivated: window.adjustZoom(1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: window.adjustZoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: window.resetZoom() }
    Shortcut { sequence: "F5"; onActivated: { if (window.bridge.path) { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); } } }

    // === MENÚ CONTEXTUAL FLOTANTE GLASS (CAPA IN-WINDOW SIN COLAPSO DE ANCHO) ===
    Item {
        id: contextMenuLayer
        anchors.fill: parent
        z: 500
        visible: window.contextMenuOpen
        focus: window.contextMenuOpen
        Keys.onEscapePressed: (event) => {
            window.closeContextMenu();
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: window.closeContextMenu()
        }

        // Sombra suave detrás del menú flotante.
        Rectangle {
            x: contextMenuPanel.x - 4
            y: contextMenuPanel.y + 4
            width: contextMenuPanel.width + 8
            height: contextMenuPanel.height + 6
            radius: 17
            color: "#5c05070e"
        }

        MattePanel {
            id: contextMenuPanel
            overlay: true
            radius: 14
            width: 266
            height: contextMenuColumn.implicitHeight + 14
            x: Math.max(10, Math.min(window.contextMenuX, contextMenuLayer.width - width - 10))
            y: Math.max(10, Math.min(window.contextMenuY, contextMenuLayer.height - height - 10))

            // Evita que clics dentro del panel cierren el menú antes de activar una opción.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            ColumnLayout {
                id: contextMenuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 7
                spacing: 2

                // Encabezado compacto indicando el archivo o carpeta objetivo.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.topMargin: 3
                    Layout.bottomMargin: 4
                    spacing: 8

                    GlassIcon {
                        name: window.contextEntry
                              ? (window.contextEntry.isDir ? "folder" : window.fileIcon(window.contextEntry.name))
                              : "folder-open"
                        size: 13
                        color: GemaTheme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: window.contextEntry
                              ? window.contextEntry.name
                              : (window.pathSegments.length > 0 ? window.pathSegments[window.pathSegments.length - 1] : "/")
                        textFormat: Text.PlainText
                        color: GemaTheme.subtleColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                }

                ContextDivider {}

                // Acciones para elemento seleccionado (archivo o carpeta).
                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "folder-open"
                    text: "Abrir"
                    shortcutHint: "Enter"
                    onTriggered: window.openEntry(window.contextEntry)
                }
                ContextAction {
                    visible: window.contextEntry !== null && window.contextEntry.isDir
                    iconName: "terminal"
                    text: "Abrir terminal aquí"
                    actionEnabled: !window.bridge.busy
                    onTriggered: if (window.contextEntry) window.bridge.openTerminal(window.contextEntry.path)
                }
                ContextDivider { visible: window.contextEntry !== null }

                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "copy"
                    text: "Copiar"
                    shortcutHint: "Ctrl+C"
                    onTriggered: window.setClipboard(window.contextEntry, "copy")
                }
                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "scissors"
                    text: "Cortar"
                    shortcutHint: "Ctrl+X"
                    onTriggered: window.setClipboard(window.contextEntry, "cut")
                }
                ContextAction {
                    visible: window.contextEntry !== null && window.clipboardPath !== ""
                    iconName: "clipboard"
                    text: (window.contextEntry && window.contextEntry.isDir) ? "Pegar en esta carpeta" : "Pegar aquí"
                    shortcutHint: "Ctrl+V"
                    actionEnabled: !window.bridge.busy
                    onTriggered: window.pasteInto((window.contextEntry && window.contextEntry.isDir) ? window.contextEntry.path : window.bridge.path)
                }
                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "edit"
                    text: "Renombrar"
                    shortcutHint: "F2"
                    actionEnabled: !window.bridge.busy
                    onTriggered: window.openRenameDialog(window.contextEntry)
                }
                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "link"
                    text: "Copiar ruta"
                    onTriggered: window.copyPath(window.contextEntry ? window.contextEntry.path : "")
                }

                ContextDivider { visible: window.contextEntry !== null }

                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "info"
                    text: "Información"
                    shortcutHint: "Ctrl+I"
                    onTriggered: window.openInfoDialog(window.contextEntry)
                }

                ContextDivider { visible: window.contextEntry !== null }

                ContextAction {
                    visible: window.contextEntry !== null
                    iconName: "trash"
                    text: "Mover a papelera"
                    shortcutHint: "Supr"
                    destructive: true
                    actionEnabled: !window.bridge.busy
                    onTriggered: window.openTrashDialog(window.contextEntry)
                }

                // Acciones para espacio vacío de la carpeta actual.
                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "folder-plus"
                    text: "Nueva carpeta"
                    shortcutHint: "Ctrl+Shift+N"
                    actionEnabled: !window.bridge.busy && window.bridge.path !== ""
                    onTriggered: window.openMkdirDialog()
                }
                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "clipboard"
                    text: window.clipboardPath !== "" ? ("Pegar «" + window.clipboardName + "»") : "Pegar"
                    shortcutHint: "Ctrl+V"
                    actionEnabled: window.clipboardPath !== "" && !window.bridge.busy
                    onTriggered: window.pasteClipboard()
                }

                ContextDivider { visible: window.contextEntry === null }

                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "link"
                    text: "Copiar ruta de carpeta"
                    onTriggered: window.copyPath(window.bridge.path)
                }
                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "terminal"
                    text: "Abrir terminal aquí"
                    actionEnabled: !window.bridge.busy && window.bridge.path !== ""
                    onTriggered: window.bridge.openTerminal(window.bridge.path)
                }
                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "refresh"
                    text: "Actualizar"
                    shortcutHint: "F5"
                    actionEnabled: !window.bridge.busy && window.bridge.path !== ""
                    onTriggered: { window.bridge.list(window.bridge.path, window.bridge.showHidden, "refresh"); window.bridge.loadPlaces(); }
                }

                ContextDivider { visible: window.contextEntry === null }

                ContextAction {
                    visible: window.contextEntry === null
                    iconName: "info"
                    text: "Información de carpeta"
                    shortcutHint: "Ctrl+I"
                    actionEnabled: window.bridge.path !== ""
                    onTriggered: window.openInfoDialog(null)
                }
            }
        }
    }

    // === DIÁLOGOS MODALES ===
    GlassDialog {
        id: mkdirDialog
        title: "Nueva carpeta"
        dialogWidth: 420
        onOpened: { mkdirInput.text = ""; mkdirInput.forceActiveFocus(); }
        function submit() {
            if (!window.validName(mkdirInput.text)) return;
            window.bridge.mkdir(window.bridge.path, mkdirInput.text.trim());
            mkdirDialog.close();
        }
        contentItem: TextField {
            id: mkdirInput
            implicitHeight: 38
            leftPadding: 12
            rightPadding: 12
            placeholderText: "Nombre de la carpeta"
            placeholderTextColor: GemaTheme.placeholderColor
            selectByMouse: true
            color: GemaTheme.textColor
            selectionColor: GemaTheme.accentAlpha(0.45)
            selectedTextColor: "#ffffff"
            font.pixelSize: 13
            background: GlassPanel {
                radius: GemaTheme.controlRadius
                highlighted: mkdirInput.activeFocus
                topColor: "#1a0d1220"
                bottomColor: "#220a0e18"
                edgeColor: mkdirInput.activeFocus ? GemaTheme.accentAlpha(0.76) : "#36ffffff"
            }
            onAccepted: mkdirDialog.submit()
        }
        footer: Item {
            implicitHeight: 62
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; ghost: true; onClicked: mkdirDialog.close() }
                ActionButton { iconName: "folder-plus"; text: "Crear"; accent: true; enabled: window.validName(mkdirInput.text); onClicked: mkdirDialog.submit() }
            }
        }
    }

    GlassDialog {
        id: renameDialog
        property var targetEntry: null
        title: "Renombrar"
        dialogWidth: 420
        onOpened: { renameInput.text = renameDialog.targetEntry ? renameDialog.targetEntry.name : ""; renameInput.forceActiveFocus(); renameInput.selectAll(); }
        function submit() {
            if (!renameDialog.targetEntry || !window.validName(renameInput.text)) return;
            window.bridge.renameEntry(renameDialog.targetEntry.path, renameInput.text.trim());
            renameDialog.close();
        }
        contentItem: TextField {
            id: renameInput
            implicitHeight: 38
            leftPadding: 12
            rightPadding: 12
            placeholderText: "Nuevo nombre"
            placeholderTextColor: GemaTheme.placeholderColor
            selectByMouse: true
            color: GemaTheme.textColor
            selectionColor: GemaTheme.accentAlpha(0.45)
            selectedTextColor: "#ffffff"
            font.pixelSize: 13
            background: GlassPanel {
                radius: GemaTheme.controlRadius
                highlighted: renameInput.activeFocus
                topColor: "#1a0d1220"
                bottomColor: "#220a0e18"
                edgeColor: renameInput.activeFocus ? GemaTheme.accentAlpha(0.76) : "#36ffffff"
            }
            onAccepted: renameDialog.submit()
        }
        footer: Item {
            implicitHeight: 62
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; ghost: true; onClicked: renameDialog.close() }
                ActionButton { iconName: "check"; text: "Renombrar"; accent: true; enabled: window.validName(renameInput.text); onClicked: renameDialog.submit() }
            }
        }
    }

    GlassDialog {
        id: trashDialog
        property var targetEntry: null
        title: "Mover a la papelera"
        dialogWidth: 420
        contentItem: Text {
            text: "¿Mover «" + (trashDialog.targetEntry ? trashDialog.targetEntry.name : "") + "» a la papelera?"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: GemaTheme.mutedColor
            font.pixelSize: 13
        }
        footer: Item {
            implicitHeight: 62
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                ActionButton { text: "Cancelar"; ghost: true; onClicked: trashDialog.close() }
                ActionButton {
                    iconName: "trash"
                    text: "Mover a papelera"
                    destructive: true
                    onClicked: {
                        if (trashDialog.targetEntry) window.bridge.trashEntry(trashDialog.targetEntry.path);
                        trashDialog.close();
                    }
                }
            }
        }
    }

    GlassDialog {
        id: infoDialog
        property var targetEntry: null
        property string targetPath: ""
        property var infoData: null

        readonly property string resolvedName: infoDialog.infoData
            ? infoDialog.infoData.name
            : (infoDialog.targetEntry
               ? infoDialog.targetEntry.name
               : (infoDialog.targetPath === "/" ? "/" : infoDialog.targetPath.slice(infoDialog.targetPath.lastIndexOf("/") + 1)))
        readonly property bool resolvedIsDir: infoDialog.infoData
            ? Boolean(infoDialog.infoData.isDir)
            : (infoDialog.targetEntry ? Boolean(infoDialog.targetEntry.isDir) : true)
        readonly property bool isImage: !infoDialog.resolvedIsDir && window.isImageFile(infoDialog.resolvedName)
        readonly property bool isVideo: !infoDialog.resolvedIsDir && window.isVideoFile(infoDialog.resolvedName)
        readonly property var videoMeta: infoDialog.isVideo ? (window.bridge.videoThumbs[infoDialog.targetPath] || null) : null
        readonly property string previewPath: infoDialog.isImage
            ? infoDialog.targetPath
            : (infoDialog.videoMeta ? infoDialog.videoMeta.thumbPath : "")
        readonly property color accentTone: infoDialog.resolvedIsDir ? GemaTheme.accent : window.fileColor(infoDialog.resolvedName)
        readonly property string durationStr: (infoDialog.videoMeta && infoDialog.videoMeta.duration > 0)
            ? window.durationText(infoDialog.videoMeta.duration)
            : ""

        title: "Información"
        dialogWidth: 480

        // Sonda ligera para leer la resolución real en píxeles de imágenes.
        Image {
            id: imageDimProbe
            visible: false
            asynchronous: true
            cache: true
            source: (infoDialog.visible && infoDialog.isImage && infoDialog.targetPath.length > 0)
                    ? ("file://" + infoDialog.targetPath.split("/").map(seg => encodeURIComponent(seg)).join("/"))
                    : ""
        }

        contentItem: ColumnLayout {
            spacing: 12

            // Tarjeta superior con vista previa/icono + nombre + resumen.
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + 20
                radius: 12
                topColor: "#16ffffff"
                bottomColor: "#1a0a0e18"
                edgeColor: "#30ffffff"

                RowLayout {
                    id: heroRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        implicitWidth: 68
                        implicitHeight: 68
                        radius: 11
                        color: Qt.rgba(infoDialog.accentTone.r, infoDialog.accentTone.g, infoDialog.accentTone.b, infoDialog.resolvedIsDir ? 0.24 : 0.16)
                        border.width: infoDialog.previewPath.length > 0 && infoThumb.ready ? 0 : 1
                        border.color: Qt.rgba(infoDialog.accentTone.r, infoDialog.accentTone.g, infoDialog.accentTone.b, 0.48)
                        Layout.alignment: Qt.AlignVCenter

                        GlassThumbnail {
                            id: infoThumb
                            visible: infoDialog.previewPath.length > 0
                            anchors.fill: parent
                            filePath: infoDialog.previewPath
                            cornerRadius: 11
                            decodeSize: 320
                        }

                        Rectangle {
                            visible: infoDialog.isVideo && infoThumb.ready
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: "#bc0b0f18"
                            border.width: 1
                            border.color: "#5cffffff"
                            GlassIcon {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: 1
                                name: "play"
                                size: 12
                                color: "#ffffff"
                            }
                        }

                        GlassIcon {
                            visible: infoDialog.previewPath.length === 0 || !infoThumb.ready
                            anchors.centerIn: parent
                            name: infoDialog.resolvedIsDir ? "folder" : window.fileIcon(infoDialog.resolvedName)
                            size: 28
                            color: infoDialog.accentTone
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: infoDialog.resolvedName
                            textFormat: Text.PlainText
                            color: GemaTheme.textColor
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                let parts = [window.kindDescription(infoDialog.resolvedName, infoDialog.resolvedIsDir)];
                                if (infoDialog.resolvedIsDir && infoDialog.infoData) {
                                    const n = infoDialog.infoData.itemCount || 0;
                                    parts.push(n + (n === 1 ? " elemento" : " elementos"));
                                } else if (infoDialog.durationStr.length > 0) {
                                    parts.push(infoDialog.durationStr);
                                } else if (infoDialog.isImage && imageDimProbe.status === Image.Ready && imageDimProbe.implicitWidth > 0) {
                                    parts.push(imageDimProbe.implicitWidth + " × " + imageDimProbe.implicitHeight + " px");
                                }
                                return parts.join("  ·  ");
                            }
                            textFormat: Text.PlainText
                            color: GemaTheme.accent
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !infoDialog.resolvedIsDir || (infoDialog.infoData && infoDialog.infoData.readonly)
                            text: {
                                if (!infoDialog.resolvedIsDir) {
                                    const sz = infoDialog.infoData ? infoDialog.infoData.size : (infoDialog.targetEntry ? infoDialog.targetEntry.size : 0);
                                    return window.sizeText(sz);
                                }
                                return "Solo lectura";
                            }
                            textFormat: Text.PlainText
                            color: GemaTheme.subtleColor
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Tabla estructurada de metadatos.
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: metaCol.implicitHeight + 6
                radius: 12
                topColor: "#140b0f1a"
                bottomColor: "#1e080c15"
                edgeColor: "#2cffffff"

                ColumnLayout {
                    id: metaCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    spacing: 0

                    InfoRow {
                        label: "Tipo"
                        value: window.kindDescription(infoDialog.resolvedName, infoDialog.resolvedIsDir)
                               + (infoDialog.infoData && infoDialog.infoData.isSymlink ? " (Enlace simbólico)" : "")
                    }
                    InfoRow {
                        label: "Ubicación"
                        value: infoDialog.infoData
                               ? (infoDialog.infoData.parent || "/")
                               : (infoDialog.targetPath.slice(0, infoDialog.targetPath.lastIndexOf("/")) || "/")
                    }
                    InfoRow {
                        label: infoDialog.resolvedIsDir ? "Contenido" : "Tamaño"
                        value: {
                            if (infoDialog.resolvedIsDir) {
                                if (!infoDialog.infoData) return "Calculando…";
                                const d = infoDialog.infoData.dirCount || 0;
                                const f = infoDialog.infoData.fileCount || 0;
                                const total = infoDialog.infoData.itemCount || 0;
                                if (total === 0) return "Carpeta vacía";
                                return total + (total === 1 ? " elemento" : " elementos") + " (" + d + " carp., " + f + " arch.)";
                            }
                            const sz = infoDialog.infoData ? infoDialog.infoData.size : (infoDialog.targetEntry ? infoDialog.targetEntry.size : 0);
                            return window.sizeText(sz) + " (" + window.exactBytesText(sz) + ")";
                        }
                    }
                    InfoRow {
                        visible: infoDialog.isImage && imageDimProbe.status === Image.Ready && imageDimProbe.implicitWidth > 0
                        label: "Resolución"
                        value: imageDimProbe.implicitWidth + " × " + imageDimProbe.implicitHeight + " px"
                    }
                    InfoRow {
                        visible: infoDialog.durationStr.length > 0
                        label: "Duración"
                        value: infoDialog.durationStr
                    }
                    InfoRow {
                        label: "Modificado"
                        value: window.dateText(infoDialog.infoData ? infoDialog.infoData.mtime : (infoDialog.targetEntry ? infoDialog.targetEntry.mtime : 0))
                    }
                    InfoRow {
                        visible: infoDialog.infoData !== null && infoDialog.infoData.ctime > 0
                        label: "Creado"
                        value: window.dateText(infoDialog.infoData ? infoDialog.infoData.ctime : 0)
                    }
                    InfoRow {
                        label: "Permisos"
                        value: infoDialog.infoData ? infoDialog.infoData.permissions : "—"
                        showDivider: infoDialog.infoData !== null && Boolean(infoDialog.infoData.isSymlink)
                    }
                    InfoRow {
                        visible: infoDialog.infoData !== null && Boolean(infoDialog.infoData.isSymlink)
                        label: "Enlace hacia"
                        value: infoDialog.infoData ? infoDialog.infoData.linkTarget : ""
                        showDivider: false
                    }
                }
            }
        }

        footer: Item {
            implicitHeight: 62
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton {
                    iconName: "link"
                    text: "Copiar ruta"
                    ghost: true
                    onClicked: window.copyPath(infoDialog.targetPath)
                }
                ActionButton {
                    visible: infoDialog.targetEntry !== null
                    iconName: "edit"
                    text: "Renombrar"
                    ghost: true
                    enabled: !window.bridge.busy
                    onClicked: {
                        const target = infoDialog.targetEntry;
                        infoDialog.close();
                        window.openRenameDialog(target);
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton {
                    text: "Cerrar"
                    accent: true
                    onClicked: infoDialog.close()
                }
            }
        }
    }
}
