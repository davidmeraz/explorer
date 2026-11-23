import QtQuick
import QtQuick.Controls

// Botón Matte Transparent Glassmorphism de Gema UI Kit con cápsula 3D de luz y sombra.
Button {
    id: control
    property bool accent: false
    horizontalPadding: 14
    verticalPadding: 10
    hoverEnabled: true
    font.pixelSize: 13
    contentItem: Text {
        text: control.text
        font: control.font
        color: GemaTheme.darkText ? "#263d50" : "#ffffff"
        opacity: control.enabled ? 1 : 0.55
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: GlassPanel {
        radius: Math.max(8, GemaTheme.rounding * 0.6)
        topColor: control.down ? "#36ffffff"
                  : control.accent && control.enabled ? (GemaTheme.synced ? GemaTheme.accentAlpha(control.hovered ? 0.42 : 0.30) : "#30ffffff")
                  : control.hovered && control.enabled ? "#30ffffff" : "#18ffffff"
        bottomColor: control.accent && control.enabled
                     ? (GemaTheme.synced ? GemaTheme.accentAlpha(0.18) : "#1cffffff")
                     : "#10ffffff"
        edgeColor: control.accent && control.enabled ? (GemaTheme.synced ? GemaTheme.accentAlpha(0.85) : "#80ffffff")
                   : control.hovered && control.enabled ? (GemaTheme.synced ? GemaTheme.accentAlpha(0.68) : "#68ffffff") : "#48ffffff"
        highlighted: control.activeFocus || (control.hovered && control.accent)
        opacity: control.enabled ? 1 : 0.55
    }
}
