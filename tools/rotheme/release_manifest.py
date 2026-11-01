"""ro release-manifest: dağıtım paketi için SHA256SUMS ve V2 bileşen manifestosu."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

from . import manifest

MANIFEST_NAME = "component-artifact-manifest-v1.json"
SUMS_NAME = "SHA256SUMS"
RPM_QUERY = ("%{NAME}\t%{EPOCHNUM}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\t"
             "%{SOURCERPM}\t%|SOURCEPACKAGE?{true}:{false}|")


def _rpm_header(path: Path) -> list[str]:
    try:
        out = subprocess.run(["rpm", "-qp", "--qf", RPM_QUERY, str(path)],
                             text=True, capture_output=True, check=True).stdout
    except FileNotFoundError:
        raise SystemExit("ro release-manifest: rpm bulunamadı")
    except subprocess.CalledProcessError as e:
        raise SystemExit(f"ro release-manifest: {path.name} başlığı okunamadı: {e.stderr.strip()}")
    values = out.split("\t")
    if len(values) != 7:
        raise SystemExit(f"ro release-manifest: {path.name} için beklenmeyen RPM başlığı")
    return values


def artifacts(bundle: Path) -> list[dict]:
    result = []
    for path in sorted(bundle.glob("*.rpm"), key=lambda p: p.name):
        name, epoch, version, release, arch, source_rpm, is_source = _rpm_header(path)
        if is_source == "true":
            arch, source_rpm = "src", None
        result.append({
            "filename": path.name,
            "name": name,
            "epoch": int(epoch or 0),
            "version": version,
            "release": release,
            "architecture": arch,
            "source_rpm": source_rpm,
            "producer_artifact_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    return result


def _env(name: str) -> str:
    try:
        return os.environ[name]
    except KeyError:
        raise SystemExit(f"ro release-manifest: {name} ortam değişkeni yok")


def build(bundle: Path) -> dict:
    items = artifacts(bundle)
    if not items:
        raise SystemExit(f"ro release-manifest: {bundle} içinde RPM yok")

    sums = "".join(f"{item['producer_artifact_sha256']}  {item['filename']}\n" for item in items)
    (bundle / SUMS_NAME).write_text(sums, encoding="utf-8")

    data = {
        "schema_version": 1,
        "component": manifest.PACKAGE,
        "source_repository": _env("GITHUB_REPOSITORY"),
        "source_commit": _env("GITHUB_SHA"),
        "release_tag": _env("TAG"),
        "release_id": int(_env("RELEASE_ID")),
        "workflow_run": int(_env("GITHUB_RUN_ID")),
        "fedora_release": manifest.FEDORA_RELEASE,
        "artifacts": items,
        "provenance": {"provider": "github", "subject_digest": "sha256"},
        "attestation": {"provider": "github", "verification": "gh attestation verify"},
    }
    (bundle / MANIFEST_NAME).write_text(
        json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return data


def main(args) -> int:
    build(Path(args.bundle))
    print(f"yazıldı: {Path(args.bundle) / MANIFEST_NAME}")
    print(f"yazıldı: {Path(args.bundle) / SUMS_NAME}")
    return 0
