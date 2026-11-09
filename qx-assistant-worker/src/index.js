const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
const MAX_BODY_BYTES = 48 * 1024;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 8000;

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders },
  });
}

function corsHeaders(request) {
  const origin = request.headers.get("Origin");
  return {
    "access-control-allow-origin": origin || "*",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-max-age": "86400",
    "vary": "Origin",
  };
}

function extractOutputText(payload) {
  if (typeof payload.output_text === "string" && payload.output_text.length > 0) {
    return payload.output_text;
  }
  const chunks = [];
  for (const item of payload.output || []) {
    if (item.type !== "message" || item.role !== "assistant") continue;
    for (const part of item.content || []) {
      if (part.type === "output_text" && typeof part.text === "string") chunks.push(part.text);
    }
  }
  return chunks.join("\n").trim();
}

export default {
  async fetch(request, env) {
    const headers = corsHeaders(request);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });

    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, service: "qx-assistant-worker" }, 200, headers);
    }
    if (request.method !== "POST" || url.pathname !== "/v1/chat") {
      return json({ error: "Not found" }, 404, headers);
    }
    if (!env.QX_CONNECTOR_TOKEN || !env.OPENAI_API_KEY) {
      return json({ error: "Server setup is incomplete" }, 503, headers);
    }
    if ((request.headers.get("Authorization") || "") !== `Bearer ${env.QX_CONNECTOR_TOKEN}`) {
      return json({ error: "Unauthorized" }, 401, headers);
    }

    const contentLength = Number(request.headers.get("Content-Length") || 0);
    if (contentLength > MAX_BODY_BYTES) return json({ error: "Request is too large" }, 413, headers);

    let body;
    try {
      const raw = await request.text();
      if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
        return json({ error: "Request is too large" }, 413, headers);
      }
      body = JSON.parse(raw);
    } catch {
      return json({ error: "Invalid JSON body" }, 400, headers);
    }

    if (!Array.isArray(body.messages) || body.messages.length === 0 || body.messages.length > MAX_MESSAGES) {
      return json({ error: "Provide between 1 and 20 messages" }, 400, headers);
    }
    const messages = [];
    for (const message of body.messages) {
      if (!message || !["user", "assistant"].includes(message.role) ||
          typeof message.content !== "string" || !message.content.trim() ||
          message.content.length > MAX_MESSAGE_CHARS) {
        return json({ error: "Invalid message format" }, 400, headers);
      }
      messages.push({ role: message.role, content: message.content });
    }

    try {
      const upstream = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "authorization": `Bearer ${env.OPENAI_API_KEY}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || "gpt-6-astra",
          instructions: "You are the assistant inside QX Studio. Help the user plan, understand, and build projects. Be clear about actions you can and cannot perform. Never claim to have changed files or run tools unless the application explicitly provides and confirms that capability.",
          input: messages,
          max_output_tokens: 1200,
          store: false,
        }),
      });
      const result = await upstream.json().catch(() => ({}));
      if (!upstream.ok) {
        return json({ error: "The AI provider could not complete the request", provider_status: upstream.status }, 502, headers);
      }
      const answer = extractOutputText(result);
      if (!answer) return json({ error: "The AI provider returned an empty response" }, 502, headers);
      return json({ ok: true, answer }, 200, headers);
    } catch {
      return json({ error: "Unable to reach the AI provider" }, 502, headers);
    }
  },
};
