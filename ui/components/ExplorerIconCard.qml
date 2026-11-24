import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Arte adaptado de Agent Shell, ExplorerIconCard.qml.
ItemDelegate {
    id: tile
    required property string path
    required property string name
    required property bool directory
    required property color itemAccent
    required property string langLabel
    property bool selected: false
    hoverEnabled: true
    padding: 8
    Accessible.name: name
    ToolTip.visible: hovered
    ToolTip.delay: 550
    ToolTip.text: path
    background: GlassPanel {
        radius: 13
        topColor: tile.selected ? GemaTheme.accentAlpha(0.22) : tile.hovered ? GemaTheme.accentAlpha(0.14) : "#0effffff"
        bottomColor: "#14060a10"
        edgeColor: tile.selected ? GemaTheme.accentAlpha(0.62) : "#22ffffff"
    }
    contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 14
            spacing: 6

            // Icono vectorial grande: carpeta con hojas interiores o documento con esquina doblada y lenguaje.
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 62
                Layout.preferredHeight: 52

                // Halo ambiental suave detrás del icono.
                Rectangle {
                    anchors.centerIn: parent
                    width: tile.directory ? 58 : 48
                    height: tile.directory ? 42 : 48
                    radius: 16
                    color: tile.itemAccent
                    opacity: tile.selected ? 0.24 : (tile.hovered ? 0.16 : 0.06)
                    Behavior on opacity { NumberAnimation { duration: (GemaTheme.animations ? 150 : 0) } }
                }

                // === CARPETA GRANDE DE CRISTAL ===
                Item {
                    anchors.centerIn: parent
                    width: 58
                    height: 46
                    visible: tile.directory

                    // Pestaña superior de la carpeta.
                    Rectangle {
                        x: 3
                        y: 3
                        width: 23
                        height: 11
                        radius: 4
                        color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.62)
                        border.width: 1
                        border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.85)
                    }

                    // Fondo posterior de la carpeta.
                    Rectangle {
                        x: 3
                        y: 9
                        width: 52
                        height: 34
                        radius: 7
                        color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.34)
                        border.width: 1
                        border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.72)
                    }

                    // Hoja interior trasera (asoma suavemente al pasar el cursor).
                    Rectangle {
                        x: 11
                        y: tile.hovered ? 7 : 10
                        width: 36
                        height: 14
                        radius: 3
                        color: "#38ffffff"
                        border.width: 1
                        border.color: "#55ffffff"
                        Behavior on y { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }
                    }

                    // Hoja interior frontal con micro-líneas de contenido.
                    Rectangle {
                        x: 8
                        y: tile.hovered ? 10 : 12
                        width: 42
                        height: 16
                        radius: 3
                        color: "#52f4f8ff"
                        border.width: 1
                        border.color: "#78ffffff"
                        Behavior on y { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }
                    }

                    // Solapa frontal esmerilada de la carpeta con brillo especular.
                    Rectangle {
                        x: 2
                        y: 16
                        width: 54
                        height: 28
                        radius: 7
                        border.width: 1
                        border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.90)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.56) }
                            GradientStop { position: 1.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.26) }
                        }
                        // Destello especular en el borde superior.
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            height: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#00ffffff" }
                                GradientStop { position: 0.35; color: "#98ffffff" }
                                GradientStop { position: 1.0; color: "#00ffffff" }
                            }
                        }
                        // Muesca sutil central en la solapa.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 9
                            width: 18
                            height: 2
                            radius: 1
                            color: "#48ffffff"
                        }
                    }
                }

                // === ARCHIVO GRANDE DE CRISTAL ===
                Item {
                    anchors.centerIn: parent
                    width: 46
                    height: 52
                    visible: !tile.directory

                    // Cuerpo del documento.
                    Rectangle {
                        x: 2
                        y: 1
                        width: 42
                        height: 50
                        radius: 7
                        border.width: 1
                        border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b,
                                              tile.selected || tile.hovered ? 0.88 : 0.62)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.26) }
                            GradientStop { position: 1.0; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.10) }
                        }
                        // Reflejo superior del cristal.
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            width: 22
                            height: 1
                            color: "#66ffffff"
                        }
                        // Pliegue decorativo en la esquina superior derecha.
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: 11
                            height: 11
                            radius: 3
                            color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.42)
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.72)
                        }
                        // Líneas estilizadas de código dentro del documento.
                        Column {
                            x: 7
                            y: 11
                            spacing: 4
                            Rectangle { width: 16; height: 2; radius: 1; color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.78) }
                            Rectangle { width: 26; height: 2; radius: 1; color: "#52ffffff" }
                            Rectangle { width: 20; height: 2; radius: 1; color: "#3cffffff" }
                        }
                        // Etiqueta del lenguaje integrada en la parte inferior del icono.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            implicitWidth: Math.min(36, fileTypeLabel.implicitWidth + 8)
                            implicitHeight: 15
                            radius: 4
                            color: "#aa0e1520"
                            border.width: 1
                            border.color: Qt.rgba(tile.itemAccent.r, tile.itemAccent.g, tile.itemAccent.b, 0.72)
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

            // Nombre del archivo o carpeta centrado en hasta 2 líneas.
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: tile.name
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                color: GemaTheme.darkText ? "#263d50" : "#ffffff"
                opacity: tile.selected || tile.hovered ? 1.0 : 0.90
                font.pixelSize: 11
                font.weight: tile.selected ? Font.DemiBold : (tile.directory ? Font.Medium : Font.Normal)
                style: GemaTheme.darkText ? Text.Normal : Text.Raised
                styleColor: "#60000000"
                Behavior on opacity { NumberAnimation { duration: GemaTheme.animations ? 150 : 0 } }
            }
        }
    }
}
