#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------
# tools/gp_run_digest.sh - digest of an observation game for Geopolicy: wars by year + the mod's yearly reports.
#
#   bash tools/gp_run_digest.sh                 copy the live logs, build the digest, print the overview
#   bash tools/gp_run_digest.sh -d DIR          digest of logs already copied to DIR
#   bash tools/gp_run_digest.sh -o OUTDIR       where to write (default: Documents/NewIntelligence/runs/<date_time>)
#   bash tools/gp_run_digest.sh -t FRA          also print the compact yearly state changes of that tag (repeatable)
#
# The game TRUNCATES every log when it starts: run this (or tools/log_stats.sh --snapshot) BEFORE the next launch.
# Output files: timeline.tsv, wars.tsv, newyear.tsv, reports.tsv, war_blocks.tsv (see gp_log_timeline.pl / gp_log_reports.pl),
# plus copies of the raw logs. No Python needed (perl + awk from Git Bash).
# ---------------------------------------------------------------------------------------------
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERDIR="$(cygpath -u "${USERPROFILE:-$HOME}" 2>/dev/null || printf '%s' "$HOME")"
LIVE="$USERDIR/Documents/Paradox Interactive/Europa Universalis V/logs"
SRC=""; OUT=""; TAGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -d) SRC="${2:?missing DIR}"; shift 2 ;;
    -o) OUT="${2:?missing OUTDIR}"; shift 2 ;;
    -t) TAGS+=("${2:?missing TAG}"); shift 2 ;;
    -h|--help) sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done
if [ -z "$OUT" ]; then OUT="$USERDIR/Documents/NewIntelligence/runs/$(date +%Y%m%d_%H%M%S)"; fi
mkdir -p "$OUT" || exit 1
if [ -z "$SRC" ]; then
  [ -d "$LIVE" ] || { echo "logs dir not found: $LIVE" >&2; exit 1; }
  cp "$LIVE"/*.log "$OUT"/ 2>/dev/null || { echo "could not copy the logs" >&2; exit 1; }
else
  [ "$SRC" = "$OUT" ] || cp "$SRC"/*.log "$OUT"/ 2>/dev/null
fi
perl "$HERE/tools/gp_log_timeline.pl" "$OUT" "$OUT" || exit 1
perl "$HERE/tools/gp_log_reports.pl" "$OUT" "$OUT" || exit 1

echo; echo "== digest written to: $OUT"
echo; echo "== wars declared per 25-year bucket"
awk -F'\t' '{b=int(($1-1337)/25)*25+1337; c[b]++} END{for(k in c) print k, c[k]}' "$OUT/wars.tsv" | sort -n
echo; echo "== top 15 attackers"
cut -f3 "$OUT/wars.tsv" | sort | uniq -c | sort -rn | head -15
echo; echo "== gp_ errors in debug.log / error logs (must be empty)"
grep -a -h -iE 'gp_[a-z_]+' "$OUT"/debug.log "$OUT"/error*.log 2>/dev/null | grep -a -v 'GP_REPORT\|GP_WAR\|GP_COL\|GP_CRISIS' \
  | grep -a -iE 'error|unknown|invalid|not found|failed|unexpected' | sed -E 's/^\[[0-9:]{8}\]//' | sort | uniq -c | sort -rn | head -20

compact() {  # print only the years in which a country's state line changed
  awk -F'\t' -v T="$1" '$2==T{print $1"\t"$5}' "$OUT/reports.tsv" | perl -ne '
    chomp; my ($y, $s) = split /\t/, $_, 2;
    $s =~ s/zone profile \w+ \| //; $s =~ s/historic contender \| //; $s =~ s/contender of the region \| //;
    $s =~ s/may use the unification casus belli \| //; $s =~ s/ruler (likes|dislikes) a country \| //;
    $s =~ s/region share/share/; $s =~ s/threat found, /thr /; $s =~ s/no regional threat/nothr/;
    $s =~ s/at war this year/WAR/; $s =~ s/lost a war recently/LOSTWAR/;
    if ($s ne $prev) { print "$y\t$s\n"; $prev = $s; }'
}
for T in "${TAGS[@]:-}"; do [ -n "$T" ] || continue; echo; echo "== $T: yearly state changes"; compact "$T" | cut -c1-260; done
