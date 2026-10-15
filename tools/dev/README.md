# Developer Tools

Bu klasör geliştirme ve yerel test yardımcılarını tutar. Bu dosyalar GitHub
reposunda kalır ama RPM paketinin içine kurulmaz.

- `install-local.sh`: Temayı mevcut kullanıcının `~/.local` dizinlerine kurar ve koyu temayı uygular.
  `--files-only` yalnız dosyaları kurar; etkin KDE ayarlarını değiştirmez.
- `apply-theme.sh`: Kaynak checkout üzerinden Ro Dark/Ro Light geçişi yapar.
- `test-local-safe.sh`: Generate, validate, local install, tema geçişleri ve diagnose zincirini çalıştırır.
- `test-layout.sh`: Plasma layout dosyasını canlı oturumda dener.
- `build-rpm.sh`: Yerel makinede kaynak arşivi ve RPM üretimini kolaylaştırır.
- `test-rpm.sh`: Oluşan RPM dosyasını kurmadan önce denetler.
- `test-system-defaults.sh NEW.rpm [OLD.rpm]`: Fedora konteynerlerinde kurulum, kullanıcı/yönetici ayarı,
  yükseltme (`.rpmnew` dahil), kaldırma, Plymouth ve bağımlılık senaryolarını çalıştırır.
- `check-rpm-dependencies.sh NEW.rpm`: Temiz Fedora test konteynerinde bağımlılıkları kurmadan çözer;
  DNF işlem özetini ve beklenen `--assumeno` iptalini doğrular. Ağ/depo hataları başarı sayılmaz.
- `test-asset-validation.py`, `test-dependency-check.py`: Bozuk varlıklar ve DNF hata durumları için
  CI'da da çalıştırılan regresyon testleri. `python3 tools/dev/<dosya>` ile çalışır.
- `test-appearance-reset.py`: Görünüm sıfırlama aracının yedekleme, okuma/yazma hataları,
  dosya izinleri ve kullanıcıya ait diğer ayarları korumasını geçici XDG dizinlerinde sınar.
  Root çalıştırılan CI'da betik yetkisiz UID ile denenir; canlı kullanıcı ayarlarına dokunmaz.
- `test-local-install.py`: Yerel kurulumun zorunlu dosya kopyalama/tema uygulama hatalarını
  başarısız saymasını ve `--files-only` seçeneğinin uygulama adımını atlamasını sınar.
- `install-system-preview.sh`: RPM kurmadan Plasma Login Manager/Plymouth önizlemesi yapar.

Kısa yerel test:

```bash
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh dark
./scripts/diagnose.sh --local
```

Yalnız dosyaları incelemek için `./tools/dev/install-local.sh --files-only` kullanılabilir.
Üretim ve doğrulama yine çalışır; hiçbir tema uygulama komutu çağrılmaz. Varsayılan kurulumda
uygulama betiği başarısız çıkarsa kurulum da başarısız döner ve komut çıktısını gösterir.
Kopyalama sırasında hata oluşursa dosyaların bir kısmı kurulmuş olabilir; kurulum başarı mesajı
vermez, etkin temayı uygulamaya geçmez. Hata giderildikten sonra yeniden çalıştırılabilir.

`scripts/apply-dark-defaults.sh` yalnızca açıkça çalıştırıldığında mevcut kullanıcının Ro
görünüm anahtarlarını sıfırlar. `--dry-run` değişiklikleri gösterir. Araç önce bütün değişecek
dosyaları yedekler, ardından aynı dizinde hazırlanan dosyaları yerlerine taşır ve izinleri korur.
Yedekleme veya hazırlık hatasında hiçbir ayar değiştirilmez. Birden çok dosyayı yerlerine taşıma
sırasında hata olursa daha önce değişen dosyalar olabilir; hata çıktısındaki yedek dizini korunur.
Sembolik bağlantı olan ayar dosyaları otomatik değiştirilmez; araç hata ile durur.
