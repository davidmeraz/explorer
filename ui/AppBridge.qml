import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: bridge
    property bool ready: false
    property string appName: "Explorer"
    property string appVersion: "0.1.0"
    property bool loading: false
    property string error: ""
    property string path: ""
    property string parentPath: ""
    property bool showHidden: false
    property var entries: []
    property int skipped: 0
    property var places: []
    property string sortBy: "name"
    property bool sortDesc: false
    signal listingSucceeded()
    property var history: []
    property string pendingMode: ""
    function list(target, hidden, mode, sort, desc) {
        if (!ready || loading) return;
        loading = true;
        error = "";
        pendingMode = mode || "navigate";
        backend.write(JSON.stringify({version: 2, type: "fs.list", data: {path: target, showHidden: hidden, sortBy: sort === undefined ? bridge.sortBy : sort, sortDesc: desc === undefined ? bridge.sortDesc : desc}}) + "\n");
    }
    property var forwardHistory: []
    readonly property bool canBack: ready && !loading && history.length > 0
    readonly property bool canForward: ready && !loading && forwardHistory.length > 0
    function setSort(nextSortBy, nextSortDesc) {
        if (bridge.path) bridge.list(bridge.path, bridge.showHidden, "refresh", nextSortBy, nextSortDesc);
        else { bridge.sortBy = nextSortBy; bridge.sortDesc = nextSortDesc; }
    }
    function loadPlaces() {
        if (!bridge.ready) return;
        backend.write(JSON.stringify({version: 2, type: "fs.places", data: {}}) + "\n");
    }
    function home() { list("", showHidden, "navigate"); }
    function back() { if (history.length) list(history[history.length - 1], showHidden, "back"); }
    function forward() { if (forwardHistory.length) list(forwardHistory[forwardHistory.length - 1], showHidden, "forward"); }
    function receive(line) {
        let event;
        try {
            event = JSON.parse(line);
            if (event.version !== 2 || !event.data || typeof event.type !== "string") throw new Error("Formato incompatible");
        } catch (e) {
            loading = false;
            error = "Error de comunicación: " + e.message;
            return;
        }
        const data = event.data;
        if (event.type === "app.ready") {
            ready = true;
            appName = data.name || "Explorer";
            appVersion = data.version || "0.1.0";
            loadPlaces();
            home();
        } else if (event.type === "fs.listed" && loading) {
            let items = (data.entries || []).filter(e => e && (e.isDir || e.isFile) && typeof e.path === "string");
            const moved = path && path !== data.path;
            if (pendingMode === "back") {
                history = history.slice(0, -1);
                if (moved) forwardHistory = forwardHistory.concat([path]);
            } else if (pendingMode === "forward") {
                forwardHistory = forwardHistory.slice(0, -1);
                if (moved) history = history.concat([path]);
            } else if (pendingMode === "navigate" && moved) {
                history = history.concat([path]);
                forwardHistory = [];
            }
            path = data.path;
            parentPath = data.parent || "";
            showHidden = data.showHidden;
            sortBy = data.sortBy || "name";
            sortDesc = Boolean(data.sortDesc);
            entries = items;
            skipped = data.skipped || 0;
            loading = false;
            listingSucceeded();
        } else if (event.type === "fs.places") {
            places = (data.places || []).filter(p => p && typeof p.path === "string" && typeof p.name === "string");
        } else if (event.type === "error") {
            loading = false;
            error = data.message || "No se pudo abrir la carpeta.";
        }
    }
    readonly property Process backend: Process {
        command: [Quickshell.shellDir + "/backend/run-backend.sh"]
        workingDirectory: Quickshell.shellDir
        stdinEnabled: true
        running: true
        stdout: SplitParser { onRead: data => bridge.receive(data) }
        stderr: SplitParser { onRead: data => console.warn("Backend: " + data) }
        onExited: (exitCode, exitStatus) => {
            bridge.ready = false;
            bridge.loading = false;
            bridge.error = "Motor desconectado (" + exitCode + ").";
        }
    }
}
