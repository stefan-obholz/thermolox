#!/usr/bin/env bash
# Synchronisiert alle Secrets aus der lokalen secrets-Datei in den Cloudflare Worker.
# Usage: ./sync-secrets.sh [--dry-run]
set -euo pipefail

SECRETS_FILE="$(dirname "$0")/secrets"
WORKER_NAME="thermolox-proxy"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Fehler: $SECRETS_FILE nicht gefunden."
  exit 1
fi

# Keys die als Worker Secrets gesetzt werden sollen
KEYS=(
  ANTHROPIC_API_KEY
  OPENAI_API_KEY
  SUPABASE_URL
  SUPABASE_ANON_KEY
  SUPABASE_SERVICE_ROLE_KEY
  WORKER_APP_TOKEN
  SHOPIFY_STOREFRONT_TOKEN
  STRIPE_SECRET_KEY
  STRIPE_WEBHOOK_SECRET
  FCM_SERVER_KEY
)

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Keine Secrets werden geschrieben."
fi

# Secrets-Datei parsen (KEY=VALUE, ignoriert Kommentare und HIER_EINTRAGEN)
declare -A secrets
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  [[ "$value" == "HIER_EINTRAGEN" || -z "$value" ]] && continue
  secrets["$key"]="$value"
done < "$SECRETS_FILE"

echo "Worker: $WORKER_NAME"
echo "---"

ok=0
skip=0
fail=0

for key in "${KEYS[@]}"; do
  if [[ -z "${secrets[$key]:-}" ]]; then
    echo "SKIP  $key (nicht gesetzt oder HIER_EINTRAGEN)"
    ((skip++))
    continue
  fi

  if $DRY_RUN; then
    echo "OK    $key (${#secrets[$key]} Zeichen)"
    ((ok++))
    continue
  fi

  if echo "${secrets[$key]}" | npx wrangler secret put "$key" --name "$WORKER_NAME" >/dev/null 2>&1; then
    echo "OK    $key"
    ((ok++))
  else
    echo "FAIL  $key"
    ((fail++))
  fi
done

echo "---"
echo "Ergebnis: $ok gesetzt, $skip uebersprungen, $fail fehlgeschlagen"
