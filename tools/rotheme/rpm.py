"""ro rpm-build / rpm-check: kaynak tarball, SRPM, RPM üretimi ve paket denetimi."""
from __future__ import annotations

import shutil
import stat
import subprocess
import sys
from pathlib import Path

from . import ROOT, version
from . import manifest

SPEC = Path("packaging/ro-theme.spec")
DIST = ".fc44"
FONT_REQUIRES = ("google-noto-sans-fonts", "google-noto-sans-mono-fonts", "rsms-inter-fonts")
PAPIRUS_REQUIRES = ("papirus-icon-theme", "papirus-icon-theme-dark", "papirus-icon-theme-light")
META_QUERY = "%{NAME}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n"
FILE_QUERY = "[%{FILENAMES}\t%{FILEMODES:octal}\n]"


def _run(cmd, cwd=None, capture=False, check=True):
    try:
        return subprocess.run(cmd, cwd=cwd, text=True, check=check,
                              capture_output=capture)
    except FileNotFoundError:
        raise SystemExit(f"ro: gerekli araç bulunamadı: {cmd[0]}")


def _output(cmd, cwd=None) -> str:
    return _run(cmd, cwd=cwd, capture=True).stdout


def source_tarball(root: Path, topdir: Path) -> Path:
    """git archive + gzip -n ile tekrarlanabilir kaynak tarball üretir."""
    name = manifest.PACKAGE
    ver = version(root)
    sources = topdir / "SOURCES"
    sources.mkdir(parents=True, exist_ok=True)
    target = sources / f"{name}-{ver}.tar.gz"

    archive = subprocess.Popen(
        ["git", "archive", "--format=tar", f"--prefix={name}-{ver}/", "HEAD"],
        cwd=root, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    with target.open("wb") as out:
        comp = subprocess.Popen(["gzip", "-n"], stdin=archive.stdout, stdout=out)
        archive.stdout.close()
        status = comp.wait()
    archive_status = archive.wait()
    if archive_status or status:
        target.unlink(missing_ok=True)
        raise SystemExit("ro rpm-build: kaynak tarball üretilemedi (git archive/gzip)")
    return target


def build(args, root: Path = ROOT) -> int:
    topdir = Path(args.topdir).resolve()
    for sub in ("SOURCES", "SPECS", "BUILD", "BUILDROOT", "RPMS", "SRPMS"):
        (topdir / sub).mkdir(parents=True, exist_ok=True)

    if args.container:
        return _build_container(topdir, root)

    tarball = source_tarball(root, topdir)
    print(f"kaynak tarball: {tarball}", flush=True)
    defines = ["--define", f"_topdir {topdir}", "--define", f"dist {DIST}"]
    # SRPM önce üretilir: %install henüz hazır olmasa da kaynak paket elde kalır.
    if _run(["rpmbuild", "-bs", str(root / SPEC), *defines], cwd=root, check=False).returncode:
        print("ro rpm-build: SRPM üretilemedi", file=sys.stderr)
        return 1
    result = _run(["rpmbuild", "-bb", str(root / SPEC), *defines], cwd=root, check=False)
    if result.returncode:
        print("ro rpm-build: rpmbuild başarısız", file=sys.stderr)
        return 1

    for pattern in ("RPMS/noarch/*.rpm", "SRPMS/*.src.rpm"):
        for path in sorted(topdir.glob(pattern)):
            print(f"üretildi: {path}")
    return 0


def _build_container(topdir: Path, root: Path) -> int:
    if not shutil.which("podman"):
        print("ro rpm-build: podman bulunamadı", file=sys.stderr)
        return 2
    exists = _run(["podman", "image", "exists", "fedora:44"], check=False)
    if exists.returncode:
        print("ro rpm-build: fedora:44 imajı yerelde yok; indirme yapılmadı "
              "(önce: podman pull fedora:44)", file=sys.stderr)
        return 2
    command = (f"dnf install -y --setopt=install_weak_deps=False python3 rpm-build git-core && "
               f"git config --global --add safe.directory {root} && "
               f"cd {root} && ./ro rpm-build --topdir {topdir}")
    result = _run(["podman", "run", "--rm", "-v", f"{root}:{root}:Z", "-w", str(root),
                   "fedora:44", "sh", "-c", command], check=False)
    return 0 if result.returncode == 0 else 1


def _dest(entry) -> str:
    return entry.dest.format(**manifest.DIRS)


def _walk(src: Path, dest: str, files: set, dirs: set) -> None:
    if not src.is_dir():
        return
    dirs.add(dest)
    for path in src.rglob("*"):
        if "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        target = f"{dest}/{path.relative_to(src).as_posix()}"
        (dirs if path.is_dir() else files).add(target)


def expected_paths(root: Path = ROOT) -> tuple[set[str], set[str]]:
    """manifest.INSTALL'dan beklenen mutlak dosya ve dizin yolları."""
    files: set[str] = set()
    dirs: set[str] = set()
    for entry in manifest.INSTALL:
        dest = _dest(entry)
        src = root / entry.src
        if src.is_dir():
            _walk(src, dest, files, dirs)
        else:
            files.add(dest)

    # Kurulumda ro-icons ağacından sentezlenen açık simge teması.
    light = manifest.LIGHT_ICONS["dest"].format(**manifest.DIRS)
    _walk(root / "platform/icons" / manifest.LIGHT_ICONS["base"], light, files, dirs)

    for name in manifest.LICENSE_FILES:
        files.add(f"/usr/share/licenses/{manifest.PACKAGE}/{Path(name).name}")
    for name in manifest.DOC_FILES:
        files.add(f"/usr/share/doc/{manifest.PACKAGE}/{name}")
    dirs.add(manifest.STAMP_DIR)
    return files, dirs


def _ancestors(path: str) -> set[str]:
    parts = Path(path).parents
    return {str(p) for p in parts if str(p) != "."}


def _parse_files(text: str) -> tuple[set[str], set[str]]:
    files, dirs = set(), set()
    for line in text.splitlines():
        if not line.strip():
            continue
        name, _, mode = line.rpartition("\t")
        try:
            is_dir = stat.S_ISDIR(int(mode, 8))
        except ValueError:
            is_dir = False
        (dirs if is_dir else files).add(name)
    return files, dirs


def check(args, root: Path = ROOT) -> int:
    topdir = Path(getattr(args, "topdir", None) or ROOT / "build" / "rpmbuild")
    rpm = Path(args.rpm) if args.rpm else _find_rpm(topdir)
    if not rpm or not rpm.is_file():
        print("ro rpm-check: RPM bulunamadı (önce ./ro rpm-build)", file=sys.stderr)
        return 1

    failures: list[str] = []
    meta = _output(["rpm", "-qp", "--qf", META_QUERY, str(rpm)]).strip().split("\t")
    if len(meta) != 4:
        print(f"ro rpm-check: başlık okunamadı: {rpm}", file=sys.stderr)
        return 1
    name, ver, release, arch = meta
    print(f"paket: {name} {ver}-{release} {arch}")

    if name != manifest.PACKAGE:
        failures.append(f"ad {manifest.PACKAGE} olmalı: {name}")
    if ver != version(root):
        failures.append(f"sürüm {version(root)} olmalı: {ver}")
    if arch != "noarch":
        failures.append(f"mimari noarch olmalı: {arch}")
    if not release.endswith(DIST):
        failures.append(f"release {DIST} ile bitmeli: {release}")

    requires = {line.split()[0] for line in _output(
        ["rpm", "-qp", "--requires", str(rpm)]).splitlines() if line.strip()}
    for pkg in FONT_REQUIRES + PAPIRUS_REQUIRES:
        if pkg not in requires:
            failures.append(f"Requires eksik: {pkg}")

    actual_files, actual_dirs = _parse_files(
        _output(["rpm", "-qp", "--qf", FILE_QUERY, str(rpm)]))
    want_files, want_dirs = expected_paths(root)
    missing = sorted(want_files - actual_files)
    unexpected = sorted(actual_files - want_files)
    allowed_dirs = set(want_dirs)
    for path in want_files | want_dirs:
        allowed_dirs |= _ancestors(path)
    unexpected_dirs = sorted(actual_dirs - allowed_dirs)

    for path in missing:
        print(f"  [FAIL] eksik dosya: {path}", file=sys.stderr)
    for path in unexpected:
        print(f"  [FAIL] beklenmeyen dosya: {path}", file=sys.stderr)
    for path in unexpected_dirs:
        print(f"  [FAIL] beklenmeyen dizin: {path}", file=sys.stderr)
    failures += [f"eksik: {p}" for p in missing]
    failures += [f"beklenmeyen: {p}" for p in unexpected]
    failures += [f"beklenmeyen dizin: {p}" for p in unexpected_dirs]

    if failures:
        print(f"ro rpm-check: {len(failures)} sorun", file=sys.stderr)
        return 1
    print("ro rpm-check: dosya listesi, bağımlılıklar ve başlık doğru")
    return 0


def _find_rpm(topdir: Path) -> Path | None:
    found = sorted(Path(topdir).glob("RPMS/noarch/*.noarch.rpm"))
    return found[0] if found else None


def main(args) -> int:
    return check(args) if getattr(args, "rpm_command", "build") == "check" else build(args)
