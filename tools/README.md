# Geliştirme araçları

`./ro` aracının kodu `tools/rotheme/` altındadır (yalnız Python 3 standart kütüphanesi).

| Modül | Komut | Görev |
|---|---|---|
| `manifest.py` | — | Tek doğruluk kaynağı: kurulum eşlemesi, xdg anahtarları, panel ve applet listeleri, SVG kimlikleri |
| `tokens.py` | — | Token yükleme, şema doğrulaması, renk ve sayı dönüşümleri |
| `generate/` | `ro generate [--check\|--list]` | Token'lardan türetilen dosyalar; önce bellekte üretir, sonra atomik yazar |
| `validate/` | `ro validate [--installed KÖK] [--json]` | Kimlikli kontroller (kaynak ağacı ve kurulu ağaç) |
| `install.py` | `ro install --destdir\|--local`, `ro uninstall` | Sistem/kullanıcı kurulumu ve RPM `%files` listesi |
| `apply.py` | `ro apply light\|dark` | Temayı canlı oturuma uygular (önce yedek alır) |
| `diagnose.py` | `ro diagnose` | Salt okunur tanı (`ro-theme-diagnose`) |
| `runtime.py` | `ro check-runtime` | Gerekli Plasma applet'leri kurulu mu |
| `reset.py` | `ro reset-defaults` | Kullanıcı ayarlarını varsayılana döndürür (`apply-dark-defaults`) |
| `rpm.py` | `ro rpm-build`, `ro rpm-check` | RPM derleme ve denetim |
| `release_manifest.py` | `ro release-manifest` | Sürüm paketi için `SHA256SUMS` ve bileşen manifesti |

`tools/dev/` kalan yardımcıları barındırır: `check-rpm-dependencies.sh` (RPM bağımlılık denetimi),
`fedora-baseline.txt` (haftalık paket sürüm tabanı), `resize-plymouth-frames.py` (Plymouth karelerini
yeniden boyutlandırır) ve `test-system-defaults.sh` (sistem varsayılanlarını sınar).
