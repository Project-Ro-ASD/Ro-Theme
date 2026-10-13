# Ro Theme Proje Notları

Bu dosya Ro Theme projesinde günlük bakım, release, RPM build ve GitHub akışı için
kısa notlar içerir. Detaylı sürüm akışı için ayrıca `docs/release-build.md`
dosyasına bakılabilir.

## Temel Mantık

Ro Theme bir Fedora/KDE tema paketidir. Kaynak dosyalar repoda durur, RPM paketini
ise `packaging/ro-theme.spec` ve GitHub Actions workflow'u üretir.

Önemli parçalar:

- `VERSION`: Projenin ana sürüm numarası.
- `packaging/ro-theme.spec`: RPM paket tarifidir.
- `.github/workflows/ci.yml`: Her PR'da Fedora 44 konteynerinde üretir, doğrular, RPM derler; `rpmlint` raporu verir.
- `.github/workflows/release.yml`: `vX.Y.Z` etiketi gelince RPM, SRPM ve sağlama toplamlarını yayınlar.
- `.github/workflows/fedora-weekly.yml`: Her pazartesi güncel Fedora 44 ile derler (PKG-16).
- `.github/workflows/rpm-build.yml`: Elle başlatılan RPM derlemesi.
- `scripts/validate.sh`: Dosya yollarını, metadata'yı ve tema bağlantılarını kontrol eder.
- `tools/dev/build-rpm.sh`: Yerelde RPM build sürecini GitHub'a benzer şekilde çalıştırır.
- `build/`: Üretilen paketlerin çıktısıdır, Git'e gönderilmez.

## Normal Release Akışı

`main` korumalı: değişiklik yalnızca PR ile girer ve CI geçmeden merge edilemez. Yeni sürüm için sıra:

1. Bir `release/vX.Y.Z` branch'inde `VERSION`, spec'teki `Version`/`Release` ve `%changelog` güncellenir.
2. `./scripts/generate-theme.sh && ./scripts/validate.sh` temiz olmalı; PR açılır, CI yeşil olunca merge edilir.
3. Etiket, merge edilen `main` commit'ine atılır:

```bash
git checkout main && git pull
git tag -a vX.Y.Z -m "Ro Theme X.Y.Z"
git push origin vX.Y.Z
```

Etiket gidince `release.yml` çalışır; RPM, SRPM ve `SHA256SUMS` GitHub Releases sayfasına eklenir.
## Etiketler Yeniden Basılmaz

Yayınlanmış bir etiket (`vX.Y.Z`) asla silinip yeniden gönderilmez; Ro-Repo ve kullanıcılar aynı sürüm
numarasının hep aynı paketi göstermesine güvenir (Ro-Theme-Docs 23 · PKG-07). Yayında bir hata varsa yeni
bir sürüm çıkarılır (`v1.1.1` gibi). Etiket atmadan önce CI'ın yeşil olduğunu ve `VERSION`, spec ve
değişiklik notlarının aynı sürümü gösterdiğini kontrol et.

Eski bir örnek: `v1.0.1` sürüm sayfasında sonradan yüklenmiş `ro-theme-1.0.5` paketleri de duruyor.
Böyle karışıklıkları önlemek için kural budur.

## Release ve Artifact Farkı

GitHub Actions iki farklı yere çıktı koyabilir:

- **Artifact**: Workflow run içinde geçici build çıktısıdır. Süresi sınırlıdır.
- **Release**: GitHub Releases sayfasında kalıcı sürüm çıktısıdır.

Ro Theme workflow'u tag ile çalıştığında RPM'i Release'e koyar. `Run workflow`
ile manuel çalıştırılırsa build alınabilir, ancak release yayınlama adımı sadece
`v*` tag referanslarında çalışır.

## Sürüm Artırırken

Sürüm değişirken en az şu yerler kontrol edilmeli:

```text
VERSION
packaging/ro-theme.spec
platform/plasma/desktoptheme/RoDark/metadata.json
platform/plasma/desktoptheme/RoLight/metadata.json
platform/plasma/look-and-feel/org.ro.dark/metadata.json
platform/plasma/look-and-feel/org.ro.light/metadata.json
platform/plasma/layout-templates/org.ro.desktop/metadata.json
```

Örnek: `1.0.0` -> `1.0.1` yapıldıysa tag de `v1.0.1` olmalı.

```bash
git tag -a v1.0.1 -m "Ro Theme 1.0.1"
git push origin v1.0.1
```

## Yerel Kontrol Komutları

Her push öncesi kısa kontrol:

```bash
./scripts/validate.sh
bash -n scripts/*.sh tools/dev/*.sh
git diff --check
```

Yerel RPM build:

```bash
./tools/dev/build-rpm.sh
```

Yerel kurulum ve tema testi:

```bash
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh dark
./tools/dev/apply-theme.sh light
./scripts/diagnose.sh --local
```

Sistem RPM kurulumu sonrası kontrol:

```bash
sudo dnf install ./build/rpmbuild/RPMS/noarch/ro-theme-*.noarch.rpm
ro-theme-diagnose --system
```

## Git Remote ve SSH Notu

Push sırasında kullanıcı adı/şifre istiyorsa remote büyük ihtimalle HTTPS'tir.
SSH için remote şu formatta olmalı:

```bash
git remote set-url origin git@github.com:Project-Ro-ASD/Ro-Theme.git
git remote -v
ssh -T git@github.com
```

Doğru remote çıktısı:

```text
origin  git@github.com:Project-Ro-ASD/Ro-Theme.git (fetch)
origin  git@github.com:Project-Ro-ASD/Ro-Theme.git (push)
```

## Dikkat Edilecekler

- `build/`, RPM dosyaları ve kaynak tarball Git'e gönderilmez.
- `tools/dev/` kaynak repoda kalır ama RPM paketine kurulmaz.
- `VERSION` ile tag adı eşleşmeli: `VERSION=1.0.0` ise tag `v1.0.0` olmalı.
- Global theme wallpaper değiştirir; color scheme sadece renk paletini değiştirir.
- Plasma Login Manager Ro giriş duvar kâğıdının sistemde görünmesi için RPM kurulumu veya sistem önizlemesi gerekir.
- Kilit ekranında KDE'nin güvenli auth akışı korunur; özel `LockScreen.qml` kullanılmaz.
