# 1 · Renkler

Ro renkleri bir **KDE renk şemasıdır** (`RoLight.colors`, `RoDark.colors`). KDE uygulamaları bu şemayı rollerle okur.
QML'de roller `Kirigami.Theme` üzerinden, C++'ta `KColorScheme` üzerinden gelir (bkz. [05](05-qt-widgets.md)).

## Kirigami renk rolleri

```qml
import org.kde.kirigami as Kirigami

Rectangle {
    color: Kirigami.Theme.backgroundColor
    Text { color: Kirigami.Theme.textColor }
}
```

| İş | Rol |
|---|---|
| Zemin | `Kirigami.Theme.backgroundColor` |
| Alternatif satır / hafif ayrışan zemin | `Kirigami.Theme.alternateBackgroundColor` |
| Metin | `Kirigami.Theme.textColor` |
| Pasif / devre dışı metin | `Kirigami.Theme.disabledTextColor` |
| Vurgu (seçim, etkin öğe, dolu çubuk) | `Kirigami.Theme.highlightColor` |
| Vurgu üstündeki metin ve simge | `Kirigami.Theme.highlightedTextColor` |
| Klavye odağı halkası | `Kirigami.Theme.focusColor` |
| Üzerine gelme (hover) vurgusu | `Kirigami.Theme.hoverColor` |
| Bağlantı / ziyaret edilmiş bağlantı | `linkColor` / `visitedLinkColor` |
| Hata / uyarı / başarı metni | `negativeTextColor` / `neutralTextColor` / `positiveTextColor` |
| Hata / uyarı / başarı zemini | `negativeBackgroundColor` / `neutralBackgroundColor` / `positiveBackgroundColor` |

## Renk seti (colorSet)

Aynı rol, bulunduğu yere göre farklı renk verir: bir görünümün (liste, kart) zemini pencere zemininden farklıdır,
düğmeninki de. Öğenin hangi set olduğunu söyleyin:

```qml
Rectangle {
    Kirigami.Theme.colorSet: Kirigami.Theme.View   // liste, kart, metin alanı gibi içerik yüzeyleri
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor
}
```

| Set | Ne için |
|---|---|
| `Window` | Pencere zemini (varsayılan) |
| `View` | İçerik alanları: liste, ızgara, kart, metin alanı |
| `Button` | Düğme, açılır kutu |
| `Selection` | Seçili öğe |
| `Header` | Başlık çubuğu / araç çubuğu bölgesi |
| `Tooltip` | İpucu |
| `Complementary` | Ters kontrastlı yüzeyler (ör. koyu bir şerit) |

`inherit: false` yazılmazsa set üst öğeden gelir; çoğu zaman istenen budur.

## Rolü olmayan yüzeyler (02 · COL-33)

Kart, hap ve basılı durum gibi yüzeylerin şemada kendi rolü yoktur. Bunlar **zemin ve metin rengi karıştırılarak**
türetilir; sabit hex yazılmaz. Oranlar Ro token'larındadır (`RoTokens.qml`, bkz. [02](02-sekil-ve-olcu.md)):

| Yüzey | Formül | Token |
|---|---|---|
| Kart | zemin + metin × %7 | `RoTokens.opacityMixCard` (0.07) |
| Üzerine gelme | zemin + metin × %8 | `RoTokens.opacityHover` (0.08) |
| Basılı | zemin + metin × %14 | `RoTokens.opacityMixPressed` (0.14) |
| Hap düğme | oran değil, `Button` seti | `Kirigami.Theme.colorSet: Kirigami.Theme.Button` |

```qml
Rectangle {   // kart
    color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                   Kirigami.Theme.textColor, RoTokens.opacityMixCard)
}
```

**İkincil metin:** Ro'da ikincil metin şemadaki `ForegroundInactive` rolüdür. Kirigami bu rolü vermez; zemin ile metnin
%72 karışımı iki temada da Ro değerine denk düşer (açık `#5D5F65` → ~`#666`, koyu `#B4B5B9` → ~`#B7B7B9`):

```qml
color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.72)
```

Devre dışı öğeler için `disabledTextColor` kullanın; ikincil metin devre dışı metin değildir.

## Karşılık tablosu

Sistem Ayarları uyarlamasında (Ro-KDE-SystemSettings, Ekim 2026) en sık geçen sabit renkler ve yerlerine yazılacaklar:

| Bulunan | Nerede | Yerine |
|---|---|---|
| `#007aff` (Apple mavisi) | dolu kaydırıcı, seçili radyo, vurgulu kenar | `Kirigami.Theme.highlightColor` |
| `#007aff` | odak kenarı (`activeFocus`) | `Kirigami.Theme.focusColor` |
| `#ffffff` | kart / panel zemini | `Kirigami.Theme.backgroundColor` (`View` seti) |
| `#ffffff` | vurgu üstündeki metin / simge | `Kirigami.Theme.highlightedTextColor` |
| `#ffffff` | kaydırıcı tutamağı, radyo içi | Elle çizmeyin: `QQC2.Slider`, `QQC2.RadioButton` (bkz. [03](03-kontroller.md)) |
| `#94a3b8` | devre dışı dolgu / metin | `Kirigami.Theme.disabledTextColor` |
| `#cbd5e1`, `Qt.rgba(0,0,0,0.2)` | kontrol kenarı | Hazır kontrol; kendi yüzeyinizse zemin + metin × %20 |
| `#e2e8f0` | kaydırıcı oluğu | Hazır kontrol; kendi çiziminizse zemin + metin × `RoTokens.opacitySliderGroove` |
| `#f8fafc`, `#f1f5f9` | alan zemini, hover | `backgroundColor` (`View`) / zemin + metin × `RoTokens.opacityHover` |
| `#1e293b`, `#0f172a` | metin | `Kirigami.Theme.textColor` |
| `#3b82f6`, `#2563eb` | seçili sekme | `Kirigami.Theme.highlightColor` |

`Qt.rgba(0, 0, 0, a)` / `Qt.rgba(1, 1, 1, a)` ile yazılmış gölge ve çizgiler de aynı sorunu taşır: siyah çizgi koyu
temada görünmez. Yerine metin renginin alfası: `Kirigami.ColorUtils.tintWithAlpha` ya da `Qt.alpha(Kirigami.Theme.textColor, a)`.

## Sabit renk ne zaman doğrudur

Gerçek bir rengi **göstermesi gereken** yerler: renk körlüğü düzeltme önizlemesi, vurgu rengi seçicideki aday renkler,
bir fotoğraf ya da renk örneği. Bunlar istisnadır; denetim betiğinde işaretlenir (bkz. [06](06-test-ve-denetim.md)).
Kategori renkleri (grafik, disk çubuğu) için Ro'nun kararı 02 · COL-34'tedir.
