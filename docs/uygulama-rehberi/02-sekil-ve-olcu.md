# 2 · Köşe, boşluk ve ölçü

## RoTokens.qml

Ro-Theme, token'ları QML'de kullanılmak üzere `RoTokens.qml` olarak üretir (01 · TOK-16). Ro-Theme paketi bunu
`/usr/share/ro-theme/qml/RoTokens.qml` olarak kurar; kaynağı Ro-Theme reposunda `dist/qml/RoTokens.qml`'dir.

**Uygulamaya nasıl alınır:** Dosyayı uygulamanın QML klasörüne kopyalayın ve `qmldir`'de singleton olarak kaydedin.
Uygulama böylece Ro-Theme kurulu olmasa da çalışır. ro-widgets bunu böyle yapar; kopyayı güncel tutan araç:
`ro-widgets/tools/sync-tokens`.

```
# qmldir
singleton RoTokens 1.0 RoTokens.qml
```

```qml
Rectangle { radius: RoTokens.radiusMd }
```

Dosyayı elle düzenlemeyin; Ro-Theme'de `core/tokens/` değişince yeniden kopyalayın.

## Köşeler

| Token | Değer | Ne için |
|---|---|---|
| `RoTokens.radiusXs` | 4 | Çok küçük öğe (rozet, etiket) |
| `RoTokens.radiusSm` | 8 | Düğme, alan, liste öğesi, kart içindeki öğe |
| `RoTokens.radiusMd` | 12 | Kart, grup |
| `RoTokens.radiusLg` / `radiusPopup` | 18 | Popup, büyük yüzey |
| `RoTokens.radiusXl` | 24 | Çok büyük yüzey |
| `RoTokens.radiusWindow` | 12 | Pencere köşesi (dekorasyon çizer) |

Ölçek dışı değerler (3, 9, 10, 16...) kullanmayın. Tam yuvarlak (daire, hap) için `height / 2` doğrudur, ama hap
**düğme** için bkz. [03](03-kontroller.md).

### İç içe köşe kuralı (01 · TOK-03)

İç öğenin köşesi, dış öğenin köşesinden boşluğun yarısı kadar küçük olmalı; yoksa köşeler birbirine paralel durmaz:

```
iç köşe ≤ dış köşe − boşluk / 2      ve      iç köşe ≥ RoTokens.radiusSm
```

Örnek: popup 18, iç boşluk 12 → içindeki kart en çok 12; kartın içindeki öğe 8.

## Boşluk

| Token | Değer |
|---|---|
| `RoTokens.spaceXs` | 4 |
| `RoTokens.spaceSm` | 8 |
| `RoTokens.spaceMd` | 12 |
| `RoTokens.spaceLg` | 16 |
| `RoTokens.spaceXl` | 24 |

KDE bileşenlerinin kendi boşlukları için `Kirigami.Units.smallSpacing` / `largeSpacing` da doğrudur; ikisini karıştırmak
sorun değildir, ölçek dışı sabit (7, 13, 22 px) yazmak sorundur.

## Ölçek ve yazı boyutu

- QML ölçüleri **mantıksal pikseldir**: %150 ekran ölçeğinde kendiliğinden 1.5 katına çıkar. Ölçek için ek bir şey
  yapmanız gerekmez.
- **Ekrana sığma:** Sabit genişlik/yükseklik küçük ekranda büyük ölçekte taşabilir (1280×800 %150'de mantıksal 853×533).
  Pencere ya da popup ölçülerini ekranın kullanılabilir alanıyla sınırlayın (`Screen.desktopAvailableHeight`). ro-launcher
  bunu yaşadı (21 · WGT-09).
- **Yazı boyutu:** Yazı boyutunu sabit piksel ya da punto ile vermeyin; `Kirigami.Theme.defaultFont` ve
  `Kirigami.Theme.smallFont`'tan türetin. Kullanıcı yazı tipini büyütünce metin büyür, kutular da metne göre büyümelidir.
  Not: `smallFont` ("en küçük okunabilir yazı") genel yazı tipini izlemez; küçük metin için
  `defaultFont.pointSize * 0.8` gibi göreli bir değer kullanın (alt sınır `smallFont`).

## Opaklık ve süre

`RoTokens.opacity*` (hover, devre dışı, seçili liste öğesi...) ve `RoTokens.motion*` (animasyon süreleri) token'ları da
vardır. Animasyon süreleri kullanıcının "animasyon hızı" ayarıyla çarpılmalıdır (01 · TOK-13):
`Kirigami.Units.longDuration` gibi KDE süreleri bunu zaten yapar.
