#!/usr/bin/env bash
# Run from Git Bash:  bash tools/validate.sh [mod_folder_name] [--strict]
# Default mod: mods/new_intelligence_battle. Builds the vanilla key cache on first run
# (delete tools/cache/ to rebuild after a game patch), then validates the mod statically.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="${EU5_GAME_DIR:-/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V}"
CACHE="$HERE/tools/cache/vanilla_script_keys.txt"
MOD="new_intelligence_battle"
if [ "${1:-}" != "" ] && [ "${1#--}" = "$1" ]; then MOD="$1"; shift; fi
MODROOT="$HERE/mods/$MOD"
[ -d "$MODROOT" ] || { echo "mod folder not found: $MODROOT"; exit 1; }

if [ ! -s "$CACHE" ]; then
  echo "Building vanilla key cache from $GAME ..."
  mkdir -p "$HERE/tools/cache"
  # Every "key =" / "key <" ... at the start of a line in vanilla script files, including documented keys inside
  # comment lines of readme.txt / *.info files (e.g. "#  interface_lock = no").
  grep -rhE --include="*.txt" --include="*.info" "^[[:space:]]*#?[[:space:]]*[A-Za-z_][A-Za-z0-9_.:]*[[:space:]]*(=|<|>|>=|<=|!=|\?=)" \
    "$GAME/game/in_game/common" "$GAME/game/in_game/events" "$GAME/jomini/in_game" \
    "$GAME/game/main_menu/common" "$GAME/game/dlc" "$GAME/game/loading_screen/common" \
    "$GAME/jomini/loading_screen/common" "$GAME/jomini/main_menu/common" 2>/dev/null \
    | perl -ne 's/^\s*#?\s*//; print "$1\n" if /^([A-Za-z_][A-Za-z0-9_.:]*)\s*(=|<|>|>=|<=|!=|\?=)/' \
    | sort -u > "$CACHE"
  echo "  $(wc -l < "$CACHE") keys cached"
fi

perl "$HERE/tools/validate.pl" --root "$MODROOT" --cache "$CACHE" --game "$GAME" "$@"
