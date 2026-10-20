# Assets

Bu klasör Ro temasının ortak görsellerini tutar.

- `wallpapers/RoLight/`, `wallpapers/RoDark/`: KDE duvar kâğıdı paketleri (seed 102; `contents/images/1920x1080.jpg` ve `3840x2160.jpg`, Plasma ekrana uygun boyutu seçer). `/usr/share/wallpapers/` altına kurulur; global tema ve yerleşim bunları seçer.
- `wallpapers/light.jpg`, `wallpapers/dark.jpg`: aynı görsellerin 1080p kopyası (`/usr/share/ro-theme/wallpapers/`; betikler ve diagnose için).
- `brand/roasd-logo.png`: marka alanlarında kullanılan logo (Plymouth logo kullanmaz; firmware logosu korunur, 16 · PLY-04/07)

`wallpapers/loginv2.jpg`, Plasma Login Manager giriş duvar kâğıdının kaynak
görselidir. RPM içinde `/usr/share/ro-theme/wallpapers/login.jpg` adıyla kurulur.
Kilit ekranı kopyaları Plasma look-and-feel paketlerinin içinde ayrıca tutulur.
Yeni wallpaper varyantı ekleme akışı için: `WALLPAPER_GUIDE.md`.
