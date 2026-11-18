#!/usr/bin/env bash
# =============================================================
#  backup.sh — timestamped, verified tar.gz backup of the project
#  Keeps only the newest KEEP_BACKUPS archives.
# =============================================================
set -Eeuo pipefail
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$ROOT_DIR/config/project.conf"; set +a
source "$ROOT_DIR/.config"

title "BACKUP — archiving the project"
require_cmd tar
mkdir -p "$BACKUP_DIR"

stamp="$(date +%Y%m%d_%H%M%S)"
archive="$BACKUP_DIR/heart_rate_project_${stamp}.tar.gz"

step "Creating archive"
tar --exclude='./backups' --exclude='__pycache__' -czf "$archive" -C "$ROOT_DIR" .
log_info "Created  →  backups/$(basename "$archive")"

step "Verifying archive integrity"
files=$(tar -tzf "$archive" | wc -l)
size=$(du -h "$archive" | cut -f1)
log_info "Archive OK: $files entries, $size"

step "Rotating old backups (keeping newest $KEEP_BACKUPS)"
# shellcheck disable=SC2012
ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f --
log_info "Backups stored: $(ls -1 "$BACKUP_DIR"/*.tar.gz | wc -l)"
