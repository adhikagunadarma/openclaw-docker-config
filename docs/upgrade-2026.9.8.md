# Upgrade to OpenClaw 2026.9.8

The repository now pins core and all six external plugins to 2026.9.8. npm publication and the Node requirement were verified: Node 24.16.0 meets `>=24.16.0 <25 || >=26.1.0`.

The prepared config selects GPT-6 Luna as primary, with GPT-6 Sol as fallback. Utility, PDF, heartbeat, and subagents also use GPT-6 Luna. Both models use the Codex runtime and low effort. GPT-6.1 Sol is not selected; its support was incomplete in this release. Account access must still be verified on the live gateway.

## Run from your Mac

```bash
cd /Users/Pong/Project/Personal/pepongclaw/openclaw-terraform-hetzner
source config/inputs.sh
make status SERVER_IP=openclaw-prod
make build
make upgrade SERVER_IP=openclaw-prod
make status SERVER_IP=openclaw-prod
make logs SERVER_IP=openclaw-prod
```

`make build` builds and pushes images tagged `2026.9.8`. It requires Docker and a GHCR login with push access. `make upgrade` requires the existing server GHCR pull access. Neither command is a Terraform infrastructure change.

`make upgrade`:

1. Validates the local config and stages it on the server.
2. Pulls the version-tagged image and checks its OpenClaw version before touching live state.
3. Checks backup capacity before stopping services. Free enough disk space for the new image and a full state backup first.
4. Saves Compose configuration and tags the current image for recovery in `~/backups/upgrade-TIMESTAMP`.
5. Stops gateway and sync services and takes a verified backup with retention cleanup disabled. The backup path is recorded in the recovery directory's `backup.log`.
6. Installs the prepared `openclaw.json` and writes a managed Compose image override. An existing custom override is refused for manual review.
7. Runs the new entrypoint in explicit repair mode: reconciles pinned plugins, runs Doctor repair, then validates config and post-upgrade diagnostics. Output is saved in the recovery directory as `repair.log`. It does not start the gateway in repair mode.
8. Starts the gateway, checks health for up to five minutes, and resumes workspace sync when configured. Errors after shutdown leave services stopped for investigation; no automatic downgrade is attempted.

Do not run `make push-config` between shutdown and repair: that target restarts the gateway. Doctor can migrate the live config; review and carry intentional changes back into the repository before a subsequent config push. Normal `make deploy` respects the managed Compose override and continues using the versioned image.

## Verify models and scheduled jobs

Confirm version 2026.9.8, send Telegram and WhatsApp test messages, and use `/codex models` in chat to confirm account access to GPT-6 Sol and Luna. Test a model turn, Brave search, browser use, and scheduled delivery.

Once Luna is available:

```bash
make set-cron-models
```

This updates editable model-backed cron jobs, including disabled jobs, to GPT-6 Luna with low effort. System-owned declared jobs are skipped because the cron client cannot edit them. Updating JSON defaults alone does not replace saved cron overrides.

## Recovery

Do not start the old image on migrated databases. Restore the image and matching state backup together; work after the backup is lost from the restored state.

The recovery directory contains the original Compose files, old image ID, and `rollback-image.yml`. Before `make restore`, point the active gateway image at the saved `openclaw-gateway:pre-upgrade-TIMESTAMP` tag. The restore target automatically starts services after extracting the backup, so the image must be selected first. An image-only downgrade is unsafe.

Sources: [2026.9.5 migration notes](https://docs.openclaw.ai/releases/2026.9.5), [2026.9.7 migration notes](https://docs.openclaw.ai/releases/2026.9.7), [2026.9.8 notes](https://docs.openclaw.ai/releases/2026.9.8).
