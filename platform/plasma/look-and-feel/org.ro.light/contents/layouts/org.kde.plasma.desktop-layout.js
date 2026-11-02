// Ro panel düzeni — otomatik üretilir (core/tokens + manifest.PANEL); elle düzenlenmez.
function safeAdd(panel, id) {
    try {
        return panel.addWidget(id);
    } catch (e) {
        print("Ro layout: could not add " + id + ": " + e);
        return null;
    }
}

var wallpaperPath = "/usr/share/wallpapers/RoLight";
var userWallpaperPath = userDataPath("data") + "/wallpapers/RoLight";
if (!fileExists(wallpaperPath) && fileExists(userWallpaperPath)) {
    wallpaperPath = userWallpaperPath;
}

var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    var d = ds[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://" + wallpaperPath);
    d.writeConfig("FillMode", "2");
}

var ps = panels();
for (var j = 0; j < ps.length; j++) {
    ps[j].remove();
}

var bar = new Panel();
bar.location = "bottom";
bar.height = 56;
bar.hiding = "none";
try { bar.floating = true; } catch (e) {}

var launcherId = knownWidgetTypes.indexOf("org.ro.launcher") !== -1 ? "org.ro.launcher" : "org.kde.plasma.kickoff";
var launcher = safeAdd(bar, launcherId);
if (!launcher) {
    launcher = safeAdd(bar, "org.kde.plasma.kickoff");
}
if (launcher && launcher.type !== "org.ro.launcher") {
    launcher.currentConfigGroup = ["General"];
    launcher.writeConfig("icon", "start-here");
}

safeAdd(bar, "org.kde.plasma.panelspacer");

var tasks = safeAdd(bar, "org.kde.plasma.icontasks");
if (tasks) {
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.mozilla.firefox.desktop,applications:systemsettings.desktop");
    tasks.writeConfig("showOnlyCurrentScreen", "true");
    tasks.writeConfig("showOnlyCurrentDesktop", "false");
    tasks.writeConfig("groupingStrategy", "1");
    tasks.writeConfig("sortingStrategy", "1");
    tasks.writeConfig("highlightWindows", "true");
}

safeAdd(bar, "org.kde.plasma.panelspacer");

var tray = safeAdd(bar, "org.kde.plasma.systemtray");
if (tray) {
    tray.currentConfigGroup = ["General"];
    tray.writeConfig("shownItems", "org.kde.plasma.networkmanagement,org.kde.plasma.bluetooth,org.kde.plasma.volume,org.kde.plasma.notifications,org.kde.plasma.battery");
    tray.writeConfig("reverseIconOrder", "true");
    tray.writeConfig("scaleIconsToFit", "false");
}

var clock = safeAdd(bar, "org.kde.plasma.digitalclock");
if (clock) {
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", "false");
    clock.writeConfig("showSeconds", "false");
    clock.writeConfig("autoFontAndSize", "false");
    clock.writeConfig("fontFamily", "Noto Sans SemiBold");
    clock.writeConfig("fontSize", "13");
}
