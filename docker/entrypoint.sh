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
# Install required OpenClaw plugins into persistent state
###############################################################################
if [[ -f "$PLUGIN_MANIFEST" ]]; then
  echo "[entrypoint] Installing OpenClaw plugins from manifest ..."
  while IFS='|' read -r plugin_id plugin_spec; do
    plugin_id="$(echo "${plugin_id%%#*}" | xargs)"
    plugin_spec="$(echo "${plugin_spec:-}" | xargs)"
    [[ -z "$plugin_id" || -z "$plugin_spec" ]] && continue

    if openclaw plugins inspect "$plugin_id" --runtime --json >/dev/null 2>&1; then
      echo "[entrypoint]   $plugin_id (already installed)"
      continue
    fi

    echo "[entrypoint]   installing $plugin_id"
    openclaw plugins install "$plugin_spec" --pin || {
      echo "[entrypoint] WARNING: Failed to install plugin $plugin_id - continuing"
    }
  done < "$PLUGIN_MANIFEST"
  echo "[entrypoint] Plugin installation complete."
fi

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
