#!/usr/bin/env bash
# =============================================================
#  monitor.sh — replays readings, classifies every one against
#  the thresholds in config/project.conf and raises alerts.
#  Usage: scripts/monitor.sh [--fast]
#  Output: logs/monitor.log  +  results/alerts.txt
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

FAST=0
if [[ "${1:-}" == "--fast" ]]; then FAST=1; fi

title "MONITOR — live threshold checking"
require_file "$RAW_FILE"
mkdir -p "$RESULTS_DIR"

{
  echo "# ALERTS — $PROJECT_NAME"
  echo "# Generated  : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "# Thresholds : normal ${MIN_BPM}-${MAX_BPM} BPM | critical <=${CRITICAL_LOW} or >=${CRITICAL_HIGH} BPM"
  echo
} > "$ALERTS_FILE"
echo "===== monitor run $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$MONITOR_LOG"

total=0; normal=0; warn=0; crit=0
printf '\n  %s%-19s %-6s %-8s %-9s %s%s\n' "$DIM" "TIMESTAMP" "ID" "BPM" "STATUS" "GRAPH" "$RESET"

while IFS=, read -r ts id bpm; do
  bpm="${bpm%$'\r'}"
  if ! [[ "$bpm" =~ ^[0-9]+$ ]]; then
    log_error "Skipping malformed row: '$ts,$id,$bpm'"
    continue
  fi
  total=$((total + 1))

  if   (( bpm <= CRITICAL_LOW || bpm >= CRITICAL_HIGH )); then
    status="CRITICAL"; color="$RED"; crit=$((crit + 1))
    echo "[$ts] [CRITICAL] sample $id: ${bpm} BPM (critical limits: <=${CRITICAL_LOW} / >=${CRITICAL_HIGH})" >> "$ALERTS_FILE"
  elif (( bpm < MIN_BPM || bpm > MAX_BPM )); then
    status="WARNING";  color="$YELLOW"; warn=$((warn + 1))
    echo "[$ts] [WARNING]  sample $id: ${bpm} BPM (normal range: ${MIN_BPM}-${MAX_BPM})" >> "$ALERTS_FILE"
  else
    status="NORMAL";   color="$GREEN"; normal=$((normal + 1))
  fi

  echo "$ts | sample $id | $(printf '%3d' "$bpm") BPM | $status" >> "$MONITOR_LOG"

  n=$((bpm / 5)); if (( n > 40 )); then n=40; fi
  printf -v bar '%*s' "$n" ''; bar=${bar// /█}
  printf '  %-19s %-6s %3d BPM  %s%-8s%s  %s%s%s\n' "$ts" "$id" "$bpm" "$color" "$status" "$RESET" "$color" "$bar" "$RESET"

  if (( FAST == 0 )); then sleep "$REPLAY_DELAY"; fi
done < <(tail -n +2 "$RAW_FILE")

(( total > 0 )) || die "No valid readings found in data/raw/sensor_data.csv"
[[ $crit -eq 0 && $warn -eq 0 ]] && echo "No alerts — all readings within the normal range." >> "$ALERTS_FILE"

title "MONITOR SUMMARY"
printf '    Readings checked : %d\n' "$total"
printf '    %sNormal%s           : %d (%d%%)\n'   "$GREEN"  "$RESET" "$normal" $(( 100 * normal / total ))
printf '    %sWarnings%s         : %d (%d%%)\n'   "$YELLOW" "$RESET" "$warn"   $(( 100 * warn   / total ))
printf '    %sCritical%s         : %d (%d%%)\n'   "$RED"    "$RESET" "$crit"   $(( 100 * crit   / total ))
echo
log_info "monitor.log updated   →  logs/monitor.log"
log_info "Alerts written        →  results/alerts.txt"
if (( crit > 0 )); then log_warn "$crit CRITICAL reading(s) detected — review results/alerts.txt"; fi
