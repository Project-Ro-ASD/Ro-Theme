// Ro: mevcut panellere 'Masaüstüne göz at' ekler (her kullanıcıda bir kez çalışır).
// Otomatik üretilir (manifest.PANEL); elle düzenlenmez.
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var panel = ps[i];
    var types = panel.widgetIds.map(function (id) { return panel.widgetById(id).type; });
    if (types.indexOf("org.kde.plasma.digitalclock") === -1) {
        continue;
    }
    var peek = null;
    var found = panel.widgets("org.kde.plasma.showdesktop");
    if (found.length > 0) {
        peek = found[0];
    } else {
        try { peek = panel.addWidget("org.kde.plasma.showdesktop"); } catch (e) { print("Ro: eklenemedi: " + e); }
    }
    if (peek) {
        peek.currentConfigGroup = ["General"];
        var icon = peek.readConfig("icon", "");
        if (icon === "" || icon === "user-desktop-symbolic" || icon === "user-desktop") {
            peek.writeConfig("icon", "show-desktop");
        }
    }
}
