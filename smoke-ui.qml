import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "ui"

ShellRoot {
    id: root
    property int phase: -3
    property int ticks: 0
    property var monitors: []
    property var client: null
    Process { id: monitorQuery; command: ["hyprctl", "-j", "monitors"]; running: true
        stdout: StdioCollector { onStreamFinished: { try { root.monitors = JSON.parse(text); } catch (e) {} } }
    }
    Process { id: clientQuery; command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { onStreamFinished: {
            try { root.client = JSON.parse(text).find(c => c.pid === Quickshell.processId && c.title === "Explorer" && c.mapped) ?? null; }
            catch (e) { console.warn("SMOKE: lectura clientes: " + e); root.client = null; }
        } }
    }
    AppBridge { id: bridge }
    AppWindow { id: window; bridge: bridge }
    TestCase { id: input; when: false }
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
                const m = c && root.monitors.find(x => x.id === c.monitor);
                if (!c || !m) return;
                const r = m.reserved;
                const rotated = m.transform % 2 === 1;
                const width = Math.round((rotated ? m.height : m.width) / m.scale) - r[0] - r[2];
                const height = Math.round((rotated ? m.width : m.height) / m.scale) - r[1] - r[3];
                const x = m.x + r[0], y = m.y + r[1];
                const rw = Math.min(900, width), rh = Math.min(620, height);
                const matchesMax = (c.fullscreen === 0 || c.fullscreen === 1) && c.at[0] === x && c.at[1] === y && c.size[0] === width && c.size[1] === height;
                const matchesRestore = c.fullscreen === 0 && c.at[0] === x + Math.floor((width - rw) / 2) && c.at[1] === y + Math.floor((height - rh) / 2) && c.size[0] === rw && c.size[1] === rh;
                if ((root.phase === -2 ? matchesRestore : matchesMax)) {
                    console.log("SMOKE_HYPRLAND: " + JSON.stringify({pid:c.pid, at:c.at, size:c.size, fullscreen:c.fullscreen}));
                    root.client = null;
                    if (root.phase === -1) root.phase = 0;
                    else { ++root.phase; window.toggleFit(); }
                }
                return;
            }
            if (root.phase === 0) {
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
