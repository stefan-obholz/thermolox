#!/bin/bash
# CLIMALOX Supabase Backup - Exports all tables as JSON daily
set -euo pipefail

BACKUP_DIR="/Users/stefanobholz/Projekte/thermolox/backups/supabase"
DATE=$(date +%Y-%m-%d_%H%M)
TARGET="$BACKUP_DIR/$DATE"
SUPABASE_URL="https://xivtfgyvpqckfwwyloub.supabase.co"
SUPABASE_KEY=$(python3 -c "import json; print(json.load(open('$(dirname "$0")/supabase.json'))['SUPABASE_ANON_KEY'])")

mkdir -p "$TARGET"

TABLES=(
  palette_colors
  plans
  plan_features
  profiles
  projects
  project_items
  project_measurements
  user_credits
  credit_ledger
  credit_consumptions
  user_entitlements
  user_subscriptions
  user_consents
  user_devices
  feature_usage
  push_tokens
  chat_contacts
  analytics_events
  translation_glossary
  stripe_customers
  stripe_webhook_events
)

OK=0
FAIL=0

for TABLE in "${TABLES[@]}"; do
  HTTP_CODE=$(curl -s -o "$TARGET/${TABLE}.json" -w "%{http_code}" \
    "${SUPABASE_URL}/rest/v1/${TABLE}?limit=10000" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)

  if [[ "$HTTP_CODE" == "200" ]]; then
    ROWS=$(python3 -c "import json; print(len(json.load(open('$TARGET/${TABLE}.json'))))" 2>/dev/null || echo "?")
    echo "OK    ${TABLE} (${ROWS} rows)"
    ((OK++))
  else
    echo "FAIL  ${TABLE} (HTTP ${HTTP_CODE})"
    rm -f "$TARGET/${TABLE}.json"
    ((FAIL++))
  fi
done

echo "---"
echo "Backup: $TARGET"
echo "Result: $OK OK, $FAIL failed"
echo "$(date): $OK tables backed up" >> "$BACKUP_DIR/last-backup.log"

# Keep only last 14 backups
cd "$BACKUP_DIR" && ls -dt */ 2>/dev/null | tail -n +15 | xargs rm -rf 2>/dev/null || true
