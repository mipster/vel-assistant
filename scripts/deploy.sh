#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$REPO_ROOT/secrets.env"
MARK2_HOST="${MARK2_HOST:-mycroft.local}"

# Load secrets
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: secrets.env not found at $SECRETS_FILE" >&2
  exit 1
fi
set -a; source "$SECRETS_FILE"; set +a

# Build persona/vel.json from template
envsubst < "$REPO_ROOT/persona/vel.template.json" > "$REPO_ROOT/persona/vel.json"
echo "Built persona/vel.json from template"

# Deploy to Mark II
rsync -av "$REPO_ROOT/persona/vel.json" "${MARK2_HOST}:~/.config/ovos_persona/vel.json"
rsync -av "$REPO_ROOT/skill-vel-router/" "${MARK2_HOST}:~/.local/share/mycroft/skills/skill-vel-router/"
rsync -av "$REPO_ROOT/config/mycroft.conf.patch" "${MARK2_HOST}:~/mycroft.conf.patch"

echo "Deploy complete."
