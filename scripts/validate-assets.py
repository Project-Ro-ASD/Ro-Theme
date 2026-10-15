#!/usr/bin/env python3
"""Paketlenen varlıkların sözdizimini, bağlantılarını ve ikon dizinlerini denetler."""
import configparser
import gzip
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def validate(root):
    root = root.resolve()
    errors = []
    counts = dict(svg=0, json=0, symlinks=0, icon_directories=0)
    for folder in ("platform", "assets", "core", "dist"):
        for path in sorted((root / folder).rglob("*")):
            label = str(path.relative_to(root))
            if path.is_symlink():
                counts["symlinks"] += 1
                try:
                    target = path.resolve(strict=True)
                    if not target.is_relative_to(root):
                        errors.append(f"{label}: symlink target is outside the source tree")
                        continue
                except (OSError, RuntimeError) as error:
                    errors.append(f"{label}: invalid symlink ({error})")
                    continue
            if not path.is_file():
                continue
            try:
                if path.suffix in (".svg", ".svgz"):
                    counts["svg"] += 1
                    data = path.read_bytes()
                    svg = ET.fromstring(gzip.decompress(data) if path.suffix == ".svgz" else data)
                    if svg.tag not in ("svg", "{http://www.w3.org/2000/svg}svg"):
                        raise ValueError("root element is not SVG")
                elif path.suffix == ".json":
                    counts["json"] += 1
                    json.loads(path.read_text(encoding="utf-8"))
                elif path.name == "index.theme" and path.is_relative_to(root / "platform/icons"):
                    config = configparser.ConfigParser(interpolation=None)
                    config.optionxform = str
                    config.read_string(path.read_text(encoding="utf-8"))
                    for key in ("Directories", "ScaledDirectories"):
                        for directory in config["Icon Theme"].get(key, "").split(","):
                            directory = directory.strip()
                            if not directory:
                                continue
                            counts["icon_directories"] += 1
                            target = (path.parent / directory).resolve()
                            if not target.is_relative_to(path.parent.resolve()):
                                raise ValueError(f"icon directory escapes its theme: {directory}")
                            if directory not in config or not target.is_dir():
                                raise ValueError(f"missing icon directory or section: {directory}")
            except (OSError, EOFError, ValueError, ET.ParseError, configparser.Error, KeyError) as error:
                errors.append(f"{label}: {error}")
    return errors, counts


if __name__ == "__main__":
    errors, counts = validate(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
    for error in errors:
        print(f"[FAIL] {error}", file=sys.stderr)
    print("Asset validation: " + ", ".join(f"{value} {key}" for key, value in counts.items())
          + f"; {len(errors)} error(s)")
    sys.exit(bool(errors))
