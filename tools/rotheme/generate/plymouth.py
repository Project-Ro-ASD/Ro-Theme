"""Plymouth açılış teması ve 4 PNG görseli (gereksinimler/14 §4-5)."""
from __future__ import annotations

from .. import png
from ..kconfig import KConfig
from ..tokens import channels


def _plymouth_hex(color: str) -> str:
    return "0x" + color.lstrip("#").lower()


def _plymouth(t) -> str:
    d = t.dark
    cfg = KConfig()
    cfg.groups["[Plymouth Theme]"] = {
        "Name": "Ro",
        "Description": "Ro Desktop boot splash (two-step BGRT)",
        "ModuleName": "two-step",
    }
    cfg.groups["[two-step]"] = {
        "Font": "Noto Sans 12",
        "TitleFont": "Noto Sans Light 30",
        "ImageDir": "/usr/share/plymouth/themes/ro-theme",
        "DialogHorizontalAlignment": ".5",
        "DialogVerticalAlignment": ".382",
        "TitleHorizontalAlignment": ".5",
        "TitleVerticalAlignment": ".382",
        "HorizontalAlignment": ".5",
        "VerticalAlignment": ".75",
        "WatermarkHorizontalAlignment": ".5",
        "WatermarkVerticalAlignment": ".96",
        "Transition": "none",
        "TransitionDuration": "0.0",
        "BackgroundStartColor": _plymouth_hex(d.bootBackground),
        "BackgroundEndColor": _plymouth_hex(d.bootBackground),
        "ProgressBarBackgroundColor": _plymouth_hex(d.surfaceAlt),
        "ProgressBarForegroundColor": _plymouth_hex(d.accent),
        "MessageBelowAnimation": "true",
    }
    for group in ("boot-up", "shutdown", "reboot"):
        cfg.groups[f"[{group}]"] = {"UseEndAnimation": "false", "UseFirmwareBackground": "true"}
    titles = {
        "updates": ("Güncellemeler yükleniyor…", "Bilgisayarınızı kapatmayın"),
        "system-upgrade": ("Sistem yükseltiliyor…", "Bilgisayarınızı kapatmayın"),
        "firmware-upgrade": ("Donanım yazılımı güncelleniyor…", "Bilgisayarınızı kapatmayın"),
        "system-reset": ("Sistem sıfırlanıyor…", "Bilgisayarınızı kapatmayın"),
    }
    for group, (title, subtitle) in titles.items():
        cfg.groups[f"[{group}]"] = {
            "SuppressMessages": "true",
            "ProgressBarShowPercentComplete": "true",
            "UseProgressBar": "true",
            "Title": title,
            "SubTitle": subtitle,
        }
    return cfg.dump()


def _in_rrect(x: float, y: float, x0: float, y0: float, x1: float, y1: float, r: float) -> bool:
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def _lock(x: float, y: float) -> bool:
    ring = y <= 12.0 and 4.5 ** 2 <= (x - 17.0) ** 2 + (y - 12.0) ** 2 <= 8.0 ** 2
    legs = 11.0 <= y <= 16.0 and (9.0 <= x <= 12.0 or 22.0 <= x <= 25.0)
    body = _in_rrect(x, y, 6, 15, 28, 31, 4)
    return ring or legs or body


def _capslock(x: float, y: float) -> bool:
    head = 2.0 <= y <= 12.0 and abs(x - 12.0) <= (y - 2.0) * 0.9
    stem = 12.0 <= y <= 19.0 and 8.0 <= x <= 16.0
    bar = 21.0 <= y <= 25.0 and 8.0 <= x <= 16.0
    return head or stem or bar


def _images(t) -> dict[str, bytes]:
    d = t.dark
    return {
        "entry.png": png.raster(320, 40, channels(d.surface),
                                lambda x, y: _in_rrect(x, y, 0, 0, 320, 40, t.radius.md)),
        "bullet.png": png.raster(10, 10, channels(d.text),
                                 lambda x, y: (x - 5.0) ** 2 + (y - 5.0) ** 2 <= 5.0 ** 2),
        "lock.png": png.raster(34, 34, channels(d.textSecondary), _lock),
        "capslock.png": png.raster(24, 28, channels(d.neutral), _capslock),
    }


def outputs(ctx) -> dict[str, str | bytes]:
    base = "platform/plymouth/ro-theme"
    out: dict[str, str | bytes] = {f"{base}/ro-theme.plymouth": _plymouth(ctx.tokens)}
    for name, data in _images(ctx.tokens).items():
        out[f"{base}/{name}"] = data
    return out
