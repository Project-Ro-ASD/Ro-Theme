# Scripts

Bu klasörde yalnızca build, doğrulama ve RPM/runtime tarafından gerçekten kullanılan
scriptler kalır.

- `generate-theme.sh`: Tokenlardan Plasma, GTK ve dist çıktılarını üretir.
- `validate.sh`: Kaynak ağacı, metadata, renkler, layout ve RPM kurallarını denetler.
- `apply-dark-defaults.sh`: RPM kurulumunda Ro Dark varsayılanlarını uygular.
- `diagnose.sh`: Local veya sistem kurulumundaki hataları raporlar.
- `check-plasma-runtime.sh`: KDE/Plasma widget ve layout bağımlılıklarını kontrol eder.

Yerel kurulum, canlı tema değiştirme ve RPM deneme komutları `tools/dev/` altındadır.
