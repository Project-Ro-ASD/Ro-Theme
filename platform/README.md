# Platform Paketleri

Bu klasör masaüstü ortamlarının doğrudan okuduğu tema paketlerini içerir.

- `plasma/`: KDE color scheme, Plasma style, global theme ve panel layout dosyaları
- `plasmalogin/`: Plasma Login Manager için Ro giriş duvar kâğıdı varsayılanı
- `plymouth/`: Açılış animasyonu ve boot splash teması
- `gtk/`: GTK3/GTK4 uygulamaları için temel Ro stili
- `kwin/`: Opsiyonel KWin efekt paketi
- `icons/` ve `cursor/`: Tema kimlik dosyaları

Buradaki dosya adları ve metadata ID'leri KDE tarafından doğrudan okunur; taşıma
ve isim değiştirme yapılırken `scripts/validate.sh` mutlaka çalıştırılmalı.
