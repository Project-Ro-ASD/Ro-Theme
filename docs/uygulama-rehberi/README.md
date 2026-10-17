# Ro temasıyla uygulama geliştirme rehberi

Bu rehber, Ro Desktop üzerinde **KDE/Qt uygulaması** (QML, Kirigami, Qt Widgets) geliştiren ya da var olan bir KDE
uygulamasını Ro görünümüne uyarlayan ekipler içindir. Kısa cevap: **renkleri ve şekilleri koda yazmayın, temadan
okuyun.** Böyle yaparsanız uygulamanız açık/koyu geçişine, kullanıcının vurgu rengine ve ölçek ayarına kendiliğinden uyar.

Kararların kendisi Ro-Theme-Docs'taki karar belgelerindedir (01 token, 02 renk, 03 Plasma stili, 04 uygulama stili,
21 widget sözleşmesi). Bu rehber o kararları "uygulama yazarken ne yapayım" sorusuna çevirir.

## Altın kural

| Yapmayın | Yapın |
|---|---|
| `color: "#007aff"` | `color: Kirigami.Theme.highlightColor` |
| `color: "#ffffff"` (kart zemini) | `color: Kirigami.Theme.backgroundColor` |
| `radius: 12` | `radius: RoTokens.radiusMd` |
| Kaydırıcıyı `Rectangle` ile yeniden çizmek | `QQC2.Slider` (Breeze çizer, Ro renkleriyle) |
| Kendi `.qss` dosyası, Kvantum, `LD_PRELOAD` | Hiçbiri; görünüm Ro-Theme'den gelir |

## Bölümler

1. [Renkler](01-renkler.md): Kirigami rolleri, renk setleri, rolü olmayan yüzeyler, karşılık tablosu.
2. [Köşe, boşluk, ölçü](02-sekil-ve-olcu.md): `RoTokens.qml`, iç içe köşe kuralı, ölçek ve yazı boyutu.
3. [Kontroller](03-kontroller.md): Hazır bileşen kullanmak, kart, sekme, hap düğme.
4. [Yapılmayacaklar](04-yapilmayacaklar.md): Kvantum, `.qss`, `LD_PRELOAD`, kullanıcı ayarına yazmak, sabit yollar.
5. [Qt Widgets ve C++](05-qt-widgets.md): `KColorScheme`, `KColorUtils`, `QPalette`.
6. [Test ve denetim](06-test-ve-denetim.md): Açık/koyu, vurgu rengi, ölçek; `ro-tema-denetim.py`.

## Hızlı denetim

```sh
python3 docs/uygulama-rehberi/ro-tema-denetim.py /uygulamanin/kaynak/klasoru
```

Sabit renkleri, sabit köşeleri ve yasaklı yöntemleri (Kvantum, `.qss`, `LD_PRELOAD`, `/home/...` yolları) dosya ve
satır numarasıyla listeler. Gerçek rengi göstermesi gereken yerler için istisna işareti vardır (bkz. 06).

## Neden önemli

- **Koyu tema:** Sabit `#ffffff` kart, koyu temada göz alıcı beyaz bir blok olur; üstündeki tema renkli metin okunmaz.
- **Vurgu rengi:** Kullanıcı Sistem Ayarları'ndan vurgu rengini değiştirdiğinde sabit mavi değişmez; uygulama sistemden
  kopuk görünür.
- **Erişilebilirlik:** Ro renkleri kontrast eşiklerine göre seçildi (02 · COL-04: vurgu üstünde beyaz metin ≥ 4.5).
  `#007aff` üstünde beyaz metin 4.02, `#94a3b8` beyaz üstünde 2.56'dır; ikisi de okunabilirlik eşiğinin altında.
- **Bakım:** Ro paleti güncellenince temadan okuyan uygulama kendiliğinden güncellenir; sabit renkli uygulama elle
  aranıp değiştirilir.

## Sorular

Ro-Theme reposunda issue açın ya da tema sorumlusuna yazın. Rehberde eksik bir durum gördüyseniz (rolü olmayan bir
yüzey, Breeze'in çizemediği bir kontrol) bu da bir issue'dur: çözümü bir kez temada yaparız, her uygulama kullanır.
