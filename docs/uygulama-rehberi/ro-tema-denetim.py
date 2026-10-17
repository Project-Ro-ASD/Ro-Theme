#!/usr/bin/env python3
# SPDX-FileCopyrightText: Project Ro-ASD
# SPDX-License-Identifier: GPL-3.0-or-later
"""Ro tema denetimi: bir uygulama kaynağında temadan okunması gereken sabit değerleri ve yasaklı yöntemleri bulur.

Kullanım:
    ro-tema-denetim.py KLASOR [--ozet] [--uyari-hata]

Hata (çıkış kodu 1):
    - QML/JS/C++'ta sabit renk: "#RRGGBB", Qt.rgba(sayı, ...), QColor("#..."), QColor(sayı, sayı, sayı)
    - .qss stil dosyası ve setStyleSheet / -stylesheet
    - Kvantum, Klassy, LD_PRELOAD, QML2_IMPORT_PATH ile bileşen değiştirme
    - kullanıcı ayar dosyasına yazma (kdeglobals, kwinrc, kwinrulesrc ... için kwriteconfig)
    - sabit ev dizini yolu (/home/<ad>/)
Uyarı (--uyari-hata ile hata sayılır):
    - QML'de sayı olarak yazılmış köşe (radius: 12); Ro ölçeği dışındaysa ayrıca belirtilir

İstisna: gerçek bir rengi göstermesi gereken satıra (renk körlüğü önizlemesi, renk seçici adayları) ya da hemen
üstündeki satıra "ro-tema: izin <sebep>" yorumu yazılır. Sebepsiz izin kabul edilmez.

Rehber: Ro-Theme reposu, docs/uygulama-rehberi/.
"""
import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

RO_RADII = {0, 4, 8, 12, 18, 24}
SKIP_DIRS = {'.git', 'build', 'node_modules', '__pycache__', '.cache'}
SKIP_FILES = {'RoTokens.qml'}  # Ro-Theme'in ürettiği token dosyası

HEX = re.compile(r'''["']#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})["']''')
QT_RGBA = re.compile(r'Qt\.(?:rgba|hsla|hsva)\(\s*[0-9.]+\s*,')
QCOLOR_LIT = re.compile(r'QColor(?:\s+\w+)?\s*[({]\s*(?:"#|[0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+)')
QCOLOR_GLOBAL = re.compile(r'Qt::(?:white|black|red|green|blue|gray|darkGray|lightGray|yellow|cyan|magenta)\b')
RADIUS = re.compile(r'\bradius\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*(?:$|//|;|\}|,)')
STYLESHEET = re.compile(r'setStyleSheet\s*\(|-stylesheet\b')
FORBIDDEN = [
    (re.compile(r'kvantum', re.I), 'Kvantum (Ro uygulama stili Breeze, 04 · APP-01)'),
    (re.compile(r'klassy', re.I), 'Klassy dekorasyonu (pencere dekorasyonu Ro-Theme\'den, 05)'),
    (re.compile(r'\bLD_PRELOAD\b'), 'LD_PRELOAD (güncellemede sessizce bozulur)'),
    (re.compile(r'\bQML2?_IMPORT_PATH\b'), 'QML_IMPORT_PATH ile bileşen değiştirme (Kirigami/Breeze kopyası eskir)'),
    (re.compile(r'kwriteconfig[56]?\b[^\n]*--file\s+["\']?(?:kdeglobals|kwinrc|kwinrulesrc|plasmarc|kcminputrc|breezerc)'),
     'kullanıcının sistem ayar dosyasına yazma (22 · SYS)'),
    (re.compile(r'/home/(?!\$|\{|<)[a-z_][a-z0-9_-]*/'), 'sabit ev dizini yolu ($HOME / QStandardPaths kullanın)'),
]
EXCEPTION = re.compile(r'ro-tema:\s*izin\s+\S')

CODE_EXT = {'.qml', '.js', '.mjs'}
CPP_EXT = {'.cpp', '.cc', '.cxx', '.h', '.hpp'}
SCRIPT_EXT = {'.sh', '.bash', '.desktop', '.in', '.cmake', '.txt', '.py', '.service', '.conf', '.spec'}


def strip_comment(line, ext):
    if ext in CODE_EXT or ext in CPP_EXT:
        return line.split('//', 1)[0]
    if ext in {'.sh', '.bash', '.py', '.cmake', '.conf', '.spec', '.desktop', '.in', '.txt', '.service'}:
        return line.split('#', 1)[0] if not line.lstrip().startswith('#!') else ''
    return line


def scan(root):
    errors, warnings = defaultdict(list), defaultdict(list)
    for path in sorted(root.rglob('*')):
        if not path.is_file() or path.name in SKIP_FILES or any(p in SKIP_DIRS for p in path.relative_to(root).parts):
            continue
        ext = path.suffix.lower()
        rel = str(path.relative_to(root))
        if ext == '.qss':
            errors[rel].append((0, '.qss stil dosyası (sabit renkler koyu temada bozulur; hazır kontroller ve tema rolleri)', ''))
            continue
        if ext not in CODE_EXT | CPP_EXT | SCRIPT_EXT and path.name != 'CMakeLists.txt':
            continue
        try:
            lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
        except OSError:
            continue
        for i, raw in enumerate(lines, 1):
            allowed = EXCEPTION.search(raw) or (i > 1 and EXCEPTION.search(lines[i - 2]))
            code = strip_comment(raw, ext)
            found = []
            if ext in CODE_EXT:
                if HEX.search(code):
                    found.append(('e', 'sabit renk (Kirigami.Theme rolü ya da COL-33 karışımı)'))
                if QT_RGBA.search(code):
                    found.append(('e', 'sayısal Qt.rgba (tema renginin alfası: Qt.alpha(Kirigami.Theme.textColor, a))'))
                m = RADIUS.search(code)
                if m:
                    val = float(m.group(1))
                    note = '' if val in RO_RADII else f' (Ro ölçeği dışında: {m.group(1)})'
                    found.append(('w', f'sayı olarak köşe{note}; RoTokens.radius*'))
            if ext in CPP_EXT:
                if QCOLOR_LIT.search(code) or HEX.search(code):
                    found.append(('e', 'sabit QColor (KColorScheme rolü)'))
                if QCOLOR_GLOBAL.search(code):
                    found.append(('e', 'Qt::white/black... sabit renk (KColorScheme rolü)'))
            if ext in CODE_EXT | CPP_EXT | SCRIPT_EXT and STYLESHEET.search(code):
                found.append(('e', 'stil dosyası / setStyleSheet (Breeze + tema rolleri)'))
            for rx, why in FORBIDDEN:
                if rx.search(code):
                    found.append(('e', why))
            for kind, why in found:
                if allowed:
                    continue
                (errors if kind == 'e' else warnings)[rel].append((i, why, raw.strip()[:110]))
    return errors, warnings


def main():
    ap = argparse.ArgumentParser(description='Ro tema denetimi')
    ap.add_argument('klasor', type=Path)
    ap.add_argument('--ozet', action='store_true', help='yalnız dosya başına sayılar')
    ap.add_argument('--uyari-hata', action='store_true', help='uyarıları da hata say')
    a = ap.parse_args()
    if not a.klasor.is_dir():
        sys.exit(f'klasör yok: {a.klasor}')
    errors, warnings = scan(a.klasor)
    for title, group in (('HATA', errors), ('UYARI', warnings)):
        for f in sorted(group, key=lambda k: -len(group[k])):
            items = group[f]
            print(f'[{title}] {f}: {len(items)}')
            if a.ozet:
                continue
            for line, why, src in items:
                where = f'  {line}: ' if line else '  '
                print(f'{where}{why}' + (f'\n      {src}' if src else ''))
    ne, nw = sum(map(len, errors.values())), sum(map(len, warnings.values()))
    print(f'\nToplam: {ne} hata ({len(errors)} dosya), {nw} uyarı ({len(warnings)} dosya)')
    sys.exit(1 if ne or (a.uyari_hata and nw) else 0)


if __name__ == '__main__':
    main()
