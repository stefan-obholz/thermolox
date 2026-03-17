const ALLOWED_ORIGINS = [
  'https://climalox.de',
  'https://www.climalox.de',
  'https://thermolox.de',
  'https://www.thermolox.de',
  'https://thermolox.myshopify.com',
  'https://climalox-design.myshopify.com',
];

function getAllowedOrigin(request) {
  const origin = request.headers.get('Origin') || '';
  if (!origin) return null;
  if (ALLOWED_ORIGINS.includes(origin)) return origin;
  return null;
}

function getCorsHeaders(request) {
  const origin = getAllowedOrigin(request);
  return {
    'Access-Control-Allow-Origin': origin || ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Worker-Token, X-Platform',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  };
}

function decodeBase64ToBytes(input) {
  const cleaned = input.includes(',') ? input.split(',')[1] : input;
  const binary = atob(cleaned.trim());
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function guessImageType(dataUrl, fallback) {
  if (dataUrl.startsWith('data:image/jpeg')) return 'image/jpeg';
  if (dataUrl.startsWith('data:image/jpg')) return 'image/jpeg';
  if (dataUrl.startsWith('data:image/webp')) return 'image/webp';
  if (dataUrl.startsWith('data:image/png')) return 'image/png';
  return fallback;
}

async function fileFromImageUrl(url, fallbackName) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Image download failed: ${response.status}`);
  }
  const contentType =
    response.headers.get('content-type') ?? 'image/png';
  const bytes = await response.arrayBuffer();
  return new File([bytes], fallbackName, { type: contentType });
}

let _currentCors = {};

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ..._currentCors,
      'Content-Type': 'application/json',
    },
  });
}

function readAppToken(request) {
  const authHeader = request.headers.get('authorization') || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1];
  return (
    request.headers.get('x-worker-token') ||
    request.headers.get('x-app-token') ||
    ''
  );
}

function requireAppToken(request, env) {
  if (!env.WORKER_APP_TOKEN) {
    return jsonResponse(500, { error: 'Missing WORKER_APP_TOKEN.' });
  }
  const token = readAppToken(request);
  if (!token || token !== env.WORKER_APP_TOKEN) {
    return jsonResponse(401, { error: 'Unauthorized.' });
  }
  return null;
}

function getPlatform(request) {
  const platform = request.headers.get('X-Platform');
  if (platform) return platform;
  const origin = request.headers.get('Origin') || '';
  if (origin.includes('myshopify.com') || origin.includes('climalox') || origin.includes('thermolox')) return 'web';
  return 'app';
}

function buildPlatformContext(platform) {
  if (platform === 'web') {
    return (
      'PLATFORM: web\n' +
      'Du läufst auf der CLIMALOX Design Website. Verfügbare Features:\n' +
      '- Farbberatung und Empfehlungen (immer mit HEX-Codes)\n' +
      '- Produktempfehlungen mit BUTTONS\n' +
      '- Warenkorb-Aktionen via BUTTONS (der Client verarbeitet add_to_cart Buttons)\n' +
      '- Rich Color Cards (HEX-Codes werden automatisch als Farbkarten dargestellt)\n' +
      'NICHT verfügbar: Voice, Raum-Scan, Projekte, virtuelles Rendering, Skills/Skill-Blöcke.\n' +
      'Nutze BUTTONS: JSON für alle Aktionen. Für Warenkorb nutze: {"label":"In den Warenkorb","value":"add_to_cart","variant":"preferred","productHandle":"HANDLE_HERE"}'
    );
  }
  return (
    'PLATFORM: app\n' +
    'Du läufst in der CLIMALOX Design App. Alle Features verfügbar:\n' +
    'Voice, Skills, Rendering, Projekte, Farb-Scan, Warenkorb.'
  );
}

function buildSystemMessages(env, request) {
  const systemMessages = [];
  const platform = request ? getPlatform(request) : 'web';

  // App sends its own complete system prompt — don't inject PROMPT_BRAIN/TECH
  // Web has no own prompt, so it needs the worker-side prompts
  if (platform === 'web') {
    const brain = (env.PROMPT_BRAIN || '').trim();
    const tech = (env.PROMPT_TECH || '').trim();

    if (brain) {
      systemMessages.push({ role: 'system', content: brain });
    }
    if (tech) {
      systemMessages.push({ role: 'system', content: tech });
    }
  }

  const platformContext = buildPlatformContext(platform);
  systemMessages.push({ role: 'system', content: platformContext });

  return systemMessages;
}

// ── Shopify Admin Token (auto-refresh, 24h expiry) ──
let _adminToken = null;
let _adminTokenExpiry = 0;

async function getAdminToken(env) {
  if (_adminToken && Date.now() < _adminTokenExpiry) return _adminToken;

  const resp = await fetch('https://thermolox.myshopify.com/admin/oauth/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=client_credentials&client_id=${env.SHOPIFY_CLIENT_ID}&client_secret=${env.SHOPIFY_CLIENT_SECRET}`,
  });

  if (!resp.ok) throw new Error(`Token refresh failed: ${resp.status}`);
  const data = await resp.json();
  _adminToken = data.access_token;
  _adminTokenExpiry = Date.now() + (data.expires_in - 300) * 1000; // refresh 5 min early
  return _adminToken;
}

// ── Sync helper: pulls content from Shopify, upserts to Supabase ──
async function syncContent(env) {
  const adminToken = await getAdminToken(env);
  const supabaseUrl = env.SUPABASE_URL;
  const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;

  const contentQuery = `{
    pages(first: 50) { edges { node { id title handle body updatedAt } } }
    articles(first: 50, sortKey: PUBLISHED_AT, reverse: true) {
      edges { node { id title handle body publishedAt image { url altText } tags blog { title handle } } }
    }
  }`;

  const shopifyResp = await fetch('https://thermolox.myshopify.com/admin/api/2024-10/graphql.json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Shopify-Access-Token': adminToken },
    body: JSON.stringify({ query: contentQuery }),
  });
  const shopifyData = await shopifyResp.json();
  if (shopifyData.errors) throw new Error(JSON.stringify(shopifyData.errors));

  const pages = (shopifyData.data?.pages?.edges || []).map(e => ({
    type: 'page', title: e.node.title, handle: e.node.handle,
    body: e.node.body, shopify_id: e.node.id,
    published_at: e.node.updatedAt, is_visible: true,
  }));

  const articles = (shopifyData.data?.articles?.edges || []).map(e => ({
    type: 'article', title: e.node.title, handle: e.node.handle,
    body: e.node.body, shopify_id: e.node.id,
    image_url: e.node.image?.url || null, image_alt: e.node.image?.altText || null,
    tags: e.node.tags || [],
    blog_title: e.node.blog?.title || null, blog_handle: e.node.blog?.handle || null,
    published_at: e.node.publishedAt, is_visible: true,
  }));

  let synced = 0;
  for (const item of [...pages, ...articles]) {
    const resp = await fetch(`${supabaseUrl}/rest/v1/content?on_conflict=shopify_id`, {
      method: 'POST',
      headers: {
        'apikey': supabaseKey, 'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(item),
    });
    if (resp.ok) synced++;
  }
  return { synced, total: pages.length + articles.length };
}

// ── Design Tokens → CSS conversion ──
let _tokenCache = null;
let _tokenCacheTime = 0;
const TOKEN_CACHE_TTL = 5 * 60 * 1000; // 5 min

async function getDesignTokens(env) {
  if (_tokenCache && Date.now() - _tokenCacheTime < TOKEN_CACHE_TTL) return _tokenCache;

  const resp = await fetch(
    `${env.SUPABASE_URL}/rest/v1/design_tokens?is_active=eq.true&select=tokens&limit=1`,
    { headers: { 'apikey': env.SUPABASE_ANON_KEY, 'Authorization': `Bearer ${env.SUPABASE_ANON_KEY}` } }
  );
  const rows = await resp.json();
  _tokenCache = rows[0]?.tokens || null;
  _tokenCacheTime = Date.now();
  return _tokenCache;
}

function hexToRgb(hex) {
  const h = hex.replace('#', '');
  return `${parseInt(h.substring(0,2),16)},${parseInt(h.substring(2,4),16)},${parseInt(h.substring(4,6),16)}`;
}

function tokensToCss(t) {
  const c = t.colors || {};
  const f = t.fonts || {};
  const b = t.buttons || {};
  const s = t.spacing || {};
  const ca = t.cards || {};

  return `:root {
  /* ── CLIMALOX Design Tokens (auto-generated from Supabase) ── */
  --climalox-primary: ${c.primary || '#efbba5'};
  --climalox-primary-rgb: ${hexToRgb(c.primary || '#efbba5')};
  --climalox-primary-hover: ${c.primaryHover || '#d4896f'};
  --climalox-bg: ${c.background || '#ffffff'};
  --climalox-bg-warm: ${c.backgroundWarm || '#ffffff'};
  --climalox-fg: ${c.foreground || '#404040'};
  --climalox-fg-rgb: ${hexToRgb(c.foreground || '#404040')};
  --climalox-fg-light: ${c.foregroundLight || '#ffffff'};
  --climalox-dark: ${c.dark || '#000000'};
  --climalox-accent: ${c.accent || '#efbba5'};
  --climalox-accent2: ${c.accent2 || '#505050'};
  --climalox-border: ${c.border || '#e0e0e0'};
  --climalox-shadow: ${c.shadow || '#404040'};
  --climalox-footer: ${c.footer || '#000000'};
  --climalox-header: ${c.header || '#505050'};
  --climalox-icon-color: ${(t.icons || {}).color || '#505050'};
  --climalox-font-heading: '${f.heading || 'Times New Roman'}', ${f.headingFallback || 'Georgia, serif'};
  --climalox-font-body: '${f.body || 'Lato'}', ${f.bodyFallback || 'sans-serif'};
  --climalox-font-heading-weight: ${f.headingWeight || 700};
  --climalox-font-body-weight: ${f.bodyWeight || 400};
  --climalox-font-body-size: 17px;
  --climalox-btn-radius: ${b.radius || 40}px;
  --climalox-card-radius: ${ca.radius || 12}px;
  --climalox-page-width: ${s.page || 1400}px;
}

/* ── Override Shopify theme variables ── */
:root, .color-scheme-1 {
  --color-background: ${hexToRgb(c.background || '#ffffff')};
  --color-foreground: ${hexToRgb(c.foreground || '#404040')};
  --color-button: ${hexToRgb(c.primary || '#efbba5')};
  --color-button-text: ${hexToRgb(c.foreground || '#404040')};
  --color-secondary-button-text: ${hexToRgb(c.accent2 || '#505050')};
  --color-link: ${hexToRgb(c.accent2 || '#505050')};
  --color-badge-foreground: ${hexToRgb(c.foreground || '#404040')};
  --color-badge-border: ${hexToRgb(c.foreground || '#404040')};
  --font-heading-family: '${f.heading || 'Times New Roman'}', ${f.headingFallback || 'Georgia, serif'};
  --font-heading-weight: ${f.headingWeight || 700};
}
.color-scheme-2 {
  --color-background: ${hexToRgb(c.background || '#ffffff')};
  --color-foreground: ${hexToRgb(c.foreground || '#404040')};
  --color-button: ${hexToRgb(c.primary || '#efbba5')};
  --color-button-text: ${hexToRgb(c.foreground || '#404040')};
  --color-secondary-button-text: ${hexToRgb(c.accent2 || '#505050')};
  --color-link: ${hexToRgb(c.accent2 || '#505050')};
}
.color-scheme-3 {
  --color-background: ${hexToRgb(c.accent2 || '#505050')};
  --gradient-background: ${c.accent2 || '#505050'};
  --color-foreground: 255,255,255;
  --color-button: ${hexToRgb(c.primary || '#efbba5')};
  --color-button-text: ${hexToRgb(c.foreground || '#404040')};
  --color-secondary-button-text: ${hexToRgb(c.primary || '#efbba5')};
  --color-link: ${hexToRgb(c.primary || '#efbba5')};
  --color-badge-foreground: 255,255,255;
  --color-badge-border: 255,255,255;
}
.color-scheme-4 {
  --color-background: ${hexToRgb(c.dark || '#000000')};
  --gradient-background: ${c.dark || '#000000'};
  --color-foreground: 255,255,255;
  --color-button: ${hexToRgb(c.primary || '#efbba5')};
  --color-button-text: ${hexToRgb(c.dark || '#000000')};
  --color-secondary-button-text: ${hexToRgb(c.primary || '#efbba5')};
  --color-link: ${hexToRgb(c.primary || '#efbba5')};
}
.color-scheme-5 {
  --color-background: ${hexToRgb(c.primary || '#efbba5')};
  --gradient-background: ${c.primary || '#efbba5'};
  --color-foreground: ${hexToRgb(c.foreground || '#404040')};
  --color-button: ${hexToRgb(c.foreground || '#404040')};
  --color-button-text: 255,255,255;
  --color-secondary-button-text: ${hexToRgb(c.foreground || '#404040')};
  --color-link: ${hexToRgb(c.foreground || '#404040')};
}

/* ── Font & size overrides ── */
h1, h2, h3, h4, h5, h6,
.h0, .h1, .h2, .h3, .h4, .h5 {
  font-family: '${f.heading || 'Times New Roman'}', ${f.headingFallback || 'Georgia, serif'} !important;
}

body, .rte, p, li, td, th, label, input, select, textarea, .product__description {
  font-size: 19px !important;
  line-height: 1.65 !important;
}
h1, .h1 { font-size: 3.2rem !important; }
h2, .h2 { font-size: 2.6rem !important; }
h3, .h3 { font-size: 1.9rem !important; }
h4, .h4 { font-size: 1.5rem !important; }

.caption, .caption-large, .caption-with-letter-spacing {
  font-size: 15px !important;
}

@media screen and (max-width: 749px) {
  body, .rte, p, li, td, th, label, input, select, textarea, .product__description {
    font-size: 17px !important;
  }
  h1, .h1 { font-size: 2.6rem !important; }
  h2, .h2 { font-size: 2.1rem !important; }
  h3, .h3 { font-size: 1.6rem !important; }
}

/* ═══════ CLIMALOX COMPONENT CLASSES ═══════
   ALL font sizes & spacing in one place. Edit here to change site-wide.
   PREMIUM SPACING: generous whitespace between all sections.
*/

/* ── Premium whitespace ── */
section, [aria-label] {
  padding-top: 100px !important;
  padding-bottom: 100px !important;
}

/* ── Scroll reveal animation ── */
.cx-reveal {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 0.8s cubic-bezier(0.16, 1, 0.3, 1),
              transform 0.8s cubic-bezier(0.16, 1, 0.3, 1);
}
.cx-reveal.cx-visible {
  opacity: 1;
  transform: translateY(0);
}

/* Section headings – large, airy */
.cx-section-heading {
  font-family: var(--climalox-font-heading) !important;
  font-size: clamp(2.4rem, 5vw, 3.6rem) !important;
  color: var(--climalox-fg) !important;
  margin: 0 0 20px !important;
  font-weight: 400 !important;
  letter-spacing: -0.02em;
}
.cx-section-sub {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.25rem !important;
  color: #909090 !important;
  max-width: 560px;
  margin: 0 auto !important;
  line-height: 1.7 !important;
}

/* Tags / labels */
.cx-tag {
  font-family: var(--climalox-font-body) !important;
  font-size: 0.82rem !important;
  letter-spacing: 3px;
  text-transform: uppercase;
  color: var(--climalox-primary) !important;
  margin-bottom: 10px;
  font-weight: 600;
}

/* Cards – hover with color flash */
.cx-card {
  transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1),
              box-shadow 0.4s cubic-bezier(0.16, 1, 0.3, 1) !important;
}
.cx-card:hover {
  transform: translateY(-6px) !important;
  box-shadow: 0 16px 40px rgba(0,0,0,0.1) !important;
}
.cx-card-title {
  font-family: var(--climalox-font-heading) !important;
  font-size: 1.5rem !important;
  color: var(--climalox-fg) !important;
  margin-bottom: 8px;
  letter-spacing: -0.01em;
}
.cx-card-sub {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.05rem !important;
  color: #909090 !important;
  line-height: 1.55;
}

/* Steps */
.cx-step-circle {
  width: 72px; height: 72px; border-radius: 50%;
  background: var(--climalox-primary);
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 24px;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}
.cx-step-circle:hover {
  transform: scale(1.1);
  box-shadow: 0 8px 24px rgba(239,187,165,0.4);
}
.cx-step-title {
  font-family: var(--climalox-font-heading) !important;
  font-size: 1.5rem !important;
  color: var(--climalox-fg) !important;
  margin: 0 0 10px !important;
  letter-spacing: -0.01em;
}
.cx-step-text {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.1rem !important;
  color: #909090 !important;
  line-height: 1.6;
}

/* Stats – large with subtle animation */
.cx-stat {
  font-family: var(--climalox-font-heading) !important;
  font-size: 4rem !important;
  color: var(--climalox-primary) !important;
  font-weight: 400 !important;
  letter-spacing: -0.03em;
}
.cx-stat-label {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.05rem !important;
  color: rgba(255,255,255,0.6) !important;
  margin-top: 8px;
  letter-spacing: 0.5px;
}

/* USP strip */
.cx-usp-title {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.1rem !important;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 6px;
}
.cx-usp-sub {
  font-family: var(--climalox-font-body) !important;
  font-size: 0.92rem !important;
  color: rgba(255,255,255,0.55);
  line-height: 1.45;
}

/* CTA */
.cx-cta-heading {
  font-family: var(--climalox-font-heading) !important;
  font-size: clamp(2.6rem, 5vw, 4rem) !important;
  color: #fff !important;
  font-weight: 400 !important;
  margin: 0 0 20px !important;
  line-height: 1.1;
  letter-spacing: -0.02em;
}
.cx-cta-sub {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.2rem !important;
  color: rgba(255,255,255,0.55) !important;
  margin: 0 0 44px !important;
  line-height: 1.6;
}
.cx-cta-btn {
  display: inline-block;
  padding: 20px 64px;
  background: var(--climalox-primary);
  color: var(--climalox-fg);
  text-decoration: none;
  border-radius: var(--climalox-btn-radius);
  font-family: var(--climalox-font-body) !important;
  font-size: 1.15rem !important;
  font-weight: 600;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
  letter-spacing: 0.5px;
}
.cx-cta-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(239,187,165,0.4);
}

/* Buttons */
.cx-btn {
  font-family: var(--climalox-font-body) !important;
  font-size: 1.1rem !important;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}
.cx-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(239,187,165,0.4);
}

/* ── Parallax images ── */
.cx-parallax-img {
  transition: transform 0.15s linear;
  will-change: transform;
}

/* ═══════ RESPONSIVE ═══════ */
@media screen and (max-width: 749px) {
  section, [aria-label] {
    padding-top: 60px !important;
    padding-bottom: 60px !important;
  }
  .cx-section-heading { font-size: clamp(1.8rem, 6vw, 2.4rem) !important; }
  .cx-section-sub { font-size: 1.05rem !important; }
  .cx-card-title { font-size: 1.3rem !important; }
  .cx-card-sub { font-size: 0.95rem !important; }
  .cx-step-title { font-size: 1.3rem !important; }
  .cx-stat { font-size: 2.8rem !important; }
  .cx-usp-title { font-size: 1rem !important; }
  .cx-usp-sub { font-size: 0.85rem !important; }
  .cx-cta-heading { font-size: clamp(2rem, 6vw, 2.8rem) !important; }
}

/* ── Header: white background ── */
.section-header,
.header-wrapper {
  background-color: #ffffff !important;
  --color-foreground: ${hexToRgb(c.foreground || '#404040')};
}
.section-header .header__heading-link,
.section-header .header__icon,
.section-header a {
  color: ${c.foreground || '#404040'} !important;
}

/* ── Footer: Black ── */
.section-footer,
footer,
.footer {
  background-color: ${c.footer || '#000000'} !important;
  --color-foreground: 255,255,255;
}
.footer a, .footer .footer-block__heading {
  color: #fff !important;
}
`;
}

export default {
  // ── Cron Trigger: auto-sync every 15 min ──
  async scheduled(event, env, ctx) {
    try {
      const result = await syncContent(env);
      console.log(`Cron sync: ${result.synced}/${result.total} items`);
    } catch (err) {
      console.error('Cron sync failed:', err.message);
    }
  },

  async fetch(request, env) {
    const cors = getCorsHeaders(request);
    _currentCors = cors;

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);

    // Public endpoints (no auth required)
    if (url.pathname === '/style.css' || url.pathname === '/style.json') {
      // handled below, skip auth
    } else if (url.pathname === '/webhook/sync') {
      // webhooks have their own auth
    } else {
      const authError = requireAppToken(request, env);
      if (authError) return authError;
    }
    if (url.pathname === '/upload') {
      if (request.method !== 'POST') {
        return jsonResponse(405, { error: 'Method not allowed.' });
      }

      let base64;
      const contentType = request.headers.get('content-type') ?? '';
      try {
        if (contentType.includes('application/json')) {
          const body = await request.json();
          base64 = body?.base64 || body?.data || body?.image;
        } else if (contentType.includes('multipart/form-data')) {
          const form = await request.formData();
          base64 = form.get('base64') || form.get('data');
        } else {
          const text = await request.text();
          base64 = text?.trim();
        }
      } catch (_) {
        return jsonResponse(400, { error: 'Invalid upload body.' });
      }

      if (!base64 || typeof base64 !== 'string') {
        return jsonResponse(400, { error: 'Missing base64.' });
      }

      const dataUrl = base64.startsWith('data:')
        ? base64.trim()
        : `data:image/jpeg;base64,${base64.trim()}`;

      return jsonResponse(200, { imageUrl: dataUrl });
    }

    if (url.pathname === '/chat') {
      if (request.method !== 'POST') {
        return jsonResponse(405, { error: 'Method not allowed.' });
      }

      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: 'Missing OPENAI_API_KEY.' });
      }

      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: 'Invalid JSON body.' });
      }

      const {
        apiKey: _apiKey,
        openaiApiKey: _openaiApiKey,
        messages: rawMessages,
        ...rest
      } = body ?? {};

      const incomingMessages = Array.isArray(rawMessages)
        ? rawMessages
        : [];
      const systemMessages = buildSystemMessages(env, request);

      const payload = {
        ...rest,
        messages: [...systemMessages, ...incomingMessages],
        stream: true,
      };

      const openaiResponse = await fetch(
        'https://api.openai.com/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
            Accept: 'text/event-stream',
          },
          body: JSON.stringify(payload),
        },
      );

      const contentType =
        openaiResponse.headers.get('content-type') ?? 'text/event-stream';

      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...cors,
          'Content-Type': contentType,
        },
      });
    }

    if (url.pathname === '/tts') {
      if (request.method !== 'POST') {
        return jsonResponse(405, { error: 'Method not allowed.' });
      }

      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: 'Missing OPENAI_API_KEY.' });
      }

      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: 'Invalid JSON body.' });
      }

      const {
        text,
        input,
        voice = 'onyx',
        model = 'tts-1',
        format = 'mp3',
      } = body ?? {};
      const resolvedText =
        typeof text === 'string' ? text : typeof input === 'string' ? input : '';

      if (!resolvedText.trim()) {
        return jsonResponse(400, { error: 'Missing text.' });
      }

      const payload = {
        model,
        voice,
        input: resolvedText,
        format,
      };

      const openaiResponse = await fetch(
        'https://api.openai.com/v1/audio/speech',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
            Accept: 'audio/mpeg',
          },
          body: JSON.stringify(payload),
        },
      );

      const contentType =
        openaiResponse.headers.get('content-type') ?? 'audio/mpeg';

      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...cors,
          'Content-Type': contentType,
        },
      });
    }

    if (url.pathname === '/stt') {
      if (request.method !== 'POST') {
        return jsonResponse(405, { error: 'Method not allowed.' });
      }

      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: 'Missing OPENAI_API_KEY.' });
      }

      const contentType = request.headers.get('content-type') ?? '';
      if (!contentType.includes('multipart/form-data')) {
        return jsonResponse(400, { error: 'Expected multipart/form-data.' });
      }

      let formData;
      try {
        formData = await request.formData();
      } catch (_) {
        return jsonResponse(400, { error: 'Invalid form data.' });
      }

      const file = formData.get('file');
      if (!(file instanceof File)) {
        return jsonResponse(400, { error: 'Missing audio file.' });
      }

      const model = (formData.get('model') || 'gpt-4o-mini-transcribe')
        .toString()
        .trim();
      const language = formData.get('language');
      const prompt = formData.get('prompt');
      const temperature = formData.get('temperature');
      const responseFormat = formData.get('response_format');

      const openaiForm = new FormData();
      openaiForm.append('file', file, file.name || 'audio.m4a');
      openaiForm.append('model', model || 'gpt-4o-mini-transcribe');
      if (language) {
        openaiForm.append('language', language.toString());
      }
      if (prompt) {
        openaiForm.append('prompt', prompt.toString());
      }
      if (temperature) {
        openaiForm.append('temperature', temperature.toString());
      }
      if (responseFormat) {
        openaiForm.append('response_format', responseFormat.toString());
      }

      const openaiResponse = await fetch(
        'https://api.openai.com/v1/audio/transcriptions',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          },
          body: openaiForm,
        },
      );

      const openaiContentType =
        openaiResponse.headers.get('content-type') ?? 'application/json';

      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...cors,
          'Content-Type': openaiContentType,
        },
      });
    }

    if (url.pathname === '/image-edit') {
      if (request.method !== 'POST') {
        return jsonResponse(405, { error: 'Method not allowed.' });
      }

      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: 'Missing OPENAI_API_KEY.' });
      }

      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: 'Invalid JSON body.' });
      }

      const {
        prompt,
        imageUrl,
        imageBase64,
        maskBase64,
        model = 'gpt-image-1',
        size,
      } = body ?? {};

      if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
        return jsonResponse(400, { error: 'Missing prompt.' });
      }
      if (!maskBase64 || typeof maskBase64 !== 'string') {
        return jsonResponse(400, { error: 'Missing maskBase64.' });
      }
      if (
        (!imageUrl || typeof imageUrl !== 'string') &&
        (!imageBase64 || typeof imageBase64 !== 'string')
      ) {
        return jsonResponse(400, { error: 'Missing image input.' });
      }

      let sourceFile;
      try {
        if (imageUrl && imageUrl.trim()) {
          sourceFile = await fileFromImageUrl(imageUrl, 'image.png');
        } else {
          const bytes = decodeBase64ToBytes(imageBase64);
          const type = guessImageType(imageBase64, 'image/png');
          sourceFile = new File([bytes], 'image.png', { type });
        }
      } catch (e) {
        return jsonResponse(400, { error: e.message || 'Image load failed.' });
      }

      let maskFile;
      try {
        const maskBytes = decodeBase64ToBytes(maskBase64);
        const maskType = guessImageType(maskBase64, 'image/png');
        maskFile = new File([maskBytes], 'mask.png', { type: maskType });
      } catch (_) {
        return jsonResponse(400, { error: 'Mask decode failed.' });
      }

      const form = new FormData();
      form.append('model', model);
      form.append('prompt', prompt);
      if (size && typeof size === 'string') {
        form.append('size', size);
      }
      form.append('image', sourceFile, sourceFile.name || 'image.png');
      form.append('mask', maskFile, 'mask.png');

      const openaiResponse = await fetch(
        'https://api.openai.com/v1/images/edits',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
          },
          body: form,
        },
      );

      const responseText = await openaiResponse.text();
      if (!openaiResponse.ok) {
        return jsonResponse(openaiResponse.status, {
          error: responseText || 'Image edit failed.',
        });
      }

      try {
        const parsed = JSON.parse(responseText);
        const data = Array.isArray(parsed?.data) ? parsed.data : [];
        const first = data[0] || {};
        const b64 = first.b64_json || first.image_base64 || first.base64;
        const url = first.url || first.imageUrl;
        if (b64) {
          return jsonResponse(200, {
            imageBase64: `data:image/png;base64,${b64}`,
          });
        }
        if (url) {
          return jsonResponse(200, { imageUrl: url });
        }
        return jsonResponse(200, parsed);
      } catch (_) {
        return jsonResponse(200, { imageBase64: responseText });
      }
    }

    // ── Design Tokens: /style.css (CSS) and /style.json (raw JSON) ──
    // Public stylesheets use permissive CORS (any origin)
    if (url.pathname === '/style.css') {
      const publicHeaders = {
        'Content-Type': 'text/css',
        'Cache-Control': 'public, max-age=300',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
      };
      try {
        const tokens = await getDesignTokens(env);
        if (!tokens) return new Response('/* no tokens */', { status: 200, headers: publicHeaders });
        const css = tokensToCss(tokens);
        return new Response(css, { status: 200, headers: publicHeaders });
      } catch (err) {
        return new Response(`/* error: ${err.message} */`, { status: 200, headers: publicHeaders });
      }
    }

    if (url.pathname === '/style.json') {
      try {
        const tokens = await getDesignTokens(env);
        return jsonResponse(200, tokens || {});
      } catch (err) {
        return jsonResponse(502, { error: err.message });
      }
    }

    // ── Content API: triggers sync and returns content from Supabase ──
    if (url.pathname === '/content') {
      try {
        // Trigger sync first
        await syncContent(env);

        // Return content from Supabase
        const resp = await fetch(
          `${env.SUPABASE_URL}/rest/v1/content?is_visible=eq.true&order=sort_order,published_at.desc&limit=100`,
          { headers: { 'apikey': env.SUPABASE_SERVICE_ROLE_KEY, 'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}` } }
        );
        const items = await resp.json();
        const pages = items.filter(i => i.type === 'page');
        const articles = items.filter(i => i.type === 'article');
        return jsonResponse(200, { pages, articles });
      } catch (err) {
        return jsonResponse(502, { error: 'Content fetch failed', message: err.message });
      }
    }

    // ── Webhook: Shopify product/content update ──
    if (url.pathname === '/webhook/sync') {
      try {
        const result = await syncContent(env);
        return jsonResponse(200, { ok: true, ...result });
      } catch (err) {
        return jsonResponse(502, { error: 'Sync failed', message: err.message });
      }
    }

    return jsonResponse(404, { error: 'Not found.' });
  },
};
