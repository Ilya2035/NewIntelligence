#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------
# tools/log_stats.sh - gameplay / AI / performance metrics from the EU5 logs, to compare a
# vanilla run with a Concentrated Warfare run.  Documented in docs/research/13_ai_log_baseline.md.
# Needs Git Bash (GNU awk, grep, sort).  Reads the logs only; never writes into the logs dir.
#
#   bash tools/log_stats.sh                       report from the live logs directory
#   bash tools/log_stats.sh -d DIR                report from DIR (a snapshot made earlier)
#   bash tools/log_stats.sh --tsv > base.tsv      machine-readable "metric<TAB>value" lines
#   bash tools/log_stats.sh --compare base.tsv    current logs vs a saved TSV (base | now | delta)
#   bash tools/log_stats.sh --snapshot NAME       copy ai/game/perf/error/... logs + metrics.tsv to
#                                                tools/log_snapshots/NAME/  (--with-debug: debug.log too)
#   bash tools/log_stats.sh --player "Бранденбург"  also count wars declared by / against that name
#                                                (the localised country name as printed in game.log)
#   EU5_LOG_DIR=/path/to/logs        overrides the default logs directory
#   EU5_SNAPSHOT_DIR=/path           overrides tools/log_snapshots
#
# The game TRUNCATES every log when it starts, so export (--tsv) or --snapshot BEFORE the next launch.
# ---------------------------------------------------------------------------------------------
set -u
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERDIR="$(cygpath -u "${USERPROFILE:-$HOME}" 2>/dev/null || printf '%s' "$HOME")"
DEFAULT_LOGDIR="$USERDIR/Documents/Paradox Interactive/Europa Universalis V/logs"
LOGDIR="${EU5_LOG_DIR:-$DEFAULT_LOGDIR}"
SNAPROOT="${EU5_SNAPSHOT_DIR:-$HERE/tools/log_snapshots}"
MODE=human; COMPARE=""; SNAP=""; WITH_DEBUG=0; PLAYER=""

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)      LOGDIR="${2:?missing DIR}"; shift 2 ;;
    --tsv)         MODE=tsv; shift ;;
    --compare)     MODE=compare; COMPARE="${2:?missing base.tsv}"; shift 2 ;;
    --snapshot)    SNAP="${2:?missing NAME}"; shift 2 ;;
    --with-debug)  WITH_DEBUG=1; shift ;;
    --player)      PLAYER="${2:?missing NAME}"; shift 2 ;;
    -h|--help)     sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done
[ -d "$LOGDIR" ] || { echo "log directory not found: $LOGDIR" >&2; exit 1; }
[ "$MODE" = compare ] && [ ! -f "$COMPARE" ] && { echo "baseline TSV not found: $COMPARE" >&2; exit 1; }

AI="$LOGDIR/ai.log"; GAME="$LOGDIR/game.log"; PERF="$LOGDIR/performance_degradation.log"
DED="$LOGDIR/dedicated_server.log"; MP="$LOGDIR/multiplayer.log"; DBG="$LOGDIR/debug.log"
ERR="$LOGDIR/error.log"; GUI="$LOGDIR/gui.log"; CODEREV="$LOGDIR/code_revisions.log"
CONT="$LOGDIR/continue_game.json"; [ -f "$CONT" ] || CONT="$LOGDIR/../continue_game.json"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/metrics.tsv"; YEARS="$TMP/years.tsv"; YSTAT="$TMP/ystat.tsv"; : > "$OUT"; : > "$YEARS"; : > "$YSTAT"
emit()    { printf '%s\t%s\n' "$1" "$2" >> "$OUT"; }
section() { printf '#\t%s\n' "$1" >> "$OUT"; }
lines()   { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
cnt()     { [ -f "$2" ] && { grep -a -c -- "$1" "$2" || true; } || echo 0; }   # grep -c prints 0 on no match
ratio()   { awk -v a="$1" -v b="$2" 'BEGIN{ if (b+0>0) printf "%.2f", a/b; else printf "n/a" }'; }

# awk helper shared by the timestamped logs: "[HH:MM:SS]" -> seconds, made monotonic across midnight
AWK_TS='function ts(s,   h,m,x){ h=substr(s,2,2)+0; m=substr(s,5,2)+0; x=substr(s,8,2)+0; return h*3600+m*60+x }
function mono(s,   t){ t=ts(s)+off; if (t < last-1) { off+=86400; t+=86400 } last=t; return t }'

# ------------------------------------------------------------------ session
section session
emit log_dir "$LOGDIR"
emit report_time "$(date '+%Y-%m-%d %H:%M:%S')"
gv="$( [ -f "$CONT" ] && grep -a -o '"rawGameVersion":[[:space:]]*"[^"]*"' "$CONT" | sed 's/.*"\([^"]*\)"$/\1/' )"
emit game_version "${gv:-?}"
emit exe_hash   "$( [ -f "$CODEREV" ] && grep -a -o 'game_hash_short: [0-9a-f]*' "$CODEREV" | head -n1 | cut -d' ' -f2 )"
emit exe_branch "$( [ -f "$CODEREV" ] && grep -a -o 'game_branch: .*' "$CODEREV" | head -n1 | cut -d' ' -f2- | tr -d '\r' )"
first_ts="$( [ -f "$DBG" ] && head -n1 "$DBG" | grep -a -o '^\[[0-9:]*\]' | tr -d '[]' )"
last_ts="$( [ -f "$GAME" ] && grep -a -o '^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\]' "$GAME" | tail -n1 | tr -d '[]' )"
emit wallclock_first "${first_ts:-?}"
emit wallclock_last  "${last_ts:-?}"

# mods: every non-vanilla root mounted by the engine (debug.log "Mounted Data:" lines), names from .metadata
mods=""; nmods=0
if [ -f "$DBG" ]; then
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    name="$(grep -a -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/.metadata/metadata.json" 2>/dev/null | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
    [ -n "$name" ] || name="$(basename "$root")"
    mods="${mods:+$mods | }$name"; nmods=$((nmods+1))
  done < <(grep -a 'Mounted Data: ' "$DBG" | grep -a -i 'workshop/content/\|/mod/' \
           | sed -E 's/.*Mounted Data: //; s/\r$//; s#/(main_menu|in_game|loading_screen)/?$##' | sort -u)
fi
emit mods_mounted_count "$nmods"
emit mods_mounted "${mods:-none (vanilla)}"
emit player_country "$( [ -f "$MP" ] && grep -a 'New Country:' "$MP" | tail -n1 | sed 's/.*New Country:[[:space:]]*//' | tr -d '\r' )"
emit game_speed_last "$( [ -f "$DED" ] && grep -a 'Changing game speed to:' "$DED" | tail -n1 | grep -o '[0-9]*' | tail -n1 )"

# pause accounting: seconds spent unpaused (dedicated_server.log pause toggles; EU5 starts paused)
read -r unpaused toggles still_running < <(
  if [ -f "$DED" ]; then
    awk -v endts="${last_ts:-}" "$AWK_TS"'
      { sub(/\r$/,""); if ($0 !~ /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\]/) next; t=mono($0)
        if ($0 ~ /Pause Toggled! Paused: false/) { toggles++; if (!run) { run=1; t0=t } }
        else if ($0 ~ /Pause Toggled! Paused: true/) { toggles++; if (run) { run=0; acc+=t-t0 } } }
      END { if (run && endts!="") { e=ts("[" endts "]")+off; if (e<last) e=(last-e>43200 ? e+86400 : last); if (e>t0) acc+=e-t0 }
            printf "%d %d %d\n", acc, toggles, run }' "$DED"
  else echo "0 0 0"; fi)
emit unpaused_seconds "$unpaused"
emit pause_toggles "$toggles"
emit unpaused_when_log_ended "$still_running"

# ------------------------------------------------------------------ performance_degradation.log
section performance
start_year=""
if [ -f "$PERF" ]; then
  perf="$(awk -F, '
    BEGIN { split("0 31 59 90 120 151 181 212 243 273 304 334", cum, " ") }
    function days(d,   a) { split(d, a, "_"); return a[1]*365 + cum[a[2]+0] + a[3]+0 }
    NR==1 { next }
    { sub(/\r$/,""); for (i=1;i<=NF;i++) gsub(/[" \t]/, "", $i)
      if ($9=="" || $9=="1_01_01") next                       # main-menu samples carry date 1_01_01
      n++; T=$1+0; ad=$2*1000
      if (n==1) { first=$9; memmin=$10+0 }
      adsum+=ad; if (ad>admax) admax=ad; if ($4+0>mdmax) mdmax=$4+0
      if ($10+0<memmin) memmin=$10+0; if ($10+0>memmax) memmax=$10+0
      if ($8+0>gw) gw=$8+0; if ($6+0>ecs) ecs=$6+0
      if (n>1) { dd=days($9)-days(pd); dt=T-pT; if (dd>0 && dt>0) { sdd+=dd; sdt+=dt } }
      pd=$9; pT=T; last=$9; lastT=T }
    END { if (n==0) { print "0"; exit }
          printf "%d\t%s\t%s\t%d\t%.0f\t%.2f\t%.2f\t%.2f\t%.0f\t%.0f\t%d\t%d\t%s\n", n, first, last, days(last)-days(first), lastT,
                 adsum/n, admax, mdmax, memmin, memmax, gw, ecs, (sdt>0 ? sprintf("%.2f", sdd/sdt) : "n/a") }' "$PERF")"
  IFS=$'\t' read -r p_n p_first p_last p_days p_total p_admean p_admax p_mdmax p_memmin p_memmax p_gw p_ecs p_dps <<< "$perf"
  if [ "${p_n:-0}" != "0" ]; then
    start_year="${p_first%%_*}"
    emit perf_samples_ingame "$p_n"
    emit game_date_first "$p_first"
    emit game_date_last "$p_last"
    emit game_days_elapsed "$p_days"
    emit perf_total_time_s "$p_total"
    emit perf_frame_ms_mean "$p_admean"
    emit perf_frame_ms_max "$p_admax"
    emit perf_maxdelta_s_max "$p_mdmax"
    emit perf_mem_mb_min "$p_memmin"
    emit perf_mem_mb_max "$p_memmax"
    emit perf_gui_widgets_max "$p_gw"
    emit perf_ecs_entities_max "$p_ecs"
    emit perf_days_per_s_sampled "$p_dps"
    emit game_days_per_unpaused_s "$(ratio "$p_days" "$unpaused")"
  else emit perf_samples_ingame 0; fi
else emit perf_samples_ingame "missing"; fi

# ------------------------------------------------------------------ game.log
section game_log
if [ -f "$GAME" ]; then
  gstats="$(awk -v startyear="${start_year:-}" -v yearsfile="$YEARS" -v ystat="$YSTAT" -v player="$PLAYER" "$AWK_TS"'
    BEGIN { year = (startyear!="" ? startyear+0 : 0) }
    { sub(/\r$/,""); if ($0 !~ /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\]\[/) next
      nl++; t=mono($0); msg=$0; sub(/^\[[^]]*\]\[[^]]*\]: /, "", msg)
      if (msg ~ /^NEW YEAR: /)     { y=substr(msg,11)+0; if (ny==0) firstny=y; ny++; year=y; seen[year]=1; print "Y\t" t "\t" y > yearsfile; next }
      seen[year]=1
      if (msg ~ /^WAR: /)          { wars++; wy[year]++; s=msg; sub(/^WAR: /,"",s); sub(/ *$/,"",s); i=index(s," declared war on ")
                                     a=substr(s,1,i-1); d=substr(s,i+17); att[a]++; def[d]++
                                     if (player!="") { if (a==player) pw++; if (d==player) pa++ } next }
      if (msg ~ /^CIVIL WAR: /)    { cw++; cwy[year]++; next }
      if (msg ~ /^REVOLT: /)       { rv++; rvy[year]++; next }
      if (msg ~ /^COLONISATION: /) { col++; next }
      if (msg ~ /^DISASTER: /)     { if (msg ~ / starts in /) ds++; else de++; next }
      if (msg ~ /^SITUATION: /)    { if (msg ~ / starts on /) ss++; else se++; next }
      if (msg ~ /^EXPLORATION: /)  { ex++; next } }
    END { na=0; for (a in att) na++; nd=0; for (d in def) nd++
          printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", nl, wars, cw, rv, col, ds, de, ss, se, ex, ny, na, nd, pw, pa
          if ((0 in seen) && firstny>0) { y0=firstny-1; wy[y0]+=wy[0]; cwy[y0]+=cwy[0]; rvy[y0]+=rvy[0]; seen[y0]=1; delete seen[0] }
          for (a in att) print "ATT\t" a "\t" att[a] >> ystat
          for (y in seen) { printf "YEAR\t%d\t%d\t%d\t%d\n", y, wy[y], cwy[y], rvy[y] >> ystat } }' "$GAME")"
  IFS=$'\t' read -r g_lines g_wars g_cw g_rv g_col g_ds g_de g_ss g_se g_ex g_ny g_na g_nd g_pw g_pa <<< "$gstats"
  emit game_log_lines "$g_lines"
  emit wars_declared "$g_wars"
  emit wars_per_game_year "$(awk -v w="$g_wars" -v d="${p_days:-0}" 'BEGIN{ if (d+0>0) printf "%.1f", w/(d/365); else printf "n/a" }')"
  emit wars_distinct_attackers "$g_na"
  emit wars_distinct_defenders "$g_nd"
  if [ -n "$PLAYER" ]; then emit wars_declared_by_player "$g_pw"; emit wars_declared_on_player "$g_pa"; fi
  emit civil_wars "$g_cw"
  emit revolts "$g_rv"
  emit colonisations_started "$g_col"
  emit disasters_started "$g_ds"
  emit disasters_ended "$g_de"
  emit situations_started "$g_ss"
  emit situations_ended "$g_se"
  emit explorations "$g_ex"
  emit new_year_markers "$g_ny"
  top="$(grep -a '^ATT' "$YSTAT" | sort -t"$(printf '\t')" -k3,3nr -k2,2 | head -n 10 | awk -F'\t' '{ s = s (s==""?"":", ") $2 ":" $3 } END { print s }')"
  emit top_attackers "${top:-none}"
else emit game_log_lines "missing"; fi

# ------------------------------------------------------------------ ai.log
section ai_log
ARMY_KINDS="move_unit merge_army split_unit attach_unit detach_unit toggle_can_attach_to set_unit_activity take_over_siege asssume_siege_control transfer_occupation disband_subunit disband_unit raise_all_levies use_unit_ability consolidate"
if [ -f "$AI" ]; then
  astats="$(awk -v startyear="${start_year:-}" -v army="$ARMY_KINDS" -v ystat="$YSTAT" "$AWK_TS"'
    BEGIN { n=split(army, ak, " "); for (i=1;i<=n;i++) isarmy[ak[i]]=1; year=(startyear!="" ? startyear+0 : 0) }
    FNR==NR { yb[++ny]=$2; yv[ny]=$3; next }                       # year boundaries written by the game.log pass
    { sub(/\r$/,""); if ($0 !~ /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\]\[/) { unparsed++; next }
      lines++; t=mono($0)
      if (year==0 && ny>0) year=yv[1]-1
      while (yi<ny && t>=yb[yi+1]) { yi++; year=yv[yi] }
      if (match($0, /AI tried to execute invalid command: [A-Za-z0-9_]+\./)) {
        k=substr($0, RSTART+37, RLENGTH-38); inv++; kind[k]++; invy[year]++
        if (k in isarmy) { arm++; army_y[year]++ } next }
      if ($0 ~ /AI posting invalid commands: /) { post++; k=$0; sub(/.*AI posting invalid commands: /,"",k); pk[k]++; next }
      if ($0 ~ /\[AI Warning\]/) { ow++; next }
      other++ }
    END { printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\n", lines, inv, arm, post, ow, other, unparsed
          for (k in kind) print "KIND\t" k "\t" kind[k] >> ystat
          for (k in pk)   print "POST\t" k "\t" pk[k] >> ystat
          for (y in invy) print "AIY\t" y "\t" invy[y] "\t" army_y[y]+0 >> ystat }' "$YEARS" "$AI")"
  IFS=$'\t' read -r a_lines a_inv a_arm a_post a_ow a_other a_unp <<< "$astats"
  emit ai_log_lines "$a_lines"
  emit ai_invalid_commands_total "$a_inv"
  emit ai_invalid_commands_army "$a_arm"
  emit ai_invalid_commands_army_pct "$(awk -v a="$a_arm" -v b="$a_inv" 'BEGIN{ if (b+0>0) printf "%.1f", 100*a/b; else printf "n/a" }')"
  emit ai_invalid_per_game_year "$(awk -v w="$a_inv" -v d="${p_days:-0}" 'BEGIN{ if (d+0>0) printf "%.1f", w/(d/365); else printf "n/a" }')"
  emit ai_invalid_per_unpaused_min "$(awk -v w="$a_inv" -v s="$unpaused" 'BEGIN{ if (s+0>0) printf "%.2f", w/(s/60); else printf "n/a" }')"
  emit ai_posting_invalid_total "$a_post"
  emit ai_other_warnings "$a_ow"
  emit ai_other_lines "$a_other"
  emit ai_unparsed_lines "$a_unp"
  while IFS=$'\t' read -r _ k c; do emit "ai_invalid_cmd.$k" "$c"; done < <(grep -a '^KIND' "$YSTAT" | sort -t"$(printf '\t')" -k3,3nr -k2,2)
  while IFS=$'\t' read -r _ k c; do emit "ai_posting_invalid.$k" "$c"; done < <(grep -a '^POST' "$YSTAT" | sort -t"$(printf '\t')" -k3,3nr -k2,2)
else emit ai_log_lines "missing"; fi

# ------------------------------------------------------------------ per game year (game.log + ai.log joined on wall-clock time)
section by_year
awk -F'\t' '
  $1=="YEAR" { y[$2]=1; w[$2]=$3; c[$2]=$4; r[$2]=$5 }
  $1=="AIY"  { y[$2]=1; ai[$2]=$3; aa[$2]=$4 }
  END { for (k in y) printf "%d\t%d\t%d\t%d\t%d\t%d\n", k, w[k]+0, c[k]+0, r[k]+0, ai[k]+0, aa[k]+0 }' "$YSTAT" | sort -n > "$TMP/byyear.tsv"
while IFS=$'\t' read -r y w c r ai aa; do
  emit "year.$y.wars" "$w"; emit "year.$y.civil_wars" "$c"; emit "year.$y.revolts" "$r"
  emit "year.$y.ai_invalid" "$ai"; emit "year.$y.ai_invalid_army" "$aa"
done < "$TMP/byyear.tsv"

# ------------------------------------------------------------------ error.log / gui.log / debug.log (grep only - debug.log is huge)
section errors
emit error_log_lines "$(lines "$ERR")"
emit error_log_rotated_files "$(ls "$LOGDIR"/error.[0-9]*.log 2>/dev/null | wc -l | tr -d ' ')"
emit error_log_lines_all "$(cat "$ERR" "$LOGDIR"/error.[0-9]*.log 2>/dev/null | wc -l | tr -d ' ')"
# error.log rotates at ~1 MB (5 generations kept) and the vanilla army window alone fills it in seconds,
# so mod errors are searched across error.log AND error.N.log.
# cw_core_l_*.yml / cw_settings_l_*.yml are ENGINE (clausewitz) files, not this mod - exclude them.
emit error_log_cw_lines "$( cat "$ERR" "$LOGDIR"/error.[0-9]*.log 2>/dev/null | grep -a 'cw_' | grep -a -v -c 'cw_core_l_\|cw_settings_l_' || true )"
emit error_top_sources "$( [ -f "$ERR" ] && grep -a -o '^\[[0-9:]*\]\[[^]]*\]' "$ERR" | sed 's/^\[[0-9:]*\]//' | sort | uniq -c | sort -rn | head -n 3 | awk '{ s = s (s==""?"":", ") $2 ":" $1 } END { print s }' )"
emit gui_log_lines "$(lines "$GUI")"
emit gui_log_cw_lines "$(cnt 'cw_' "$GUI")"
emit debug_log_lines "$(lines "$DBG")"
emit debug_cw_lines "$( [ -f "$DBG" ] && { grep -a 'cw_' "$DBG" | grep -a -v -c 'cw_core_l_\|cw_settings_l_' || true; } || echo 0 )"
emit debug_concentrated_warfare_mentions "$(cnt 'concentrated_warfare' "$DBG")"
emit debug_bom_warnings "$(cnt 'should be in utf8-bom encoding' "$DBG")"
emit debug_duplicate_loc_keys "$(cnt 'Duplicate localization key' "$DBG")"
emit debug_loc_keys_multi_defined "$(cnt 'defined in multiple files' "$DBG")"
emit debug_define_missing "$(cnt 'Maybe a define macro is missing' "$DBG")"
emit debug_postvalidate_false "$(cnt 'PostValidate of trigger' "$DBG")"
emit debug_loc_data_errors "$(cnt 'Data error in loc string' "$DBG")"

# ------------------------------------------------------------------ output
case "$MODE" in
  tsv) cat "$OUT" ;;
  compare)
    printf '%-36s %16s %16s  %s\n' "metric" "base" "now" "delta"
    awk -F'\t' 'NR==FNR { if ($1!="#") b[$1]=$2; next }
      $1=="#" { print ""; print "== " $2 " =="; next }
      { bv=($1 in b) ? b[$1] : "-"; nv=$2; d=""
        if (bv ~ /^-?[0-9]+(\.[0-9]+)?$/ && nv ~ /^-?[0-9]+(\.[0-9]+)?$/) {
          d=sprintf("%+g", nv-bv); if (bv+0!=0) d=d sprintf(" (%+.1f%%)", (nv-bv)/bv*100) }
        else if (bv!=nv) d="changed"
        printf "%-36s %16s %16s  %s\n", $1, substr(bv,1,16), substr(nv,1,16), d }' "$COMPARE" "$OUT" ;;
  *)
    awk -F'\t' '$1=="#" { if ($2=="by_year") next; print ""; print "== " $2 " =="; next }
                $1 ~ /^year\./ { next }                       # the per-year keys are printed as a table below
                { printf "%-36s %s\n", $1, $2 }' "$OUT"
    if [ -s "$TMP/byyear.tsv" ]; then
      printf '\n%-6s %6s %10s %8s %11s %14s\n' year wars civil_wars revolts ai_invalid ai_inv_army
      awk -F'\t' '{ printf "%-6s %6d %10d %8d %11d %14d\n", $1, $2, $3, $4, $5, $6 }' "$TMP/byyear.tsv"
    fi ;;
esac

# ------------------------------------------------------------------ snapshot
if [ -n "$SNAP" ]; then
  dest="$SNAPROOT/$SNAP"; mkdir -p "$dest"
  for f in ai.log game.log performance_degradation.log dedicated_server.log multiplayer.log error.log gui.log setup.log code_revisions.log system.log; do
    [ -f "$LOGDIR/$f" ] && cp "$LOGDIR/$f" "$dest/"
  done
  for f in "$LOGDIR"/error.[0-9]*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$CONT" ] && cp "$CONT" "$dest/continue_game.json"
  [ "$WITH_DEBUG" = 1 ] && [ -f "$DBG" ] && cp "$DBG" "$dest/"
  cp "$OUT" "$dest/metrics.tsv"
  echo "" >&2; echo "snapshot written to $dest (metrics.tsv + $(ls "$dest" | wc -l | tr -d ' ') files; *.log are git-ignored)" >&2
fi
