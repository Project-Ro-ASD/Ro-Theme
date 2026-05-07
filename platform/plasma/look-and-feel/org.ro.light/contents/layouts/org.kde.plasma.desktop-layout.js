// Ro Light global theme desktop layout.
// Applies the Ro panel layout and the light wallpaper when the global theme
// desktop layout is enabled/reset.

var wallpaperPath = "file://" + userDataPath("data") + "/ro-theme/wallpapers/light.jpg";

function safeAdd(panel, pluginId) {
    try {
        return panel.addWidget(pluginId);
    } catch (e) {
        print("Ro layout: could not add " + pluginId + ": " + e);
        return null;
    }
}

function applyWallpaper() {
    var ds = desktops();
    for (var i = 0; i < ds.length; i++) {
        ds[i].wallpaperPlugin = "org.kde.image";
        ds[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
        ds[i].writeConfig("Image", wallpaperPath);
        ds[i].writeConfig("FillMode", 2);
    }
}

function removePanels() {
    var oldPanels = panels();
    for (var i = 0; i < oldPanels.length; i++) {
        oldPanels[i].remove();
    }
}

function createTopPanel() {
    var top = new Panel();
    top.location = "top";
    top.height = 28;
    top.hiding = "none";
    try { top.alignment = "center"; } catch (e) {}

    var kickoff = safeAdd(top, "org.kde.plasma.kickoff");
    if (kickoff) {
        try {
            kickoff.currentConfigGroup = ["General"];
            kickoff.writeConfig("icon", "start-here-kde");
        } catch (e) {}
    }

    safeAdd(top, "org.kde.plasma.showdesktop");
    safeAdd(top, "org.kde.plasma.panelspacer");

    var clock = safeAdd(top, "org.kde.plasma.digitalclock");
    if (clock) {
        try {
            clock.currentConfigGroup = ["Appearance"];
            clock.writeConfig("showDate", false);
            clock.writeConfig("showSeconds", false);
        } catch (e) {}
    }

    safeAdd(top, "org.kde.plasma.panelspacer");
    safeAdd(top, "org.kde.plasma.systemtray");
}

function createDock() {
    var dock = new Panel();
    dock.location = "bottom";
    dock.height = 44;
    dock.hiding = "dodgewindows";
    try { dock.alignment = "center"; } catch (e) {}
    try { dock.lengthMode = "fit"; } catch (e) {}
    try { dock.floating = true; } catch (e) {}
    try { dock.minimumLength = 260; } catch (e) {}
    try { dock.maximumLength = 620; } catch (e) {}

    var tasks = safeAdd(dock, "org.kde.plasma.icontasks");
    if (tasks) {
        try {
            tasks.currentConfigGroup = ["General"];
            tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:google-chrome.desktop,applications:org.kde.systemsettings.desktop");
            tasks.writeConfig("showOnlyCurrentScreen", true);
            tasks.writeConfig("showOnlyCurrentDesktop", false);
            tasks.writeConfig("showOnlyMinimized", false);
            tasks.writeConfig("showToolTips", true);
            tasks.writeConfig("groupingStrategy", 1);
            tasks.writeConfig("sortingStrategy", 1);
            tasks.writeConfig("maxStripes", 1);
            tasks.writeConfig("highlightWindows", true);
        } catch (e) {}
    }
}

removePanels();
applyWallpaper();
createTopPanel();
createDock();
