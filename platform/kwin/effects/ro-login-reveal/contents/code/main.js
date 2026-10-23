/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Ro Login Reveal. ksplashqml (the Ro splash: blurred wallpaper) exits by itself when plasmashell reports the desktop
 * is ready, so KWin sees that window close exactly when the desktop is ready. At that moment this effect
 *   - dissolves the closing splash window (opacity 1 -> 0), and
 *   - floats the desktop up into place (small rise + 1.03 -> 1.0 zoom; the zoom keeps the moved edges covered), and
 *   - slides the panel in from its own screen edge,
 * all in well under half a second. Without a splash (other session setups) the shell windows get the same motion when
 * they appear, only in the first minute after KWin starts, so a later plasmashell restart does not replay it.
 */
"use strict";

var START = Date.now();
var FIRST_MINUTE_MS = 60000;
var SPLASH_FADE_MS = 300;
var SHELL_MS = 420;
var DESKTOP_RISE_PX = 14;
var DESKTOP_FROM_SCALE = 1.03;
var PANEL_MIN_SLIDE_PX = 48;

function isShell(w) {
    return w && (w.desktopWindow || w.dock) && String(w.windowClass).indexOf("plasmashell") >= 0;
}

function isSplash(w) {
    return w && String(w.windowClass).indexOf("ksplashqml") >= 0;
}

// Pixels the panel starts away from its final place, pointing away from the screen centre (so it slides in from its edge).
// Uses the plain x/y/width/height window properties and the virtual screen size; if anything is missing it falls back to
// sliding up from the bottom edge, so the effect never breaks the login.
function panelOffset(w) {
    var size = effects.virtualScreenSize;
    if (!size || !(w.width > 0) || !(w.height > 0)) {
        return { x: 0, y: PANEL_MIN_SLIDE_PX };
    }
    var dx = (w.x + w.width / 2) - size.width / 2;
    var dy = (w.y + w.height / 2) - size.height / 2;
    if (w.width >= w.height) {
        return { x: 0, y: (dy >= 0 ? 1 : -1) * Math.max(PANEL_MIN_SLIDE_PX, w.height + 24) };
    }
    return { x: (dx >= 0 ? 1 : -1) * Math.max(PANEL_MIN_SLIDE_PX, w.width + 24), y: 0 };
}

function floatIn(w) {
    if (w.dock) {
        var o = panelOffset(w);
        animate({
            window: w,
            duration: SHELL_MS,
            animations: [{
                type: Effect.Translation,
                from: { value1: o.x, value2: o.y },
                to: { value1: 0, value2: 0 },
                curve: QEasingCurve.OutCubic
            }]
        });
        return;
    }
    animate({
        window: w,
        duration: SHELL_MS,
        animations: [
            {
                type: Effect.Translation,
                from: { value1: 0, value2: DESKTOP_RISE_PX },
                to: { value1: 0, value2: 0 },
                curve: QEasingCurve.OutCubic
            },
            { type: Effect.Scale, from: DESKTOP_FROM_SCALE, to: 1.0, curve: QEasingCurve.OutCubic }
        ]
    });
}

function splashPresent() {
    return effects.stackingOrder.some(isSplash);
}

effects.windowAdded.connect(function (w) {
    // With a splash the motion waits for its dissolve (below); the splash covers the desktop until then.
    if (!isShell(w) || Date.now() - START > FIRST_MINUTE_MS || splashPresent()) {
        return;
    }
    floatIn(w);
});

effects.windowClosed.connect(function (w) {
    if (!isSplash(w)) {
        return;
    }
    animate({
        window: w,
        duration: SPLASH_FADE_MS,
        animations: [{ type: Effect.Opacity, from: 1.0, to: 0.0, curve: QEasingCurve.OutQuad }]
    });
    effects.stackingOrder.filter(isShell).forEach(floatIn);
});
