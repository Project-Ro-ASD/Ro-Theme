"""ro diagnose: kurulu Ro temasının salt okunur tanısı."""
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from . import manifest, sysutil
from .kconfig import KConfig

TOOLS = ("rpm", "coredumpctl", "lookandfeeltool", "plasma-apply-colorscheme", "plasma-apply-wallpaperimage",
         "plymouth-set-default-theme")
# Bu gruplardan birinin bulunması yeterli
TOOL_GROUPS = (("kreadconfig6", "kreadconfig5"), ("qdbus6", "qdbus", "gdbus"))
CRASH_NAMES = ("plasmashell", "kwin", "kwin_wayland", "kioworker")
NO_READER = "KDE yapılandırma okuyucusu bulunamadı, ayar denetimleri atlanıyor"


@dataclass
class Result:
    status: str
    message: str
    check: str = ""


def _sysroot(env) -> Path:
    return Path((env or os.environ).get("RO_THEME_SYSROOT") or "/").resolve()


def _target(template: str, system: bool, env) -> Path | None:
    expanded = template.format(**manifest.DIRS)
    if system:
        return _sysroot(env) / expanded.lstrip("/")
    base = manifest.DIRS["datadir"] + "/"
    return sysutil.data_home(env) / expanded[len(base):] if expanded.startswith(base) else None


def _search_dirs(env, system: bool) -> list[Path]:
    if system:
        root = _sysroot(env)
        dirs = [root / "usr/local/share", root / "usr/share"]
        if root == Path("/"):
            dirs += sysutil.data_dirs(env)
    else:
        dirs = [sysutil.data_home(env), sysutil.home(env) / ".local/share"]
        dirs += sysutil.data_dirs(env)
    unique = []
    for d in dirs:
        if d not in unique:
            unique.append(d)
    return unique


def _file_results(system: bool, env) -> list[Result]:
    out = []
    templates = list(manifest.REQUIRED_FILES)
    if system:
        templates += list(manifest.SYSTEM_FILES)
    for template in templates:
        path = _target(template, system, env)
        if path is None:
            continue
        if path.is_symlink() and not path.exists():
            out.append(Result("FAIL", f"bozuk sembolik bağ: {path}", "DOSYA"))
        elif not path.exists():
            out.append(Result("FAIL", f"eksik: {path}", "DOSYA"))
        elif path.is_dir():
            out.append(Result("FAIL", f"dosya beklenirken dizin: {path}", "DOSYA"))
        elif not os.access(path, os.R_OK):
            out.append(Result("FAIL", f"okunamıyor: {path}", "DOSYA"))
        else:
            out.append(Result("OK", str(path), "DOSYA"))
    for template in manifest.ABSENT_FILES:
        path = _target(template, system, env)
        if path is None:
            continue
        if path.exists() or path.is_symlink():
            out.append(Result("FAIL", f"güvenlik gereği bulunmamalı: {path}", "YOKLUK"))
        else:
            out.append(Result("OK", f"yok: {path}", "YOKLUK"))
    return out


def _read_config(reader: str, file: str, group: str, key: str, env) -> str:
    cmd = [reader, "--file", file, *sysutil.group_flags(group), "--key", key]
    proc = sysutil.run(cmd, env)
    return proc.stdout.strip() if proc is not None and proc.returncode == 0 else ""


def _defaults(package: str, env, system: bool) -> Path | None:
    for base in _search_dirs(env, system):
        path = base / "plasma/look-and-feel" / package / "contents/defaults"
        if path.is_file():
            return path
    return None


def _kde_results(system: bool, env) -> list[Result]:
    reader = "kreadconfig6" if sysutil.which("kreadconfig6", env) else (
        "kreadconfig5" if sysutil.which("kreadconfig5", env) else "")
    if not reader:
        return [Result("WARN", NO_READER, "KDE")]
    out = []
    package = _read_config(reader, "kdeglobals", "[KDE]", "LookAndFeelPackage", env)
    if not package:
        return [Result("WARN", "etkin LookAndFeelPackage okunamadı; ayar denetimleri atlandı", "KDE")]
    defaults = _defaults(package, env, system)
    if defaults is None:
        return [Result("WARN", f"{package}: contents/defaults bulunamadı; ayar denetimleri atlandı", "KDE")]
    try:
        expected = KConfig.parse(defaults.read_text(encoding="utf-8"))
    except OSError as e:
        return [Result("WARN", f"{defaults}: okunamadı ({e})", "KDE")]

    for file, group, key in manifest.KDE_KEYS:
        want = expected.get(f"[{file}]{group}", key)
        actual = _read_config(reader, file, group, key, env)
        label = f"{file} {group} {key}"
        if want is None:
            # Tema bu anahtarı belirlemiyor; yalnız eski sürümden kalan [KDE] ColorScheme sorun
            if file == "kdeglobals" and group == "[KDE]" and key == "ColorScheme" and actual:
                out.append(Result("WARN", f"{label}={actual}: eski sürümden kalma anahtar; "
                                         "/usr/libexec/ro-theme/apply-dark-defaults ile temizlenebilir", "KDE"))
            continue
        elif actual != want:
            out.append(Result("WARN", f"{label}: beklenen {want}, okunan {actual or 'boş'}", "KDE"))
        else:
            out.append(Result("OK", f"{label}={actual}", "KDE"))
        if key == "Blur" and actual != "false" and (want is None or actual == want):
            out.append(Result("WARN", f"{label}: false olmalı, okunan {actual or 'boş'}", "KDE"))
    return out


def _runtime_results(env) -> list[Result]:
    from . import runtime
    out = []
    for mode in ("layout", "popups"):
        try:
            results = runtime.check(mode, env)
        except Exception as e:  # çalışma zamanı denetimi tanıyı çökertmemeli
            out.append(Result("WARN", f"check-runtime {mode}: çalıştırılamadı ({e})", "RUNTIME"))
            continue
        for r in results:
            if r.status != "OK":
                out.append(Result("WARN", f"check-runtime {mode}: {r.applet}: {r.source}", "RUNTIME"))
    if not out:
        out.append(Result("OK", "layout ve popups çalışma zamanı hazır", "RUNTIME"))
    return out


def _rpm_results(env) -> list[Result]:
    if not sysutil.which("rpm", env):
        return [Result("WARN", "rpm bulunamadı; paket bütünlüğü denetlenemedi", "RPM")]
    out = []
    query = sysutil.run(["rpm", "-q", "ro-theme"], env)
    if query is None or query.returncode != 0:
        return [Result("WARN", "ro-theme RPM paketi kurulu değil", "RPM")]
    out.append(Result("OK", query.stdout.strip(), "RPM"))
    verify = sysutil.run(["rpm", "-V", "ro-theme"], env)
    if verify is None:
        out.append(Result("WARN", "rpm -V çalıştırılamadı", "RPM"))
    elif _verify_detail(verify):
        detail = _verify_detail(verify)
        out.append(Result("WARN", "ro-theme dosyaları değişmiş ya da eksik:\n" + detail, "RPM"))
    else:
        out.append(Result("OK", "rpm -V: değişiklik yok", "RPM"))
    return out


def _verify_detail(verify) -> str:
    """rpm -V çıktısı; %ghost dosyalar (ör. Plymouth damgası) beklenen şekilde değişir, sayılmaz."""
    lines = [l for l in (verify.stdout + verify.stderr).splitlines()
             if l.strip() and not l.split()[1:2] == ["g"]]
    return "\n".join(lines)


def _crash_results(env) -> list[Result]:
    if not sysutil.which("coredumpctl", env):
        return [Result("WARN", "coredumpctl bulunamadı; çökme günlüğü denetlenemedi", "ÇÖKME")]
    proc = sysutil.run(["coredumpctl", "list", "--since", "30 minutes ago"], env)
    if proc is not None and proc.returncode != 0 and "No coredumps found" in (proc.stdout + proc.stderr):
        return [Result("OK", "son 30 dakikada çökme yok", "ÇÖKME")]
    if proc is None or proc.returncode != 0:
        return [Result("WARN", "coredumpctl çalıştırılamadı; çökme günlüğü denetlenemedi", "ÇÖKME")]
    lines = [line for line in proc.stdout.splitlines() if any(n in line for n in CRASH_NAMES)]
    if lines:
        return [Result("WARN", "son 30 dakikada çökme:\n" + "\n".join(lines[-20:]), "ÇÖKME")]
    return [Result("OK", "son 30 dakikada plasmashell/kwin çökmesi yok", "ÇÖKME")]


def _tool_results(env) -> list[Result]:
    missing = [name for name in TOOLS if not sysutil.which(name, env)]
    missing += ["/".join(g) for g in TOOL_GROUPS if not any(sysutil.which(n, env) for n in g)]
    if missing:
        return [Result("WARN", "eksik harici komutlar: " + ", ".join(missing), "ARAÇ")]
    return [Result("OK", "harici komutlar tam", "ARAÇ")]


def run(system: bool, env=None) -> list[Result]:
    env = dict(env or os.environ)
    results = _file_results(system, env)
    results += _runtime_results(env)
    results += _kde_results(system, env)
    results += _tool_results(env)
    if system:
        results += _rpm_results(env)
    results += _crash_results(env)
    return results


def main(args) -> int:
    system = bool(getattr(args, "system", False))
    env = dict(os.environ)
    if getattr(args, "root", None):
        env["RO_THEME_SYSROOT"] = str(args.root)
    results = run(system, env)
    errors = sum(r.status == "FAIL" for r in results)
    warnings = sum(r.status == "WARN" for r in results)
    if getattr(args, "json", False):
        print(json.dumps({"mode": "system" if system else "local", "errors": errors,
                          "warnings": warnings, "results": [r.__dict__ for r in results]},
                         ensure_ascii=False, indent=2))
    else:
        for r in results:
            stream = sys.stdout if r.status == "OK" else sys.stderr
            print(f"  [{r.status}] {r.check}: {r.message}", file=stream)
        print(f"Diagnosis summary: {errors} error(s), {warnings} warning(s)")
    return 1 if errors else 0
