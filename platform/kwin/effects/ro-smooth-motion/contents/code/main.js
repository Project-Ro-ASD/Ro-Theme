"use strict";

// Ro Smooth Motion
// Motion constants are generated from core/tokens/motion.json by scripts/generate-theme.sh.
// Bounce, shake, squash and magic-lamp movements are intentionally avoided.

const OPEN_MS = 185;
const CLOSE_MS = 155;
const MINIMIZE_MS = 170;

class RoSmoothMotion {
    constructor() {
        effects.windowAdded.connect(this.open.bind(this));
        effects.windowClosed.connect(this.close.bind(this));

        // Plasma/KWin sürüm farkları için iki minimize sinyali de desteklenir.
        if (effects.windowMinimized) {
            effects.windowMinimized.connect(this.minimize.bind(this));
            effects.windowUnminimized.connect(this.unminimize.bind(this));
        } else if (effects.windowMinimizeStateChanged) {
            effects.windowMinimizeStateChanged.connect((w) => {
                if (w.minimized) this.minimize(w);
                else this.unminimize(w);
            });
        }
    }

    // Popup, desktop, fullscreen ve özel pencereler filtrelenir.
    animatable(w) {
        if (!w) return false;
        if (w.deleted || w.popupWindow || w.specialWindow || w.desktopWindow) return false;
        if (w.fullScreen || !w.managed) return false;
        return !!(w.normalWindow || w.dialog);
    }

    open(w) {
        if (effects.hasActiveFullScreenEffect || !this.animatable(w) || !w.visible) return;
        animate({
            window: w,
            duration: OPEN_MS,
            curve: QEasingCurve.OutCubic,
            animations: [
                { type: Effect.Opacity, from: 0.0, to: 1.0 }
            ]
        });
    }

    close(w) {
        if (effects.hasActiveFullScreenEffect || !this.animatable(w)) return;
        if (!w.visible || w.skipsCloseAnimation) return;
        animate({
            window: w,
            duration: CLOSE_MS,
            curve: QEasingCurve.InCubic,
            animations: [
                { type: Effect.Opacity, from: 1.0, to: 0.0 }
            ]
        });
    }

    minimize(w) {
        if (!this.animatable(w)) return;
        animate({
            window: w,
            duration: MINIMIZE_MS,
            curve: QEasingCurve.InOutCubic,
            animations: [
                { type: Effect.Opacity, from: 1.0, to: 0.0 }
            ]
        });
    }

    unminimize(w) {
        if (!this.animatable(w)) return;
        animate({
            window: w,
            duration: OPEN_MS,
            curve: QEasingCurve.OutCubic,
            animations: [
                { type: Effect.Opacity, from: 0.0, to: 1.0 }
            ]
        });
    }
}

new RoSmoothMotion();
