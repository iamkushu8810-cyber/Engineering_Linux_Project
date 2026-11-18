#!/usr/bin/env bash
# =============================================================
#  setup.sh — prepares the project environment
#  Checks tools, creates folders, sets permissions, seeds logs.
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

banner
title "SETUP — environment preparation"

step "1/4 Checking required tools"
for cmd in bash awk sed grep sort cut head tail tar date wc tr; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '    %s✔%s %s\n' "$GREEN" "$RESET" "$cmd"
  else
    die "Missing required tool: $cmd"
  fi
done
if command -v python3 >/dev/null 2>&1; then
  printf '    %s✔%s python3 (%s)\n' "$GREEN" "$RESET" "$(python3 --version 2>&1)"
else
  log_warn "python3 not found — analyze/report steps will not work (sudo apt install python3)"
fi

step "2/4 Creating directory structure"
for d in data/raw data/processed scripts logs config python results tests docs backups; do
  mkdir -p "$ROOT_DIR/$d"
  printf '    %s✔%s %s/\n' "$GREEN" "$RESET" "$d"
done

step "3/4 Setting permissions"
chmod +x "$ROOT_DIR"/scripts/*.sh
chmod 750 "$ROOT_DIR/backups"
log_info "Scripts are executable; backups/ is restricted to owner and group (750)"

step "4/4 Initialising log files"
touch "$SYSTEM_LOG" "$MONITOR_LOG" "$ERROR_LOG"
_log INFO "Setup complete | host=$(hostname) | kernel=$(uname -r) | user=${USER:-unknown} | shell=$BASH_VERSION"
log_info "Logs ready in logs/ (system.log, monitor.log, error.log)"

printf '\n%sSetup finished.%s Next: %smake collect%s (or %smake all%s)\n' "$GREEN$BOLD" "$RESET" "$BOLD" "$RESET" "$BOLD" "$RESET"
