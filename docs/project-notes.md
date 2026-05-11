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
- `.github/workflows/rpm-build.yml`: Tag gelince GitHub'da RPM build alır.
- `scripts/validate.sh`: Dosya yollarını, metadata'yı ve tema bağlantılarını kontrol eder.
- `tools/dev/build-rpm.sh`: Yerelde RPM build sürecini GitHub'a benzer şekilde çalıştırır.
- `build/`: Üretilen paketlerin çıktısıdır, Git'e gönderilmez.

## Normal Release Akışı

Yeni sürüm için genel sıra:

```bash
./scripts/generate-theme.sh
./scripts/validate.sh

git status
git add .
git commit -m "Release 1.0.0"
git push origin main

git tag -a v1.0.0 -m "Ro Theme 1.0.0"
git push origin v1.0.0
```

Tag GitHub'a gidince `Build RPM` workflow'u otomatik çalışır. Build başarılıysa
RPM dosyaları GitHub Releases sayfasına eklenir.

## Aynı Tag'i Yeniden Göndermek

İlk denemede workflow eksikse, release yanlış oluştuysa veya aynı sürümü yeniden
build etmek gerekiyorsa tag yenilenebilir.

Kullandığımız komutlar:

```bash
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

git tag -a v1.0.0 -m "Ro Theme 1.0.0"
git push origin v1.0.0
```

Bu komutların anlamı:

- `git tag -d v1.0.0`: Yereldeki eski `v1.0.0` tag'ini siler.
- `git push origin :refs/tags/v1.0.0`: GitHub'daki eski `v1.0.0` tag'ini siler.
- `git tag -a v1.0.0 -m "Ro Theme 1.0.0"`: Mevcut commit üzerine açıklamalı yeni tag oluşturur.
- `git push origin v1.0.0`: Yeni tag'i GitHub'a gönderir ve workflow'u tekrar başlatır.

Bu yöntem özellikle ilk sürümde veya henüz kimse kullanmadan önce uygundur. Yayına
çıkmış ve kullanıcıya gitmiş sürümlerde aynı tag'i değiştirmek yerine `v1.0.1`
gibi yeni sürüm çıkarmak daha temizdir.

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
- SDDM login theme sistemde görünmesi için RPM kurulumu veya sistem kopyası gerekir.
- Kilit ekranında KDE'nin güvenli auth akışı korunur; özel `LockScreen.qml` kullanılmaz.
