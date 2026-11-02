# Ro-Theme

Ro masaüstünün KDE Plasma teması: Ro Açık ve Ro Koyu global temaları, Plasma stilleri, renk şemaları,
Aurorae pencere dekorasyonu, panel düzeni, simgeler, açılış ekranı, Plymouth ve GRUB teması ile
`/etc/xdg` sistem varsayılanları. Fedora 44 için `ro-theme` RPM paketi olarak dağıtılır.

## Hızlı başlangıç

```sh
make test          # birim testleri
make check         # üretilen dosyalar güncel mi + kaynak denetimi
./ro generate      # token'lardan türetilen dosyaları yeniden üret
make rpm           # kaynak tarball, SRPM ve noarch RPM (build/rpmbuild)
./ro install --local   # RPM'siz, yalnız kendi kullanıcına kur (~/.local/share)
```

Tüm komutlar: `./ro --help`.

## Klasörler

| Yol | İçerik |
|---|---|
| `core/tokens/` | Tasarım token'ları (renk, yarıçap, boşluk, opaklık, hareket, yazı tipi): tek doğruluk kaynağı |
| `platform/` | Plasma, KWin, simge, imleç, Plymouth, GRUB, giriş ekranı ve Firefox dosyaları (bkz. `platform/README.md`) |
| `assets/` | Duvar kâğıtları ve logo (bkz. `assets/README.md`) |
| `dist/qml/RoTokens.qml` | Ro uygulamalarının ve widget'larının kullandığı QML token nesnesi |
| `tools/rotheme/` | `./ro` aracının Python paketi (bkz. `tools/README.md`) |
| `packaging/` | RPM spec dosyası (bkz. `packaging/README.md`) |
| `tests/` | Birim testleri (`python3 -m unittest discover -s tests -t .`) |

Üretilen dosyalar (renk şemaları, Plasma SVG'leri, Aurorae, xdg varsayılanları, panel düzeni, Plymouth ve
GRUB yapılandırması) depoda tutulur ama elle düzenlenmez; token'ı değiştirip `./ro generate` çalıştırın.

## Kurulu araçlar

| Komut | Görev |
|---|---|
| `ro-theme-diagnose [--local\|--system]` | Salt okunur tanı raporu |
| `/usr/libexec/ro-theme/apply-dark-defaults [--dry-run]` | Kendi `~/.config` ayarlarını Ro sistem varsayılanlarına döndürür (önce yedek alır) |
| `/usr/libexec/ro-theme/check-plasma-runtime [layout\|popups]` | Panel için gereken Plasma bileşenleri kurulu mu |
| `ro-grub-theme enable\|disable\|status` | GRUB temasını açar/kapatır |

## Katkı

`main` korumalıdır: her değişiklik bir dalda yapılır ve PR ile gelir; `Fedora 44 RPM CI` geçmelidir.
Sürüm süreci: `docs/release-build.md`.

## Lisans

Kod ve üretilen dosyalar GPL-3.0-or-later; görseller CC-BY-SA-4.0; GRUB yazı tipi OFL-1.1.
Ayrıntı: `LICENSES/ASSETS.md`.
