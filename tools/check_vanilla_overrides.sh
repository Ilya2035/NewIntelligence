#!/usr/bin/env bash
# Checks whether the vanilla files that this mod overrides wholesale changed since the override was made.
# Run from Git Bash after a game patch:  bash tools/check_vanilla_overrides.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="${EU5_GAME_DIR:-/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V}"
status=0
while read -r rel md5 lines; do
  case "$rel" in ''|\#*) continue;; esac
  now="$(md5sum "$GAME/$rel" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$now" ]; then echo "MISSING  $rel (vanilla file not found)"; status=1
  elif [ "$now" != "$md5" ]; then echo "CHANGED  $rel  (vanilla now $(wc -l < "$GAME/$rel") lines, was $lines) -> re-merge the # CW blocks into a fresh copy"; status=1
  else echo "OK       $rel"; fi
done < "$HERE/tools/vanilla_overrides.txt"
exit $status
