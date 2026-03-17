#!/bin/bash
# Setup script: Configures Shopify Admin Token, deploys Worker, registers Webhooks.
# Usage: ./setup-shopify-sync.sh <ADMIN_API_TOKEN>
set -euo pipefail

TOKEN="${1:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Usage: ./setup-shopify-sync.sh <SHOPIFY_ADMIN_API_TOKEN>"
  echo ""
  echo "Get the token from:"
  echo "  https://thermolox.myshopify.com/admin/settings/apps/development"
  exit 1
fi

WORKER_NAME="thermolox-proxy"
STORE="thermolox.myshopify.com"
WEBHOOK_URL="https://thermolox-proxy.stefan-obholz.workers.dev/webhook/sync"

echo "=== 1. Setting Worker Secret ==="
echo "$TOKEN" | npx wrangler secret put SHOPIFY_ADMIN_TOKEN --name "$WORKER_NAME"

echo ""
echo "=== 2. Deploying Worker ==="
cd "$(dirname "$0")"
npx wrangler deploy

echo ""
echo "=== 3. Registering Shopify Webhooks ==="

# Register webhooks for content changes
TOPICS=("pages/create" "pages/update" "articles/create" "articles/update" "products/update")

for TOPIC in "${TOPICS[@]}"; do
  echo -n "  Webhook: $TOPIC ... "

  MUTATION="{\"query\":\"mutation { webhookSubscriptionCreate(topic: $(echo "$TOPIC" | tr '/' '_' | tr '[:lower:]' '[:upper:]'), webhookSubscription: { callbackUrl: \\\"$WEBHOOK_URL\\\", format: JSON }) { webhookSubscription { id } userErrors { message } } }\"}"

  RESULT=$(curl -s -X POST "https://$STORE/admin/api/2024-10/graphql.json" \
    -H "Content-Type: application/json" \
    -H "X-Shopify-Access-Token: $TOKEN" \
    -d "$MUTATION")

  if echo "$RESULT" | grep -q '"id"'; then
    echo "OK"
  else
    ERROR=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errors',d.get('data',{}).get('webhookSubscriptionCreate',{}).get('userErrors','?')))" 2>/dev/null || echo "$RESULT")
    echo "WARN: $ERROR"
  fi
done

echo ""
echo "=== Done! ==="
echo "Content sync is now fully automatic:"
echo "  Shopify Save → Webhook → Worker → Supabase → App"
