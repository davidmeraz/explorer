//@ pragma AppId dev.gema.explorer
import Quickshell
import "ui"

// Punto de entrada Gema UI Kit: conecta AppBridge con AppWindow.
ShellRoot {
    AppBridge { id: appBridge }

    AppWindow {
        bridge: appBridge
        onClosed: Qt.quit()
    }
}
