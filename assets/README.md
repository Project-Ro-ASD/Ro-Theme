# Görsel varlıklar

| Yol | Kullanım |
|---|---|
| `wallpapers/RoDark/`, `wallpapers/RoLight/` | KDE duvar kâğıdı paketleri (1920x1080 ve 3840x2160); global temalar bunları seçer |
| `wallpapers/dark.jpg`, `light.jpg` | `/usr/share/ro-theme/wallpapers/` altına kurulan tek dosyalık kopyalar |
| `wallpapers/loginv2.jpg` | Giriş ekranı arka planı; `/usr/share/ro-theme/wallpapers/login.jpg` olarak kurulur |
| `brand/roasd-logo.png` | Ro-ASD logosu; GRUB simgeleri `scripts/make-grub-assets.py` ile bundan üretilir |

Aynı içerikli görseller kurulumda hardlink ile birleştirilir; paket boyutu artmaz.
Lisans: CC-BY-SA-4.0 (`LICENSES/ASSETS.md`).
