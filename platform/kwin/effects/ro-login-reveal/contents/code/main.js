/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Ro Login Reveal: the desktop and panel windows of plasmashell appear with a soft zoom-in (scale 1.06 -> 1.0)
 * and fade, so they settle in as the Ro splash screen (blurred wallpaper) dissolves. Runs only in the first
 * minute after KWin starts (login), so restarting plasmashell later does not replay it.
 */
"use strict";

var START = Date.now();
var WINDOW_OF_OPPORTUNITY_MS = 60000;
var DURATION_DESKTOP = 900;
var DURATION_PANEL = 700;
var FROM_SCALE = 1.06;

function isShell(w) {
    return w && (w.desktopWindow || w.dock) && String(w.windowClass).indexOf("plasmashell") >= 0;
}

function reveal(w) {
    if (!isShell(w) || Date.now() - START > WINDOW_OF_OPPORTUNITY_MS) {
        return;
    }
    var duration = w.desktopWindow ? DURATION_DESKTOP : DURATION_PANEL;
    animate({
        window: w,
        duration: duration,
        animations: [
            { type: Effect.Scale, from: FROM_SCALE, to: 1.0, curve: QEasingCurve.OutCubic },
            { type: Effect.Opacity, from: 0.0, to: 1.0, curve: QEasingCurve.OutCubic }
        ]
    });
}

effects.windowAdded.connect(reveal);
