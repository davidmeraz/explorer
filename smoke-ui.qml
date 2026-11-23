import QtQuick
import QtTest
import Quickshell
import "ui"

ShellRoot {
    id: root
    property int phase: 0
    AppBridge { id: bridge }
    AppWindow { id: window; bridge: bridge }
    TestCase { id: input; when: false }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (bridge.error) { console.error("SMOKE_ERROR: " + bridge.error); Qt.quit(); return; }
            if (!bridge.ready || bridge.loading || !bridge.path) return;
            if (root.phase === 0) {
                if (bridge.entries.length !== 2 || !bridge.entries[0].isDir || !bridge.entries[1].isFile) {
                    console.error("SMOKE_ERROR: entradas inesperadas"); Qt.quit(); return;
                }
                const folder = window.gridView.itemAtIndex(0);
                const file = window.gridView.itemAtIndex(1);
                if (!folder || !file) return;
                if (!folder.directory || file.directory || folder.name !== "carpeta" || file.name !== "archivo.txt") {
                    console.error("SMOKE_ERROR: delegates incorrectos"); Qt.quit(); return;
                }
                window.gridView.currentIndex = 0;
                window.switchView(false);
                if (window.listView.currentIndex !== 0 || !window.listView.activeFocus) {
                    console.error("SMOKE_ERROR: selección o foco de lista"); Qt.quit(); return;
                }
                const row = window.listView.itemAtIndex(1);
                if (!row) return;
                input.mouseClick(row, 10, 10);
                if (window.listView.currentIndex !== 1) {
                    console.error("SMOKE_ERROR: clic en lista"); Qt.quit(); return;
                }
                window.listView.currentIndex = 0;
                window.switchView(true);
                if (window.gridView.currentIndex !== 0 || !window.gridView.activeFocus) {
                    console.error("SMOKE_ERROR: selección o foco de cuadrícula"); Qt.quit(); return;
                }
                root.phase = 1;
                input.keyClick(Qt.Key_Return);
            } else if (root.phase === 1) {
                if (!bridge.path.endsWith("/carpeta") || bridge.entries.length !== 0) {
                    console.error("SMOKE_ERROR: navegación"); Qt.quit(); return;
                }
                console.log("EXPLORER_SMOKE_OK");
                Qt.quit();
            }
        }
    }
}
