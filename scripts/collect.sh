#!/usr/bin/env bash
# =============================================================
#  collect.sh — generates simulated heart-rate sensor readings
#  Usage: scripts/collect.sh [number_of_samples]
#  Output: data/raw/sensor_data.csv  +  data/raw/sample_data.txt
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

title "COLLECT — acquiring sensor data"
require_cmd awk

SAMPLES="${1:-$SAMPLE_COUNT}"
[[ "$SAMPLES" =~ ^[1-9][0-9]*$ ]] || die "Sample count must be a positive integer (got: '$SAMPLES')"

mkdir -p "$(dirname "$RAW_FILE")"
TMP_FILE="$(mktemp)"
START=$(( $(date +%s) - SAMPLES * SAMPLE_INTERVAL_SEC ))

step "Generating $SAMPLES readings (1 every ${SAMPLE_INTERVAL_SEC}s of simulated time)"
{
  echo "timestamp,sample_id,bpm"
  # awk simulates a realistic heart rate: a smooth random walk around 72 BPM
  # with occasional tachycardia / bradycardia spikes.
  awk -v n="$SAMPLES" -v seed="${SEED:-$RANDOM$RANDOM}" '
    BEGIN {
      srand(seed); b = 72
      for (i = 1; i <= n; i++) {
        b += (rand() - 0.5) * 5
        if (b < 62) b = 62 + rand() * 3
        if (b > 88) b = 88 - rand() * 3
        v = b; r = rand()
        if      (r < 0.01) v = 142 + rand() * 22
        else if (r < 0.02) v = 36  + rand() * 8
        else if (r < 0.05) v = 102 + rand() * 22
        else if (r < 0.08) v = 50  + rand() * 9
        printf "%d\n", v
      }
    }' | {
      i=0
      while read -r bpm; do
        i=$((i + 1))
        printf '%(%Y-%m-%d %H:%M:%S)T,%04d,%d\n' "$((START + i * SAMPLE_INTERVAL_SEC))" "$i" "$bpm"
      done
    }
} > "$TMP_FILE"
mv "$TMP_FILE" "$RAW_FILE"

# Human-readable sample (first 10 readings, tab separated)
head -n 11 "$RAW_FILE" | tr ',' '\t' > "$SAMPLE_FILE"

rows=$(( $(wc -l < "$RAW_FILE") - 1 ))
log_info "Saved $rows readings  →  data/raw/sensor_data.csv"
log_info "Saved preview         →  data/raw/sample_data.txt"

step "Preview (first 5 rows)"
head -n 6 "$RAW_FILE" | sed 's/^/    /'
