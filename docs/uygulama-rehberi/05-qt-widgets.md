# 5 · Qt Widgets ve C++

Qt Widgets uygulamaları (Dolphin, Konsole, Sistem Ayarları'nın QWidget modülleri) renkleri `KColorScheme` ile okur.
Kural aynıdır: sabit `QColor` yazmayın, rolü okuyun.

```cpp
#include <KColorScheme>
#include <KColorUtils>

const KColorScheme view(QPalette::Active, KColorScheme::View);
const QColor zemin   = view.background(KColorScheme::NormalBackground).color();
const QColor metin   = view.foreground(KColorScheme::NormalText).color();
const QColor ikincil = view.foreground(KColorScheme::InactiveText).color();   // Ro ikincil metin
const QColor vurgu   = KColorScheme(QPalette::Active, KColorScheme::Selection)
                           .background(KColorScheme::NormalBackground).color();
```

| İş | Rol |
|---|---|
| Zemin | `background(NormalBackground)` (`View` / `Window` / `Button` seti) |
| Alternatif satır | `background(AlternateBackground)` |
| Metin / ikincil metin | `foreground(NormalText)` / `foreground(InactiveText)` |
| Bağlantı | `foreground(LinkText)` / `foreground(VisitedText)` |
| Hata / uyarı / başarı | `foreground(NegativeText / NeutralText / PositiveText)`, zemin için `background(...)` |
| Vurgu | `Selection` seti `background(NormalBackground)`, üstündeki metin `foreground(NormalText)` |
| Hover / odak | `decoration(HoverColor)` / `decoration(FocusColor)` |

Basit durumlarda `QPalette` da yeterlidir (`palette().color(QPalette::Highlight)`); KDE uygulamasında palet zaten Ro
şemasından gelir.

## Rolü olmayan yüzeyler

Kart, hover ve basılı durum için Ro oranları (02 · COL-33): `zemin + metin × oran`.

```cpp
// Ro token'ları: core/tokens/opacity.json (mixCard 0.07, hover 0.08, mixPressed 0.14)
constexpr qreal kRoMixCard = 0.07;
const QColor kart = KColorUtils::mix(zemin, metin, kRoMixCard);
```

C++ uygulamalar oranı Ro-Theme'deki `core/tokens/opacity.json`'dan kopyalar; kopyanın yanına kaynağını yazın ki
değişince bulunsun. Köşe ve boşluk değerleri `core/tokens/radius.json` ve `spacing.json`'dadır.

## Tema değişimini izlemek

Kullanıcı açık/koyu ya da vurgu rengini değiştirdiğinde `QEvent::PaletteChange` gelir. Renkleri bir kez hesaplayıp
saklıyorsanız bu olayda yeniden hesaplayın; her çizimde rolden okumak en güvenlisidir.

## Stil dosyası yok

`setStyleSheet`/`.qss` ile renk vermeyin (bkz. [04](04-yapilmayacaklar.md)). Tek bir öğenin rengini değiştirmeniz
gerekiyorsa paletini değiştirin (`QPalette` + `setPalette`), değeri yine `KColorScheme`'den alın.
