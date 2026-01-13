const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Worker-Token',
};

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

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
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

function buildSystemMessages(env) {
  const systemMessages = [];
  const brain = (env.PROMPT_BRAIN || '').trim();
  const tech = (env.PROMPT_TECH || '').trim();

  if (brain) {
    systemMessages.push({ role: 'system', content: brain });
  }
  if (tech) {
    systemMessages.push({ role: 'system', content: tech });
  }

  return systemMessages;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const authError = requireAppToken(request, env);
    if (authError) return authError;

    const url = new URL(request.url);
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
      const systemMessages = buildSystemMessages(env);

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
          ...corsHeaders,
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
          ...corsHeaders,
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
          ...corsHeaders,
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

    return jsonResponse(404, { error: 'Not found.' });
  },
};
