# Packaging

RPM paketinin ana dosyası `ro-theme.spec` dosyasıdır.

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
