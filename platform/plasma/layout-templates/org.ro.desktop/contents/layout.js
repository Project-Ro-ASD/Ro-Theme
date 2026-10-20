// Ro desktop layout. Generated from core/tokens by scripts/generate-theme.sh; do not edit.
// 07 PAN-01 B: single bottom bar; launcher left, icon task manager centred, tray and clock right.

function safeAdd(panel, pluginId) {
    try { return panel.addWidget(pluginId); } catch (e) { print("Ro layout: could not add " + pluginId + ": " + e); return null; }
}

var bar = new Panel();
bar.location = "bottom";
bar.height = 52;
bar.hiding = "none";
try { bar.floating = true; } catch (e) {}

// PAN-08/24, WGT-14: ro-launcher (ro-widgets package) when installed, otherwise Kickoff;
// the bar never stays without a launcher. ro-launcher keeps its own icon (ro-start, the Ro logo
// rings, from ro-widgets); Kickoff gets the distribution logo.
var launcherId = knownWidgetTypes.indexOf("org.ro.launcher") >= 0 ? "org.ro.launcher" : "org.kde.plasma.kickoff";
var launcher = safeAdd(bar, launcherId) || safeAdd(bar, "org.kde.plasma.kickoff");
if (launcher && launcher.type !== "org.ro.launcher") { launcher.currentConfigGroup = ["General"]; launcher.writeConfig("icon", "start-here"); }
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
    tray.writeConfig("scaleIconsToFit", true);   // PAN-03: tepsi ikonları panel yüksekliğiyle ölçeklenir (sabit 22 px kalmaz)
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
