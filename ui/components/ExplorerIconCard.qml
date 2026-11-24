pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tarjeta de carpeta, archivo o miniatura de imagen en cuadrícula con zoom fluido.
ItemDelegate {
    id: tile
    required property string path
    required property string name
    required property bool directory
    required property color itemAccent
    required property string langLabel
    property bool imagePreview: false
    property bool videoPreview: false
    property string previewSourcePath: ""
    property string durationLabel: ""
    property string detailText: ""
    property bool selected: false
    hoverEnabled: true
    padding: tile.width < 112 ? 6 : 8
    Accessible.name: name

    readonly property bool hasVisualPreview: tile.imagePreview || (tile.videoPreview && tile.previewSourcePath.length > 0)
    readonly property int labelFontSize: tile.width < 112 ? 11 : (tile.width > 210 ? 13 : 12)
    readonly property int labelBoxHeight: tile.width < 112 ? 30 : (tile.width > 210 ? 38 : 34)

    scale: tile.down ? 0.975 : (tile.hovered ? 1.015 : 1.0)
    Behavior on scale { NumberAnimation { duration: GemaTheme.animations ? 130 : 0; easing.type: Easing.OutCubic } }

    function folderBadgeIcon(folderName) {
        const lower = folderName.toLowerCase();
        if (lower === "documents" || lower === "documentos") return "documents";
        if (lower === "downloads" || lower === "descargas") return "downloads";
        if (lower === "pictures" || lower === "imágenes" || lower === "imagenes" || lower === "photos") return "pictures";
        if (lower === "music" || lower === "música" || lower === "musica") return "music";
        if (lower === "videos" || lower === "vídeos") return "videos";
        if (lower === "desktop" || lower === "escritorio") return "desktop";
        if (lower === "dev" || lower === "proyectos" || lower === "projects" || lower === "code" || lower === "src") return "code";
        if (lower === "applications" || lower === "apps" || lower === "snap") return "box";
        return "";
    }

    readonly property string badgeIcon: tile.directory ? folderBadgeIcon(tile.name) : ""

    background: GlassPanel {
        radius: tile.width < 112 ? 11 : 14
        reflective: true
        topColor: tile.selected
                  ? GemaTheme.accentAlpha(0.28)
                  : tile.hovered
                    ? GemaTheme.accentAlpha(0.16)
                    : "#11ffffff"
        bottomColor: tile.selected
                     ? GemaTheme.accentAlpha(0.14)
                     : tile.hovered
                       ? "#180b0f1a"
                       : "#16070a12"
        edgeColor: tile.selected
                   ? GemaTheme.accentAlpha(0.78)
                   : tile.hovered
                     ? GemaTheme.accentAlpha(0.45)
                     : "#22ffffff"
        highlighted: tile.selected
    }

    GlassToolTip {
        visible: tile.hovered
        delay: 550
        text: tile.detailText.length > 0 ? (tile.name + "\n" + tile.detailText) : tile.path
    }

    contentItem: Item {
        // Indicador de selección en esquina superior derecha.
        Rectangle {
            z: 3
            visible: tile.selected
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            width: 18
            height: 18
            radius: 9
            color: GemaTheme.accentAlpha(0.95)
            border.width: 1
            border.color: "#8810141e"
            GlassIcon {
                anchors.centerIn: parent
                name: "check"
                size: 10
                strokeWidth: 2.6
                color: "#111420"
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: tile.width < 112 ? 5 : 7

            // Área visual superior: miniatura real para imágenes/vídeos o arte de cristal escalable.
            Item {
                id: previewHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: tile.hasVisualPreview ? 0 : 4

                readonly property real artworkScale: Math.max(
                    0.74,
                    Math.min(1.95, Math.min((previewHost.width - 8) / 64.0, (previewHost.height - 4) / 54.0))
                )
                readonly property int playBadgeSize: Math.max(24, Math.min(44, Math.round(Math.min(previewHost.width, previewHost.height) * 0.36)))

                // === MINIATURA DE IMAGEN O VÍDEO ===
                GlassThumbnail {
                    id: thumbPreview
                    visible: tile.hasVisualPreview
                    anchors.fill: parent
                    filePath: tile.hasVisualPreview ? (tile.previewSourcePath.length > 0 ? tile.previewSourcePath : tile.path) : ""
                    cornerRadius: tile.width < 112 ? 7 : 10
                    decodeSize: 320
                }

                // Insignia central de reproducción translúcida para vídeos.
                Rectangle {
                    visible: tile.videoPreview && thumbPreview.ready
                    anchors.centerIn: parent
                    width: previewHost.playBadgeSize
                    height: previewHost.playBadgeSize
                    radius: width / 2
                    color: tile.hovered || tile.selected ? "#c80d111b" : "#9c0b0f18"
                    border.width: 1
                    border.color: tile.hovered || tile.selected ? GemaTheme.accentAlpha(0.82) : "#62ffffff"
                    scale: tile.hovered ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: GemaTheme.animations ? 140 : 0; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }

                    GlassIcon {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        name: "play"
                        size: Math.max(11, Math.round(previewHost.playBadgeSize * 0.44))
                        strokeWidth: 1.6
                        color: "#ffffff"
                    }
                }

                // Etiqueta de formato en esquina superior izquierda en tarjetas grandes de vídeo.
                Rectangle {
                    visible: tile.videoPreview && thumbPreview.ready && tile.durationLabel.length > 0 && (tile.hovered || tile.width >= 160)
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 5
                    anchors.topMargin: 5
                    implicitWidth: videoFmtLabel.implicitWidth + 8
                    implicitHeight: 15
                    radius: 4.5
                    color: "#b40c101a"
                    border.width: 1
                    border.color: "#38ffffff"

                    Text {
                        id: videoFmtLabel
                        anchors.centerIn: parent
                        text: tile.langLabel
                        color: "#e6ecf5"
                        font.family: "monospace"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }

                // Etiqueta inferior derecha: duración en vídeos o formato en imágenes.
                Rectangle {
                    visible: tile.hasVisualPreview && thumbPreview.ready && (tile.width >= 102 || tile.durationLabel.length > 0)
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 5
                    anchors.bottomMargin: 5
                    implicitWidth: thumbExtLabel.implicitWidth + 10
                    implicitHeight: tile.durationLabel.length > 0 ? 17 : 15
                    radius: 4.5
                    color: tile.durationLabel.length > 0 ? "#d40b0e18" : "#c20c101a"
                    border.width: 1
                    border.color: tile.durationLabel.length > 0
                                  ? "#44ffffff"
                                  : Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.58)
                    opacity: tile.hovered || tile.selected || tile.durationLabel.length > 0 ? 0.96 : 0.80
                    Behavior on opacity { NumberAnimation { duration: GemaTheme.animDuration } }

                    Text {
                        id: thumbExtLabel
                        anchors.centerIn: parent
                        text: tile.durationLabel.length > 0 ? tile.durationLabel : tile.langLabel
                        color: tile.durationLabel.length > 0 ? "#f4f6fa" : tile.itemAccent
                        font.family: "monospace"
                        font.pixelSize: tile.durationLabel.length > 0 ? 9 : 8
                        font.weight: Font.Bold
                    }
                }

                // === ARTE DE CRISTAL (carpetas, documentos y fallback mientras carga miniatura) ===
                Item {
                    anchors.centerIn: parent
                    width: 64
                    height: 54
                    visible: !tile.hasVisualPreview || !thumbPreview.ready
                    scale: previewHost.artworkScale
                    transformOrigin: Item.Center

                    // Halo ambiental suave detrás del icono.
                    Rectangle {
                        anchors.centerIn: parent
                        width: tile.directory ? 60 : 50
                        height: tile.directory ? 44 : 50
                        radius: 18
                        color: tile.itemAccent
                        opacity: tile.selected ? 0.28 : (tile.hovered ? 0.18 : 0.07)
                        Behavior on opacity { NumberAnimation { duration: GemaTheme.animDuration } }
                    }

                    // === CARPETA DE CRISTAL ===
                    Item {
                        anchors.centerIn: parent
                        width: 60
                        height: 48
                        visible: tile.directory

                        Rectangle {
                            x: 3
                            y: 3
                            width: 24
                            height: 11
                            radius: 4.5
                            color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.64)
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.88)
                        }

                        Rectangle {
                            x: 3
                            y: 9
                            width: 54
                            height: 36
                            radius: 8
                            color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.34)
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.72)
                        }

                        Rectangle {
                            x: 11
                            y: tile.hovered ? 6 : 10
                            width: 38
                            height: 14
                            radius: 3.5
                            color: "#36ffffff"
                            border.width: 1
                            border.color: "#52ffffff"
                            Behavior on y { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            x: 8
                            y: tile.hovered ? 9 : 12
                            width: 44
                            height: 16
                            radius: 3.5
                            color: "#54f4f8ff"
                            border.width: 1
                            border.color: "#7cffffff"
                            Behavior on y { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            x: 2
                            y: 16
                            width: 56
                            height: 29
                            radius: 8
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.92)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.58) }
                                GradientStop { position: 1.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.28) }
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.topMargin: 1
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                height: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#00ffffff" }
                                    GradientStop { position: 0.35; color: "#a4ffffff" }
                                    GradientStop { position: 1.0; color: "#00ffffff" }
                                }
                            }

                            GlassIcon {
                                visible: tile.badgeIcon.length > 0
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                name: tile.badgeIcon
                                size: 14
                                strokeWidth: 1.9
                                color: "#c8ffffff"
                            }
                            Rectangle {
                                visible: tile.badgeIcon.length === 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 10
                                width: 18
                                height: 2
                                radius: 1
                                color: "#52ffffff"
                            }
                        }
                    }

                    // === ARCHIVO DE CRISTAL ===
                    Item {
                        anchors.centerIn: parent
                        width: 46
                        height: 52
                        visible: !tile.directory

                        Rectangle {
                            x: 2
                            y: 1
                            width: 42
                            height: 50
                            radius: 8
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b,
                                                  tile.selected || tile.hovered ? 0.90 : 0.65)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.28) }
                                GradientStop { position: 1.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.10) }
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.topMargin: 1
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                width: 22
                                height: 1
                                color: "#72ffffff"
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 11
                                height: 11
                                radius: 3
                                color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.44)
                                border.width: 1
                                border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.74)
                            }

                            Column {
                                x: 7
                                y: 11
                                spacing: 4
                                Rectangle { width: 16; height: 2; radius: 1; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.82) }
                                Rectangle { width: 26; height: 2; radius: 1; color: "#58ffffff" }
                                Rectangle { width: 20; height: 2; radius: 1; color: "#40ffffff" }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                implicitWidth: Math.min(36, fileTypeLabel.implicitWidth + 8)
                                implicitHeight: 15
                                radius: 4.5
                                color: "#ba0d121d"
                                border.width: 1
                                border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.74)
                                Text {
                                    id: fileTypeLabel
                                    anchors.centerIn: parent
                                    text: tile.langLabel
                                    color: tile.itemAccent
                                    font.family: "monospace"
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
            }

            // Nombre centrado en hasta 2 líneas con altura estable.
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: tile.labelBoxHeight
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                text: tile.name
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                color: tile.selected ? (GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff") : GemaTheme.textColor
                opacity: tile.selected || tile.hovered ? 1.0 : 0.92
                font.pixelSize: tile.labelFontSize
                font.weight: tile.selected ? Font.DemiBold : Font.Medium
                style: GemaTheme.darkText ? Text.Normal : Text.Raised
                styleColor: "#58000000"
                Behavior on opacity { NumberAnimation { duration: GemaTheme.animDuration } }
            }
        }
    }
}
