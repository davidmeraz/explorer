import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: bridge
    property bool ready: false
    property string appName: "Explorer"
    property string appVersion: "0.2.0"
    property bool loading: false
    property bool mutating: false
    readonly property bool busy: loading || mutating
    property string error: ""
    property string path: ""
    property string parentPath: ""
    property bool showHidden: false
    property var entries: []
    property int skipped: 0
    property var places: []
    property string sortBy: "name"
    property bool sortDesc: false
    property var videoThumbs: ({})
    property int thumbGeneration: 0
    property var entryInfo: null
    signal listingSucceeded()
    signal mutationSucceeded(string action, string sourcePath, string targetPath)
    signal statusNotice(string message)
    signal entryInfoReady(var info)
    property var history: []
    property string pendingMode: ""
    function list(target, hidden, mode, sort, desc) {
        if (!ready || loading || mutating) return;
        loading = true;
        error = "";
        pendingMode = mode || "navigate";
        backend.write(JSON.stringify({version: 2, type: "fs.list", data: {path: target, showHidden: hidden, sortBy: sort === undefined ? bridge.sortBy : sort, sortDesc: desc === undefined ? bridge.sortDesc : desc}}) + "\n");
    }
    property var forwardHistory: []
    readonly property bool canBack: ready && !busy && history.length > 0
    readonly property bool canForward: ready && !busy && forwardHistory.length > 0
    function setSort(nextSortBy, nextSortDesc) {
        if (bridge.path) bridge.list(bridge.path, bridge.showHidden, "refresh", nextSortBy, nextSortDesc);
        else { bridge.sortBy = nextSortBy; bridge.sortDesc = nextSortDesc; }
    }
    function sendMutation(type, data) {
        mutating = true;
        error = "";
        backend.write(JSON.stringify({version: 2, type: type, data: data}) + "\n");
    }
    function mkdir(parent, name) { if (!ready || busy) return; sendMutation("fs.mkdir", {parent: parent, name: name}); }
    function renameEntry(path, newName) { if (!ready || busy) return; sendMutation("fs.rename", {path: path, newName: newName}); }
    function trashEntry(path) { if (!ready || busy) return; sendMutation("fs.trash", {path: path}); }
    function copyEntry(source, destDir) { if (!ready || busy) return; sendMutation("fs.copy", {source: source, destDir: destDir}); }
    function moveEntry(source, destDir) { if (!ready || busy) return; sendMutation("fs.move", {source: source, destDir: destDir}); }
    function openTerminal(dirPath) {
        if (!ready || busy || !dirPath) return;
        mutating = true;
        error = "";
        backend.write(JSON.stringify({version: 2, type: "fs.openTerminal", data: {path: dirPath}}) + "\n");
    }
    function loadPlaces() {
        if (!bridge.ready) return;
        backend.write(JSON.stringify({version: 2, type: "fs.places", data: {}}) + "\n");
    }
    function requestVideoThumbs(paths) {
        if (!bridge.ready) return;
        bridge.thumbGeneration += 1;
        backend.write(JSON.stringify({
            version: 2,
            type: "fs.videoThumbs",
            data: {generation: bridge.thumbGeneration, paths: paths || []}
        }) + "\n");
    }
    function statEntry(targetPath) {
        if (!bridge.ready || !targetPath) return;
        backend.write(JSON.stringify({
            version: 2,
            type: "fs.stat",
            data: {path: targetPath}
        }) + "\n");
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
            mutating = false;
            error = "Error de comunicación: " + e.message;
            return;
        }
        const data = event.data;
        if (event.type === "app.ready") {
            ready = true;
            appName = data.name || "Explorer";
            appVersion = data.version || "0.2.0";
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
            if (moved) videoThumbs = ({});
            entries = items;
            skipped = data.skipped || 0;
            loading = false;
            listingSucceeded();
        } else if (event.type === "fs.videoThumb") {
            if (data.generation === bridge.thumbGeneration && typeof data.path === "string" && typeof data.thumbPath === "string") {
                const next = Object.assign({}, bridge.videoThumbs);
                next[data.path] = {
                    thumbPath: data.thumbPath,
                    duration: typeof data.duration === "number" ? data.duration : 0
                };
                bridge.videoThumbs = next;
            }
        } else if (event.type === "fs.videoThumbsQueued") {
            // Confirmación silenciosa del encolado en segundo plano.
        } else if (event.type === "fs.statResult") {
            entryInfo = data;
            entryInfoReady(data);
        } else if (event.type === "fs.places") {
            places = (data.places || []).filter(p => p && typeof p.path === "string" && typeof p.name === "string");
        } else if (event.type === "fs.mutated") {
            mutating = false;
            mutationSucceeded(data.action || "", data.path || "", data.targetPath || data.path || "");
            const refreshTarget = bridge.path || data.parent || "";
            if (refreshTarget) list(refreshTarget, showHidden, "refresh");
            if (data.action === "trash") loadPlaces();
        } else if (event.type === "fs.terminalOpened") {
            mutating = false;
            statusNotice("Terminal abierto (" + (data.terminal || "terminal") + ")");
        } else if (event.type === "error") {
            loading = false;
            mutating = false;
            error = data.message || "No se pudo completar la operación.";
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
            bridge.mutating = false;
            bridge.error = "Motor desconectado (" + exitCode + ").";
        }
    }
}
