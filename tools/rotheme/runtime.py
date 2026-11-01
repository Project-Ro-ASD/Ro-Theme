"""ro check-runtime: Plasma applet ve eklentilerinin çalışma zamanı hazırlığını denetler."""
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from . import manifest, sysutil

FAIL_MESSAGES = {
    "layout": ("Unsafe to apply the full Ro panel layout on the current system. "
               "This is a system Plasma package/runtime problem, not a theme color problem."),
    "popups": "Plasma popup runtime is incomplete on the current system.",
}


@dataclass
class Result:
    applet: str
    status: str          # OK / FAIL / WARN
    required: bool
    source: str = ""


def _data_dirs(env) -> list[Path]:
    dirs = [sysutil.data_home(env), sysutil.home(env) / ".local/share"]
    dirs += sysutil.data_dirs(env)
    unique = []
    for d in dirs:
        if d not in unique:
            unique.append(d)
    return unique


def _plugin_dirs(env) -> list[Path]:
    dirs = []
    for raw in (env or os.environ).get("QT_PLUGIN_PATH", "").split(":"):
        if raw:
            dirs += [Path(raw) / "plasma/applets", Path(raw)]
    home = sysutil.home(env)
    dirs += [
        home / ".local/lib64/qt6/plugins/plasma/applets",
        Path("/usr/lib64/qt6/plugins/plasma/applets"),
        Path("/usr/lib/qt6/plugins/plasma/applets"),
        Path("/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/applets"),
    ]
    return dirs


def _package(applet: str, env) -> tuple[bool, str, list[str]]:
    """Önce kpackagetool6, yoksa dosya sistemi. (bulundu, kaynak, uyarılar)."""
    tool = sysutil.which("kpackagetool6", env)
    if tool:
        proc = sysutil.run([tool, "--type", "Plasma/Applet", "--show", applet], env)
        if proc is not None and proc.returncode == 0:
            return True, "kpackagetool6", []

    warnings = []
    for base in _data_dirs(env):
        package = base / "plasma/plasmoids" / applet
        if not package.is_dir():
            continue
        meta = package / "metadata.json"
        if meta.is_file():
            try:
                json.loads(meta.read_text(encoding="utf-8"))
            except (OSError, ValueError) as e:
                warnings.append(f"{meta}: metadata okunamadı ({e})")
                continue
        elif not (package / "metadata.desktop").is_file():
            continue
        if (package / "contents/ui/main.qml").is_file():
            return True, str(package), warnings
        warnings.append(f"{package}: contents/ui/main.qml eksik")

    for base in _plugin_dirs(env):
        if (base / applet).exists() or any(base.glob(f"{applet}*.so")):
            return True, str(base / applet), warnings
    return False, "", warnings


def check(mode: str, env=None) -> list[Result]:
    spec = manifest.RUNTIME_APPLETS[mode]
    results = []
    for applet in spec["required"] + spec["optional"]:
        required = applet in spec["required"]
        found, source, warnings = _package(applet, env)
        for message in warnings:
            results.append(Result(applet, "WARN", required, message))
        results.append(Result(applet, "OK" if found else ("FAIL" if required else "WARN"),
                              required, source or "bulunamadı"))
    return results


def main(args) -> int:
    mode = getattr(args, "mode", "layout")
    results = check(mode)
    errors = sum(r.status == "FAIL" for r in results)
    warnings = sum(r.status == "WARN" for r in results)
    if getattr(args, "json", False):
        print(json.dumps({"mode": mode, "errors": errors, "warnings": warnings,
                          "results": [r.__dict__ for r in results]}, ensure_ascii=False, indent=2))
    else:
        for r in results:
            stream = sys.stderr if r.status != "OK" else sys.stdout
            print(f"  [{r.status}] {r.applet}: {r.source}", file=stream)
        print(f"Plasma runtime summary: {errors} error(s), {warnings} warning(s)")
    if errors:
        print(FAIL_MESSAGES[mode], file=sys.stderr)
        return 1
    return 0
