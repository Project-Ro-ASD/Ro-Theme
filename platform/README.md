# Platform dosyaları

| Yol | Ne | Üretilir mi |
|---|---|---|
| `plasma/` | Renk şemaları, Plasma stilleri, global temalar, panel şablonu, `/etc/xdg` varsayılanları | Çoğu `./ro generate` ile (bkz. `plasma/README.md`) |
| `kwin/aurorae/` | Ro Açık/Koyu pencere dekorasyonu | Evet |
| `kwin/effects/ro-login-reveal/` | Oturum açılışında masaüstünü yumuşakça gösteren KWin efekti | Hayır |
| `icons/ro-icons/` | Ro simge teması (Papirus'tan miras alır); açık sürümü kurulumda türetilir | Hayır |
| `cursor/ro-cursor/` | İmleç teması tanımı (Breeze imleçleri) | Hayır |
| `plymouth/ro-theme/` | Açılış teması: animasyon kareleri elle, `.plymouth` ve küçük simgeler üreteçle | Kısmen |
| `grub/ro/` | GRUB teması: görseller elle, `theme.txt` üreteçle | Kısmen |
| `plasmalogin/` | Giriş ekranı duvar kâğıdı ayarı | Hayır |
| `firefox/` | Firefox vurgu rengi tercihi | Hayır |

Kurulum yolları `tools/rotheme/manifest.py` içindeki `INSTALL` tablosundadır.
