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

# Install skill into OVOS venv so it's discoverable via entry points
ssh "${MARK2_HOST}" "~/.venvs/ovos/bin/pip install -e ~/.local/share/mycroft/skills/skill-vel-router/ -q"
echo "skill-vel-router installed in OVOS venv"
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

# Ensure voice_id is read from override file per call (avoids mycroft.conf writes/listener reloads)
OVERRIDE_SENTINEL = 'vel_voice_override'
OVERRIDE_CODE = 'import os as _os; _override = _os.path.expanduser(\"~/.config/mycroft/vel_voice_override\"); _voice_id = open(_override).read().strip() if _os.path.exists(_override) else self.voice_id'
if OVERRIDE_SENTINEL not in content:
    # Replace old config-based patch if present, otherwise replace original line
    if 'voice_id = self.config.get(\"voice_id\", self.voice_id)' in content:
        content = content.replace('voice_id = self.config.get(\"voice_id\", self.voice_id)', OVERRIDE_CODE + '; voice_id = _voice_id')
    elif 'url = f\"{self.API_URL}/{self.voice_id}\"' in content:
        content = content.replace(
            'url = f\"{self.API_URL}/{self.voice_id}\"',
            OVERRIDE_CODE + '\n        url = f\"{self.API_URL}/{_voice_id}\"'
        )
    else:
        content = content.replace(
            'url = f\"https://api.elevenlabs.io/v1/text-to-speech/{self.voice_id}\"',
            OVERRIDE_CODE + '\n        url = f\"https://api.elevenlabs.io/v1/text-to-speech/{_voice_id}\"'
        )

with open(path, 'w') as f:
    f.write(content)
print('ElevenLabs plugin patched')
PYEOF"
echo "Plugin patch applied"

# Inject TTS and listener config into mycroft.conf on device
ssh "${MARK2_HOST}" "python3 -c \"
import json
with open('/home/pi/.config/mycroft/mycroft.conf', 'r') as f:
    conf = json.load(f)
conf['tts'] = {
    'module': 'ovos-tts-plugin-elevenlabs',
    'ovos-tts-plugin-elevenlabs': {
        'api_key': '${ELEVENLABS_API_KEY}',
        'voice_id': '0lp4RIz96WD1RUtvEu3Q',
        'model_id': 'eleven_flash_v2_5',
        'stability': 0.5,
        'similarity_boost': 0.75,
        'style': 0.0,
        'use_speaker_boost': True,
        'speed': 1.2
    }
}
listener = conf.get('listener', {})
listener['recording_timeout_with_silence'] = 8.0
conf['listener'] = listener
with open('/home/pi/.config/mycroft/mycroft.conf', 'w') as f:
    json.dump(conf, f, indent=4)
\""
echo "TTS + listener config injected into mycroft.conf"

echo "Deploy complete."
