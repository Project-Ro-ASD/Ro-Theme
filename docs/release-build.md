# Sürüm, Tag ve GitHub Build

Bu not Ro Theme için sürüm artırma ve tag ile build başlatma akışını özetler.

## Sürüm Artırma

İlk sürüm `1.0.0` olarak ayarlıdır. Yeni sürüm çıkarırken aynı değeri şu dosyalarda
güncelle:

```text
VERSION
packaging/ro-theme.spec
platform/plasma/desktoptheme/RoDark/metadata.json
platform/plasma/desktoptheme/RoLight/metadata.json
platform/plasma/look-and-feel/org.ro.dark/metadata.json
platform/plasma/look-and-feel/org.ro.light/metadata.json
platform/plasma/layout-templates/org.ro.desktop/metadata.json
```

Değişiklikten sonra üretim ve kontrol:

```bash
./scripts/generate-theme.sh
./scripts/validate.sh
```

## Tag Atma

Tag adı paket sürümüyle aynı olmalı:

```bash
git add .
git commit -m "Release 1.0.0"
git tag -a v1.0.0 -m "Ro Theme 1.0.0"
git push origin main
git push origin v1.0.0
```

## GitHub Build Başlatma

Workflow dosyası repo içinde `.github/workflows/rpm-build.yml` yolundadır.
GitHub Actions bu dosyayı repoda gördükten sonra tag push yakalar ve RPM build
başlatır.

```yaml
on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
```

Bu yüzden normal release akışı şöyledir:

```bash
git push origin main
git push origin v1.0.0
```

`v1.0.0` tag'i GitHub'a ulaştığında workflow otomatik başlar. Actions ekranından
manuel başlatmak gerekirse `Build RPM` workflow'u `workflow_dispatch` ile de
çalıştırılabilir.

Workflow içinde temel sıra:

```bash
dnf install -y rpm-build python3 bash
./tools/dev/build-rpm.sh
```

Workflow, tag adı ile `VERSION` değerini karşılaştırır. Örneğin `VERSION`
`1.0.0` ise tag `v1.0.0` olmalıdır. Build çıktıları Actions run içinde artifact
olarak yüklenir: RPM, source RPM ve kaynak tarball.

`tools/dev/` repo içinde kalabilir. RPM paketine kurulmaz; paket içeriğini
`packaging/ro-theme.spec` dosyasındaki `%install` ve `%files` bölümleri belirler.
