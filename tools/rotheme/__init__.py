"""Ro-Theme derleme, doğrulama, kurulum ve paketleme araçları."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def version(root: Path = ROOT) -> str:
    """VERSION dosyasındaki sürüm (boşluklar atılmış)."""
    return (root / "VERSION").read_text(encoding="utf-8").strip()
