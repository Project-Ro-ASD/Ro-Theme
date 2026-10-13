#!/usr/bin/env bash
set -u

# "Ro görünümüne dön" aracı (22 SYS-07 B). Yalnızca çalıştıran kullanıcı için ve yalnızca kullanıcı
# kendisi çalıştırdığında kullanılır; paket betikleri bu aracı çağırmaz.
#
# Yöntem: Ro'nun /etc/xdg altında yönettiği anahtarların satırları kullanıcının ~/.config dosyalarından
# kaldırılır. KDE ayar zinciri (XDG_CONFIG_DIRS) sayesinde kullanıcı o anahtarlar için sistem varsayılanına
# döner; değerlerin kopyası bu betikte tutulmaz. Değişiklikten önce dosyaların yedeği alınır.
#
# NOT: kwriteconfig6 --delete kullanılmaz. Alt katmanda (/etc/xdg) aynı anahtar varsa kwriteconfig6
# "anahtar[$d]" işareti yazar; bu işaret sistem varsayılanını da gizler. Satır doğrudan kaldırılır.

SYSTEM_XDG="${RO_THEME_SYSTEM_XDG:-/etc/xdg}"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
FILES=(kdeglobals kcmfonts plasmarc ksplashrc kscreenlockerrc kwinrc)
# Eski sürümün kullanıcı dosyalarına yazdığı, artık yönetilmeyen anahtarlar: "dosya|[grup]|anahtar"
LEGACY_KEYS=(
  "kdeglobals|[KDE]|ColorScheme"
  "kwinrc|[Plugins]|kwin4_effect_scaleEnabled"
  "kwinrc|[Plugins]|kwin4_effect_glideEnabled"
  "kwinrc|[Plugins]|kwin4_effect_squashEnabled"
  "kwinrc|[Plugins]|kwin4_effect_magiclampEnabled"
  "kwinrc|[Plugins]|kwin4_effect_windowapertureEnabled"
  "kwinrc|[Plugins]|kwin4_effect_frozenappEnabled"
)
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: apply-dark-defaults [--current-user] [--dry-run]

Reset the Ro-managed appearance settings of the current user to the Ro-ASD
system defaults. Only keys that Ro-Theme ships in /etc/xdg are removed from
your ~/.config files; everything else is kept. A backup is written to
~/.config/ro-theme/backup-<date>/ first.

  --current-user  apply to the user running the command (default)
  --dry-run       show what would change, change nothing
EOF
}

for arg in "$@"; do
  case "$arg" in
    --current-user) ;;
    --dry-run) DRY_RUN=1 ;;
    --all-users|--force)
      echo "apply-dark-defaults: $arg was removed; the tool only changes the current user's own settings." >&2
      exit 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "apply-dark-defaults: unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(id -u)" -eq 0 ]]; then
  echo "apply-dark-defaults: run this as your own user, not as root." >&2
  exit 2
fi

# Yönetilen anahtarlar: sistem dosyasındaki her "[grup]<TAB>anahtar" çifti + eski sürüm anahtarları.
managed_list() {
  local f="$1"
  if [[ -f "$SYSTEM_XDG/$f" ]]; then
    awk '/^\[.*\]$/ { g = $0; next }
         /^[^#].*=/ && g != "" { k = $0; sub(/=.*/, "", k); sub(/\[[^]]*\]$/, "", k); print g "\t" k }' "$SYSTEM_XDG/$f"
  fi
  local entry ef eg ek
  for entry in "${LEGACY_KEYS[@]}"; do
    IFS='|' read -r ef eg ek <<< "$entry"
    [[ "$ef" = "$f" ]] && printf '%s\t%s\n' "$eg" "$ek"
  done
}

# Kullanıcı dosyasından yönetilen anahtar satırlarını (yerelleştirilmiş "anahtar[tr]=" ve "anahtar[$d]"
# biçimleri dahil) kaldırır; boş kalan grupları atar. Kaldırılan satırlar stderr'e yazılır.
filter_user_file() {
  awk -F'\t' -v dry="$DRY_RUN" -v file="$2" '
    NR == FNR { m[$1 SUBSEP $2] = 1; next }
    /^\[.*\]$/ { g = $0; pending = $0; next }
    {
      k = $0
      if (k ~ /=/ || k ~ /\[\$[a-z]+\]$/) {
        sub(/=.*/, "", k); while (k ~ /\[[^]]*\]$/) sub(/\[[^]]*\]$/, "", k)
        if ((g SUBSEP k) in m) { print "reset: " file " " g " " k > "/dev/stderr"; next }
      }
      if ($0 == "") next
      if (pending != "") {
        if (printed) print ""
        print pending; pending = ""; printed = 1
      }
      print
    }' "$1" "$USER_CONFIG/$2"
}

backup_dir="$USER_CONFIG/ro-theme/backup-$(date +%Y%m%d-%H%M%S)-$$"

changed=0
for f in "${FILES[@]}"; do
  [[ -f "$USER_CONFIG/$f" ]] || continue
  list="$(mktemp)"; out="$(mktemp)"; log="$(mktemp)"
  managed_list "$f" > "$list"
  filter_user_file "$list" "$f" > "$out" 2> "$log"
  if [[ -s "$log" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      sed 's/^reset:/would reset:/' "$log"
    else
      mkdir -p "$backup_dir" && cp -a "$USER_CONFIG/$f" "$backup_dir/"
      cat "$out" > "$USER_CONFIG/$f"
    fi
    changed=$((changed + $(wc -l < "$log")))
  fi
  rm -f "$list" "$out" "$log"
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  # Eski sürümün bıraktığı işaret dosyası artık kullanılmıyor.
  rm -f "$USER_CONFIG/ro-theme/default-dark-applied"
  echo "Ro appearance settings reset to the system defaults: $changed setting(s) removed from your files."
  [[ -d "$backup_dir" ]] && echo "Backup: $backup_dir"
  [[ "$changed" -gt 0 ]] && echo "Log out and back in to see all changes."
fi

exit 0
