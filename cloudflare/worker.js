const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
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

    const url = new URL(request.url);
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

    return jsonResponse(404, { error: 'Not found.' });
  },
};
