#!/bin/bash
# EVERLOXX Theme Backup - Pulls current online theme state daily
BACKUP_DIR="/Users/stefanobholz/Projekte/thermolox/backups/everloxx"
DATE=$(date +%Y-%m-%d_%H%M)
TARGET="$BACKUP_DIR/$DATE"

mkdir -p "$TARGET"

npx shopify theme pull \
  --path "$TARGET" \
  --store thermolox \
  --theme 185262768469 \
  2>&1 | tee "$BACKUP_DIR/last-backup.log"

# Keep only the last 14 backups
cd "$BACKUP_DIR" && ls -dt */ 2>/dev/null | tail -n +15 | xargs rm -rf

echo "Backup completed: $TARGET"
