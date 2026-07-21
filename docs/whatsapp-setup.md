# WhatsApp Channel Setup

The repository enables the official OpenClaw WhatsApp plugin for owner-only
direct messages. Telegram remains enabled as a recovery channel. Explicit
owner-approved messages to third parties use the same OpenClaw WhatsApp
listener. Recipients do not need to be admitted to the inbound allowlist.

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

Do the pairing in a wide interactive SSH terminal. Do not relay the QR through
Telegram or another image-compression path because the QR is both short-lived
and sensitive.

On the VPS, from `~/openclaw`, clear a logged-out session and start a fresh
login:

```bash
docker compose exec openclaw-gateway \
  openclaw channels logout --channel whatsapp --account default

docker compose exec openclaw-gateway \
  openclaw channels login --channel whatsapp --account default
```

Maximize the terminal or reduce its font size if the QR wraps. Scan the current
QR code immediately in WhatsApp under **Linked devices** and wait for the CLI to
confirm that credentials were saved. If it expires, rerun the login command.

Restart the gateway and verify the listener:

```bash
docker compose restart openclaw-gateway
sleep 10
docker compose exec openclaw-gateway \
  openclaw channels status --channel whatsapp --probe --json
```

The WhatsApp status must report `connected: true` and `running: true`. A last
disconnect status of `401` means the linked-device session was logged out; a
restart cannot repair it, so remove the stale entry from **Linked devices** and
repeat logout/login.

Only the two configured owner numbers can send direct-message commands.
`selfChatMode` also permits the linked account to issue commands through its
**Message yourself** chat when that account is one of the configured owners.
Groups, channel config writes, and experimental WhatsApp voice calls remain
disabled.

## Outbound Third-Party Messaging

Do not pair a second WhatsApp Web client. OpenClaw's native message command can
send to an explicit E.164 target through the already-linked listener:

```bash
docker compose exec openclaw-gateway \
  openclaw message send --channel whatsapp \
  --target "+<RECIPIENT_E164>" --message "<FINAL_MESSAGE>"
```

`allowFrom` controls who may send inbound commands; it does not block explicit
outbound targets. Replies from non-allowlisted recipients are still rejected by
the channel's `dmPolicy` and cannot become agent instructions.

For third-party sends, the agent must have an explicit recipient and final
message text, show both to the requesting owner, and receive confirmation before
using the native WhatsApp message action. For a batch or sheet-driven send, it
must also confirm the source, recipient count, schedule, and a representative
preview, reject empty, duplicate, malformed, or non-WhatsApp targets, and keep a
send-result ledger.

Start with one controlled outbound recipient. From an allowlisted WhatsApp
operator or Telegram, ask the agent to send an exact message by WhatsApp.
Confirm the normalized E.164 recipient and final message when prompted.
