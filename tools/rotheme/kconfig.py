"""KConfig (KDE INI) dosyaları için küçük, sıra koruyan okuyucu/yazıcı.

configparser kullanılmaz: KConfig grup başlıkları iç içe olabilir (`[Colors:Header][Inactive]`),
anahtarlar büyük/küçük harfe duyarlıdır ve `key[tr]`, `key[$d]` gibi ekler taşır.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

HEADER = re.compile(r"^(\[[^\]]*\])+$")
SUFFIX = re.compile(r"(\[[^\]]*\])+$")


def bare_key(key: str) -> str:
    """'ColorScheme[tr]' ya da 'ColorScheme[$d]' -> 'ColorScheme'."""
    return SUFFIX.sub("", key.strip())


@dataclass
class KConfig:
    """Gruplar eklenme sırasında tutulur; '' grubu ilk başlıktan önceki satırlardır."""

    groups: dict[str, dict[str, str]] = field(default_factory=dict)
    header: list[str] = field(default_factory=list)   # dosya başındaki yorumlar

    # --- okuma ---
    @classmethod
    def parse(cls, text: str) -> "KConfig":
        cfg, current = cls(), None
        for raw in text.splitlines():
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#"):
                if current is None:
                    cfg.header.append(line)
                continue
            if HEADER.match(line):
                current = line
                cfg.groups.setdefault(current, {})
                continue
            key, sep, value = line.partition("=")
            if not sep:
                continue
            cfg.groups.setdefault(current or "", {})[key.strip()] = value.strip()
        return cfg

    def get(self, group: str, key: str, default: str | None = None) -> str | None:
        return self.groups.get(group, {}).get(key, default)

    # --- değiştirme ---
    def set(self, group: str, key: str, value) -> None:
        if isinstance(value, bool):
            value = "true" if value else "false"
        self.groups.setdefault(group, {})[key] = str(value)

    def update(self, group: str, values: dict) -> None:
        for k, v in values.items():
            self.set(group, k, v)

    def remove(self, group: str, key: str) -> bool:
        return self.groups.get(group, {}).pop(key, None) is not None

    # --- yazma ---
    def dump(self) -> str:
        """Başlık yorumları, ardından boş satırla ayrılmış gruplar; boş gruplar yazılmaz."""
        blocks = []
        if self.header:
            blocks.append("\n".join(self.header))
        for name, keys in self.groups.items():
            if not keys:
                continue
            lines = [name] if name else []
            lines += [f"{k}={v}" for k, v in keys.items()]
            blocks.append("\n".join(lines))
        return "\n\n".join(blocks) + "\n"
