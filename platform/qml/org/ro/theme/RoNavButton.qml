// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Kurulum sihirbazının alt köşeleri için Geri/İleri gezinme düğmesi
Button {
    id: control

    // 0: cam hap, 1: vurgu (primary ise dolu), 2: yuvarlak ok + dış etiket
    property int variant: 0
    property bool primary: false
    property bool dark: true

    readonly property bool isCircle: variant === 2
    readonly property bool isFilled: variant !== 0 && primary
    // Yuvarlak okta dairenin ve metnin konumunu LayoutMirroring'e göre belirler
    readonly property bool circleOnRight: primary !== mirrored
    readonly property color fgColor: isFilled ? "#FFFFFF" : (dark ? "#FFFFFF" : "#0F1A33")
    // Açıkta düğmeler koyu mavi en ön tepenin üstünde durur: beyaz cam + koyu yazı okunaklı kalır
    readonly property color glassFill: dark
        ? Qt.rgba(1, 1, 1, 0.10 + (enabled && hovered ? 0.08 : 0))
        : Qt.rgba(1, 1, 1, 0.62 + (enabled && hovered ? 0.12 : 0))
    readonly property color glassBorder: dark
        ? Qt.rgba(1, 1, 1, 0.25)
        : Qt.rgba(1, 1, 1, 0.85)

    hoverEnabled: true
    topPadding: 0
    bottomPadding: 0
    leftPadding: isCircle ? 0 : 22
    rightPadding: isCircle ? 0 : 22

    opacity: enabled ? 1.0 : 0.42
    scale: !enabled ? 1.0 : (pressed ? 0.97 : (hovered ? 1.03 : 1.0))

    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    background: Item {
        implicitWidth: control.isCircle ? 56 : 44
        implicitHeight: control.isCircle ? 56 : 44

        Rectangle {
            id: bgRect
            width: control.isCircle ? 56 : parent.width
            height: control.isCircle ? 56 : parent.height
            x: control.isCircle && control.circleOnRight ? parent.width - width : 0
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: control.isFilled ? Kirigami.Theme.highlightColor : control.glassFill
            border.width: (control.isCircle && control.isFilled) ? 0 : 1
            // Açıkta vurgu dolgusu en ön tepeyle aynı mavide; beyaz kenar düğmeyi ayırır
            border.color: control.isFilled
                ? (control.dark ? Qt.rgba(201 / 255, 168 / 255, 106 / 255, 0.6) : Qt.rgba(1, 1, 1, 0.9))
                : control.glassBorder

            Behavior on color { ColorAnimation { duration: 120 } }

            // Dolu vurgu zemininde hover belirginleştirme katmanı (%8)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#FFFFFF"
                opacity: (control.isFilled && control.enabled && control.hovered) ? 0.08 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        // Klavye odak halkası: 2 px highlightColor, 3 px dışarıda
        Rectangle {
            anchors.fill: bgRect
            anchors.margins: -3
            radius: bgRect.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Kirigami.Theme.highlightColor
            opacity: control.visualFocus ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row
            x: control.isCircle
                ? (control.circleOnRight ? parent.width - width : 0)
                : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            // İleri'de ikonu sağa (yuvarlak okta daireyi sağa) alır; RTL'de terslenir
            LayoutMirroring.enabled: control.circleOnRight

            Item {
                visible: control.isCircle || control.icon.name.length > 0
                Layout.preferredWidth: control.isCircle ? 56 : 18
                Layout.preferredHeight: control.isCircle ? 56 : 18
                Layout.alignment: Qt.AlignVCenter

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: control.isCircle ? 24 : 18
                    height: width
                    source: control.icon.name
                    color: control.fgColor
                }
            }

            Label {
                visible: control.text.length > 0
                text: control.text
                // Yuvarlak okta etiket düğmenin dışında, tepenin üstünde: her iki modda beyaz
                color: control.isCircle ? "#FFFFFF" : control.fgColor
                opacity: control.isCircle ? 0.9 : 1.0
                font.pixelSize: control.isCircle ? 13 : 15
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
