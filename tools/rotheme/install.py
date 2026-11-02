"""ro install / ro uninstall: manifestteki ağacı sistem ya da kullanıcı dizinine yerleştirir."""
from __future__ import annotations

import os
import shutil
import stat
import sys
from pathlib import Path

from . import ROOT, manifest, sysutil

# RPM %files listesinde sahiplenilmeyecek ortak üst dizinler.
RECORD_IGNORE = {
    "/usr", "/usr/share", "/usr/bin", "/usr/lib", "/usr/lib64", "/usr/libexec",
    "/etc", "/etc/xdg", "/var", "/var/lib",
    "/usr/share/color-schemes", "/usr/share/plasma", "/usr/share/plasma/desktoptheme",
    "/usr/share/plasma/look-and-feel", "/usr/share/plasma/layout-templates",
    "/usr/share/wallpapers", "/usr/share/aurorae", "/usr/share/aurorae/themes",
    "/usr/share/kwin", "/usr/share/kwin/effects", "/usr/share/icons",
    "/usr/share/grub", "/usr/share/grub/themes", "/usr/share/plymouth",
    "/usr/share/plymouth/themes", "/usr/share/firefox", "/usr/share/firefox/defaults",
    "/usr/lib64/firefox", "/usr/lib64/firefox/defaults",
    "/usr/lib/plasmalogin", "/usr/lib/plasmalogin/plasmalogin.conf.d",
}


def _targets(dest: str, destroot: Path) -> Path:
    return destroot / dest.format(**manifest.DIRS).lstrip("/")


def _local_target(dest: str, data_home: Path) -> Path | None:
    """Yalnız {datadir} altındaki hedefler kullanıcı dizinine taşınır."""
    expanded = dest.format(**manifest.DIRS)
    base = manifest.DIRS["datadir"] + "/"
    return data_home / expanded[len(base):] if expanded.startswith(base) else None


def _ensure_dir(path: Path, dirs: set[Path]) -> None:
    if path.is_dir():
        dirs.add(path)
        return
    missing = []
    p = path
    while not p.exists() and p != p.parent:
        missing.append(p)
        p = p.parent
    path.mkdir(parents=True, exist_ok=True)
    for created in missing:
        os.chmod(created, 0o755)
    dirs.update(missing)


def _copy_file(src: Path, dst: Path, mode: int, files: set[Path], dirs: set[Path],
               config: set[Path] | None = None) -> None:
    _ensure_dir(dst.parent, dirs)
    if dst.is_dir() and not dst.is_symlink():
        raise IsADirectoryError(f"hedefte dizin var: {dst}")
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    if src.is_symlink():
        os.symlink(os.readlink(src), dst)
    else:
        shutil.copyfile(src, dst)
        os.chmod(dst, mode)
    files.add(dst)
    if config is not None:
        config.add(dst)


def _copy_tree(src: Path, dst: Path, files: set[Path], dirs: set[Path],
               skip: frozenset[str] = frozenset()) -> None:
    _ensure_dir(dst, dirs)
    for current, dirnames, filenames in os.walk(src):
        rel = Path(current).relative_to(src)
        kept = []
        for name in sorted(dirnames):
            if name in skip:
                continue
            source = Path(current) / name
            if source.is_symlink():
                _copy_file(source, dst / rel / name, 0o644, files, dirs)
            else:
                _ensure_dir(dst / rel / name, dirs)
                kept.append(name)
        dirnames[:] = kept
        for name in sorted(filenames):
            if name in skip or name.endswith(".pyc"):
                continue
            source = Path(current) / name
            mode = 0o755 if os.access(source, os.X_OK) else 0o644
            _copy_file(source, dst / rel / name, mode, files, dirs)


def _synthesize_light_icons(base: Path, light: Path, files: set[Path], dirs: set[Path]) -> None:
    """ro-icons ağacına göreli bağlar ve güncellenmiş index.theme üretir."""
    _ensure_dir(light, dirs)
    for child in sorted(base.iterdir()):
        if child.name == "index.theme":
            continue
        link = light / child.name
        if link.exists() or link.is_symlink():
            link.unlink()
        os.symlink(f"../{manifest.LIGHT_ICONS['base']}/{child.name}", link)
        files.add(link)

    lines = (base / "index.theme").read_text(encoding="utf-8").splitlines()
    wanted = {"Name": manifest.LIGHT_ICONS["name"], "Inherits": manifest.LIGHT_ICONS["inherits"]}
    seen = set()
    out = []
    for line in lines:
        key = line.split("=", 1)[0]
        if key in wanted:
            out.append(f"{key}={wanted[key]}")
            seen.add(key)
        else:
            out.append(line)
    if seen != set(wanted):
        extra = [f"{k}={v}" for k, v in wanted.items() if k not in seen]
        if "[Icon Theme]" in out:
            out[out.index("[Icon Theme]") + 1:out.index("[Icon Theme]") + 1] = extra
        else:
            out[0:0] = extra
    index = light / "index.theme"
    index.write_text("\n".join(out) + "\n", encoding="utf-8")
    os.chmod(index, 0o644)
    files.add(index)


def _hardlink_trees(roots: list[Path]) -> int:
    """Baytları ve izinleri özdeş .jpg/.png dosyalarını ilk kopyaya bağlar."""
    seen: dict[tuple[str, int], Path] = {}
    linked = 0
    for base in roots:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.is_symlink() or path.suffix.lower() not in (".jpg", ".jpeg", ".png"):
                continue
            key = (sysutil.sha256(path), stat.S_IMODE(path.stat().st_mode))
            if key not in seen:
                seen[key] = path
                continue
            try:
                path.unlink()
                os.link(seen[key], path)
                linked += 1
            except OSError:
                pass
    return linked


def _write_record(path: Path, files: set[Path], dirs: set[Path], config: set[Path],
                  destroot: Path, local: bool) -> None:
    rows: list[tuple[str, str]] = []
    for directory in dirs:
        if directory == destroot:
            continue
        rel = "/" + directory.relative_to(destroot).as_posix()
        if rel in RECORD_IGNORE or (not local and rel == manifest.STAMP_DIR):
            continue   # damga dizini aşağıda bir kez eklenir
        rows.append((rel, f"%dir {rel}" if not local else rel))
    for item in files:
        rel = "/" + item.relative_to(destroot).as_posix()
        if item in config:
            rows.append((rel, f"%config(noreplace) {rel}" if not local else rel))
        else:
            rows.append((rel, rel))
    if not local:
        stamp = manifest.STAMP_DIR
        rows.append((stamp, f"%dir {stamp}"))
        rows.append((stamp + "/plymouth.sha256", f"%ghost {stamp}/plymouth.sha256"))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(line for _, line in sorted(rows)) + "\n", encoding="utf-8")


def _backup_local(data_home: Path) -> Path | None:
    ro_dir = data_home / manifest.BACKUP_DIR
    if not ro_dir.is_dir():
        return None
    stamp = sysutil.timestamp()
    backup = ro_dir / f"yedek-{stamp}"
    counter = 1
    while backup.exists():
        backup = ro_dir / f"yedek-{stamp}-{counter}"
        counter += 1
    backup.mkdir()
    for child in sorted(ro_dir.iterdir()):
        if child == backup or child.name.startswith("yedek-"):
            continue
        shutil.move(str(child), str(backup / child.name))
    print(f"Önceki Ro kurulumu yedeklendi: {backup}")
    return backup


def install(root: Path | None = None, destroot: Path | None = None, data_home: Path | None = None,
            local: bool = False, files_only: bool = False, record_files: Path | None = None) -> int:
    root = Path(root) if root is not None else ROOT
    entries = [e for e in manifest.INSTALL if e.local] if local else list(manifest.INSTALL)
    destroot = Path(destroot).expanduser().resolve() if destroot else None
    data_home = Path(data_home).expanduser().resolve() if data_home else sysutil.data_home()
    base = destroot if destroot is not None else data_home

    missing = [e.src for e in entries if not (root / e.src).exists()]
    icon_base = root / "platform/icons/ro-icons"
    if not (icon_base / "index.theme").is_file():
        missing.append("platform/icons/ro-icons/index.theme")
    if missing:
        for src in missing:
            print(f"eksik kaynak: {src}", file=sys.stderr)
        print(f"{len(missing)} kaynak dosya bulunamadı; kurulum yapılmadı.", file=sys.stderr)
        return 1

    if local:
        _backup_local(data_home)

    files: set[Path] = set()
    dirs: set[Path] = set()
    config: set[Path] = set()
    try:
        for entry in entries:
            dest = _local_target(entry.dest, data_home) if local else _targets(entry.dest, destroot)
            if dest is None:
                continue
            source = root / entry.src
            if source.is_dir():
                if dest.is_dir() and not dest.is_symlink():
                    shutil.rmtree(dest)
                skip = frozenset({"__pycache__", "tests"}) if entry.src == "tools/rotheme" else frozenset()
                _copy_tree(source, dest, files, dirs, skip)
            else:
                _copy_file(source, dest, entry.mode, files, dirs,
                           config if entry.config else None)
        icons = (_local_target(manifest.LIGHT_ICONS["dest"], data_home) if local
                 else _targets(manifest.LIGHT_ICONS["dest"], destroot))
        _synthesize_light_icons(_local_target("{datadir}/icons/ro-icons", data_home) if local
                                else _targets("{datadir}/icons/ro-icons", destroot), icons, files, dirs)
        if not local:
            _ensure_dir(destroot / manifest.STAMP_DIR.lstrip("/"), dirs)
        linked = _hardlink_trees([_local_target(t, data_home) if local else _targets(t, destroot)
                                  for t in manifest.HARDLINK_TREES])
        if record_files:
            _write_record(Path(record_files), files, dirs, config, base, local)
    except OSError as e:
        print(f"kurulum hatası: {e}", file=sys.stderr)
        return 1

    print(f"{len(files)} dosya kuruldu: {base}")
    if linked:
        print(f"{linked} yinelenen görsel hardlink ile bağlandı.")
    return 0


def uninstall(data_home: Path | None = None) -> int:
    data_home = Path(data_home).expanduser().resolve() if data_home else sysutil.data_home()
    removed: list[Path] = []
    for entry in manifest.INSTALL:
        if not entry.local:
            continue
        path = _local_target(entry.dest, data_home)
        if path is None or not (path.exists() or path.is_symlink()):
            continue
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
        removed.append(path)
    light = _local_target(manifest.LIGHT_ICONS["dest"], data_home)
    if light and (light.exists() or light.is_symlink()):
        shutil.rmtree(light) if light.is_dir() and not light.is_symlink() else light.unlink()
        removed.append(light)

    parents = {p.parent for p in removed}
    for parent in sorted(parents, key=lambda p: len(p.parts), reverse=True):
        p = parent
        while p != data_home and p.is_dir() and not any(p.iterdir()):
            p.rmdir()
            p = p.parent
    print(f"Yerel Ro kurulumu kaldırıldı: {len(removed)} bileşen.")
    return 0


def main(args) -> int:
    if getattr(args, "uninstall", False):
        return uninstall()
    if getattr(args, "local", False):
        return install(ROOT, data_home=sysutil.data_home(), local=True,
                       files_only=getattr(args, "files_only", False),
                       record_files=getattr(args, "record_files", None))
    if getattr(args, "destdir", None):
        return install(ROOT, destroot=args.destdir, record_files=getattr(args, "record_files", None))
    print("ro install: --destdir ya da --local gerekli", file=sys.stderr)
    return 2
