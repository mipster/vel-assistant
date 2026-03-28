#!/usr/bin/env bash
# Check whether the OVOS community STT server is reachable

STT_URL="https://stt.openvoiceos.org"
MARK2_HOST="${MARK2_HOST:-pi@192.168.132.142}"

echo "Checking STT server..."
HTTP=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$STT_URL" 2>/dev/null)

if [[ "$HTTP" == "000" ]]; then
    echo "STT server UNREACHABLE ($STT_URL)"
    exit 1
else
    echo "STT server OK — HTTP $HTTP ($STT_URL)"
fi

echo ""
echo "Checking active STT module on Mark II..."
ssh "$MARK2_HOST" "python3 -c \"
import json
conf = json.load(open('/home/pi/.config/mycroft/mycroft.conf'))
print('Active module:', conf.get('stt', {}).get('module', 'not set'))
\"" 2>/dev/null
