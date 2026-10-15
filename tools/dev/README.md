# Developer Tools

Bu klasör geliştirme ve yerel test yardımcılarını tutar. Bu dosyalar GitHub
reposunda kalır ama RPM paketinin içine kurulmaz.

- `install-local.sh`: Temayı mevcut kullanıcının `~/.local` dizinlerine kurar ve koyu temayı uygular.
  `--files-only` yalnız dosyaları kurar; etkin KDE ayarlarını değiştirmez.
- `apply-theme.sh`: Kaynak checkout üzerinden Ro Dark/Ro Light geçişi yapar.
- `test-local-safe.sh`: Generate, validate, local install, tema geçişleri ve diagnose zincirini çalıştırır.
- `test-layout.sh`: Plasma layout dosyasını canlı oturumda dener.
- `build-rpm.sh`: Kaynak arşivi ve RPM üretir; spec'in bildirdiği yeni noarch çıktıyı test eder.
  `RPMBUILD_TOPDIR` göreli verilirse depo köküne göre mutlaklaştırılır. `FEDORA_RELEASE` sorgu
  ve derlemeye aynı şekilde aktarılır; başka sürümdeki eski RPM'ler çıktı olarak seçilmez.
- `test-rpm.sh [RPM_PATH] [--verify-installed]`: Oluşan RPM dosyasını kurmadan önce denetler.
  Yol verilmezse depo `build/rpmbuild/RPMS` ve `~/rpmbuild/RPMS` içindeki en yeni
  `ro-theme-*.noarch.rpm` seçilir; göreli yol çağıranın çalışma dizinine göre yorumlanır.
- `test-system-defaults.sh NEW.rpm [OLD.rpm]`: Fedora konteynerlerinde kurulum, kullanıcı/yönetici ayarı,
  yükseltme (`.rpmnew` dahil), kaldırma, Plymouth ve bağımlılık senaryolarını çalıştırır.
- `check-rpm-dependencies.sh NEW.rpm`: Temiz Fedora test konteynerinde bağımlılıkları kurmadan çözer;
  DNF işlem özetini ve beklenen `--assumeno` iptalini doğrular. Ağ/depo hataları başarı sayılmaz.
- `test-asset-validation.py`, `test-dependency-check.py`: Bozuk varlıklar ve DNF hata durumları için
  CI'da da çalıştırılan regresyon testleri. `python3 tools/dev/<dosya>` ile çalışır.
- `test-rpm-build.py`: Göreli/mutlak derleme kökü, spec/derleme makrolarının eşliği ve doğru
  RPM çıktısının teste gönderilmesini yalıtılmış RPM araç taklitleriyle sınar.
- `test-theme-decoration.py`: Yerel açık/koyu geçişinin ve tanı aracının üretilmiş global tema
  dekorasyonunu izlemesini, gerekli bileşen dosyalarını ve geçersiz dosya/bağlantı durumlarını sınar.
  Eksik defaults/okuyucu durumunda uygulama ayar yazmadan durur.
  Testler geçici kullanıcı dizinleri ve yalıtılmış komut taklitleri kullanır; canlı oturuma erişmez.
- `test-appearance-reset.py`: Görünüm sıfırlama aracının yedekleme, okuma/yazma hataları,
  dosya izinleri ve kullanıcıya ait diğer ayarları korumasını geçici XDG dizinlerinde sınar.
  Root çalıştırılan CI'da betik yetkisiz UID ile denenir; canlı kullanıcı ayarlarına dokunmaz.
- `test-local-install.py`: Yerel kurulumun zorunlu dosya kopyalama/tema uygulama hatalarını
  başarısız saymasını ve `--files-only` seçeneğinin uygulama adımını atlamasını sınar.
- `test-rpm-selection.py`: İki derleme dizini arasında en yeni noarch paket seçimini,
  boşluk içeren/göreli yolları ve komut seçeneklerini geçici RPM komut taklidiyle sınar.
  Gerçek RPM içeriği ve işlem kontrolü CI'ın derleme adımında ayrıca çalışır.
- `install-system-preview.sh`: RPM kurmadan Plasma Login Manager/Plymouth önizlemesini kurar;
  masaüstü varsayılanlarını değiştirmez. Kaynak dosyalar sistem dosyalarına dokunmadan kontrol
  edilir. Plymouth etkinleştirme hatası başarısız döner; araç yoksa yalnız dosya kurulumu bildirilir.
  `--help` bilgi gösterir; bilinmeyen seçenekler kuruluma geçmeden reddedilir.
- `test-system-preview.py --require-container`: Gerçek önizleme yollarında dosya korumasını ve
  hata durumlarını sınar; root yetkili geçici Fedora konteyneri gerektirir, host üzerinde çalışmaz.
  Plymouth komutu taklittir; gerçek initramfs/boot testi yapmaz. Önceki dosyalar test sonunda geri yüklenir.

Kısa yerel test:

```bash
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh dark
./scripts/diagnose.sh --local
```

Tanı aracı, yerel ve sistem kurulumunda QML token'ını, açık/koyu Aurorae dosyalarını,
yerleşim şablonunu, GTK CSS dosyalarını, ikon tanımı/Dolphin/klasör girişlerini ve mevcut imleç
tanımını kontrol eder. Eksik/okunamayan dosyalar ve dosya yerindeki klasörler hata sayılır;
geçerli dosya bağlantıları kabul edilir. İmleç yer tutucusuna yeni varlık şartı eklenmez;
GTK/Flatpak davranışı ve açık tasarım kararları ayrıca değerlendirilir.

Yalnız dosyaları incelemek için `./tools/dev/install-local.sh --files-only` kullanılabilir.
Üretim ve doğrulama yine çalışır; hiçbir tema uygulama komutu çağrılmaz. Varsayılan kurulumda
uygulama betiği başarısız çıkarsa kurulum da başarısız döner ve komut çıktısını gösterir.
Kopyalama sırasında hata oluşursa dosyaların bir kısmı kurulmuş olabilir; kurulum başarı mesajı
vermez, etkin temayı uygulamaya geçmez. Hata giderildikten sonra yeniden çalıştırılabilir.

Sistem önizlemesinde eksik kaynak girdisi kurulumu başlamadan durdurur. Kurulum başladıktan
sonraki kopyalama/etkinleştirme hataları çok dosyalı geri alma yapmaz; dosyalar kurulmuş olabilir.
Plymouth etkinleştirme hatasında tamamlandı/yeniden başlat mesajı verilmez; hata giderilip tekrar
çalıştırılmalıdır. Gerçek açılış kabulü VM'de ayrıca yapılır.

RPM derlemesi için `rpm-build` paketindeki `rpmbuild` ve `rpmspec` gerekir. Örneğin
`RPMBUILD_TOPDIR=build/custom-rpmbuild ./tools/dev/build-rpm.sh` çıktıları repo altındaki bu
dizine yazar. Tek `ro-theme` noarch çıktısı spec'ten belirlenir; beklenen dosya bulunamazsa
araç başka eski bir pakete geri düşmeden başarısız olur.

`scripts/apply-dark-defaults.sh` yalnızca açıkça çalıştırıldığında mevcut kullanıcının Ro
görünüm anahtarlarını sıfırlar. `--dry-run` değişiklikleri gösterir. Araç önce bütün değişecek
dosyaları yedekler, ardından aynı dizinde hazırlanan dosyaları yerlerine taşır ve izinleri korur.
Yedekleme veya hazırlık hatasında hiçbir ayar değiştirilmez. Birden çok dosyayı yerlerine taşıma
sırasında hata olursa daha önce değişen dosyalar olabilir; hata çıktısındaki yedek dizini korunur.
Sembolik bağlantı olan ayar dosyaları otomatik değiştirilmez; araç hata ile durur.
