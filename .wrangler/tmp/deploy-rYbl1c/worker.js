var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// cloudflare/worker.js
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Worker-Token"
};
function decodeBase64ToBytes(input) {
  const cleaned = input.includes(",") ? input.split(",")[1] : input;
  const binary = atob(cleaned.trim());
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
__name(decodeBase64ToBytes, "decodeBase64ToBytes");
function guessImageType(dataUrl, fallback) {
  if (dataUrl.startsWith("data:image/jpeg")) return "image/jpeg";
  if (dataUrl.startsWith("data:image/jpg")) return "image/jpeg";
  if (dataUrl.startsWith("data:image/webp")) return "image/webp";
  if (dataUrl.startsWith("data:image/png")) return "image/png";
  return fallback;
}
__name(guessImageType, "guessImageType");
async function fileFromImageUrl(url, fallbackName) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Image download failed: ${response.status}`);
  }
  const contentType = response.headers.get("content-type") ?? "image/png";
  const bytes = await response.arrayBuffer();
  return new File([bytes], fallbackName, { type: contentType });
}
__name(fileFromImageUrl, "fileFromImageUrl");
function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
__name(jsonResponse, "jsonResponse");
function readAppToken(request) {
  const authHeader = request.headers.get("authorization") || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1];
  return request.headers.get("x-worker-token") || request.headers.get("x-app-token") || "";
}
__name(readAppToken, "readAppToken");
function requireAppToken(request, env) {
  if (!env.WORKER_APP_TOKEN) {
    return jsonResponse(500, { error: "Missing WORKER_APP_TOKEN." });
  }
  const token = readAppToken(request);
  if (!token || token !== env.WORKER_APP_TOKEN) {
    return jsonResponse(401, { error: "Unauthorized." });
  }
  return null;
}
__name(requireAppToken, "requireAppToken");
function buildSystemMessages(env) {
  const systemMessages = [];
  const brain = (env.PROMPT_BRAIN || "").trim();
  const tech = (env.PROMPT_TECH || "").trim();
  if (brain) {
    systemMessages.push({ role: "system", content: brain });
  }
  if (tech) {
    systemMessages.push({ role: "system", content: tech });
  }
  return systemMessages;
}
__name(buildSystemMessages, "buildSystemMessages");
async function fetchPushTokens(env, userId) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) return [];
  const url = `${env.SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${encodeURIComponent(
    userId
  )}&select=token`;
  const res = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`
    }
  });
  if (!res.ok) return [];
  const rows = await res.json();
  if (!Array.isArray(rows)) return [];
  return rows.map((row) => row?.token).filter(Boolean);
}
__name(fetchPushTokens, "fetchPushTokens");
async function sendPushNotification(env, notify) {
  if (!env.FCM_SERVER_KEY) return;
  if (!notify?.userId || !notify?.title || !notify?.body) return;
  const tokens = await fetchPushTokens(env, notify.userId);
  if (!tokens.length) return;
  const data = {
    ...notify.data || {},
    projectId: notify.projectId || void 0,
    type: notify.type || "render_complete"
  };
  const payload = {
    registration_ids: tokens,
    priority: "high",
    notification: {
      title: notify.title,
      body: notify.body
    },
    data
  };
  await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${env.FCM_SERVER_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
}
__name(sendPushNotification, "sendPushNotification");
function parseStripeSignatureHeader(header) {
  if (!header) return { timestamp: 0, signatures: [] };
  const parts = header.split(",");
  let timestamp = 0;
  const signatures = [];
  for (const part of parts) {
    const [key, value] = part.split("=");
    if (!key || !value) continue;
    const trimmedKey = key.trim();
    const trimmedValue = value.trim();
    if (trimmedKey === "t") {
      const parsed = Number(trimmedValue);
      if (!Number.isNaN(parsed)) {
        timestamp = parsed;
      }
    } else if (trimmedKey === "v1") {
      signatures.push(trimmedValue);
    }
  }
  return { timestamp, signatures };
}
__name(parseStripeSignatureHeader, "parseStripeSignatureHeader");
async function hmacSha256Hex(secret, payload) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(payload)
  );
  return Array.from(new Uint8Array(signature)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
__name(hmacSha256Hex, "hmacSha256Hex");
function isStripeTimestampFresh(timestamp, toleranceSeconds) {
  if (!timestamp) return false;
  const now = Math.floor(Date.now() / 1e3);
  return Math.abs(now - timestamp) <= toleranceSeconds;
}
__name(isStripeTimestampFresh, "isStripeTimestampFresh");
async function verifyStripeSignature(header, payload, secret) {
  const { timestamp, signatures } = parseStripeSignatureHeader(header);
  if (!timestamp || signatures.length === 0) return false;
  if (!isStripeTimestampFresh(timestamp, 300)) return false;
  const signedPayload = `${timestamp}.${payload}`;
  const expected = await hmacSha256Hex(secret, signedPayload);
  return signatures.some((signature) => signature === expected);
}
__name(verifyStripeSignature, "verifyStripeSignature");
async function supabaseRequest(env, path, options = {}) {
  const { method = "GET", body, headers } = options;
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("Supabase not configured.");
  }
  const url = `${env.SUPABASE_URL}/rest/v1/${path}`;
  const response = await fetch(url, {
    method,
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...headers || {}
    },
    body: body ? JSON.stringify(body) : void 0
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Supabase request failed (${response.status}): ${text}`);
  }
  if (response.status === 204) return null;
  return response.json();
}
__name(supabaseRequest, "supabaseRequest");
async function upsertStripeCustomer(env, payload) {
  const { userId, customerId } = payload || {};
  if (!userId || !customerId) return;
  await supabaseRequest(env, "stripe_customers?on_conflict=customer_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: {
      user_id: userId,
      customer_id: customerId
    }
  });
}
__name(upsertStripeCustomer, "upsertStripeCustomer");
async function findUserIdForCustomer(env, customerId) {
  if (!customerId) return null;
  const rows = await supabaseRequest(
    env,
    `stripe_customers?select=user_id&customer_id=eq.${encodeURIComponent(
      customerId
    )}&limit=1`
  );
  const row = Array.isArray(rows) ? rows[0] : null;
  return row?.user_id || null;
}
__name(findUserIdForCustomer, "findUserIdForCustomer");
async function resolvePlanByPrice(env, priceId) {
  if (!priceId) return null;
  const rows = await supabaseRequest(
    env,
    `plans?select=id,slug&stripe_price_id=eq.${encodeURIComponent(
      priceId
    )}&limit=1`
  );
  return Array.isArray(rows) ? rows[0] : null;
}
__name(resolvePlanByPrice, "resolvePlanByPrice");
async function upsertSubscription(env, payload) {
  await supabaseRequest(env, "user_subscriptions?on_conflict=user_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: payload
  });
}
__name(upsertSubscription, "upsertSubscription");
async function upsertEntitlements(env, payload) {
  await supabaseRequest(env, "user_entitlements?on_conflict=user_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: payload
  });
}
__name(upsertEntitlements, "upsertEntitlements");
async function upsertWebhookEvent(env, event) {
  const eventId = event?.id;
  if (!eventId) return;
  await supabaseRequest(env, "stripe_webhook_events?on_conflict=event_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: {
      event_id: eventId,
      event_type: event?.type || null,
      processed_at: (/* @__PURE__ */ new Date()).toISOString()
    }
  });
}
__name(upsertWebhookEvent, "upsertWebhookEvent");
async function fetchStripePrices(env, lookupKeys) {
  if (!env.STRIPE_SECRET_KEY) {
    throw new Error("Missing STRIPE_SECRET_KEY.");
  }
  const params = new URLSearchParams();
  params.set("active", "true");
  for (const key of lookupKeys) {
    params.append("lookup_keys[]", key);
  }
  params.append("expand[]", "data.product");
  const response = await fetch(
    `https://api.stripe.com/v1/prices?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`
      }
    }
  );
  const text = await response.text();
  if (!response.ok) {
    throw new Error(text || "Stripe request failed.");
  }
  const payload = JSON.parse(text);
  const data = Array.isArray(payload?.data) ? payload.data : [];
  const mapped = {};
  for (const price of data) {
    const lookupKey = price?.lookup_key || price?.nickname || price?.id;
    if (!lookupKey) continue;
    mapped[lookupKey] = {
      id: price?.id,
      lookup_key: price?.lookup_key || null,
      unit_amount: price?.unit_amount,
      currency: price?.currency,
      product_name: price?.product?.name || null
    };
  }
  return mapped;
}
__name(fetchStripePrices, "fetchStripePrices");
async function handleStripeEvent(env, event) {
  await upsertWebhookEvent(env, event);
  const type = event?.type;
  if (!type) return;
  if (type === "checkout.session.completed") {
    const session = event?.data?.object || {};
    const userId2 = session?.client_reference_id || session?.metadata?.user_id;
    const customer2 = typeof session?.customer === "string" ? session.customer : session?.customer?.id;
    if (userId2 && customer2) {
      await upsertStripeCustomer(env, { userId: userId2, customerId: customer2 });
    }
    return;
  }
  if (!type.startsWith("customer.subscription")) return;
  const subscription = event?.data?.object || {};
  const customer = typeof subscription?.customer === "string" ? subscription.customer : subscription?.customer?.id;
  const userId = await findUserIdForCustomer(env, customer);
  if (!userId) return;
  const items = subscription?.items?.data;
  const priceId = Array.isArray(items) ? items[0]?.price?.id : null;
  const plan = await resolvePlanByPrice(env, priceId);
  const status = subscription?.status || "inactive";
  const periodStart = subscription?.current_period_start ? new Date(subscription.current_period_start * 1e3).toISOString() : null;
  const periodEnd = subscription?.current_period_end ? new Date(subscription.current_period_end * 1e3).toISOString() : null;
  const cancelAtPeriodEnd = Boolean(subscription?.cancel_at_period_end);
  await upsertSubscription(env, {
    user_id: userId,
    plan_id: plan?.id || null,
    status,
    stripe_customer_id: customer || null,
    stripe_subscription_id: subscription?.id || null,
    stripe_price_id: priceId || null,
    current_period_start: periodStart,
    current_period_end: periodEnd,
    cancel_at_period_end: cancelAtPeriodEnd,
    updated_at: (/* @__PURE__ */ new Date()).toISOString()
  });
  const activeStatuses = /* @__PURE__ */ new Set(["active", "trialing", "past_due"]);
  const isPro = plan?.slug === "pro" && activeStatuses.has(status);
  await upsertEntitlements(env, {
    user_id: userId,
    pro_lifetime: isPro,
    updated_at: (/* @__PURE__ */ new Date()).toISOString()
  });
}
__name(handleStripeEvent, "handleStripeEvent");
var worker_default = {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    const url = new URL(request.url);
    if (url.pathname !== "/stripe/webhook") {
      const authError = requireAppToken(request, env);
      if (authError) return authError;
    }
    if (url.pathname === "/stripe/prices") {
      if (request.method !== "GET") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      const lookupParam = url.searchParams.get("lookup_keys") || "";
      const lookupKeys = lookupParam.split(",").map((key) => key.trim()).filter(Boolean);
      if (!lookupKeys.length) {
        return jsonResponse(400, { error: "Missing lookup_keys." });
      }
      try {
        const data = await fetchStripePrices(env, lookupKeys);
        return jsonResponse(200, { data });
      } catch (error) {
        return jsonResponse(500, {
          error: error?.message || "Stripe price fetch failed."
        });
      }
    }
    if (url.pathname === "/stripe/webhook") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      if (!env.STRIPE_WEBHOOK_SECRET) {
        return jsonResponse(500, { error: "Missing STRIPE_WEBHOOK_SECRET." });
      }
      const signature = request.headers.get("stripe-signature") || "";
      const payload = await request.text();
      const isValid = await verifyStripeSignature(
        signature,
        payload,
        env.STRIPE_WEBHOOK_SECRET
      );
      if (!isValid) {
        return jsonResponse(400, { error: "Invalid signature." });
      }
      let event;
      try {
        event = JSON.parse(payload);
      } catch (_) {
        return jsonResponse(400, { error: "Invalid JSON payload." });
      }
      const work = handleStripeEvent(env, event);
      if (ctx?.waitUntil) {
        ctx.waitUntil(work);
        return jsonResponse(200, { received: true });
      }
      await work;
      return jsonResponse(200, { received: true });
    }
    if (url.pathname === "/upload") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      let base64;
      const contentType = request.headers.get("content-type") ?? "";
      try {
        if (contentType.includes("application/json")) {
          const body = await request.json();
          base64 = body?.base64 || body?.data || body?.image;
        } else if (contentType.includes("multipart/form-data")) {
          const form = await request.formData();
          base64 = form.get("base64") || form.get("data");
        } else {
          const text = await request.text();
          base64 = text?.trim();
        }
      } catch (_) {
        return jsonResponse(400, { error: "Invalid upload body." });
      }
      if (!base64 || typeof base64 !== "string") {
        return jsonResponse(400, { error: "Missing base64." });
      }
      const dataUrl = base64.startsWith("data:") ? base64.trim() : `data:image/jpeg;base64,${base64.trim()}`;
      return jsonResponse(200, { imageUrl: dataUrl });
    }
    if (url.pathname === "/chat") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: "Missing OPENAI_API_KEY." });
      }
      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: "Invalid JSON body." });
      }
      const {
        apiKey: _apiKey,
        openaiApiKey: _openaiApiKey,
        messages: rawMessages,
        stream: requestedStream,
        ...rest
      } = body ?? {};
      const incomingMessages = Array.isArray(rawMessages) ? rawMessages : [];
      const systemMessages = buildSystemMessages(env);
      const wantsStream = requestedStream !== false;
      const payload = {
        ...rest,
        messages: [...systemMessages, ...incomingMessages],
        stream: wantsStream
      };
      const headers = {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      };
      if (wantsStream) {
        headers.Accept = "text/event-stream";
      }
      let openaiResponse;
      try {
        openaiResponse = await fetch(
          "https://api.openai.com/v1/chat/completions",
          {
            method: "POST",
            headers,
            body: JSON.stringify(payload)
          }
        );
      } catch (_) {
        return jsonResponse(502, {
          error: "Upstream OpenAI request failed."
        });
      }
      if (!openaiResponse.ok) {
        const errorText = await openaiResponse.text();
        let parsed;
        try {
          parsed = JSON.parse(errorText);
        } catch (_) {
          parsed = null;
        }
        return jsonResponse(
          openaiResponse.status,
          parsed || { error: errorText || "OpenAI error." }
        );
      }
      const contentType = openaiResponse.headers.get("content-type") ?? (wantsStream ? "text/event-stream" : "application/json");
      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...corsHeaders,
          "Content-Type": contentType
        }
      });
    }
    if (url.pathname === "/tts") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: "Missing OPENAI_API_KEY." });
      }
      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: "Invalid JSON body." });
      }
      const {
        text,
        input,
        voice = "onyx",
        model = "tts-1",
        format = "mp3"
      } = body ?? {};
      const resolvedText = typeof text === "string" ? text : typeof input === "string" ? input : "";
      if (!resolvedText.trim()) {
        return jsonResponse(400, { error: "Missing text." });
      }
      const payload = {
        model,
        voice,
        input: resolvedText,
        format
      };
      const openaiResponse = await fetch(
        "https://api.openai.com/v1/audio/speech",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`,
            "Content-Type": "application/json",
            Accept: "audio/mpeg"
          },
          body: JSON.stringify(payload)
        }
      );
      const contentType = openaiResponse.headers.get("content-type") ?? "audio/mpeg";
      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...corsHeaders,
          "Content-Type": contentType
        }
      });
    }
    if (url.pathname === "/stt") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: "Missing OPENAI_API_KEY." });
      }
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("multipart/form-data")) {
        return jsonResponse(400, { error: "Expected multipart/form-data." });
      }
      let formData;
      try {
        formData = await request.formData();
      } catch (_) {
        return jsonResponse(400, { error: "Invalid form data." });
      }
      const file = formData.get("file");
      if (!(file instanceof File)) {
        return jsonResponse(400, { error: "Missing audio file." });
      }
      const model = (formData.get("model") || "gpt-4o-mini-transcribe").toString().trim();
      const language = formData.get("language");
      const prompt = formData.get("prompt");
      const temperature = formData.get("temperature");
      const responseFormat = formData.get("response_format");
      const openaiForm = new FormData();
      openaiForm.append("file", file, file.name || "audio.m4a");
      openaiForm.append("model", model || "gpt-4o-mini-transcribe");
      if (language) {
        openaiForm.append("language", language.toString());
      }
      if (prompt) {
        openaiForm.append("prompt", prompt.toString());
      }
      if (temperature) {
        openaiForm.append("temperature", temperature.toString());
      }
      if (responseFormat) {
        openaiForm.append("response_format", responseFormat.toString());
      }
      const openaiResponse = await fetch(
        "https://api.openai.com/v1/audio/transcriptions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`
          },
          body: openaiForm
        }
      );
      const openaiContentType = openaiResponse.headers.get("content-type") ?? "application/json";
      return new Response(openaiResponse.body, {
        status: openaiResponse.status,
        headers: {
          ...corsHeaders,
          "Content-Type": openaiContentType
        }
      });
    }
    if (url.pathname === "/image-edit") {
      if (request.method !== "POST") {
        return jsonResponse(405, { error: "Method not allowed." });
      }
      if (!env.OPENAI_API_KEY) {
        return jsonResponse(500, { error: "Missing OPENAI_API_KEY." });
      }
      let body;
      try {
        body = await request.json();
      } catch (_) {
        return jsonResponse(400, { error: "Invalid JSON body." });
      }
      const {
        prompt,
        imageUrl,
        imageBase64,
        maskBase64,
        model = "gpt-image-1",
        size,
        notify
      } = body ?? {};
      if (!prompt || typeof prompt !== "string" || !prompt.trim()) {
        return jsonResponse(400, { error: "Missing prompt." });
      }
      if (!maskBase64 || typeof maskBase64 !== "string") {
        return jsonResponse(400, { error: "Missing maskBase64." });
      }
      if ((!imageUrl || typeof imageUrl !== "string") && (!imageBase64 || typeof imageBase64 !== "string")) {
        return jsonResponse(400, { error: "Missing image input." });
      }
      let sourceFile;
      try {
        if (imageUrl && imageUrl.trim()) {
          sourceFile = await fileFromImageUrl(imageUrl, "image.png");
        } else {
          const bytes = decodeBase64ToBytes(imageBase64);
          const type = guessImageType(imageBase64, "image/png");
          sourceFile = new File([bytes], "image.png", { type });
        }
      } catch (e) {
        return jsonResponse(400, { error: e.message || "Image load failed." });
      }
      let maskFile;
      try {
        const maskBytes = decodeBase64ToBytes(maskBase64);
        const maskType = guessImageType(maskBase64, "image/png");
        maskFile = new File([maskBytes], "mask.png", { type: maskType });
      } catch (_) {
        return jsonResponse(400, { error: "Mask decode failed." });
      }
      const form = new FormData();
      form.append("model", model);
      form.append("prompt", prompt);
      if (size && typeof size === "string") {
        form.append("size", size);
      }
      form.append("image", sourceFile, sourceFile.name || "image.png");
      form.append("mask", maskFile, "mask.png");
      const openaiResponse = await fetch(
        "https://api.openai.com/v1/images/edits",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.OPENAI_API_KEY}`
          },
          body: form
        }
      );
      const responseText = await openaiResponse.text();
      if (!openaiResponse.ok) {
        return jsonResponse(openaiResponse.status, {
          error: responseText || "Image edit failed."
        });
      }
      try {
        const parsed = JSON.parse(responseText);
        const data = Array.isArray(parsed?.data) ? parsed.data : [];
        const first = data[0] || {};
        const b64 = first.b64_json || first.image_base64 || first.base64;
        const url2 = first.url || first.imageUrl;
        if (b64) {
          if (notify && ctx?.waitUntil) {
            ctx.waitUntil(sendPushNotification(env, notify));
          }
          return jsonResponse(200, {
            imageBase64: `data:image/png;base64,${b64}`
          });
        }
        if (url2) {
          if (notify && ctx?.waitUntil) {
            ctx.waitUntil(sendPushNotification(env, notify));
          }
          return jsonResponse(200, { imageUrl: url2 });
        }
        if (notify && ctx?.waitUntil) {
          ctx.waitUntil(sendPushNotification(env, notify));
        }
        return jsonResponse(200, parsed);
      } catch (_) {
        if (notify && ctx?.waitUntil) {
          ctx.waitUntil(sendPushNotification(env, notify));
        }
        return jsonResponse(200, { imageBase64: responseText });
      }
    }
    return jsonResponse(404, { error: "Not found." });
  }
};
export {
  worker_default as default
};
//# sourceMappingURL=worker.js.map
