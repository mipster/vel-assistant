#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$REPO_ROOT/secrets.env"
MARK2_HOST="${MARK2_HOST:-pi@192.168.132.142}"

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

# Inject TTS config into mycroft.conf on device
ssh "${MARK2_HOST}" "python3 -c \"
import json
with open('/home/pi/.config/mycroft/mycroft.conf', 'r') as f:
    conf = json.load(f)
conf['tts'] = {
    'module': 'ovos-tts-plugin-elevenlabs',
    'ovos-tts-plugin-elevenlabs': {
        'api_key': '${ELEVENLABS_API_KEY}',
        'voice_id': '5AYcH1Cr8nW0XgDTtRI4',
        'model_id': 'eleven_flash_v2_5',
        'stability': 0.5,
        'similarity_boost': 0.75,
        'style': 0.0,
        'use_speaker_boost': True,
        'speed': 1.2
    }
}
with open('/home/pi/.config/mycroft/mycroft.conf', 'w') as f:
    json.dump(conf, f, indent=4)
\""
echo "TTS config injected into mycroft.conf"

echo "Deploy complete."
