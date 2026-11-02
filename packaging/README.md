# Paketleme

`ro-theme.spec` tek RPM tanımıdır. Derleme:

```sh
./ro rpm-build              # build/rpmbuild altında tarball, SRPM, noarch RPM
./ro rpm-build --container  # aynısını fedora:44 podman konteynerinde
./ro rpm-check              # RPM'i kurmadan dosya listesi ve bağımlılık denetimi
```

- Kaynak tarball `git archive` ile üretilir; yalnız commit'lenmiş dosyalar girer
  (`.gitattributes` içindeki `export-ignore` yolları hariç).
- `%build` üretilen dosyaların güncel olduğunu denetler, `%install` `./ro install --destdir` ile kurar ve
  `%files` listesini yazar, `%check` kurulu ağacı `./ro validate --installed` ile denetler.
- Scriptlet'ler: ilk kurulumda Plymouth teması seçilir; tema dosyaları değiştiyse initramfs bir kez yenilenir
  (konteyner ve imaj derlemesinde denenmez); tam kaldırmada Plymouth varsayılana döner.
- Kullanıcı ayarlarına paket hiçbir zaman dokunmaz; Ro varsayılanları `/etc/xdg` üzerinden gelir.
