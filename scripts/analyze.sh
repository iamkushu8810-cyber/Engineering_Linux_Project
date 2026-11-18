#!/usr/bin/env bash
# =============================================================
#  analyze.sh — cleans raw data, extracts abnormal readings and
#  runs the Python statistics engine.
#  Output: data/processed/*  +  results/summary.txt
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

title "ANALYZE — cleaning, filtering, statistics"
require_file "$RAW_FILE"
require_cmd python3
mkdir -p "$(dirname "$CLEAN_FILE")" "$RESULTS_DIR"

step "1/4 Cleaning raw data  (sed + awk)"
total_rows=$(( $(wc -l < "$RAW_FILE") - 1 ))
# strip Windows line-endings, drop blank/malformed rows and impossible BPM values
sed 's/\r$//' "$RAW_FILE" | awk -F, -v lo="$VALID_MIN" -v hi="$VALID_MAX" '
  NR == 1 { print; next }
  NF == 3 && $3 ~ /^[0-9]+$/ && $3 + 0 >= lo && $3 + 0 <= hi { print }
' > "$CLEAN_FILE"
kept=$(( $(wc -l < "$CLEAN_FILE") - 1 ))
dropped=$(( total_rows - kept ))
log_info "Rows read: $total_rows | kept: $kept | dropped: $dropped  →  data/processed/cleaned_data.csv"

step "2/4 Extracting abnormal readings  (awk)"
awk -F, -v mn="$MIN_BPM" -v mx="$MAX_BPM" -v cl="$CRITICAL_LOW" -v ch="$CRITICAL_HIGH" '
  NR > 1 {
    s = "NORMAL"
    if ($3 <= cl || $3 >= ch) s = "CRITICAL"
    else if ($3 < mn || $3 > mx) s = "WARNING"
    if (s != "NORMAL") printf "%s | sample %s | %3d BPM | %s\n", $1, $2, $3, s
  }' "$CLEAN_FILE" > "$FILTERED_FILE"
abn=$(wc -l < "$FILTERED_FILE")
log_info "Found $abn abnormal reading(s)  →  data/processed/filtered_data.txt"

step "3/4 Quick look with sort / cut / head"
{
  printf '    %sTop 5 highest readings (timestamp, BPM):%s\n' "$BOLD" "$RESET"
  tail -n +2 "$CLEAN_FILE" | sort -t, -k3,3nr | head -n 5 | cut -d, -f1,3 | sed 's/^/      /'
  printf '    %sTop 5 lowest readings (timestamp, BPM):%s\n' "$BOLD" "$RESET"
  tail -n +2 "$CLEAN_FILE" | sort -t, -k3,3n  | head -n 5 | cut -d, -f1,3 | sed 's/^/      /'
} || true

step "4/4 Running Python statistics engine"
python3 "$ROOT_DIR/python/analysis.py" --input "$CLEAN_FILE" --output "$SUMMARY_FILE" --quiet
log_info "Summary written  →  results/summary.txt"
echo
grep -E '^ +(Samples|Mean|Median|Minimum|Maximum|Std deviation|Resting|Assessment)' "$SUMMARY_FILE" | sed 's/^/  /' || true
