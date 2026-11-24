pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Diálogo modal Matte Transparent Glassmorphism de Gema UI Kit.
Dialog {
    id: control
    modal: true
    leftPadding: 22
    rightPadding: 22
    topPadding: 14
    bottomPadding: 8

    background: MattePanel {
        overlay: true
        radius: 16
    }

    header: Label {
        text: control.title
        color: GemaTheme.textColor
        opacity: control.enabled ? 1 : 0.55
        font.pixelSize: 18
        font.weight: Font.DemiBold
        leftPadding: 22
        rightPadding: 22
        topPadding: 20
        bottomPadding: 2
        elide: Text.ElideRight
    }

    footer: DialogButtonBox {
        visible: control.standardButtons !== Dialog.NoButton
        standardButtons: control.standardButtons
        padding: 16
        spacing: 8
        background: null
        delegate: ActionButton {}
    }

    Overlay.modal: Rectangle { color: "#44080b12" }
}
