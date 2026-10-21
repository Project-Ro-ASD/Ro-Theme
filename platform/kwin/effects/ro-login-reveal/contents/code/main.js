/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Ro Login Reveal. ksplashqml (the Ro splash: blurred wallpaper) exits by itself when plasmashell reports the desktop
 * is ready, so KWin sees that window close exactly when the desktop is ready. At that moment this effect
 *   - dissolves the closing splash window (opacity 1 -> 0) while it grows a little (scale 1 -> 1.05), and
 *   - lets the desktop and panel windows of plasmashell zoom in (scale 1.06 -> 1.0),
 * so the blur "falls away" as the desktop settles. Without a splash (other session setups) the shell windows get the same
 * zoom when they appear, only in the first minute after KWin starts, so a later plasmashell restart does not replay it.
 */
"use strict";

var START = Date.now();
var FIRST_MINUTE_MS = 60000;
var DURATION = 1000;
var SHELL_FROM_SCALE = 1.06;
var SPLASH_TO_SCALE = 1.05;

function isShell(w) {
    return w && (w.desktopWindow || w.dock) && String(w.windowClass).indexOf("plasmashell") >= 0;
}

function isSplash(w) {
    return w && String(w.windowClass).indexOf("ksplashqml") >= 0;
}

function zoomIn(w) {
    animate({
        window: w,
        duration: DURATION,
        animations: [{ type: Effect.Scale, from: SHELL_FROM_SCALE, to: 1.0, curve: QEasingCurve.OutCubic }]
    });
}

function splashPresent() {
    return effects.stackingOrder.some(isSplash);
}

effects.windowAdded.connect(function (w) {
    // With a splash the zoom waits for its dissolve (below); the splash covers the desktop until then.
    if (!isShell(w) || Date.now() - START > FIRST_MINUTE_MS || splashPresent()) {
        return;
    }
    zoomIn(w);
});

effects.windowClosed.connect(function (w) {
    if (!isSplash(w)) {
        return;
    }
    animate({
        window: w,
        duration: DURATION,
        animations: [
            { type: Effect.Opacity, from: 1.0, to: 0.0, curve: QEasingCurve.OutCubic },
            { type: Effect.Scale, from: 1.0, to: SPLASH_TO_SCALE, curve: QEasingCurve.OutCubic }
        ]
    });
    effects.stackingOrder.filter(isShell).forEach(zoomIn);
});
