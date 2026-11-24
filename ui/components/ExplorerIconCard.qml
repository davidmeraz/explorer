pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tarjeta de carpeta o archivo en cuadrícula estilo cristal facetado Gema.
ItemDelegate {
    id: tile
    required property string path
    required property string name
    required property bool directory
    required property color itemAccent
    required property string langLabel
    property string detailText: ""
    property bool selected: false
    hoverEnabled: true
    padding: 8
    Accessible.name: name

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
        radius: 14
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
        // Indicador sutil en esquina superior derecha cuando está seleccionado.
        Rectangle {
            visible: tile.selected
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.rightMargin: 2
            width: 16
            height: 16
            radius: 8
            color: GemaTheme.accentAlpha(0.92)
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
            anchors.topMargin: 10
            anchors.bottomMargin: 4
            spacing: 8

            // Icono vectorial grande: carpeta esmerilada con hojas o documento de cristal.
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 54

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

                    // Pestaña superior de la carpeta.
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

                    // Fondo posterior de la carpeta.
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

                    // Hoja interior trasera (asoma al pasar el cursor).
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

                    // Hoja interior frontal.
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

                    // Solapa frontal esmerilada con reflejo especular y emblema grabado.
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

                        // Destello especular en el canto superior.
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

                        // Emblema grabado sutil para carpetas conocidas, o muesca minimalista.
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

            // Nombre centrado en hasta 2 líneas con elipsis limpia.
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                text: tile.name
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: tile.selected ? (GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff") : GemaTheme.textColor
                opacity: tile.selected || tile.hovered ? 1.0 : 0.92
                font.pixelSize: 12
                font.weight: tile.selected ? Font.DemiBold : Font.Medium
                style: GemaTheme.darkText ? Text.Normal : Text.Raised
                styleColor: "#58000000"
                Behavior on opacity { NumberAnimation { duration: GemaTheme.animDuration } }
            }
        }
    }
}
