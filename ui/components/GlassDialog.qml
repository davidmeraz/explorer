import QtQuick
import QtQuick.Controls

// Diálogo modal Matte Transparent Glassmorphism de Gema UI Kit.
Dialog {
    id: control
    padding: 20
    background: MattePanel {
        overlay: true
        radius: 16
    }
    header: Label {
        text: control.title
        color: GemaTheme.darkText ? "#263d50" : "#f5f5f5"
        opacity: control.enabled ? 1 : 0.55
        font.pixelSize: 20
        font.bold: true
        padding: 20
        bottomPadding: 4
        elide: Text.ElideRight
    }
    footer: DialogButtonBox {
        standardButtons: control.standardButtons
        padding: 16
        spacing: 8
        background: null
        delegate: ActionButton {}
    }
    Overlay.modal: Rectangle { color: "#28000000" }
}
