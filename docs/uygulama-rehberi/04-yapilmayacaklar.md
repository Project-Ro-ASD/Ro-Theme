# 4 · Yapılmayacaklar

Ro'da görünümün sahibi Ro-Theme'dir (DEFAULTS-OWNERSHIP-V1). Bir uygulama kendi görünümünü sisteme dayatırsa hem
diğer uygulamaları etkiler hem de her KDE güncellemesinde kırılabilir.

| Yapmayın | Neden | Yerine |
|---|---|---|
| **Kvantum teması** kurmak / `~/.config/Kvantum/kvantum.kvconfig` yazmak | Yalnız sizin uygulamanızı değil, kullanıcının bütün Kvantum uygulamalarını değiştirir; Ro uygulama stili Breeze (04 · APP-01) | Breeze + Ro renkleri |
| **Kendi pencere dekorasyonu** (Klassy vb.) ya da renkli "trafik ışığı" pencere düğmeleri | Dekorasyon sistem genelidir (05); macOS düğmeleri birebir alınmaz (00 §3) | Ro Aurorae (Ro-Theme) |
| **`.qss` stil dosyası** (`-stylesheet`, `setStyleSheet`) | Sabit renkler koyu temada bozulur; Breeze'in çizimini ezer | Hazır kontroller, tema rolleri |
| **`LD_PRELOAD` ile kütüphane yüklemek** | KDE/Qt güncellemesinde sessizce bozulur; hata ayıklaması zordur | Uygulamanın kendi kodu; gerekirse KDE'ye yama önerisi |
| **`QML2_IMPORT_PATH` ile Kirigami/Breeze bileşenlerinin yerine kopya koymak** (ör. `breeze/impl/ButtonBackground.qml`, `FormLayout`) | Kirigami güncellenince kopya eskir; görünüm sistemden kopar | Bileşeni olduğu gibi kullanın; görünüm ihtiyacını temaya iletin |
| **Kullanıcının ayar dosyalarına yazmak** (`kdeglobals`, `kwinrc`, `kwinrulesrc`...) | Kullanıcının seçimi her zaman önce gelir (22 · SYS); başka uygulamaları etkiler | Uygulamanın kendi `*rc` dosyası (KConfig) |
| **Sabit ev dizini yolu** (`/home/kullanici/...`) | Başka kullanıcıda çalışmaz | `$HOME`, `QStandardPaths`, `@CMAKE_INSTALL_PREFIX@` |
| **Kendi yazı tipini dayatmak** | Yazı tipi sistem ayarıdır (11) | `Kirigami.Theme.defaultFont` |
| **Pencere/popup gölgesi, buzlu cam efektini kendiniz çizmek** | Gölge ve camı KWin/Plasma çizer (19); ikisi üst üste biner | Pencere bayrakları; gerekiyorsa tema sorumlusuna |

## Neden "geliştirici betiği" de olsa önemli

Bir uyarlama `~/.local`'a kuran bir geliştirici betiğiyle başlar; paketlemeye gelince aynı yaklaşım sistem geneline
taşınır. Kvantum etkinleştiren bir betik RPM'in `%post`'una girdiğinde bütün kullanıcıların uygulamalarını değiştirir.
Yaklaşımı baştan doğru kurmak, paketleme sırasında her şeyi yeniden yazmaktan ucuzdur.
