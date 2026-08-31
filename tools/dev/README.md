# Developer Tools

Bu klasör geliştirme ve yerel test yardımcılarını tutar. Bu dosyalar GitHub
reposunda kalır ama RPM paketinin içine kurulmaz.

- `install-local.sh`: Temayı mevcut kullanıcının `~/.local` dizinlerine kurar.
- `apply-theme.sh`: Kaynak checkout üzerinden Ro Dark/Ro Light geçişi yapar.
- `test-local-safe.sh`: Generate, validate, local install, tema geçişleri ve diagnose zincirini çalıştırır.
- `test-layout.sh`: Plasma layout dosyasını canlı oturumda dener.
- `build-rpm.sh`: Yerel makinede kaynak arşivi ve RPM üretimini kolaylaştırır.
- `test-rpm.sh`: Oluşan RPM dosyasını kurmadan önce denetler.
- `install-system-preview.sh`: RPM kurmadan Plasma Login Manager/Plymouth önizlemesi yapar.

Kısa yerel test:

```bash
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh dark
./scripts/diagnose.sh --local
```
