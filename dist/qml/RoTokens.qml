pragma Singleton
import QtQuick

// Ro tasarım token'ları (QML). scripts/generate-theme.sh tarafından core/tokens'tan ÜRETİLİR, elle düzenlenmez.
// Kullanım: widget paketine bu dosyayı kopyala ve qmldir'e şunu ekle: singleton RoTokens 1.0 RoTokens.qml
// Renkler bu dosyada yok: Kirigami.Theme kullan, böylece her renk şemasıyla uyumlu kalır.
// Süreler taban değerdir (ms); Plasma animasyon hızı çarpanını (AnimationDurationFactor) uygulamak widget'ın işidir.
QtObject {
    readonly property real radiusSm: 8
    readonly property real radiusMd: 12
    readonly property real radiusLg: 18
    readonly property real radiusXl: 24
    readonly property real radiusPanel: 18
    readonly property real radiusPopup: 18
    readonly property real radiusWidget: 18
    readonly property real radiusWindow: 12
    readonly property real radiusXs: 4
    readonly property real radiusDock: 24.0
    readonly property real spaceXs: 4
    readonly property real spaceSm: 8
    readonly property real spaceMd: 12
    readonly property real spaceLg: 16
    readonly property real spaceXl: 24
    readonly property real borderWidth: 1
    readonly property real popupPadding: 12
    readonly property real opacityGlass: 0.68
    readonly property real opacityGlassStrong: 0.82
    readonly property real opacityHover: 0.08
    readonly property real opacityDisabled: 0.42
    readonly property real opacitySolid: 1.0
    readonly property real opacityMixCard: 0.07
    readonly property real opacityMixPressed: 0.14
    readonly property real opacityListCurrent: 0.15
    readonly property real opacityListSelected: 0.3
    readonly property real opacityListSelectedHover: 0.4
    readonly property real opacityScrollbarLight: 0.85
    readonly property real opacityScrollbarHoverLight: 1.0
    readonly property real opacityScrollbarDark: 0.5
    readonly property real opacityScrollbarHoverDark: 0.9
    readonly property real opacityScrollbarGroove: 0.08
    readonly property real opacityButtonEdge: 0.2
    readonly property real opacityIndicatorEdge: 0.5
    readonly property real opacitySwitchTrackOff: 0.25
    readonly property real opacitySliderGroove: 0.2
    readonly property real opacitySliderHover: 0.12
    readonly property real opacitySeparator: 0.15
    readonly property real motionWindowOpenMs: 185
    readonly property real motionWindowCloseMs: 155
    readonly property real motionWindowMinimizeMs: 170
    readonly property real motionScaleFrom: 0.975
    readonly property real motionSlidePx: 18
    readonly property real motionFastMs: 120
}
