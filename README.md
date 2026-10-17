# Ro Theme

Fedora KDE Plasma için hazırlanmış Ro masaüstü tema paketi. Proje; global theme,
Plasma style, color scheme, wallpaper bağlantıları, Plasma Login Manager ve Plymouth
boot teması, GTK stili ve RPM paketleme dosyalarını tek kaynak ağacında tutar.

Güncel paket sürümü: `1.1.4`

## Ne İçerir?

- `RoLight` ve `RoDark` KDE color scheme dosyaları
- `org.ro.light` ve `org.ro.dark` Plasma global theme paketleri
- `RoLight` ve `RoDark` Plasma style paketleri
- Dark/light global theme ile otomatik wallpaper seçimi
- Kilit ekranında güvenli KDE auth akışını bozmadan `login.jpg` wallpaper ayarı
- Plasma Login Manager için Ro giriş duvar kâğıdı varsayılanı
- Plymouth boot theme
- RPM spec ve yerel doğrulama scriptleri

## Klasör Yapısı

```text
assets/      # Wallpaper ve marka görselleri
core/        # Kaynak tasarım tokenları
dist/        # Tokenlardan üretilen CSS/JSON/Tailwind çıktıları
docs/        # Geliştirici notları
packaging/   # RPM spec dosyası
platform/    # KDE, Plasma Login Manager, Plymouth, GTK, icon ve cursor paketleri
scripts/     # Build, doğrulama ve RPM/runtime scriptleri
tools/dev/   # Yerel kurulum, test ve release yardımcıları
```

Daha kısa klasör açıklamaları için ilgili dizinlerdeki `README.md` dosyalarına bak.

## Yerel Test

```bash
./scripts/validate.sh
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh dark
./tools/dev/apply-theme.sh light
./scripts/diagnose.sh --local
```

Tam global theme layout testinde mevcut Plasma panel yerleşimi resetlenir:

```bash
./scripts/check-plasma-runtime.sh layout
./tools/dev/test-layout.sh
```

## RPM Build

Fedora üzerinde yerel RPM almak için:

```bash
sudo dnf install -y rpm-build dracut plymouth plymouth-plugin-two-step
./tools/dev/build-rpm.sh
```

Kurulum:

```bash
sudo dnf install ./build/rpmbuild/RPMS/noarch/ro-theme-1.1.4-1*.noarch.rpm
ro-theme-diagnose --system
```

GitHub Actions ile build alırken esas dosya `packaging/ro-theme.spec` dosyasıdır.
Ama RPM build yalnızca spec'ten ibaret değildir: workflow'un `ro-theme-1.1.4.tar.gz`
kaynak arşivini hazırlaması ve spec'in `%build/%check` adımlarında çağırdığı
`scripts/generate-theme.sh` ile `scripts/validate.sh` dosyalarını kaynak arşive
koyması gerekir. Bu repo bu yüzden scriptleri tutar; `build-rpm.sh` sadece yerel
makinede aynı işi kolaylaştıran `tools/dev/build-rpm.sh` yardımcısıdır.

Sürüm artırma, tag atma ve GitHub build akışı için: `docs/release-build.md`.
Günlük bakım ve pratik proje notları için: `docs/project-notes.md`.
Ro temasıyla KDE/Qt uygulaması geliştiren ekipler için: [`docs/uygulama-rehberi/`](docs/uygulama-rehberi/README.md)
(renkleri ve şekilleri temadan okumak, `ro-tema-denetim.py`).

## Pakete Giren Araçlar

`tools/dev/` pakete girmez. RPM'le gelen araçlar:

| Komut | Ne yapar |
|---|---|
| `ro-theme-diagnose [--system\|--local]` | Ro dosyalarının kurulu olup olmadığını ve kullanıcının etkin tema ayarlarını raporlar; hiçbir şeyi değiştirmez |
| `/usr/libexec/ro-theme/apply-dark-defaults [--dry-run]` | Kullanıcının **kendisi çalıştırdığında**, `~/.config` içindeki Ro'nun yönettiği görünüm anahtarlarını siler; sistem varsayılanı (`/etc/xdg`) geçerli olur. Önce `~/.config/ro-theme/backup-<tarih>/` altına yedek alır; başka kullanıcılara dokunmaz |
| `/usr/libexec/ro-theme/check-plasma-runtime` | Panel yerleşimini uygulamadan önce gerekli Plasma widget'larının kurulu olduğunu denetler |

## Lisans

Kod ve üretilen dosyalar `GPL-3.0-or-later`; elle hazırlanmış görseller ve logo `CC-BY-SA-4.0`. Telif sahibi
Project Ro-ASD. Hangi dosyanın hangi lisansta olduğu ve tasarımcılar: [`LICENSES/ASSETS.md`](LICENSES/ASSETS.md).

## Notlar

Color scheme sadece uygulama/klasör/pencere renk paletini değiştirir. Plasma style
panel, popup ve widget yüzeylerinin görünümünü belirler. Global theme ise
color scheme + Plasma style + layout + wallpaper bağlantısını beraber uygular.

Kilit ekranı için özel `LockScreen.qml` kullanılmaz. Bu, KDE'nin güvenli screen
locker oturum doğrulama akışını korumak için bilinçli bırakılmıştır.
