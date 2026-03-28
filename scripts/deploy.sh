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

# Patch ElevenLabs plugin for dynamic voice_id and speed support
ssh "${MARK2_HOST}" "python3 << 'PYEOF'
path = '/home/pi/.venvs/ovos/lib/python3.11/site-packages/ovos_tts_plugin_elevenlabs/__init__.py'
with open(path, 'r') as f:
    content = f.read()

# Ensure speed is in __init__
if 'self.speed' not in content:
    content = content.replace(
        'self.use_speaker_boost = self.config.get(\"use_speaker_boost\", True)',
        'self.use_speaker_boost = self.config.get(\"use_speaker_boost\", True)\n        self.speed = self.config.get(\"speed\", 1.0)'
    )

# Ensure speed is in payload
if '\"speed\": self.speed' not in content:
    content = content.replace(
        '\"voice_settings\": {',
        '\"speed\": self.speed,\n            \"voice_settings\": {'
    )

# Ensure voice_id is read dynamically per call
if 'self.config.get(\"voice_id\"' not in content:
    content = content.replace(
        'url = f\"https://api.elevenlabs.io/v1/text-to-speech/{self.voice_id}\"',
        'voice_id = self.config.get(\"voice_id\", self.voice_id)\n        url = f\"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}\"'
    )

with open(path, 'w') as f:
    f.write(content)
print('ElevenLabs plugin patched')
PYEOF"
echo "Plugin patch applied"

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
