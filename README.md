# Ro Theme

Fedora KDE Plasma için hazırlanmış Ro masaüstü tema paketi. Proje; global theme,
Plasma style, color scheme, wallpaper bağlantıları, SDDM login teması, Plymouth
boot teması, GTK stili ve RPM paketleme dosyalarını tek kaynak ağacında tutar.

Güncel paket sürümü: `1.0.1`

## Ne İçerir?

- `RoLight` ve `RoDark` KDE color scheme dosyaları
- `org.ro.light` ve `org.ro.dark` Plasma global theme paketleri
- `RoLight` ve `RoDark` Plasma style paketleri
- Dark/light global theme ile otomatik wallpaper seçimi
- Kilit ekranında güvenli KDE auth akışını bozmadan `login.jpg` wallpaper ayarı
- Kullanıcı, masaüstü oturumu ve klavye seçicili SDDM login theme
- Plymouth boot theme
- RPM spec ve yerel doğrulama scriptleri

## Klasör Yapısı

```text
assets/      # Wallpaper ve marka görselleri
core/        # Kaynak tasarım tokenları
dist/        # Tokenlardan üretilen CSS/JSON/Tailwind çıktıları
docs/        # Geliştirici notları
packaging/   # RPM spec dosyası
platform/    # KDE, SDDM, Plymouth, GTK, icon ve cursor paketleri
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
sudo dnf install -y rpm-build
./tools/dev/build-rpm.sh
```

Kurulum:

```bash
sudo dnf install ./build/rpmbuild/RPMS/noarch/ro-theme-1.0.1-1*.noarch.rpm
ro-theme-diagnose --system
```

GitHub Actions ile build alırken esas dosya `packaging/ro-theme.spec` dosyasıdır.
Ama RPM build yalnızca spec'ten ibaret değildir: workflow'un `ro-theme-1.0.1.tar.gz`
kaynak arşivini hazırlaması ve spec'in `%build/%check` adımlarında çağırdığı
`scripts/generate-theme.sh` ile `scripts/validate.sh` dosyalarını kaynak arşive
koyması gerekir. Bu repo bu yüzden scriptleri tutar; `build-rpm.sh` sadece yerel
makinede aynı işi kolaylaştıran `tools/dev/build-rpm.sh` yardımcısıdır.

Sürüm artırma, tag atma ve GitHub build akışı için: `docs/release-build.md`.
Günlük bakım ve pratik proje notları için: `docs/project-notes.md`.

## Notlar

Color scheme sadece uygulama/klasör/pencere renk paletini değiştirir. Plasma style
panel, dock, popup ve widget yüzeylerinin görünümünü belirler. Global theme ise
color scheme + Plasma style + layout + wallpaper bağlantısını beraber uygular.

Kilit ekranı için özel `LockScreen.qml` kullanılmaz. Bu, KDE'nin güvenli screen
locker oturum doğrulama akışını korumak için bilinçli bırakılmıştır.
