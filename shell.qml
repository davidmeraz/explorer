import Quickshell
import "ui"

// Punto de entrada Gema UI Kit: conecta AppBridge con AppWindow.
ShellRoot {
    AppBridge { id: bridge }

    AppWindow {
        bridge: bridge
        onClosed: Qt.quit()
    }
}
