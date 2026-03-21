/**
 * Shopify Deploy Worker
 *
 * Safe deployment workflow for Shopify theme pushes.
 * Provides backup, push, publish, settings, and status endpoints.
 */

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build the base URL for Shopify Admin REST API calls. */
function shopifyBase(env) {
  return `https://${env.SHOPIFY_STORE}/admin/api/${env.SHOPIFY_API_VERSION}`;
}

// In-memory token cache (per isolate)
let _cachedToken = null;
let _tokenExpiresAt = 0;

/**
 * Get a valid Shopify access token via OAuth Client Credentials Grant.
 * Tokens are cached in memory and refreshed when expired.
 */
async function getAccessToken(env) {
  const now = Date.now();

  // Return cached token if still valid (with 5min buffer)
  if (_cachedToken && _tokenExpiresAt > now + 300_000) {
    return _cachedToken;
  }

  // Exchange client credentials for access token
  const res = await fetch(`https://${env.SHOPIFY_STORE}/admin/oauth/access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: env.SHOPIFY_CLIENT_ID,
      client_secret: env.SHOPIFY_CLIENT_SECRET,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OAuth token exchange failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  _cachedToken = data.access_token;
  _tokenExpiresAt = now + (data.expires_in || 86399) * 1000;

  return _cachedToken;
}

/** Standard headers for Shopify API requests (with auto-refreshing token). */
async function shopifyHeaders(env) {
  const token = await getAccessToken(env);
  return {
    'X-Shopify-Access-Token': token,
    'Content-Type': 'application/json',
  };
}

/** Add CORS headers to every response. */
function corsHeaders(env) {
  const origin = env.ALLOWED_ORIGIN || '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

/** Convenience: JSON response with CORS. */
function jsonResponse(body, status, env) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(env) },
  });
}

/** Sleep helper for rate-limit back-off. */
function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

/**
 * Fetch all assets from a Shopify theme.
 * Handles pagination automatically.
 */
async function fetchAllAssets(env, themeId) {
  const url = `${shopifyBase(env)}/themes/${themeId}/assets.json`;
  const res = await fetch(url, { headers: await shopifyHeaders(env) });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to list assets (${res.status}): ${text}`);
  }
  const data = await res.json();
  return data.assets; // array of { key, ... }
}

/**
 * Fetch the content of a single asset.
 * Returns { key, value } for text assets or { key, public_url } for binary.
 */
async function fetchAssetContent(env, themeId, key) {
  const url = `${shopifyBase(env)}/themes/${themeId}/assets.json?asset[key]=${encodeURIComponent(key)}`;
  const res = await fetch(url, { headers: await shopifyHeaders(env) });
  if (!res.ok) {
    // Some assets (e.g. binaries served via CDN) may 404 on direct fetch.
    return null;
  }
  const data = await res.json();
  return data.asset;
}

// ---------------------------------------------------------------------------
// In-memory registry of themes pushed via /push (persists per isolate only;
// for durable tracking you could extend KV usage).
// We also store this in KV under a well-known key so it survives restarts.
// ---------------------------------------------------------------------------

const PUSHED_THEMES_KEY = '__pushed_themes__';

async function getPushedThemes(env) {
  try {
    const raw = await env.BACKUPS.get(PUSHED_THEMES_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

async function markThemePushed(env, themeId, name) {
  const themes = await getPushedThemes(env);
  themes[String(themeId)] = { name, pushedAt: new Date().toISOString() };
  await env.BACKUPS.put(PUSHED_THEMES_KEY, JSON.stringify(themes));
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

/**
 * POST /backup
 *
 * Pulls ALL assets from the live theme and stores them in KV.
 * Returns backup ID and timestamp.
 */
async function handleBackup(env) {
  const themeId = env.LIVE_THEME_ID;

  // 1. List all assets
  const assetList = await fetchAllAssets(env, themeId);

  // 2. Fetch each asset's content (with light rate-limit courtesy)
  const assets = {};
  let fetched = 0;
  for (const asset of assetList) {
    const content = await fetchAssetContent(env, themeId, asset.key);
    if (content) {
      assets[asset.key] = {
        value: content.value || null,
        public_url: content.public_url || null,
        content_type: content.content_type || null,
      };
    }
    fetched++;
    // Shopify REST rate limit is 2 req/s for basic plans; pause every 2 reqs
    if (fetched % 2 === 0) await sleep(550);
  }

  // 3. Store in KV
  const backupId = `backup_${Date.now()}`;
  const backupData = {
    id: backupId,
    themeId,
    timestamp: new Date().toISOString(),
    assetCount: Object.keys(assets).length,
    assets,
  };

  // KV max value size is 25 MiB; large themes may need chunking.
  await env.BACKUPS.put(backupId, JSON.stringify(backupData), {
    expirationTtl: 60 * 60 * 24 * 30, // keep 30 days
  });

  // Also store as "latest"
  await env.BACKUPS.put('backup_latest', backupId);

  return jsonResponse(
    {
      ok: true,
      backupId,
      timestamp: backupData.timestamp,
      assetCount: backupData.assetCount,
    },
    200,
    env
  );
}

/**
 * POST /push
 *
 * Creates a new unpublished theme and uploads the provided files.
 * Rejects if settings_data.json is included.
 *
 * Body: { files: { "templates/index.json": "...", ... }, name?: "My Test Theme" }
 */
async function handlePush(request, env) {
  const body = await request.json();
  const { files, name } = body;

  if (!files || typeof files !== 'object' || Object.keys(files).length === 0) {
    return jsonResponse({ ok: false, error: 'Missing or empty "files" object.' }, 400, env);
  }

  // Block settings_data.json
  const blocked = Object.keys(files).find((k) =>
    k.toLowerCase().includes('settings_data.json')
  );
  if (blocked) {
    return jsonResponse(
      {
        ok: false,
        error:
          'settings_data.json must not be pushed via /push. Use the /settings endpoint instead.',
      },
      400,
      env
    );
  }

  // 1. Create a new unpublished theme
  const themeName = name || `Deploy Preview ${new Date().toISOString().slice(0, 16)}`;
  const createRes = await fetch(`${shopifyBase(env)}/themes.json`, {
    method: 'POST',
    headers: await shopifyHeaders(env),
    body: JSON.stringify({ theme: { name: themeName, role: 'unpublished' } }),
  });

  if (!createRes.ok) {
    const text = await createRes.text();
    return jsonResponse(
      { ok: false, error: `Failed to create theme (${createRes.status}): ${text}` },
      502,
      env
    );
  }

  const { theme } = await createRes.json();
  const newThemeId = theme.id;

  // 2. Upload each file as an asset
  const results = [];
  let idx = 0;
  for (const [key, value] of Object.entries(files)) {
    const putRes = await fetch(`${shopifyBase(env)}/themes/${newThemeId}/assets.json`, {
      method: 'PUT',
      headers: await shopifyHeaders(env),
      body: JSON.stringify({ asset: { key, value } }),
    });
    results.push({ key, status: putRes.status, ok: putRes.ok });
    idx++;
    if (idx % 2 === 0) await sleep(550);
  }

  // 3. Track this theme as pushed
  await markThemePushed(env, newThemeId, themeName);

  const previewUrl = `https://${env.SHOPIFY_STORE}/?preview_theme_id=${newThemeId}`;

  return jsonResponse(
    {
      ok: true,
      themeId: newThemeId,
      themeName,
      previewUrl,
      filesUploaded: results,
    },
    200,
    env
  );
}

/**
 * POST /publish
 *
 * Publishes a previously pushed theme (makes it live).
 * Only allows themes that were created through /push.
 *
 * Body: { theme_id: 123456 }
 */
async function handlePublish(request, env) {
  const body = await request.json();
  const { theme_id } = body;

  if (!theme_id) {
    return jsonResponse({ ok: false, error: 'Missing "theme_id".' }, 400, env);
  }

  // Verify the theme was pushed via /push
  const pushed = await getPushedThemes(env);
  if (!pushed[String(theme_id)]) {
    return jsonResponse(
      {
        ok: false,
        error: `Theme ${theme_id} was not pushed via /push. Publishing is only allowed for themes created through this worker.`,
      },
      403,
      env
    );
  }

  // Publish by setting role to "main"
  const res = await fetch(`${shopifyBase(env)}/themes/${theme_id}.json`, {
    method: 'PUT',
    headers: await shopifyHeaders(env),
    body: JSON.stringify({ theme: { id: theme_id, role: 'main' } }),
  });

  if (!res.ok) {
    const text = await res.text();
    return jsonResponse(
      { ok: false, error: `Failed to publish theme (${res.status}): ${text}` },
      502,
      env
    );
  }

  const data = await res.json();

  return jsonResponse(
    {
      ok: true,
      message: `Theme ${theme_id} is now live.`,
      theme: { id: data.theme.id, name: data.theme.name, role: data.theme.role },
    },
    200,
    env
  );
}

/**
 * POST /settings
 *
 * Safely updates settings_data.json via string replacements.
 * Fetches the current live version, applies replacements, PUTs it back.
 *
 * Body: { replacements: { "#oldcolor": "#newcolor", "OLDTEXT": "NEWTEXT" } }
 */
async function handleSettings(request, env) {
  const body = await request.json();
  const { replacements } = body;

  if (!replacements || typeof replacements !== 'object' || Object.keys(replacements).length === 0) {
    return jsonResponse({ ok: false, error: 'Missing or empty "replacements" object.' }, 400, env);
  }

  const themeId = env.LIVE_THEME_ID;
  const assetKey = 'config/settings_data.json';

  // 1. Fetch current settings_data.json
  const asset = await fetchAssetContent(env, themeId, assetKey);
  if (!asset || !asset.value) {
    return jsonResponse(
      { ok: false, error: 'Could not fetch settings_data.json from live theme.' },
      502,
      env
    );
  }

  // 2. Apply replacements
  let modified = asset.value;
  const applied = [];
  for (const [search, replace] of Object.entries(replacements)) {
    const count = (modified.split(search).length - 1);
    if (count > 0) {
      modified = modified.split(search).join(replace);
      applied.push({ search, replace, occurrences: count });
    } else {
      applied.push({ search, replace, occurrences: 0, warning: 'Not found in settings' });
    }
  }

  // 3. Validate the result is still valid JSON
  try {
    JSON.parse(modified);
  } catch (e) {
    return jsonResponse(
      {
        ok: false,
        error: 'Replacements produced invalid JSON. Aborting.',
        details: e.message,
        applied,
      },
      400,
      env
    );
  }

  // 4. PUT the modified version back
  const putRes = await fetch(`${shopifyBase(env)}/themes/${themeId}/assets.json`, {
    method: 'PUT',
    headers: await shopifyHeaders(env),
    body: JSON.stringify({ asset: { key: assetKey, value: modified } }),
  });

  if (!putRes.ok) {
    const text = await putRes.text();
    return jsonResponse(
      { ok: false, error: `Failed to update settings_data.json (${putRes.status}): ${text}` },
      502,
      env
    );
  }

  return jsonResponse(
    {
      ok: true,
      message: 'settings_data.json updated successfully.',
      applied,
    },
    200,
    env
  );
}

/**
 * GET /status
 *
 * Returns current live theme info, test theme info, and last backup timestamp.
 */
async function handleStatus(env) {
  // 1. Fetch all themes
  const res = await fetch(`${shopifyBase(env)}/themes.json`, {
    headers: await shopifyHeaders(env),
  });

  if (!res.ok) {
    const text = await res.text();
    return jsonResponse(
      { ok: false, error: `Failed to fetch themes (${res.status}): ${text}` },
      502,
      env
    );
  }

  const { themes } = await res.json();

  const liveTheme = themes.find((t) => t.role === 'main') || null;
  const unpublishedThemes = themes.filter((t) => t.role === 'unpublished');

  // 2. Get pushed themes registry
  const pushed = await getPushedThemes(env);

  // Mark which unpublished themes were pushed via this worker
  const testThemes = unpublishedThemes.map((t) => ({
    id: t.id,
    name: t.name,
    role: t.role,
    created_at: t.created_at,
    updated_at: t.updated_at,
    pushedViaWorker: !!pushed[String(t.id)],
    previewUrl: `https://${env.SHOPIFY_STORE}/?preview_theme_id=${t.id}`,
  }));

  // 3. Last backup
  let lastBackup = null;
  try {
    const latestId = await env.BACKUPS.get('backup_latest');
    if (latestId) {
      // Fetch just the metadata (avoid loading full asset blob)
      const raw = await env.BACKUPS.get(latestId);
      if (raw) {
        const parsed = JSON.parse(raw);
        lastBackup = {
          id: parsed.id,
          timestamp: parsed.timestamp,
          assetCount: parsed.assetCount,
        };
      }
    }
  } catch {
    // KV may not be bound in local dev
  }

  return jsonResponse(
    {
      ok: true,
      liveTheme: liveTheme
        ? {
            id: liveTheme.id,
            name: liveTheme.name,
            role: liveTheme.role,
            updated_at: liveTheme.updated_at,
          }
        : null,
      testThemes,
      lastBackup,
    },
    200,
    env
  );
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    // Handle CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    try {
      // Route matching
      if (method === 'POST' && pathname === '/backup') {
        return await handleBackup(env);
      }
      if (method === 'POST' && pathname === '/push') {
        return await handlePush(request, env);
      }
      if (method === 'POST' && pathname === '/publish') {
        return await handlePublish(request, env);
      }
      if (method === 'POST' && pathname === '/settings') {
        return await handleSettings(request, env);
      }
      if (method === 'GET' && pathname === '/status') {
        return await handleStatus(env);
      }

      // Fallback
      return jsonResponse(
        {
          ok: false,
          error: 'Not found',
          routes: {
            'POST /backup': 'Back up all live theme assets to KV',
            'POST /push': 'Push files to a new unpublished test theme',
            'POST /publish': 'Publish a previously pushed test theme',
            'POST /settings': 'Apply replacements to settings_data.json',
            'GET /status': 'Current theme status and last backup info',
          },
        },
        404,
        env
      );
    } catch (err) {
      return jsonResponse(
        { ok: false, error: err.message || 'Internal server error' },
        500,
        env
      );
    }
  },
};
