#!/usr/bin/env sh
# Noitamap Mod installer for Linux (including Steam Deck).
#
# Noita runs through Proton on Linux, but its mods folder is an ordinary
# directory in the game install -- steamapps/common/Noita/mods -- so installing
# is just "put the noitamap folder there". This script finds the game across
# native, Flatpak and multi-library Steam setups, then copies it in.
#
#   ./install.sh                     install (auto-detect Noita)
#   ./install.sh --dir /path/Noita   install into a specific Noita directory
#   ./install.sh --uninstall         remove the mod
#   ./install.sh --dry-run           show what would happen, change nothing
#   ./install.sh --help
#
# Exits non-zero on failure so it can be used from other scripts.

set -eu

MOD_ID=noitamap
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC="$SELF_DIR/$MOD_ID"

DRY=0
UNINSTALL=0
NOITA_DIR=

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
run() { if [ "$DRY" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else eval "$@"; fi; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# Rendered from public/assets/NoitamapLogo.png by sampling alpha-weighted
# luminance into a character ramp. Deliberately ASCII-only -- no box-drawing or
# block glyphs -- so it survives a minimal container, a non-UTF-8 locale, or a
# TTY-less pipe without turning into mojibake. Printed only to a terminal:
# piping to a file or a log gets clean text instead of 26 lines of art.
banner() {
  [ -t 1 ] || return 0
  cat <<'ART'

                            :##%%*:
                            =%@@@#-
              :--==-:  .=***#%@@@%#***=
            :=++*****=::#%@@@@@@@@@@@%%
           .=***+==++*++*#%%%@@@@%%%%#+
           .-**=====++======*%@@@#-
            :+*+============+#%%%#:
             .-*#+=========+**+-.. ..---:
        ----.  .:*#*======+*+:.  .---:::-+
     .-:....:-:   :+#+==+*+:   .--:::::::+
    =:........+ .   .-++=:   . =-::::::::+
    *...::::::+ *=:   ..   :+* =-::.....:=
    +:::--::::= *--=-.   :**** =:......::=
    +:::::..::= +--*#*--+*###+ -:.:::::::=
    *::..:..--= +**+******###= --::::::::=
    +==+==.:--+ ++++++*******= --::::::::=
    =--.......= ======+##****= ::::::::::=
    =....:::::- ::-----+++**#= ::::::::-:.
    =..:----:.     ..:------=- .:-:::..
    .--.:.              .-:=+:

 #   #  ###  ##### #####  ###  #   #  ###  ####
 ##  # #   #   #     #   #   # ## ## #   # #   #
 # # # #   #   #     #   ##### # # # ##### ####
 #  ## #   #   #     #   #   # #   # #   # #
 #   #  ###  #####   #   #   # #   # #   # #

                                    m o d

ART
}

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --dry-run)   DRY=1 ;;
    --dir)       shift; [ $# -gt 0 ] || die "--dir needs a path"; NOITA_DIR=$1 ;;
    --dir=*)     NOITA_DIR=${1#--dir=} ;;
    -h|--help)   usage ;;
    *)           die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

banner

# Extract every "path"  "/some/dir" value from a libraryfolders.vdf. Steam lists
# each library root there, so a user whose Noita lives on a second drive is only
# found via this file.
vdf_paths() {
  [ -f "$1" ] || return 0
  grep -o '"path"[[:space:]]*"[^"]*"' "$1" 2>/dev/null |
    sed 's/^"path"[[:space:]]*"//; s/"$//' || true
}

# A directory is Noita if it has the game executable. Under Proton the Windows
# binary is still what's on disk, so noita.exe is the right marker on Linux too.
is_noita() { [ -n "$1" ] && [ -f "$1/noita.exe" ]; }

find_noita() {
  # Steam root candidates: native, the older ~/.steam symlinks, and Flatpak.
  # Steam Deck uses ~/.steam/steam, which the first entry covers.
  for root in \
    "$HOME/.steam/steam" \
    "$HOME/.steam/root" \
    "$HOME/.local/share/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
  do
    [ -d "$root" ] || continue
    if is_noita "$root/steamapps/common/Noita"; then
      printf '%s\n' "$root/steamapps/common/Noita"; return 0
    fi
    # Other library drives registered with this Steam install.
    vdf_paths "$root/steamapps/libraryfolders.vdf" | while IFS= read -r lib; do
      [ -n "$lib" ] || continue
      if [ -f "$lib/steamapps/common/Noita/noita.exe" ]; then
        printf '%s\n' "$lib/steamapps/common/Noita"
      fi
    done | head -n 1 | grep . && return 0
  done
  return 1
}

if [ -z "$NOITA_DIR" ]; then
  NOITA_DIR=$(find_noita || true)
  [ -n "$NOITA_DIR" ] || die "could not find Noita.
Looked in the usual Steam locations (including Flatpak and extra library
drives). Pass the path explicitly:
  $0 --dir \"\$HOME/.steam/steam/steamapps/common/Noita\""
  info "Found Noita: $NOITA_DIR"
else
  is_noita "$NOITA_DIR" || die "no noita.exe in: $NOITA_DIR"
fi

MODS_DIR="$NOITA_DIR/mods"
DEST="$MODS_DIR/$MOD_ID"

if [ "$UNINSTALL" -eq 1 ]; then
  [ -d "$DEST" ] || { info "Not installed (nothing at $DEST)"; exit 0; }
  info "Removing $DEST"
  run "rm -rf -- '$DEST'"
  info "Done. The mod is removed; your Noita save and settings are untouched."
  exit 0
fi

[ -d "$SRC" ] || die "mod files not found next to this script (expected $SRC).
Run this from the unpacked release, so that install.sh and the $MOD_ID/ folder
sit side by side."
[ -f "$SRC/mod.xml" ] || die "$SRC exists but has no mod.xml -- wrong folder?"
# Writability is only assertable for a directory that exists. Checking it
# unconditionally broke --dry-run, which never creates mods/ and so always
# tripped the check on a fresh install.
if [ -d "$MODS_DIR" ]; then
  [ -w "$MODS_DIR" ] || die "no write permission on $MODS_DIR"
else
  info "Creating $MODS_DIR"
  run "mkdir -p -- '$MODS_DIR'"
fi

if [ -d "$DEST" ]; then
  info "Replacing existing install at $DEST"
  run "rm -rf -- '$DEST'"
else
  info "Installing to $DEST"
fi
run "cp -R -- '$SRC' '$DEST'"

if [ "$DRY" -eq 0 ]; then
  [ -f "$DEST/mod.xml" ] || die "copy failed: $DEST/mod.xml missing"
  info "Installed $(find "$DEST" -type f | wc -l | tr -d ' ') files."
fi

cat <<EOF

Next steps in Noita:
  1. Launch Noita, open "Mods"
  2. Set "Unsafe mods: Disabled" to enabled and confirm
     (the mod needs elevated permissions to read your position)
  3. Tick "Noita Map" so it shows [x]
  4. Press M during a run to open the map at your location

Uninstall later with:  $0 --uninstall
EOF
