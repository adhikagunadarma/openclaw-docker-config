# WhatsApp Channel Setup

The repository enables the official OpenClaw WhatsApp plugin for owner-only
direct messages. Telegram remains enabled as a recovery channel.

## Before Deployment

- Set `WHATSAPP_ADMIN_1` in the infrastructure repository's
  `secrets/openclaw.env` using E.164 format with no spaces.
- Prefer a dedicated WhatsApp account for OpenClaw.
- Keep the phone with that account available to scan a linked-device QR code.

The plugin is pinned to the OpenClaw version in `docker/Dockerfile` and is
installed into the mounted OpenClaw state directory on container startup.

## Deploy

1. Build and push the Docker image with `bash scripts/build-and-push.sh`.
2. From the Hetzner infrastructure repository, run `make push-env`.
3. Run `make deploy` to pull the new image, recreate the gateway, and install
   the WhatsApp plugin into persistent state.
4. Before enabling the channel, verify the plugin on the VPS:

   ```bash
   docker compose exec openclaw-gateway \
     openclaw plugins inspect whatsapp --runtime --json
   ```

5. Run `make push-config` only after the plugin inspection succeeds. This
   enables the channel and restarts the gateway.
6. Run `make status` and confirm Telegram still responds before linking
   WhatsApp.

## Link WhatsApp

On the VPS, from `~/openclaw`, run:

```bash
docker compose exec openclaw-gateway \
  openclaw channels login --channel whatsapp
```

Scan the QR code in WhatsApp under **Linked devices**, then verify:

```bash
docker compose exec openclaw-gateway \
  openclaw channels status --probe
```

Only the configured owner number can send direct-message commands. Groups,
channel config writes, and experimental WhatsApp voice calls remain disabled.
