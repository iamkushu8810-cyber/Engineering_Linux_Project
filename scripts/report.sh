#!/usr/bin/env bash
# =============================================================
#  report.sh — builds the final formatted report
#  Output: results/report.txt
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

title "REPORT — generating final report"
require_cmd python3
require_file "$CLEAN_FILE"
[[ -f "$ALERTS_FILE" ]] || die "results/alerts.txt not found — run: make monitor"

python3 "$ROOT_DIR/python/report.py" --input "$CLEAN_FILE" --alerts "$ALERTS_FILE" --output "$REPORT_FILE" --quiet
log_info "Report written  →  results/report.txt ($(wc -l < "$REPORT_FILE") lines)"
echo
cat "$REPORT_FILE"
