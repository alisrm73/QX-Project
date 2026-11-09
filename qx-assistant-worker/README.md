# QX Assistant Worker

Small Cloudflare Worker that safely proxies QX Studio chat requests to the OpenAI Responses API.

## Routes

- `GET /health` — public health check; does not reveal secret configuration.
- `POST /v1/chat` — requires `Authorization: Bearer <QX_CONNECTOR_TOKEN>`.

## Required Worker secrets

Configure these in Cloudflare Worker settings. Never commit them or place them in the Android app:

- `OPENAI_API_KEY` — OpenAI API key.
- `QX_CONNECTOR_TOKEN` — a separate, high-entropy token used only between QX Studio and this Worker.

Optional non-secret variable:

- `OPENAI_MODEL` — defaults to `gpt-6-astra`.

The Worker limits requests to 48 KB and 20 text messages, accepts only user/assistant roles, disables response storage, and does not expose the OpenAI key to the client.

## Deploy

Create a Worker named `qx-assistant-worker` in Cloudflare and publish `src/index.js`. Add the two required secrets in Worker settings before enabling chat. Set the Worker URL and the QX connector token in the QX Studio assistant screen.

The health route can be tested before secrets are configured. Chat requests remain unavailable until both secrets are present.
