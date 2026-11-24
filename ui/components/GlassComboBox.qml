import QtQuick
import QtQuick.Controls

// Selector desplegable Matte Transparent Glassmorphism de Gema UI Kit.
ComboBox {
    id: control
    property bool opensAbove: false
    implicitHeight: 40
    hoverEnabled: true
    font.pixelSize: 13
    leftPadding: 14
    rightPadding: 36
    topPadding: 10
    bottomPadding: 10

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: GemaTheme.darkText ? "#263d50" : "#f5f5f5"
        opacity: control.enabled ? 1 : 0.55
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - width - 14
        y: (control.height - height) / 2
        text: control.opensAbove ? "⌃" : "⌄"
        font.pixelSize: 18
        color: GemaTheme.darkText ? "#263d50" : "#ffffff"
        opacity: control.enabled ? 1 : 0.55
    }
    background: GlassPanel {
        implicitWidth: 180
        implicitHeight: 40
        radius: 10
        highlighted: control.activeFocus || control.popup.visible
        topColor: control.hovered ? "#22ffffff" : "#14ffffff"
        bottomColor: "#0cffffff"
        opacity: control.enabled ? 1 : 0.55
    }
}
