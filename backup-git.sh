#!/bin/bash
# EVERLOXX Git Backup - Commits all changes and pushes to GitHub daily
set -euo pipefail

cd /Users/stefanobholz/Projekte/thermolox

# Check if there are any changes
if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "$(date): No changes to backup"
  exit 0
fi

# Stage all changes (except secrets)
git add -A
git reset -- secrets .env 2>/dev/null || true

DATE=$(date +"%Y-%m-%d %H:%M:%S")
git commit -m "Backup ${DATE}" --no-gpg-sign 2>/dev/null || true

# Push to GitHub
git push origin main 2>&1 || echo "WARN: Push failed, will retry next run"

echo "$(date): Git backup completed"
