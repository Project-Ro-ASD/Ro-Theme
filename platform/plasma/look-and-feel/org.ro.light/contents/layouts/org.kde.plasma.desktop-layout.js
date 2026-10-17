// Ro desktop layout. Generated from core/tokens by scripts/generate-theme.sh; do not edit.
// 07 PAN-01 B: single bottom bar; launcher left, icon task manager centred, tray and clock right.

function safeAdd(panel, pluginId) {
    try { return panel.addWidget(pluginId); } catch (e) { print("Ro layout: could not add " + pluginId + ": " + e); return null; }
}

// PAN-23 A: RPM installs the wallpaper system-wide; tools/dev/install-local.sh uses the user data dir.
var systemWallpaper = "/usr/share/wallpapers/Ro Light.jpg";
var userWallpaper = userDataPath("data") + "/wallpapers/Ro Light.jpg";
var wallpaperPath = fileExists(systemWallpaper) ? systemWallpaper : userWallpaper;
var ds = desktops();
for (var i = 0; i < ds.length; i++) {
    ds[i].wallpaperPlugin = "org.kde.image";
    ds[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    ds[i].writeConfig("Image", "file://" + wallpaperPath);
    ds[i].writeConfig("FillMode", 2);
}

// The global theme layout replaces the panels; the layout template (Add Panel) only adds one.
var oldPanels = panels();
for (var i = 0; i < oldPanels.length; i++) { oldPanels[i].remove(); }

var bar = new Panel();
bar.location = "bottom";
bar.height = 44;
bar.hiding = "none";
try { bar.floating = true; } catch (e) {}

// PAN-08/24, WGT-14: ro-launcher (ro-widgets package) when installed, otherwise Kickoff;
// the bar never stays without a launcher. Both get the distribution logo.
var launcherId = knownWidgetTypes.indexOf("org.ro.launcher") >= 0 ? "org.ro.launcher" : "org.kde.plasma.kickoff";
var launcher = safeAdd(bar, launcherId) || safeAdd(bar, "org.kde.plasma.kickoff");
if (launcher) { launcher.currentConfigGroup = ["General"]; launcher.writeConfig("icon", "ro-start"); }
safeAdd(bar, "org.kde.plasma.panelspacer");

var tasks = safeAdd(bar, "org.kde.plasma.icontasks");
if (tasks) {
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:org.mozilla.firefox.desktop,applications:systemsettings.desktop");
    tasks.writeConfig("showOnlyCurrentScreen", true);
    tasks.writeConfig("showOnlyCurrentDesktop", false);
    tasks.writeConfig("groupingStrategy", 1);
    tasks.writeConfig("sortingStrategy", 1);
    tasks.writeConfig("highlightWindows", true);
}
safeAdd(bar, "org.kde.plasma.panelspacer");

// PAN-10: network, bluetooth, volume, notifications and battery visible; the expander arrow on the left.
// Plasma 6.7 keeps tray settings in the tray applet's own [General] group.
var tray = safeAdd(bar, "org.kde.plasma.systemtray");
if (tray) {
    tray.currentConfigGroup = ["General"];
    tray.writeConfig("shownItems", "org.kde.plasma.networkmanagement,org.kde.plasma.bluetooth,org.kde.plasma.volume,org.kde.plasma.notifications,org.kde.plasma.battery");
    tray.writeConfig("reverseIconOrder", true);
}

// PAN-09: time only, Noto Sans SemiBold 13 pt (fonts.panelClock).
var clock = safeAdd(bar, "org.kde.plasma.digitalclock");
if (clock) {
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", false);
    clock.writeConfig("showSeconds", false);
    clock.writeConfig("autoFontAndSize", false);
    clock.writeConfig("fontFamily", "Noto Sans SemiBold");
    clock.writeConfig("fontSize", 13);
}
