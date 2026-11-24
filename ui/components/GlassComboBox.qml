pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Selector desplegable Matte Transparent Glassmorphism de Gema UI Kit.
ComboBox {
    id: control
    property bool opensAbove: false
    implicitHeight: 34
    hoverEnabled: true
    font.pixelSize: 13
    leftPadding: 12
    rightPadding: 32
    topPadding: 6
    bottomPadding: 6

    contentItem: Text {
        text: control.displayText
        textFormat: Text.PlainText
        font: control.font
        color: GemaTheme.darkText ? "#263d50" : "#f5f5f5"
        opacity: control.enabled ? 1 : 0.55
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - width - 12
        y: (control.height - height) / 2
        text: control.opensAbove ? "⌃" : "⌄"
        font.pixelSize: 18
        color: GemaTheme.darkText ? "#263d50" : "#ffffff"
        opacity: control.enabled ? 1 : 0.55
    }
    delegate: ItemDelegate {
        id: option
        required property var modelData
        required property int index
        width: control.width - 12
        height: 32
        highlighted: control.highlightedIndex === option.index
        contentItem: Text {
            text: typeof option.modelData === "object" ? String(option.modelData[control.textRole]) : String(option.modelData)
            textFormat: Text.PlainText
            font: control.font
            color: GemaTheme.darkText ? "#263d50" : "#ffffff"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: option.highlighted ? GemaTheme.accentAlpha(0.30) : (option.hovered ? "#18ffffff" : "transparent")
        }
    }
    popup: Popup {
        y: control.opensAbove ? -height - 4 : control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
        background: MattePanel { overlay: true; radius: 12 }
    }
    background: GlassPanel {
        implicitWidth: 112
        implicitHeight: 34
        radius: 10
        highlighted: control.activeFocus || control.popup.visible
        topColor: control.hovered ? "#22ffffff" : "#14ffffff"
        bottomColor: "#0cffffff"
        opacity: control.enabled ? 1 : 0.55
    }
}
