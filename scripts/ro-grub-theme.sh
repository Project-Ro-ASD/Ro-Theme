#!/usr/bin/env bash
# Ro GRUB teması: açma, kapatma, durum. (Ro-Theme-Docs 24 · GRUB-04)
#
# Paket yalnızca dosyaları /usr/share/grub/themes/ro altına koyar; /boot ve /etc/default/grub'a paket betiği yazmaz
# (00 §4). Temayı açmak kullanıcının kararıdır ve bu araçla yapılır:
#   sudo ro-grub-theme enable     temayı /boot/grub2/themes/ro'ya kopyalar, /etc/default/grub'a işaretli bir blok yazar,
#                                 grub.cfg'yi yeniden üretir. Tekrar çalıştırmak temayı pakettekiyle günceller.
#   sudo ro-grub-theme disable    bloğu ve kopyayı kaldırır, grub.cfg'yi yeniden üretir.
#   ro-grub-theme status          açık mı, kopya güncel mi.
# Seçenekler: --no-regenerate (grub.cfg'ye dokunma; sonra kendiniz grub2-mkconfig çalıştırın).
# Deneme için RO_GRUB_ROOT=/ön/ek kök dizini ön ekler (gerçek sisteme dokunmadan sınama).
set -euo pipefail

ROOT="${RO_GRUB_ROOT:-}"
SRC="$ROOT/usr/share/grub/themes/ro"
DEFAULTS="$ROOT/etc/default/grub"
BEGIN='# BEGIN ro-theme (ro-grub-theme tarafından yönetilir; kaldırmak için: ro-grub-theme disable)'
END='# END ro-theme'

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }

boot_dir() {
  if [[ -d "$ROOT/boot/grub2" ]]; then echo /boot/grub2; elif [[ -d "$ROOT/boot/grub" ]]; then echo /boot/grub; else echo /boot/grub2; fi
}

mkconfig_cmd() {
  if command -v grub2-mkconfig >/dev/null 2>&1; then echo grub2-mkconfig; else echo grub-mkconfig; fi
}

has_block() { [[ -f "$DEFAULTS" ]] && grep -qF "$BEGIN" "$DEFAULTS"; }

remove_block() {
  [[ -f "$DEFAULTS" ]] || return 0
  local tmp; tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$DEFAULTS" > "$tmp"
  cat "$tmp" > "$DEFAULTS"; rm -f "$tmp"
}

regenerate() {
  local boot cfg
  boot="$(boot_dir)"; cfg="$boot/grub.cfg"
  if [[ "$REGEN" != yes ]]; then
    echo "grub.cfg yeniden üretilmedi (--no-regenerate). Sonra: sudo $(mkconfig_cmd) -o $cfg"; return 0
  fi
  "$(mkconfig_cmd)" -o "$ROOT$cfg"
}

need_root() {
  if [[ -z "$ROOT" && "$(id -u)" -ne 0 ]]; then
    echo "Bu işlem root ister: sudo ro-grub-theme $1" >&2; exit 1
  fi
}

cmd_enable() {
  need_root enable
  [[ -f "$SRC/theme.txt" ]] || { echo "Tema dosyaları yok: /usr/share/grub/themes/ro (ro-theme paketi kurulu mu?)" >&2; exit 1; }
  local boot; boot="$(boot_dir)"
  [[ -f "$DEFAULTS" ]] || { echo "/etc/default/grub yok." >&2; exit 1; }
  [[ -f "$DEFAULTS.ro-backup" ]] || cp -a "$DEFAULTS" "$DEFAULTS.ro-backup"
  rm -rf "$ROOT$boot/themes/ro"
  install -d "$ROOT$boot/themes"
  cp -a "$SRC" "$ROOT$boot/themes/ro"
  remove_block
  {
    echo
    echo "$BEGIN"
    echo "GRUB_THEME=\"$boot/themes/ro/theme.txt\""
    echo 'GRUB_TERMINAL_OUTPUT="gfxterm"'
    echo 'GRUB_TIMEOUT_STYLE=menu'
    echo "$END"
  } >> "$DEFAULTS"
  # Fedora menüyü başarılı açılıştan sonra gizler; Ro menüsü her açılışta görünür (GRUB-01).
  if [[ -z "$ROOT" ]] && command -v grub2-editenv >/dev/null 2>&1; then
    grub2-editenv - unset menu_auto_hide 2>/dev/null || true
  fi
  regenerate
  echo "Ro GRUB teması açıldı. Yedek: /etc/default/grub.ro-backup"
}

cmd_disable() {
  need_root disable
  local boot; boot="$(boot_dir)"
  remove_block
  rm -rf "$ROOT$boot/themes/ro"
  regenerate
  echo "Ro GRUB teması kapatıldı. (Önceki ayarlar /etc/default/grub.ro-backup içinde; blok dışındaki satırlara dokunulmadı.)"
}

cmd_status() {
  local boot; boot="$(boot_dir)"
  if has_block; then echo "Ayar: açık (/etc/default/grub içinde Ro bloğu var)"; else echo "Ayar: kapalı"; fi
  if [[ -d "$ROOT$boot/themes/ro" ]]; then
    if diff -rq "$SRC" "$ROOT$boot/themes/ro" >/dev/null 2>&1; then echo "Kopya: $boot/themes/ro, pakettekiyle aynı"
    else echo "Kopya: $boot/themes/ro, pakettekinden farklı (güncellemek için: sudo ro-grub-theme enable)"; fi
  else
    echo "Kopya: yok"
  fi
}

REGEN=yes
ARGS=()
for a in "$@"; do
  case "$a" in
    --no-regenerate) REGEN=no ;;
    -h|--help) usage; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

case "${ARGS[0]:-}" in
  enable) cmd_enable ;;
  disable) cmd_disable ;;
  status) cmd_status ;;
  *) usage; exit 1 ;;
esac
