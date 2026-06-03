interface Env {
  GROQ_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
}

interface FirebaseTokenPayload {
  aud?: string;
  auth_time?: number;
  exp?: number;
  iat?: number;
  iss?: string;
  sub?: string;
  user_id?: string;
  [key: string]: unknown;
}

const GOOGLE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const MAX_MESSAGES = 24;
const MAX_TEXT_LENGTH = 16_000;
const MAX_IMAGE_URI_LENGTH = 4 * 1024 * 1024;
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

let cachedJwks: Record<string, JsonWebKey> | null = null;
let cachedJwksExpiresAt = 0;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/ai/chat") {
      return jsonError(404, "Not found");
    }

    if (!env.GROQ_API_KEY?.trim()) {
      return jsonError(500, "GROQ_API_KEY is not configured on the worker.");
    }

    const authHeader = request.headers.get("Authorization") ?? "";
    const idToken = extractBearerToken(authHeader);
    if (!idToken) {
      return jsonError(401, "Missing Firebase ID token.");
    }

    let tokenPayload: FirebaseTokenPayload;
    try {
      tokenPayload = await verifyFirebaseIdToken(
        idToken,
        env.FIREBASE_PROJECT_ID,
      );
    } catch (error) {
      return jsonError(
        401,
        error instanceof Error ? error.message : "Invalid Firebase ID token.",
      );
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch (_) {
      return jsonError(400, "Invalid JSON request body.");
    }

    let payload: Record<string, unknown>;
    try {
      payload = normalizePayload(body);
    } catch (error) {
      return jsonError(
        400,
        error instanceof Error ? error.message : "Invalid AI payload.",
      );
    }

    const groqResponse = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const responseText = await groqResponse.text();
    if (!groqResponse.ok) {
      const providerMessage = extractProviderMessage(responseText);
      return jsonError(
        groqResponse.status,
        providerMessage || `Groq returned ${groqResponse.status}.`,
      );
    }

    let decoded: any;
    try {
      decoded = JSON.parse(responseText);
    } catch (_) {
      return jsonError(502, "Groq returned invalid JSON.");
    }

    const content = decoded?.choices?.[0]?.message?.content?.trim?.();
    if (!content) {
      return jsonError(502, "Groq returned an empty completion.");
    }

    return jsonResponse({
      content,
      model: String(decoded?.model || payload.model || ""),
      promptTokens: toInt(decoded?.usage?.prompt_tokens),
      completionTokens: toInt(decoded?.usage?.completion_tokens),
      uid: tokenPayload.user_id || tokenPayload.sub || null,
    });
  },
};

function normalizePayload(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object") {
    throw new Error("Payload must be an object.");
  }

  const source = input as Record<string, unknown>;
  const model = String(source.model || "").trim();
  if (!model) {
    throw new Error("Model is required.");
  }

  const messages = Array.isArray(source.messages) ? source.messages : [];
  if (!messages.length || messages.length > MAX_MESSAGES) {
    throw new Error(`Messages must contain between 1 and ${MAX_MESSAGES} items.`);
  }

  return {
    model,
    messages: messages.map(normalizeMessage),
    temperature: clampNumber(source.temperature, 0, 2, 0.2),
    max_completion_tokens: clampInteger(
      source.max_completion_tokens,
      1,
      2048,
      400,
    ),
  };
}

function normalizeMessage(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object") {
    throw new Error("Each message must be an object.");
  }

  const source = input as Record<string, unknown>;
  const role = String(source.role || "").trim();
  if (!["system", "user", "assistant"].includes(role)) {
    throw new Error("Invalid message role.");
  }

  const content = source.content;
  if (typeof content === "string") {
    if (content.length > MAX_TEXT_LENGTH) {
      throw new Error("A message exceeds the maximum text length.");
    }
    return { role, content };
  }

  if (!Array.isArray(content) || !content.length) {
    throw new Error("Message content is invalid.");
  }

  return {
    role,
    content: content.map((part) => normalizeContentPart(part)),
  };
}

function normalizeContentPart(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object") {
    throw new Error("Invalid multimodal content part.");
  }

  const source = input as Record<string, any>;
  if (source.type === "text") {
    const text = String(source.text || "");
    if (text.length > MAX_TEXT_LENGTH) {
      throw new Error("A text segment exceeds the maximum length.");
    }
    return { type: "text", text };
  }

  if (source.type === "image_url") {
    const url = String(source.image_url?.url || "");
    if (!url || url.length > MAX_IMAGE_URI_LENGTH) {
      throw new Error("An image attachment exceeds the maximum size.");
    }
    return { type: "image_url", image_url: { url } };
  }

  throw new Error("Unsupported content part type.");
}

async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<FirebaseTokenPayload> {
  const [encodedHeader, encodedPayload, encodedSignature] = token.split(".");
  if (!encodedHeader || !encodedPayload || !encodedSignature) {
    throw new Error("Malformed Firebase ID token.");
  }

  const header = parseJsonBase64Url(encodedHeader) as { alg?: string; kid?: string };
  const payload = parseJsonBase64Url(encodedPayload) as FirebaseTokenPayload;

  if (header.alg !== "RS256" || !header.kid) {
    throw new Error("Unsupported Firebase token algorithm.");
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.aud !== projectId) {
    throw new Error("Firebase token audience mismatch.");
  }
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error("Firebase token issuer mismatch.");
  }
  if (!payload.sub || payload.sub.length > 128) {
    throw new Error("Firebase token subject is invalid.");
  }
  if (!payload.exp || payload.exp <= now) {
    throw new Error("Firebase token has expired.");
  }
  if (!payload.iat || payload.iat > now + 60) {
    throw new Error("Firebase token issue time is invalid.");
  }

  const jwks = await getFirebaseJwks();
  const jwk = jwks[header.kid];
  if (!jwk) {
    throw new Error("Unable to resolve Firebase signing certificate.");
  }

  const publicKey = await importGoogleJwk(jwk);
  const signature = base64UrlToUint8Array(encodedSignature);
  const signedData = new TextEncoder().encode(
    `${encodedHeader}.${encodedPayload}`,
  );

  const isValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    signature,
    signedData,
  );
  if (!isValid) {
    throw new Error("Firebase token signature is invalid.");
  }

  return payload;
}

async function getFirebaseJwks(): Promise<Record<string, JsonWebKey>> {
  const now = Date.now();
  if (cachedJwks && now < cachedJwksExpiresAt) {
    return cachedJwks;
  }

  const response = await fetch(GOOGLE_JWKS_URL, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) {
    throw new Error("Unable to load Firebase public certificates.");
  }

  const decoded = (await response.json()) as { keys?: JsonWebKey[] };
  const keys = Array.isArray(decoded.keys) ? decoded.keys : [];
  const jwks = keys.reduce<Record<string, JsonWebKey>>((acc, key) => {
    if (typeof key.kid === "string" && key.kid.trim().length > 0) {
      acc[key.kid] = key;
    }
    return acc;
  }, {});
  const cacheControl = response.headers.get("Cache-Control") ?? "";
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAgeSeconds = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;

  cachedJwks = jwks;
  cachedJwksExpiresAt = now + maxAgeSeconds * 1000;
  return jwks;
}

async function importGoogleJwk(jwk: JsonWebKey): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["verify"],
  );
}

function parseJsonBase64Url(value: string): unknown {
  const bytes = base64UrlToUint8Array(value);
  return JSON.parse(new TextDecoder().decode(bytes));
}

function base64UrlToUint8Array(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(normalized + padding);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function extractBearerToken(value: string): string | null {
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function extractProviderMessage(body: string): string {
  try {
    const decoded = JSON.parse(body) as Record<string, any>;
    return (
      String(decoded?.error?.message || "").trim() ||
      String(decoded?.message || "").trim()
    );
  } catch (_) {
    return "";
  }
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, numeric));
}

function clampInteger(value: unknown, min: number, max: number, fallback: number): number {
  const numeric = parseInt(String(value), 10);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, numeric));
}

function toInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  const numeric = parseInt(String(value), 10);
  return Number.isFinite(numeric) ? numeric : null;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders,
    },
  });
}

function jsonError(status: number, message: string): Response {
  return jsonResponse({ error: { message }, message }, status);
}
