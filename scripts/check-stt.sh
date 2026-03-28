#!/usr/bin/env bash
# Check all OVOS community STT servers and report latency

MARK2_HOST="${MARK2_HOST:-pi@192.168.132.142}"

declare -A SERVERS=(
  ["Faster Whisper — Smart'Gic (current)"]="https://stt.smartgic.io/fasterwhisper/status"
  ["Faster Whisper — Ziggyai"]="https://fasterwhisper.ziggyai.online/status"
  ["Faster Whisper — Neon AI"]="https://whisper.neonaiservices.com/status"
  ["Citrinet — Smart'Gic"]="https://stt.smartgic.io/citrinet/status"
  ["Citrinet — Ziggyai"]="https://citrinetstt.ziggyai.online/status"
)

echo "=== OVOS STT Server Status ==="
echo ""

for NAME in "${!SERVERS[@]}"; do
  URL="${SERVERS[$NAME]}"
  RESULT=$(curl -s --max-time 8 -o /dev/null -w "%{http_code} %{time_total}" "$URL" 2>/dev/null)
  HTTP=$(echo "$RESULT" | cut -d' ' -f1)
  TIME=$(echo "$RESULT" | cut -d' ' -f2)
  TIME_MS=$(echo "$TIME * 1000" | bc 2>/dev/null | cut -d'.' -f1)

  if [[ "$HTTP" == "000" ]]; then
    printf "  %-42s  UNREACHABLE\n" "$NAME"
  else
    printf "  %-42s  HTTP %-3s  %sms\n" "$NAME" "$HTTP" "$TIME_MS"
  fi
done

echo ""
echo "=== Active STT on Mark II ==="
ssh "$MARK2_HOST" "python3 -c \"
import json, os
paths = [
  '/home/pi/.config/mycroft/mycroft.conf',
  '/home/pi/.config/ovos/ovos.conf',
]
for p in paths:
  if os.path.exists(p):
    conf = json.load(open(p))
    module = conf.get('stt', {}).get('module', 'not set')
    url = conf.get('stt', {}).get('ovos-stt-plugin-server', {}).get('url', '')
    print(f'Config: {p}')
    print(f'  Module: {module}')
    if url:
      print(f'  URL:    {url}')
\"" 2>/dev/null || echo "  (SSH check failed — is Mark II reachable?)"
