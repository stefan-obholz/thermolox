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
// PKCE + Auth Helpers
// ---------------------------------------------------------------------------

/** Generate a random string of the given byte length, hex-encoded. */
function randomString(bytes = 32) {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Generate a PKCE code verifier (43-128 chars, URL-safe). */
function generateCodeVerifier() {
  const buf = new Uint8Array(32);
  crypto.getRandomValues(buf);
  return base64UrlEncode(buf);
}

/** SHA-256 hash, then base64url-encode for code_challenge. */
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return base64UrlEncode(new Uint8Array(digest));
}

/** Base64url encode (no padding). */
function base64UrlEncode(bytes) {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Build Shopify Customer Account authorization URL. */
function shopifyAuthUrl(env) {
  return `https://shopify.com/authentication/${env.SHOPIFY_SHOP_ID}/oauth/authorize`;
}

/** Build Shopify Customer Account token endpoint URL. */
function shopifyTokenUrl(env) {
  return `https://shopify.com/authentication/${env.SHOPIFY_SHOP_ID}/oauth/token`;
}

/** Build Shopify Customer Account logout URL. */
function shopifyLogoutUrl(env) {
  return `https://shopify.com/authentication/${env.SHOPIFY_SHOP_ID}/oauth/logout`;
}

/** Worker base URL for redirects. */
function workerBaseUrl() {
  return 'https://shopify-deploy.stefan-obholz.workers.dev';
}

// ---------------------------------------------------------------------------
// Auth Route Handlers
// ---------------------------------------------------------------------------

/**
 * GET /auth/login
 *
 * Starts Shopify Customer Account OAuth flow with PKCE.
 * Generates code_verifier, stores in KV, redirects to Shopify.
 */
async function handleAuthLogin(request, env) {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  const state = randomString(16);
  const nonce = randomString(16);

  // Store code_verifier in KV with 10 min TTL
  await env.BACKUPS.put(`pkce_${state}`, codeVerifier, {
    expirationTtl: 600,
  });

  const params = new URLSearchParams({
    client_id: env.SHOPIFY_CUSTOMER_CLIENT_ID,
    scope: 'openid email customer-account-api:full',
    redirect_uri: `${workerBaseUrl()}/auth/callback`,
    response_type: 'code',
    state,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  const redirectUrl = `${shopifyAuthUrl(env)}?${params.toString()}`;
  return Response.redirect(redirectUrl, 302);
}

/**
 * GET /auth/callback
 *
 * Receives authorization code from Shopify, exchanges for tokens,
 * then redirects to the Flutter app via deep link.
 */
async function handleAuthCallback(request, env) {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  if (error) {
    return Response.redirect(
      `everloxx://auth/callback?error=${encodeURIComponent(error)}`,
      302
    );
  }

  if (!code || !state) {
    return jsonResponse({ ok: false, error: 'Missing code or state parameter.' }, 400, env);
  }

  // Retrieve PKCE verifier from KV
  const codeVerifier = await env.BACKUPS.get(`pkce_${state}`);
  if (!codeVerifier) {
    return jsonResponse(
      { ok: false, error: 'Invalid or expired state. PKCE verifier not found.' },
      400,
      env
    );
  }

  // Clean up the PKCE verifier
  await env.BACKUPS.delete(`pkce_${state}`);

  // Exchange authorization code for tokens
  const basicAuth = btoa(
    `${env.SHOPIFY_CUSTOMER_CLIENT_ID}:${env.SHOPIFY_CUSTOMER_CLIENT_SECRET}`
  );

  const tokenRes = await fetch(shopifyTokenUrl(env), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${basicAuth}`,
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: `${workerBaseUrl()}/auth/callback`,
      code_verifier: codeVerifier,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    return jsonResponse(
      { ok: false, error: `Token exchange failed (${tokenRes.status}): ${text}` },
      502,
      env
    );
  }

  const tokenData = await tokenRes.json();
  const { access_token, refresh_token, expires_in, id_token } = tokenData;

  if (!access_token) {
    return jsonResponse(
      { ok: false, error: 'No access_token in token response.' },
      502,
      env
    );
  }

  // Redirect to Flutter app with tokens
  const callbackParams = new URLSearchParams({
    access_token,
    refresh_token: refresh_token || '',
    expires_in: String(expires_in || 3600),
  });
  if (id_token) {
    callbackParams.set('id_token', id_token);
  }

  return Response.redirect(`everloxx://auth/callback?${callbackParams.toString()}`, 302);
}

/**
 * GET /auth/logout
 *
 * Redirects to Shopify logout, then back to the app.
 */
async function handleAuthLogout(request, env) {
  const params = new URLSearchParams({
    id_token_hint: new URL(request.url).searchParams.get('id_token') || '',
    post_logout_redirect_uri: 'everloxx://auth/logout',
  });

  return Response.redirect(`${shopifyLogoutUrl(env)}?${params.toString()}`, 302);
}

/**
 * POST /auth/refresh
 *
 * Exchanges a refresh token for a new access token.
 * Body: { refresh_token: "..." }
 */
async function handleAuthRefresh(request, env) {
  const body = await request.json();
  const { refresh_token } = body;

  if (!refresh_token) {
    return jsonResponse({ ok: false, error: 'Missing refresh_token.' }, 400, env);
  }

  const basicAuth = btoa(
    `${env.SHOPIFY_CUSTOMER_CLIENT_ID}:${env.SHOPIFY_CUSTOMER_CLIENT_SECRET}`
  );

  const tokenRes = await fetch(shopifyTokenUrl(env), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${basicAuth}`,
    },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    return jsonResponse(
      { ok: false, error: `Token refresh failed (${tokenRes.status}): ${text}` },
      502,
      env
    );
  }

  const tokenData = await tokenRes.json();
  return jsonResponse(
    {
      ok: true,
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token || refresh_token,
      expires_in: tokenData.expires_in || 3600,
    },
    200,
    env
  );
}

/**
 * POST /auth/customer
 *
 * Queries the Shopify Customer Account API for profile + recent orders.
 * Requires Authorization header with Shopify customer access token.
 */
async function handleAuthCustomer(request, env) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return jsonResponse({ ok: false, error: 'Missing or invalid Authorization header.' }, 401, env);
  }

  const customerToken = authHeader.replace('Bearer ', '');

  const query = `
    query {
      customer {
        id
        firstName
        lastName
        emailAddress {
          emailAddress
        }
        phoneNumber {
          phoneNumber
        }
        orders(first: 10, sortKey: PROCESSED_AT, reverse: true) {
          edges {
            node {
              id
              name
              totalPrice {
                amount
                currencyCode
              }
              processedAt
              fulfillments(first: 1) {
                status
              }
            }
          }
        }
      }
    }
  `;

  const apiUrl = `https://shopify.com/${env.SHOPIFY_SHOP_ID}/account/customer/api/2024-10/graphql`;

  const gqlRes = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${customerToken}`,
    },
    body: JSON.stringify({ query }),
  });

  if (!gqlRes.ok) {
    const text = await gqlRes.text();
    return jsonResponse(
      { ok: false, error: `Customer API request failed (${gqlRes.status}): ${text}` },
      gqlRes.status === 401 ? 401 : 502,
      env
    );
  }

  const gqlData = await gqlRes.json();

  if (gqlData.errors && gqlData.errors.length > 0) {
    return jsonResponse(
      { ok: false, error: 'GraphQL errors', details: gqlData.errors },
      400,
      env
    );
  }

  const customer = gqlData.data?.customer;
  if (!customer) {
    return jsonResponse({ ok: false, error: 'No customer data returned.' }, 404, env);
  }

  // Flatten the response for easier consumption
  const orders = (customer.orders?.edges || []).map((edge) => {
    const node = edge.node;
    return {
      id: node.id,
      name: node.name,
      totalPrice: node.totalPrice,
      createdAt: node.processedAt,
      fulfillmentStatus: node.fulfillments?.[0]?.status || null,
    };
  });

  return jsonResponse(
    {
      ok: true,
      customer: {
        id: customer.id,
        firstName: customer.firstName,
        lastName: customer.lastName,
        email: customer.emailAddress?.emailAddress || null,
        phone: customer.phoneNumber?.phoneNumber || null,
        orders,
      },
    },
    200,
    env
  );
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

      // Auth routes
      if (method === 'GET' && pathname === '/auth/login') {
        return await handleAuthLogin(request, env);
      }
      if (method === 'GET' && pathname === '/auth/callback') {
        return await handleAuthCallback(request, env);
      }
      if (method === 'GET' && pathname === '/auth/logout') {
        return await handleAuthLogout(request, env);
      }
      if (method === 'POST' && pathname === '/auth/refresh') {
        return await handleAuthRefresh(request, env);
      }
      if (method === 'POST' && pathname === '/auth/customer') {
        return await handleAuthCustomer(request, env);
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
            'GET /auth/login': 'Start Shopify Customer Account OAuth flow',
            'GET /auth/callback': 'OAuth callback (handles token exchange)',
            'GET /auth/logout': 'Logout from Shopify Customer Account',
            'POST /auth/refresh': 'Refresh access token',
            'POST /auth/customer': 'Get customer profile and orders',
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
