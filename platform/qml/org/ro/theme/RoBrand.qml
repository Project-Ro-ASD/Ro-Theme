// SPDX-FileCopyrightText: Project Ro-ASD
// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton
import QtQuick

// Ro marka bilgileri (PSU-05). ./ro generate tarafından üretilir, elle düzenlenmez.
// Sürüm VERSION dosyasından gelir; logo ro-theme paketinin kurduğu sabit yoldadır. Renk içermez.
QtObject {
    readonly property string version: "2.0.3"
    readonly property url logo: "file:///usr/share/ro-theme/brand/roasd-logo.png"
}
