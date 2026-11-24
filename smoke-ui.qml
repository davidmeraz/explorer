//@ pragma AppId dev.gema.explorer
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "ui"

ShellRoot {
    id: root
    property int phase: -1
    property int ticks: 0
    property var client: null
    Process { id: clientQuery; command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { onStreamFinished: {
            try { root.client = JSON.parse(text).find(c => c.pid === Quickshell.processId && c.title === "Explorer" && c.mapped) ?? null; }
            catch (e) { console.warn("SMOKE: lectura clientes: " + e); root.client = null; }
        } }
    }
    AppBridge { id: bridge }
    AppWindow {
        id: window
        bridge: bridge
        TestCase { id: input; when: false }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            ++root.ticks;
            if (bridge.error) { console.error("SMOKE_ERROR: " + bridge.error); Qt.quit(); return; }
            if (!bridge.ready || bridge.loading || !bridge.path) return;
            if (root.phase < 0) {
                if (root.ticks > 100) { console.error("SMOKE_ERROR: estado o geometría Hyprland no confirmados: fase=" + root.phase + " cliente=" + JSON.stringify(root.client)); Qt.quit(); return; }
                if (!clientQuery.running) clientQuery.running = true;
                const c = root.client;
                if (c && c.floating === false && c.fullscreen === 0 && window.width === c.size[0] && window.height === c.size[1]) {
                    console.log("SMOKE_HYPRLAND: " + JSON.stringify({pid:c.pid, class:c.class, floating:c.floating, fullscreen:c.fullscreen, size:c.size}));
                    root.phase = 7;
                }
                return;
            }
            if (root.phase === 7) {
                if (root.ticks < 10) return;
                if (bridge.places.length < 2) { console.error("SMOKE_ERROR: lugares insuficientes"); Qt.quit(); return; }
                if (bridge.entries.length < 3 || typeof bridge.entries[0].mtime !== "number") { console.error("SMOKE_ERROR: mtime ausente"); Qt.quit(); return; }
                root.phase = 8;
                bridge.setSort("name", true);
            } else if (root.phase === 8) {
                if (!bridge.sortDesc || bridge.sortBy !== "name" || bridge.entries.length < 3 || bridge.entries[0].name !== "segunda" || bridge.entries[2].name !== "otro.txt") {
                    console.error("SMOKE_ERROR: orden descendente"); Qt.quit(); return;
                }
                root.phase = 9;
                bridge.setSort("name", false);
            } else if (root.phase === 9) {
                if (bridge.sortDesc || bridge.sortBy !== "name") { console.error("SMOKE_ERROR: orden restaurado"); Qt.quit(); return; }
                root.phase = 0;
            } else if (root.phase === 0) {
                if (root.ticks < 10) return;
                if (bridge.entries.length !== 4 || !bridge.entries[0].isDir || !bridge.entries[2].isFile) {
                    console.error("SMOKE_ERROR: entradas inesperadas"); Qt.quit(); return;
                }
                const folder = window.gridView.itemAtIndex(0);
                const file = window.gridView.itemAtIndex(2);
                if (!folder || !file) return;
                if (!folder.directory || file.directory || folder.name !== "carpeta" || file.name !== "archivo.txt") {
                    console.error("SMOKE_ERROR: delegates incorrectos"); Qt.quit(); return;
                }
                if (window.fullscreen) { console.error("SMOKE_ERROR: fullscreen inesperado"); Qt.quit(); return; }
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
                window.searchField.text = "SEGUNDA";
                root.phase = 4;
            } else if (root.phase === 4) {
                if (window.filteredEntries.length !== 1 || window.listView.currentIndex !== -1) {
                    console.error("SMOKE_ERROR: filtro o selección de lista"); Qt.quit(); return;
                }
                window.listView.currentIndex = 0;
                root.phase = 1;
                window.listView.forceActiveFocus();
                input.keyClick(Qt.Key_Return);
            } else if (root.phase === 1) {
                if (!bridge.path.endsWith("/segunda") || window.searchField.text !== "") {
                    console.error("SMOKE_ERROR: navegación filtrada en lista"); Qt.quit(); return;
                }
                root.phase = 2;
                bridge.back();
            } else if (root.phase === 2) {
                if (bridge.path.endsWith("/segunda") || !bridge.canForward) {
                    console.error("SMOKE_ERROR: historial Adelante tras Atrás"); Qt.quit(); return;
                }
                root.phase = 5;
                bridge.forward();
            } else if (root.phase === 5) {
                if (!bridge.path.endsWith("/segunda") || bridge.canForward || !bridge.canBack) {
                    console.error("SMOKE_ERROR: bridge.forward()"); Qt.quit(); return;
                }
                root.phase = 6;
                bridge.back();
            } else if (root.phase === 6) {
                if (bridge.path.endsWith("/segunda") || !bridge.canForward) {
                    console.error("SMOKE_ERROR: segundo Atrás"); Qt.quit(); return;
                }
                window.searchField.text = "SEGUNDA";
                window.switchView(true);
                window.gridView.currentIndex = 0;
                if (!window.gridView.activeFocus) {
                    console.error("SMOKE_ERROR: selección o foco de cuadrícula"); Qt.quit(); return;
                }
                root.phase = 3;
                input.keyClick(Qt.Key_Return);
            } else if (root.phase === 3) {
                if (!bridge.path.endsWith("/segunda") || bridge.entries.length !== 0 || window.searchField.text !== "") {
                    console.error("SMOKE_ERROR: navegación"); Qt.quit(); return;
                }
                console.log("EXPLORER_SMOKE_OK");
                Qt.quit();
            }
        }
    }
}
