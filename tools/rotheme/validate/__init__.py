"""Denetim çatısı: her kontrol bir kimlik ve bölümle kaydedilir, sonuçlar toplanıp raporlanır.

Kontrol yazmak:

    from . import check

    @check("TOK-01", "Token'lar", "renk token'ları WCAG kontrastını sağlar")
    def _(ctx):
        yield ok("…")           # ya da warn("…") / fail("…")

Bir kontrol beklenmedik bir hata fırlatırsa çökme yerine FAIL olarak raporlanır.
"""
from __future__ import annotations

import importlib
import json
import sys
import traceback
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterator

from .. import ROOT

OK, WARN, FAIL = "OK", "WARN", "FAIL"
SECTION_MODULES = ("source", "installed")   # alt modüller; kontrolleri import edildiğinde kaydolur


@dataclass
class Result:
    status: str
    message: str
    check: str = ""


def ok(msg):
    return Result(OK, msg)


def warn(msg):
    return Result(WARN, msg)


def fail(msg):
    return Result(FAIL, msg)


@dataclass
class Check:
    id: str
    section: str
    title: str
    func: Callable
    target: str       # "source" ya da "installed"


@dataclass
class Context:
    root: Path                      # kaynak ağacı ya da kurulu kök
    installed: bool = False
    cache: dict = field(default_factory=dict)


REGISTRY: list[Check] = []


def check(id: str, section: str, title: str, target: str = "source"):
    def deco(func):
        REGISTRY.append(Check(id, section, title, func, target))
        return func
    return deco


def run_checks(ctx: Context, section: str | None = None) -> list[Result]:
    for name in SECTION_MODULES:
        importlib.import_module(f"{__name__}.{name}")
    target = "installed" if ctx.installed else "source"
    results = []
    for c in REGISTRY:
        if c.target != target or (section and c.section != section):
            continue
        try:
            for r in c.func(ctx) or ():
                r.check = c.id
                results.append(r)
        except Exception:
            results.append(Result(FAIL, f"{c.title}: beklenmeyen hata\n{traceback.format_exc()}", c.id))
    return results


def report(results: list[Result], as_json: bool) -> int:
    errors = sum(r.status == FAIL for r in results)
    warnings = sum(r.status == WARN for r in results)
    if as_json:
        print(json.dumps({"errors": errors, "warnings": warnings,
                          "results": [r.__dict__ for r in results]}, ensure_ascii=False, indent=2))
    else:
        for r in results:
            stream = sys.stdout if r.status == OK else sys.stderr
            print(f"  [{r.status}] {r.check}: {r.message}", file=stream)
        print(f"Doğrulama özeti: {errors} hata, {warnings} uyarı")
    return 1 if errors else 0


def main(args) -> int:
    ctx = Context(root=args.installed or ROOT, installed=bool(args.installed))
    return report(run_checks(ctx, args.section), args.json)
