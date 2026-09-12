#!/usr/bin/env bash
set -euo pipefail

MANIFEST="/opt/config/skills-manifest.txt"
PLUGIN_MANIFEST="/opt/config/plugins-manifest.txt"
WORKDIR="/home/node/.openclaw/workspace"

###############################################################################
# Persist PollyReach credentials under the mounted OpenClaw state directory
###############################################################################
POLLYREACH_LEGACY_DIR="$HOME/.config/PollyReach"
POLLYREACH_STATE_DIR="$HOME/.openclaw/.config/PollyReach"

mkdir -p "$HOME/.config" "$POLLYREACH_STATE_DIR"

if [[ -d "$POLLYREACH_LEGACY_DIR" && ! -L "$POLLYREACH_LEGACY_DIR" ]]; then
  cp -an "$POLLYREACH_LEGACY_DIR"/. "$POLLYREACH_STATE_DIR"/
  mv "$POLLYREACH_LEGACY_DIR" "${POLLYREACH_LEGACY_DIR}.pre-persist"
fi

if [[ ! -e "$POLLYREACH_LEGACY_DIR" && ! -L "$POLLYREACH_LEGACY_DIR" ]]; then
  ln -s "$POLLYREACH_STATE_DIR" "$POLLYREACH_LEGACY_DIR"
elif [[ -L "$POLLYREACH_LEGACY_DIR" ]] \
  && [[ "$(readlink "$POLLYREACH_LEGACY_DIR")" != "$POLLYREACH_STATE_DIR" ]]; then
  echo "[entrypoint] WARNING: PollyReach config link points to an unexpected target"
fi

###############################################################################
# Remove retired wacli state
###############################################################################
WACLI_STATE_DIR="$HOME/.openclaw/.wacli"
if [[ -d "$WACLI_STATE_DIR" && ! -L "$WACLI_STATE_DIR" ]]; then
  echo "[entrypoint] Removing retired wacli credentials and local message store ..."
  rm -rf -- "$WACLI_STATE_DIR"
fi

###############################################################################
# Seed workspace templates (no-clobber — won't overwrite existing files)
###############################################################################
TEMPLATES="/opt/workspace-templates"
if [[ -d "$TEMPLATES" ]]; then
  echo "[entrypoint] Seeding workspace templates ..."
  cp -rn "$TEMPLATES"/. "$WORKDIR"/
fi

###############################################################################
# Reconcile required OpenClaw plugins before Doctor inspects configured providers
###############################################################################
if [[ -f "$PLUGIN_MANIFEST" ]]; then
  echo "[entrypoint] Installing OpenClaw plugins from manifest ..."
  while IFS='|' read -r plugin_id plugin_spec; do
    plugin_id="$(echo "${plugin_id%%#*}" | xargs)"
    plugin_spec="$(echo "${plugin_spec:-}" | xargs)"
    [[ -z "$plugin_id" || -z "$plugin_spec" ]] && continue
    expected_version="${plugin_spec##*@}"

    if openclaw plugins inspect "$plugin_id" --runtime --json >/dev/null 2>&1; then
      echo "[entrypoint]   updating $plugin_id to $plugin_spec"
      openclaw plugins update "$plugin_spec" || true
    else
      echo "[entrypoint]   installing $plugin_id"
      openclaw plugins install "$plugin_spec" --pin
    fi

    installed_version="$(openclaw plugins inspect "$plugin_id" --json \
      | jq -er '.plugin.version')"
    if [[ "$installed_version" != "$expected_version" ]]; then
      echo "[entrypoint]   $plugin_id remained at $installed_version; force-installing $expected_version"
      openclaw plugins install "$plugin_spec" --force --pin
      installed_version="$(openclaw plugins inspect "$plugin_id" --json \
        | jq -er '.plugin.version')"
    fi

    if [[ "$installed_version" != "$expected_version" ]]; then
      echo "[entrypoint] ERROR: $plugin_id is $installed_version; expected $expected_version"
      exit 1
    fi
    echo "[entrypoint]   $plugin_id $installed_version ready"
  done < "$PLUGIN_MANIFEST"
  echo "[entrypoint] Plugin installation complete."
fi

###############################################################################
# Run diagnostics with the pinned plugin cohort loaded
###############################################################################
# Plugin installation requires a writable configuration surface. Once the
# manifest is reconciled, make the repository-managed config immutable for
# Doctor and the gateway while leaving normal runtime state writable.
export OPENCLAW_CONFIG_READONLY=1
echo "[entrypoint] Validating repository-managed configuration ..."
openclaw config validate --json | jq -e '.valid == true' >/dev/null
echo "[entrypoint] Running OpenClaw post-upgrade plugin diagnostics ..."
openclaw doctor --post-upgrade --json | jq -e '(.findings // []) | length == 0' >/dev/null

###############################################################################
# Install ClawHub skills from the manifest (if present)
###############################################################################
if [[ -f "$MANIFEST" ]]; then
  echo "[entrypoint] Installing ClawHub skills from manifest ..."
  while IFS= read -r line; do
    # Skip blank lines and comments
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    install_dir="${line##*/}"

    # Skip if already installed. Scoped ClawHub names like @owner/skill usually
    # land in the workspace by their skill slug.
    if [[ -d "$WORKDIR/skills/$line" || -d "$WORKDIR/skills/$install_dir" ]]; then
      echo "[entrypoint]   ✓ $line (already installed)"
      continue
    fi

    echo "[entrypoint]   → installing $line"
    clawhub install "$line" --workdir "$WORKDIR" || {
      echo "[entrypoint] WARNING: Failed to install $line — continuing"
    }
  done < "$MANIFEST"
  echo "[entrypoint] Skill installation complete."
else
  echo "[entrypoint] No skills manifest found — skipping skill install."
fi

###############################################################################
# Hand off to the real command (CMD from docker-compose)
###############################################################################
exec "$@"
