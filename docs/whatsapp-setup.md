# WhatsApp Channel Setup

The repository enables the official OpenClaw WhatsApp plugin for owner-only
direct messages. Telegram remains enabled as a recovery channel. Explicit
owner-approved messages to third parties use `wacli`, so recipients do not
need to be admitted to the inbound OpenClaw allowlist.

## Before Deployment

- Set `WHATSAPP_ADMIN_1` and `WHATSAPP_ADMIN_2` in the infrastructure
  repository's `secrets/openclaw.env` using E.164 format with no spaces.
- These values are operator numbers, not the number linked by the QR login.
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

Only the two configured owner numbers can send direct-message commands. Groups,
channel config writes, and experimental WhatsApp voice calls remain disabled.

## Link Outbound Third-Party Messaging

The bundled `wacli` skill is for explicit requests from an owner to contact a
third party. It uses an independent linked-device session and persists its
credentials under `/home/node/.openclaw/.wacli`.

After deploying the image, pair it once from `~/openclaw` on the VPS:

```bash
docker compose exec openclaw-gateway wacli auth --idle-exit 30s
```

Scan the additional QR code, then verify the persistent session:

```bash
docker compose exec openclaw-gateway wacli auth status --json
```

For third-party sends, the agent must have an explicit recipient and final
message text, show both to the requesting owner, and receive confirmation
before invoking `wacli send`. Do not run `wacli sync --follow`; replies from
non-allowlisted recipients are outside the personal-agent workflow and remain
blocked by the OpenClaw WhatsApp channel policy.
