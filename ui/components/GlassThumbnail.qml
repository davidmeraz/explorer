pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Miniatura de imagen asíncrona con esquinas redondeadas en GPU y mipmaps para zoom fluido.
Item {
    id: root
    property string filePath: ""
    property real cornerRadius: 9
    property int decodeSize: 320
    property int fillMode: Image.PreserveAspectCrop

    readonly property bool ready: img.status === Image.Ready
    readonly property bool loading: img.status === Image.Loading
    readonly property bool failed: img.status === Image.Error
    readonly property bool gpuEffects: GraphicsInfo.api !== GraphicsInfo.Software
                                       && GraphicsInfo.api !== GraphicsInfo.Unknown

    function toFileUrl(p) {
        if (!p) return "";
        return "file://" + p.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }

    // Fondo sutil para imágenes con transparencia (PNG/SVG).
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        visible: root.ready
        color: GemaTheme.darkText ? "#22ffffff" : "#340a0d16"
    }

    Item {
        id: maskShape
        anchors.fill: parent
        layer.enabled: root.gpuEffects
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.filePath ? root.toFileUrl(root.filePath) : ""
        asynchronous: true
        cache: true
        autoTransform: true
        smooth: true
        mipmap: true
        fillMode: root.fillMode
        sourceSize: Qt.size(root.decodeSize, root.decodeSize)
        opacity: root.ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }
        layer.enabled: root.ready && root.gpuEffects
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // Marco interior de cristal y destello superior sobre la miniatura.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        visible: root.ready
        color: "transparent"
        border.width: 1
        border.color: "#38ffffff"

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.cornerRadius
            anchors.rightMargin: root.cornerRadius
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 0.35; color: "#72ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }
    }
}
