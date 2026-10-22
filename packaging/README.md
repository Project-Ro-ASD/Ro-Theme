# Packaging

RPM paketinin ana dosyası `ro-theme.spec` dosyasıdır.

Noto Sans, Noto Sans Mono ve Inter, `ro-theme` RPM'inin zorunlu bağımlılıklarıdır
(`google-noto-sans-fonts`, `google-noto-sans-mono-fonts`, `rsms-inter-fonts`). Normal
DNF kurulumunda `install_weak_deps=False` olsa da kurulur; çözülemiyorlarsa işlem
başarısız olur. `test-rpm.sh` üretilmiş RPM'in güçlü bağımlılıklarını da denetler.
Bağımlılıkları atlayan `rpm --nodeps` ve yalnız dosya kopyalayan yerel kurulum bu
garantinin dışında kalır. Paket, kullanıcı font ayarlarını yeniden yazmaz.

GitHub Actions gibi CI ortamlarında genelde şu akış yeterlidir:

```bash
./scripts/generate-theme.sh
./scripts/validate.sh
mkdir -p build/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
VERSION_VALUE="$(tr -d '[:space:]' < VERSION)"
tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/ro-theme-$VERSION_VALUE"
cp -a assets core dist docs platform scripts tools packaging README.md LICENSE VERSION "$tmpdir/ro-theme-$VERSION_VALUE/"
tar -czf "build/rpmbuild/SOURCES/ro-theme-$VERSION_VALUE.tar.gz" -C "$tmpdir" "ro-theme-$VERSION_VALUE"
rpmbuild --define "_topdir $PWD/build/rpmbuild" -ba packaging/ro-theme.spec
```

Yerelde aynı işi daha rahat yapmak için `./tools/dev/build-rpm.sh` kullanılabilir.
Bu script zorunlu değildir; sadece kaynak arşivi, validate ve RPM test adımlarını
tek komutta toplar.
