# Shopify Deploy Worker

Cloudflare Worker providing a safe deployment workflow for Shopify theme pushes on `thermolox.myshopify.com`.

## Setup

```bash
cd workers/shopify-deploy
npm install

# Create the KV namespace and update wrangler.toml with the returned ID
wrangler kv namespace create BACKUPS

# (Optional) Move the API token to a secret instead of wrangler.toml [vars]:
#   1. Remove SHOPIFY_API_TOKEN from [vars] in wrangler.toml
#   2. Run: wrangler secret put SHOPIFY_API_TOKEN

# Local dev
npm run dev

# Deploy
npm run deploy
```

## Endpoints

### `GET /status`

Returns live theme info, unpublished test themes, and last backup timestamp.

```bash
curl http://localhost:8787/status
```

### `POST /backup`

Pulls all assets from the live theme and stores them in KV.

```bash
curl -X POST http://localhost:8787/backup
```

Response:
```json
{
  "ok": true,
  "backupId": "backup_1710900000000",
  "timestamp": "2026-03-20T12:00:00.000Z",
  "assetCount": 42
}
```

### `POST /push`

Creates a new unpublished theme with the provided files. Rejects `settings_data.json`.

```bash
curl -X POST http://localhost:8787/push \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Test Deploy",
    "files": {
      "templates/index.json": "{\"sections\":{},\"order\":[]}",
      "assets/custom.css": "body { color: red; }"
    }
  }'
```

Response:
```json
{
  "ok": true,
  "themeId": 192837465,
  "themeName": "My Test Deploy",
  "previewUrl": "https://thermolox.myshopify.com/?preview_theme_id=192837465",
  "filesUploaded": [
    { "key": "templates/index.json", "status": 200, "ok": true },
    { "key": "assets/custom.css", "status": 200, "ok": true }
  ]
}
```

### `POST /publish`

Publishes a test theme that was previously created via `/push`.

```bash
curl -X POST http://localhost:8787/publish \
  -H "Content-Type: application/json" \
  -d '{ "theme_id": 192837465 }'
```

### `POST /settings`

Safely updates `settings_data.json` via string replacements. Fetches the current live version, applies replacements, validates the result is still valid JSON, and PUTs it back.

```bash
curl -X POST http://localhost:8787/settings \
  -H "Content-Type: application/json" \
  -d '{
    "replacements": {
      "#ff0000": "#00ff00",
      "THERMOLOX": "EVERLOXX"
    }
  }'
```

Response:
```json
{
  "ok": true,
  "message": "settings_data.json updated successfully.",
  "applied": [
    { "search": "#ff0000", "replace": "#00ff00", "occurrences": 3 },
    { "search": "THERMOLOX", "replace": "EVERLOXX", "occurrences": 12 }
  ]
}
```

## Safety features

- `/push` rejects any attempt to include `settings_data.json` in the files payload
- `/publish` only allows themes that were created through `/push`
- `/settings` validates the modified JSON before writing it back
- `/backup` stores full theme snapshots in KV with 30-day TTL
- All responses include CORS headers for local development
