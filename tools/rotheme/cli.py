"""./ro komut satırı. Her alt komut kendi modülünü yalnız çağrıldığında yükler."""
from __future__ import annotations

import argparse
import importlib
from pathlib import Path

from . import ROOT


def _generate(a):
    from . import generate
    return generate.run(ROOT, outdir=a.outdir, check=a.check, list_only=a.list)


def _module(name):
    """Alt komutu `rotheme.<name>.main(args)` fonksiyonuna yönlendirir."""
    def run(a):
        mod = importlib.import_module(f"rotheme.{name}")
        return mod.main(a)
    return run


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="ro", description="Ro-Theme geliştirme, doğrulama ve paketleme aracı")
    sub = p.add_subparsers(dest="command", required=True, metavar="<komut>")

    g = sub.add_parser("generate", help="token'lardan türetilen dosyaları üret")
    g.add_argument("--check", action="store_true", help="yazma; depodaki dosyalar güncel değilse 1 dön")
    g.add_argument("--list", action="store_true", help="üretilecek yolları listele")
    g.add_argument("--outdir", type=Path, help="çıktı kökü (varsayılan: depo kökü)")
    g.set_defaults(func=_generate)

    v = sub.add_parser("validate", help="kaynak ağacını ya da kurulu ağacı denetle")
    v.add_argument("--json", action="store_true", help="sonuçları JSON olarak yaz")
    v.add_argument("--section", help="yalnız bu bölümü çalıştır (ör. tokens, plasma, packaging)")
    v.add_argument("--check", metavar="KİMLİK", help="yalnız bu denetim kimliğini çalıştır (ör. VAL-TOK-03)")
    v.add_argument("--root", type=Path, metavar="DİZİN", help="denetlenecek kaynak kökü")
    v.add_argument("--installed", type=Path, metavar="KÖK", help="kurulu ağacı denetle (ör. RPM buildroot)")
    v.add_argument("--freshness", action="store_true", help="üretilmiş dosyaların belirteçlerle eşleştiğini doğrula")
    v.set_defaults(func=_module("validate"))

    i = sub.add_parser("install", help="manifestteki dosyaları kur")
    where = i.add_mutually_exclusive_group(required=True)
    where.add_argument("--destdir", type=Path, help="sistem düzeninde bu köke kur (RPM buildroot)")
    where.add_argument("--local", action="store_true", help="kullanıcıya kur (~/.local/share)")
    i.add_argument("--record-files", type=Path, help="RPM %%files listesini bu dosyaya yaz")
    i.add_argument("--files-only", action="store_true", help="yalnız dosyalar; oturum ayarlarına dokunma")
    i.set_defaults(func=_module("install"))

    u = sub.add_parser("uninstall", help="kullanıcı kurulumunu kaldır (--local)")
    u.set_defaults(func=_module("install"), uninstall=True)

    ap = sub.add_parser("apply", help="Ro Açık/Koyu temayı canlı oturuma uygula (önce yedek alır)")
    ap.add_argument("theme", choices=("light", "dark"), nargs="?", default="dark")
    ap.add_argument("--live-plasmashell", action="store_true", help="plasmashell'i de canlı yenile")
    ap.set_defaults(func=_module("apply"))

    d = sub.add_parser("diagnose", help="salt okunur tanı raporu")
    mode = d.add_mutually_exclusive_group()
    mode.add_argument("--local", dest="system", action="store_false", help="kullanıcı kurulumu (varsayılan)")
    mode.add_argument("--system", dest="system", action="store_true", help="RPM ile sistem kurulumu")
    d.add_argument("--json", action="store_true")
    d.set_defaults(func=_module("diagnose"), system=False)

    r = sub.add_parser("check-runtime", help="panel ve tepsi için gereken Plasma applet'leri kurulu mu")
    r.add_argument("mode", choices=("layout", "popups"), nargs="?", default="layout")
    r.set_defaults(func=_module("runtime"))

    rs = sub.add_parser("reset-defaults", help="kullanıcının Ro ayarlarını sistem varsayılanına döndür")
    rs.add_argument("--dry-run", action="store_true")
    rs.set_defaults(func=_module("reset"))

    sm = sub.add_parser("smoke", help="canlı oturumda uçtan uca deneme (panel yedeği alır)")
    sm.add_argument("--yes", action="store_true", help="onay sorma")
    sm.set_defaults(func=_module("smoke"))

    sp = sub.add_parser("system-preview", help="root: giriş ekranı ve Plymouth önizlemesi")
    sp.add_argument("--remove", action="store_true", help="önizlemeyi geri al")
    sp.set_defaults(func=_module("preview"))

    rb = sub.add_parser("rpm-build", help="kaynak tarball, SRPM ve noarch RPM üret")
    rb.add_argument("--topdir", type=Path, default=ROOT / "build" / "rpmbuild")
    rb.add_argument("--container", action="store_true", help="fedora:44 podman konteynerinde derle")
    rb.set_defaults(func=_module("rpm"), rpm_command="build")

    rc = sub.add_parser("rpm-check", help="RPM'i kurmadan denetle (dosya listesi, bağımlılıklar)")
    rc.add_argument("rpm", type=Path, nargs="?")
    rc.set_defaults(func=_module("rpm"), rpm_command="check")

    rm = sub.add_parser("release-manifest", help="component-artifact-manifest-v1.json yaz (CI)")
    rm.add_argument("bundle", type=Path)
    rm.set_defaults(func=_module("release_manifest"))
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return int(args.func(args) or 0)
    except NotImplementedError as e:
        print(f"ro {args.command}: henüz uygulanmadı ({e})")
        return 3
