# Wallpaper Notu

Ro Theme wallpaper dosyalarında aktif isimler sabit tutulur. Yeni görsel eklerken
önce `v2` adaylarını koy, sonra aktif dosyaların üzerine geçir.

## Aday Dosyalar

```text
assets/wallpapers/lightv2.jpg   # Yeni light masaüstü wallpaper
assets/wallpapers/darkv2.jpg    # Yeni dark masaüstü wallpaper
assets/wallpapers/loginv2.jpg   # Login / splash / lockscreen kaynak görseli
```

## Aktif Dosyalar

Masaüstü global theme şu dosyaları kullanır:

```text
assets/wallpapers/light.jpg
assets/wallpapers/dark.jpg
```

SDDM login ekranı şu dosyayı kullanır:

```text
platform/sddm/themes/Ro/assets/login.jpg
```

Splash ekranı şu dosyaları kullanır:

```text
platform/plasma/look-and-feel/org.ro.light/contents/splash/login.jpg
platform/plasma/look-and-feel/org.ro.dark/contents/splash/login.jpg
platform/plasma/look-and-feel/org.ro.light/contents/splash/login-blur.jpg
platform/plasma/look-and-feel/org.ro.dark/contents/splash/login-blur.jpg
```

Lock screen şu dosyaları kullanır:

```text
platform/plasma/look-and-feel/org.ro.light/contents/lockscreen/assets/login.jpg
platform/plasma/look-and-feel/org.ro.dark/contents/lockscreen/assets/login.jpg
```

## Hızlı Güncelleme

```bash
cp assets/wallpapers/lightv2.jpg assets/wallpapers/light.jpg
cp assets/wallpapers/darkv2.jpg assets/wallpapers/dark.jpg
cp assets/wallpapers/loginv2.jpg platform/sddm/themes/Ro/assets/login.jpg
cp assets/wallpapers/loginv2.jpg platform/plasma/look-and-feel/org.ro.light/contents/splash/login.jpg
cp assets/wallpapers/loginv2.jpg platform/plasma/look-and-feel/org.ro.dark/contents/splash/login.jpg
```

Lockscreen için `loginv2.jpg` doğrudan kopyalanabilir ama önerilen yol hafif koyu
ve düşük blur bir kopya üretmektir; şifre alanı açılınca KDE'nin ek parlaklık
etkisi daha dengeli görünür.

## Kontrol

```bash
./scripts/validate.sh
./tools/dev/install-local.sh
./tools/dev/apply-theme.sh light
./tools/dev/apply-theme.sh dark
./scripts/diagnose.sh --local
```
