pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Selector desplegable Matte Transparent Glassmorphism con chevron vectorial alineado.
ComboBox {
    id: control
    property bool opensAbove: false
    implicitHeight: 34
    hoverEnabled: true
    font.pixelSize: 12
    font.weight: Font.Medium
    leftPadding: 11
    rightPadding: 28
    topPadding: 5
    bottomPadding: 5

    contentItem: Text {
        text: control.displayText
        textFormat: Text.PlainText
        font: control.font
        color: GemaTheme.textColor
        opacity: control.enabled ? 1 : 0.45
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        style: GemaTheme.darkText ? Text.Normal : Text.Raised
        styleColor: "#48000000"
    }

    indicator: GlassIcon {
        x: control.width - width - 9
        y: Math.round((control.height - height) / 2)
        name: control.opensAbove ? "chevron-up" : "chevron-down"
        size: 14
        color: GemaTheme.mutedColor
        opacity: control.enabled ? 0.9 : 0.45
    }

    delegate: ItemDelegate {
        id: option
        required property var modelData
        required property int index
        width: control.width - 12
        height: 32
        highlighted: control.highlightedIndex === option.index
        hoverEnabled: true

        contentItem: RowLayout {
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: typeof option.modelData === "object" ? String(option.modelData[control.textRole]) : String(option.modelData)
                textFormat: Text.PlainText
                font.pixelSize: 12
                font.weight: control.currentIndex === option.index ? Font.DemiBold : Font.Normal
                color: control.currentIndex === option.index ? (GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff") : GemaTheme.textColor
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            GlassIcon {
                visible: control.currentIndex === option.index
                name: "check"
                size: 13
                color: GemaTheme.accent
                Layout.alignment: Qt.AlignVCenter
            }
        }
        background: Rectangle {
            radius: 8
            color: option.highlighted || control.currentIndex === option.index
                   ? GemaTheme.accentAlpha(option.hovered ? 0.34 : 0.24)
                   : (option.hovered ? "#1affffff" : "transparent")
        }
    }

    popup: Popup {
        y: control.opensAbove ? -height - 6 : control.height + 6
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            spacing: 2
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
        background: MattePanel { overlay: true; radius: 12 }
    }

    background: GlassPanel {
        implicitWidth: 110
        implicitHeight: 34
        radius: GemaTheme.controlRadius
        highlighted: control.activeFocus || control.popup.visible
        topColor: control.hovered || control.popup.visible ? "#24ffffff" : "#15ffffff"
        bottomColor: "#0cffffff"
        edgeColor: control.hovered || control.popup.visible ? GemaTheme.accentAlpha(0.56) : "#32ffffff"
        opacity: control.enabled ? 1 : 0.55
    }
}
