const API_BASE = "https://climalox-proxy.stefan-obholz.workers.dev";
const STORAGE_KEY = "climalox_chat_history_v1";
const MODEL = "claude-haiku-4-5-20251001";
const PLATFORM = "web";

let chatHistory = [];
let pendingUploads = [];
let productCache = null;

/* ===== Cloudflare Turnstile ===== */
let turnstileWidgetId = null;
let turnstileReady = false;
let turnstileToken = null;

function getTurnstileSiteKey() {
  return (window.__CLIMALOX_CONFIG && window.__CLIMALOX_CONFIG.turnstileSiteKey) || (window.__CLIMALOX_CONFIG && window.__CLIMALOX_CONFIG.turnstileSiteKey) || "";
}

function initTurnstile() {
  const siteKey = getTurnstileSiteKey();
  if (!siteKey || turnstileWidgetId !== null) return;
  if (typeof turnstile === "undefined") {
    // Script not yet loaded, retry
    setTimeout(initTurnstile, 200);
    return;
  }
  // Create hidden container for invisible widget
  const container = document.createElement("div");
  container.id = "turnstile-container";
  container.style.display = "none";
  document.body.appendChild(container);

  turnstileWidgetId = turnstile.render("#turnstile-container", {
    sitekey: siteKey,
    size: "invisible",
    callback: (token) => {
      turnstileToken = token;
      turnstileReady = true;
    },
    "expired-callback": () => {
      turnstileToken = null;
      turnstileReady = false;
      // Auto-refresh
      if (turnstileWidgetId !== null) turnstile.reset(turnstileWidgetId);
    },
    "error-callback": () => {
      turnstileToken = null;
      turnstileReady = false;
    },
  });
}

async function getTurnstileToken() {
  // If we already have a valid token, return it
  if (turnstileToken) {
    const token = turnstileToken;
    turnstileToken = null;
    turnstileReady = false;
    if (turnstileWidgetId !== null) turnstile.reset(turnstileWidgetId);
    return token;
  }
  // Ensure Turnstile is initialized (may not be ready yet on first click)
  if (turnstileWidgetId === null) initTurnstile();
  if (turnstileWidgetId !== null) turnstile.reset(turnstileWidgetId);
  // Wait for token (max 15s)
  for (let i = 0; i < 75; i++) {
    await new Promise(r => setTimeout(r, 200));
    // Keep trying to init if widget not ready yet
    if (turnstileWidgetId === null && i % 5 === 0) initTurnstile();
    if (turnstileToken) {
      const token = turnstileToken;
      turnstileToken = null;
      turnstileReady = false;
      return token;
    }
  }
  return null;
}

/* ===== Produkte laden & cachen ===== */
async function loadProducts() {
  if (productCache) return productCache;
  try {
    const res = await fetch('/products.json?limit=250');
    const data = await res.json();
    productCache = (data.products || []).map(p => ({
      handle: p.handle,
      title: p.title,
      variants: p.variants
    }));
  } catch {
    productCache = [];
  }
  return productCache;
}

function getProductHandles() {
  if (!productCache) return [];
  return productCache.map(p => p.handle);
}

/* ===== Warenkorb-Integration ===== */
async function addToCart(handle, quantity = 1) {
  try {
    // Get variant ID from handle
    const resp = await fetch('/products/' + handle + '.json');
    const product = await resp.json();
    const variantId = product.product.variants[0].id;

    // Add to Shopify cart
    await fetch('/cart/add.js', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [{ id: variantId, quantity }] })
    });

    // Show confirmation
    appendBubble('assistant', 'Produkt wurde in den Warenkorb gelegt! \u{1F6D2}');

    // Update cart count in header
    const cartResp = await fetch('/cart.json');
    const cart = await cartResp.json();
    document.querySelectorAll('.cart-count-bubble, [data-cart-count]').forEach(el => {
      el.textContent = cart.item_count;
    });
  } catch (e) {
    console.error('[CLIMALOX] addToCart error:', e);
    appendBubble('assistant', 'Fehler beim Hinzufügen zum Warenkorb. Bitte versuche es erneut.');
  }
}

/* ===== Verlauf speichern / laden ===== */
function saveHistory() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(chatHistory));
  } catch {}
}

function addToHistory(role, text, contentForApi) {
  const hasText = text && text.trim().length > 0;
  const hasContent =
    contentForApi &&
    (!Array.isArray(contentForApi) || contentForApi.length > 0);

  if (!hasText && !hasContent) return;

  const entry = { role, text: text || "" };
  if (hasContent) entry.content = contentForApi;

  chatHistory.push(entry);
  if (chatHistory.length > 200) chatHistory = chatHistory.slice(-200);
  saveHistory();
}

function restoreHistory() {
  const win = document.getElementById("chat-window");
  if (!win) return;
  win.innerHTML = "";
  const raw = localStorage.getItem(STORAGE_KEY);
  try {
    chatHistory = JSON.parse(raw) || [];
  } catch {
    chatHistory = [];
  }
  chatHistory.forEach(m => {
    if (m.role === "assistant") {
      renderAssistantMessage(m.text, win);
    } else {
      appendBubble(m.role, m.text);
    }
  });
  win.scrollTop = win.scrollHeight;
  refreshIcons();
}

/* ===== Feather-Icons fix ===== */
function refreshIcons() {
  if (window.feather) {
    try { feather.replace(); } catch {}
  }
}

/* ===== Bubble Renderer ===== */
function appendBubble(role, text) {
  const win = document.getElementById("chat-window");
  if (!win) return null;
  const b = document.createElement("div");
  b.className = "chat-bubble " + (role === "user" ? "user-bubble" : "bot-bubble");
  b.innerHTML = formatText(text || "");
  win.appendChild(b);
  win.scrollTop = win.scrollHeight;
  return b;
}

function formatText(text) {
  // Basic markdown-like formatting
  let html = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\n/g, "<br>");
  return html;
}

/* ===== Button Rendering ===== */
function renderButtons(buttonsJson, container) {
  try {
    const data = JSON.parse(buttonsJson);
    if (!data.buttons || !Array.isArray(data.buttons)) return;

    const btnWrap = document.createElement("div");
    btnWrap.className = "climalox-buttons";

    data.buttons.forEach(btn => {
      const el = document.createElement("button");
      el.className = "climalox-btn";
      if (btn.variant === "preferred") el.classList.add("climalox-btn-preferred");
      if (btn.variant === "primary") el.classList.add("climalox-btn-primary");

      // Cart button: show cart icon
      if (btn.productHandle || (btn.value && btn.value.startsWith("add_to_cart"))) {
        el.textContent = "\u{1F6D2} " + btn.label;
      } else if (btn.url) {
        el.textContent = btn.label;
      } else {
        el.textContent = btn.label;
      }

      el.addEventListener("click", () => {
        // Disable all button groups after click
        document.querySelectorAll(".climalox-buttons").forEach(g => {
          g.querySelectorAll("button").forEach(b => { b.disabled = true; });
        });

        // Cart button: add product to Shopify cart
        if (btn.productHandle) {
          addToCart(btn.productHandle, btn.quantity || 1);
          return;
        }
        if (btn.value && btn.value.startsWith("add_to_cart")) {
          // Extract handle from value like "add_to_cart:handle-name"
          const parts = btn.value.split(":");
          if (parts.length > 1) {
            addToCart(parts[1], btn.quantity || 1);
            return;
          }
        }

        // Link button: open URL
        if (btn.url) {
          window.open(btn.url, "_blank");
          return;
        }

        // Regular button: send value as message
        const input = document.getElementById("chat-input");
        if (input) input.value = btn.value || btn.label;
        sendMessage();
      });
      btnWrap.appendChild(el);
    });

    container.appendChild(btnWrap);
  } catch {}
}

function renderAssistantMessage(fullText, container) {
  // Split text into content and buttons
  const lines = fullText.split("\n");
  let textParts = [];
  let buttonBlocks = [];

  for (const line of lines) {
    if (line.trim().startsWith("BUTTONS:")) {
      const json = line.trim().substring("BUTTONS:".length).trim();
      buttonBlocks.push(json);
    } else {
      textParts.push(line);
    }
  }

  const cleanText = textParts.join("\n").trim();
  if (cleanText) {
    const b = document.createElement("div");
    b.className = "chat-bubble bot-bubble";
    b.innerHTML = formatText(cleanText);
    container.appendChild(b);
  }

  for (const json of buttonBlocks) {
    renderButtons(json, container);
  }

  container.scrollTop = container.scrollHeight;
}

/* ===== Nachrichten für API ===== */
function buildMessagesForApi() {
  const msgs = [];
  const history = chatHistory.slice(-20);

  history.forEach((m, idx) => {
    let content = m.content ?? m.text;

    // Inject product context into the first user message
    if (idx === 0 && m.role === "user" && productCache && productCache.length > 0) {
      const handles = productCache.map(p => p.handle).join(", ");
      const productContext = "\n\n[Verfügbare Produkte im Shop: " + handles + ". " +
        "Um ein Produkt in den Warenkorb zu legen, nutze einen Button mit productHandle-Feld, z.B.: " +
        'BUTTONS: {"buttons":[{"label":"In den Warenkorb","productHandle":"produkt-handle","variant":"preferred"}]}]';
      if (typeof content === "string") {
        content = content + productContext;
      } else if (Array.isArray(content)) {
        content = [...content, { type: "text", text: productContext }];
      }
    }

    msgs.push({ role: m.role, content });
  });
  return msgs;
}

/* ===== Nachricht senden ===== */
async function sendMessage() {
  const input = document.getElementById("chat-input");
  const win = document.getElementById("chat-window");
  const preview = document.getElementById("upload-preview");

  if (!input || !win) return;

  const msg = input.value.trim();
  const hasFiles = pendingUploads.length > 0;

  if (!msg && !hasFiles) return;

  appendBubble("user", msg || "");
  input.value = "";

  // ========== BILDER HOCHLADEN ==========
  const uploadedUrls = [];

  if (hasFiles) {
    for (const p of pendingUploads) {
      try {
        const res = await fetch(`${API_BASE}/upload`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Platform": "web"
          },
          body: JSON.stringify({ base64: p.base64 })
        });

        const data = await res.json();
        if (data.imageUrl) {
          uploadedUrls.push(data.imageUrl);
          const img = document.createElement("img");
          img.src = data.imageUrl;
          img.style.maxWidth = "100%";
          img.style.borderRadius = "10px";
          const last = [...document.querySelectorAll(".user-bubble")].pop();
          if (last) last.appendChild(img);
        }
      } catch (e) {
        appendBubble("assistant", "Upload fehlgeschlagen: " + e.message);
      }
    }

    pendingUploads = [];
    if (preview) {
      preview.style.display = "none";
      preview.innerHTML = "";
    }
  }

  // ===== Message Payload =====
  const contentParts = [];
  if (msg) contentParts.push({ type: "text", text: msg });
  uploadedUrls.forEach(url => {
    contentParts.push({ type: "image_url", image_url: { url } });
  });

  const historyContent = contentParts.length > 0 ? contentParts : msg || "";
  addToHistory("user", msg || "", historyContent);

  const payload = {
    model: MODEL,
    temperature: 0.7,
    messages: buildMessagesForApi(),
    platform: PLATFORM
  };

  // ===== TURNSTILE TOKEN (optional, only if site key configured) =====
  const siteKey = getTurnstileSiteKey();
  let cfToken = null;
  if (siteKey) {
    cfToken = await getTurnstileToken();
    if (!cfToken) {
      appendBubble("assistant", "Sicherheitsprüfung fehlgeschlagen. Bitte lade die Seite neu.");
      return;
    }
  }

  // ===== REQUEST =====
  const headers = {
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
    "X-Platform": "web"
  };
  if (cfToken) headers["cf-turnstile-response"] = cfToken;

  let res;
  try {
    res = await fetch(`${API_BASE}/chat`, {
      method: "POST",
      headers,
      body: JSON.stringify(payload)
    });
  } catch (e) {
    appendBubble("assistant", "Verbindungsfehler. Bitte versuche es erneut.");
    return;
  }

  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    console.error("[CLIMALOX] Chat error:", res.status, errText);
    appendBubble("assistant", "Es ist ein Fehler aufgetreten. Bitte versuche es erneut.");
    return;
  }

  // ===== TYPING INDICATOR =====
  const typingBubble = document.createElement("div");
  typingBubble.className = "chat-bubble bot-bubble typing-indicator";
  typingBubble.innerHTML = "<span></span><span></span><span></span>";
  win.appendChild(typingBubble);
  win.scrollTop = win.scrollHeight;

  // ===== STREAM =====
  const botBubble = document.createElement("div");
  botBubble.className = "chat-bubble bot-bubble";
  botBubble.style.display = "none";
  win.appendChild(botBubble);

  const reader = res.body.getReader();
  const dec = new TextDecoder("utf-8");

  let buf = "";
  let full = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buf += dec.decode(value, { stream: true });
    const lines = buf.split("\n");
    buf = lines.pop();

    for (const line of lines) {
      const t = line.trim();
      if (!t.startsWith("data:")) continue;

      const js = t.slice(5).trim();
      if (js === "[DONE]") continue;

      try {
        const json = JSON.parse(js);
        const delta = json.choices?.[0]?.delta?.content;
        if (delta) {
          full += delta;
          // Remove typing indicator on first chunk
          if (typingBubble.parentNode) typingBubble.remove();
          botBubble.style.display = "";
          // Show raw text while streaming (buttons parsed after)
          botBubble.innerHTML = formatText(full);
          win.scrollTop = win.scrollHeight;
        }
      } catch {}
    }
  }

  // Clean up typing indicator if still present
  if (typingBubble.parentNode) typingBubble.remove();
  botBubble.style.display = "";

  // After stream complete: re-render with button support
  if (full.trim()) {
    addToHistory("assistant", full.trim());

    // Check if there are buttons in the response
    if (full.includes("BUTTONS:")) {
      botBubble.remove();
      renderAssistantMessage(full.trim(), win);
    }
  }
}

/* ===== Auto-Greeting ===== */
const GREETING_TEXT = `Hallo 👋 Willkommen bei CLIMALOX Design!
Ich helfe dir, die perfekte Wandfarbe zu finden – eine, die wunderschön aussieht und gleichzeitig dein Zuhause gemütlicher macht.
Was möchtest du als Nächstes tun? 🎨

BUTTONS: {"buttons":[{"label":"Farbe entdecken","value":"Ich suche die richtige Farbe für meinen Raum","variant":"preferred"},{"label":"Projekt planen","value":"Ich möchte mein Design-Projekt planen","variant":"primary"}]}`;

function ensureGreeting() {
  if (chatHistory.length === 0) {
    addToHistory("assistant", GREETING_TEXT);
    const win = document.getElementById("chat-window");
    if (win) renderAssistantMessage(GREETING_TEXT, win);
  }
}

/* ===== Init ===== */
document.addEventListener("DOMContentLoaded", () => {
  // Load products in background for cart integration
  loadProducts();

  initTurnstile();
  restoreHistory();
  ensureGreeting();
  refreshIcons();

  const t         = document.getElementById("chat-input");
  const sendBtn   = document.getElementById("send-btn");
  const uploadBtn = document.getElementById("upload-btn");
  const fileInput = document.getElementById("file-upload");
  const preview   = document.getElementById("upload-preview");

  const closeBtn  = document.getElementById("chat-close-btn");
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      const overlay = document.getElementById("chatbot-overlay");
      if (overlay) overlay.classList.remove("active");
      document.body.classList.remove("chat-open");
    });
  }

  if (sendBtn) sendBtn.onclick = sendMessage;

  if (t) {
    t.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
  }

  if (uploadBtn) uploadBtn.onclick = () => fileInput && fileInput.click();

  if (fileInput) {
    fileInput.addEventListener("change", e => {
      const files = Array.from(e.target.files || []);
      if (!files.length || !preview) return;

      preview.innerHTML = "";
      preview.style.display = "flex";
      pendingUploads = [];

      files.forEach(file => {
        const reader = new FileReader();
        reader.onload = ev => {
          const base64 = ev.target.result;
          pendingUploads.push({ file, base64 });

          const wrap = document.createElement("div");
          wrap.style.position = "relative";
          wrap.style.marginRight = "8px";

          const img = document.createElement("img");
          img.src = base64;
          img.style.width = "100px";
          img.style.height = "100px";
          img.style.borderRadius = "10px";
          img.style.objectFit = "cover";

          const x = document.createElement("button");
          x.textContent = "\u2716";
          x.style.position = "absolute";
          x.style.top = "-6px";
          x.style.right = "-6px";

          x.onclick = () => {
            wrap.remove();
            pendingUploads = pendingUploads.filter(p => p.file !== file);
            if (!pendingUploads.length) {
              preview.style.display = "none";
              preview.innerHTML = "";
            }
          };

          wrap.appendChild(img);
          wrap.appendChild(x);
          preview.appendChild(wrap);
        };
        reader.readAsDataURL(file);
      });
    });
  }

  const micBtn = document.getElementById("mic-btn");
  if (micBtn) micBtn.style.display = "none";
});
