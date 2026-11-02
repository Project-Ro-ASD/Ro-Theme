# Plasma dosyaları

| Yol | Kimlik | Üretilir mi |
|---|---|---|
| `color-schemes/` | `RoLight`, `RoDark` | Evet |
| `desktoptheme/RoLight`, `RoDark` | Plasma stili (29 SVG, `colors`, `plasmarc`, metadata) | Evet |
| `look-and-feel/org.ro.light`, `org.ro.dark` | Global temalar | `metadata.json`, `contents/defaults` ve panel düzeni üretilir; açılış ekranı, kilit ekranı görseli ve önizlemeler elle |
| `layout-templates/org.ro.desktop` | Ro alt panel şablonu (mevcut panelleri silmez) | Evet |
| `defaults/xdg/` | `/etc/xdg` altına `%config(noreplace)` olarak kurulan 7 varsayılan dosya | Evet |

Üretilen dosyaları elle değiştirmeyin: `./ro generate --check` ve CI farkı yakalar.
Kilit ekranı için kendi `LockScreen.qml` dosyamız yoktur; yalnız arka plan görseli sağlanır.
