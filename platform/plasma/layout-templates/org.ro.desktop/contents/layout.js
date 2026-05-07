// Ro masaüstü yerleşimi
// Amaç: üstte ince status bar, altta ortada sade uygulama dock'u.
// Önemli sınır: KDE'nin yerleşik Icons-only Task Manager widget'ı gerçek
// macOS tarzı hover büyütme animasyonu desteklemez. Gerçek magnification için
// ileride özel Ro Dock plasmoid yazılmalıdır.

// Önce mevcut paneller temizlenir. Bu script test amaçlıdır; kişisel panel
// düzenini korumak istiyorsan bu bloğu yorum satırına al.
var oldPanels = panels();
for (var i = 0; i < oldPanels.length; i++) {
    oldPanels[i].remove();
}

// Wallpaper burada değiştirilmez. Dark/light wallpaper seçimi yalnızca
// org.ro.dark ve org.ro.light global theme layout hook'larında yapılır.

// ÜST BAR
// Sol: Home/launcher + show desktop
// Orta: saat
// Sağ: system tray
var top = new Panel();
top.location = "top";
top.height = 28;
top.hiding = "none";
try { top.alignment = "center"; } catch (e) {}

var kickoff = top.addWidget("org.kde.plasma.kickoff");
try {
    kickoff.currentConfigGroup = ["General"];
    kickoff.writeConfig("icon", "start-here-kde");
} catch (e) {}

top.addWidget("org.kde.plasma.showdesktop");
top.addWidget("org.kde.plasma.panelspacer");

var clock = top.addWidget("org.kde.plasma.digitalclock");
try {
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", false);
    clock.writeConfig("showSeconds", false);
} catch (e) {}

top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");

// ALT DOCK
// Burada özellikle spacer yok. Dock içeriği sadece Icons-only Task Manager'dan oluşur.
// Plasma sürümü destekliyorsa panel fit/center moda alınır; desteklemiyorsa KDE panel
// sınırlaması nedeniyle arka plan geniş görünebilir, fakat widget içerik ortada kalır.
var dock = new Panel();
dock.location = "bottom";
dock.height = 44;
dock.hiding = "dodgewindows";
try { dock.alignment = "center"; } catch (e) {}
try { dock.lengthMode = "fit"; } catch (e) {}
try { dock.floating = true; } catch (e) {}
try { dock.minimumLength = 260; } catch (e) {}
try { dock.maximumLength = 620; } catch (e) {}

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];

// Sabit favoriler. Uygulama .desktop dosyası sistemden sisteme değişebilir.
// Çalışmayan launcher görürsen ilgili .desktop adını burada değiştir.
tasks.writeConfig("launchers", "applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop,applications:google-chrome.desktop,applications:org.kde.systemsettings.desktop");
tasks.writeConfig("showOnlyCurrentScreen", true);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("showOnlyMinimized", false);
tasks.writeConfig("showToolTips", true);
tasks.writeConfig("groupingStrategy", 1);
tasks.writeConfig("sortingStrategy", 1);
tasks.writeConfig("maxStripes", 1);
tasks.writeConfig("highlightWindows", true);
