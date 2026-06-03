# Groq Proxy Worker

This worker proxies AI chat requests from the Flutter app to Groq.

## What it does

- accepts `POST /ai/chat`
- requires `Authorization: Bearer <Firebase ID token>`
- validates the Firebase token against project `mediai-a4ebf`
- forwards the request to Groq using the server-side `GROQ_API_KEY`

## Required worker config

`wrangler.toml` already contains:

- `FIREBASE_PROJECT_ID = "mediai-a4ebf"`

You still need to set the Groq secret before deploy:

```bash
wrangler secret put GROQ_API_KEY
```

## Deploy

From `workers/groq-proxy`:

```bash
wrangler deploy
```

After deploy, copy the worker endpoint into the app `.env`:

```env
AI_PROXY_URL=https://<your-worker>.workers.dev/ai/chat
```

## Smoke test

1. Sign in to the app with Firebase Auth.
2. Set `AI_PROXY_URL` in `.env`.
3. Restart the app.
4. Send an AI request without VPN.
5. Confirm the request succeeds and no direct `api.groq.com` call is required from the client.

## Notes

- If `AI_PROXY_URL` is empty, the app falls back to direct Groq calls from the client.
- If Groq returns `403` because of model/account permissions rather than geo-routing, the worker will not fix that.
