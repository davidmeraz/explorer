pragma ComponentBehavior: Bound
import QtQuick

// Iconografía vectorial unificada (trazo limpio 24x24) sincronizada con GemaTheme.
Item {
    id: root
    property string name: ""
    property color color: GemaTheme.textColor
    property int size: 16
    property real strokeWidth: 1.8

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    function hexChannel(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * 255);
        const h = n.toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    function hexColor(c) {
        return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b);
    }

    function bodyFor(iconName) {
        switch (iconName) {
        case "sidebar":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><path d="M9 3v18"/>';
        case "arrow-left":
            return '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>';
        case "arrow-right":
            return '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>';
        case "arrow-up":
            return '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>';
        case "chevron-left":
            return '<path d="m15 18-6-6 6-6"/>';
        case "chevron-right":
            return '<path d="m9 18 6-6-6-6"/>';
        case "chevron-up":
            return '<path d="m18 15-6-6-6 6"/>';
        case "chevron-down":
            return '<path d="m6 9 6 6 6-6"/>';
        case "home":
            return '<path d="M15 21v-7a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v7"/><path d="M3 10.2a2 2 0 0 1 .7-1.5l7-6a2 2 0 0 1 2.6 0l7 6a2 2 0 0 1 .7 1.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>';
        case "desktop":
            return '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8"/><path d="M12 17v4"/>';
        case "documents":
            return '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>';
        case "downloads":
            return '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>';
        case "pictures":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>';
        case "music":
            return '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>';
        case "videos":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><path d="M7 3v18"/><path d="M3 7.5h4"/><path d="M3 12h18"/><path d="M3 16.5h4"/><path d="M17 3v18"/><path d="M17 7.5h4"/><path d="M17 16.5h4"/>';
        case "trash":
            return '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>';
        case "root":
            return '<line x1="22" x2="2" y1="12" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><circle cx="6.5" cy="16" r="0.8"/><circle cx="10.5" cy="16" r="0.8"/>';
        case "mount":
            return '<circle cx="12" cy="12" r="9.5"/><circle cx="12" cy="12" r="3"/>';
        case "folder":
            return '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>';
        case "folder-open":
            return '<path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"/>';
        case "folder-plus":
            return '<path d="M12 10.5v5.5"/><path d="M9.25 13.25h5.5"/><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>';
        case "file":
            return '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>';
        case "code":
            return '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>';
        case "box":
            return '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>';
        case "search":
            return '<circle cx="11" cy="11" r="7.5"/><path d="m20.5 20.5-4.1-4.1"/>';
        case "x":
            return '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>';
        case "edit":
            return '<path d="M21.17 6.81a1 1 0 0 0-3.98-3.98L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/><path d="m15 5 4 4"/>';
        case "refresh":
            return '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>';
        case "terminal":
            return '<polyline points="4 17 10 11 4 5"/><line x1="12" x2="20" y1="19" y2="19"/>';
        case "grid":
            return '<rect width="7" height="7" x="3" y="3" rx="1.8"/><rect width="7" height="7" x="14" y="3" rx="1.8"/><rect width="7" height="7" x="14" y="14" rx="1.8"/><rect width="7" height="7" x="3" y="14" rx="1.8"/>';
        case "list":
            return '<line x1="8" x2="21" y1="6" y2="6"/><line x1="8" x2="21" y1="12" y2="12"/><line x1="8" x2="21" y1="18" y2="18"/><circle cx="3.5" cy="6" r="0.8"/><circle cx="3.5" cy="12" r="0.8"/><circle cx="3.5" cy="18" r="0.8"/>';
        case "eye":
            return '<path d="M2.1 12.3a1 1 0 0 1 0-.6A10.7 10.7 0 0 1 21.9 11.7a1 1 0 0 1 0 .6A10.7 10.7 0 0 1 2.1 12.3"/><circle cx="12" cy="12" r="3"/>';
        case "eye-off":
            return '<path d="M10.7 5.1a10.7 10.7 0 0 1 11.2 6.6 1 1 0 0 1 0 .6 10.7 10.7 0 0 1-1.4 2.5"/><path d="M14.1 14.2a3 3 0 0 1-4.2-4.2"/><path d="M17.5 17.5a10.7 10.7 0 0 1-15.4-5.2 1 1 0 0 1 0-.6 10.7 10.7 0 0 1 4.4-5.1"/><path d="m2 2 20 20"/>';
        case "sort-asc":
            return '<path d="m3 8 4-4 4 4"/><path d="M7 4v16"/><path d="M12 12h4"/><path d="M12 16h6.5"/><path d="M12 20h9"/>';
        case "sort-desc":
            return '<path d="m3 16 4 4 4-4"/><path d="M7 20V4"/><path d="M12 4h9"/><path d="M12 8h6.5"/><path d="M12 12h4"/>';
        case "check":
            return '<path d="M20 6 9 17l-5-5"/>';
        case "copy":
            return '<rect width="13" height="13" x="9" y="9" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>';
        case "scissors":
            return '<circle cx="6" cy="6" r="3"/><path d="M8.12 8.12 12 12"/><path d="M20 4 8.12 15.88"/><circle cx="6" cy="18" r="3"/><path d="M14.8 14.8 20 20"/>';
        case "clipboard":
            return '<rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>';
        case "link":
            return '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>';
        default:
            return "";
        }
    }

    readonly property string svgBody: bodyFor(name)
    readonly property string strokeHex: hexColor(color)

    Image {
        anchors.fill: parent
        visible: root.svgBody.length > 0
        opacity: root.color.a
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.max(24, root.size * 2), Math.max(24, root.size * 2))
        source: root.svgBody.length > 0
                ? "data:image/svg+xml;utf8," + encodeURIComponent(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
                      + root.strokeHex + '" stroke-width="' + root.strokeWidth
                      + '" stroke-linecap="round" stroke-linejoin="round">'
                      + root.svgBody + '</svg>')
                : ""
    }
}
