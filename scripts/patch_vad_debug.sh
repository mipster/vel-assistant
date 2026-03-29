#!/usr/bin/env bash
# Temporary Phase 1 debug patch: adds timestamp file writes to voice_loop.py
# so we can measure the gap between record_begin and actual VAD speech detection.
# Remove once the 8s timeout fix is confirmed to work.
set -euo pipefail

MARK2_HOST="${MARK2_HOST:-pi@192.168.132.142}"
VOICE_LOOP="/home/pi/.venvs/ovos/lib/python3.11/site-packages/ovos_dinkum_listener/voice_loop/voice_loop.py"

ssh "${MARK2_HOST}" "python3 << 'PYEOF'
import re

path = '${VOICE_LOOP}'
with open(path, 'r') as f:
    content = f.read()

sentinel = 'VEL_VAD_DEBUG'
if sentinel in content:
    print('Debug patch already applied — skipping')
else:
    import re

    # 1. Log entry into _before_cmd (first meaningful line after the def)
    content = re.sub(
        r'(def _before_cmd\(self[^)]*\):\n)',
        r'\1        # VEL_VAD_DEBUG\n'
        r'        import datetime as _dt\n'
        r'        with open(\"/tmp/vel_vad_debug.log\", \"a\") as _f:\n'
        r'            _f.write(_dt.datetime.now().isoformat() + \" BEFORE_COMMAND start\\n\")\n',
        content,
        count=1
    )

    # 2. Log transition to IN_COMMAND (VAD speech detected)
    content = content.replace(
        'self.state = ListeningState.IN_COMMAND',
        'self.state = ListeningState.IN_COMMAND\n'
        '        with open(\"/tmp/vel_vad_debug.log\", \"a\") as _f:\n'
        '            import datetime as _dt2; _f.write(_dt2.datetime.now().isoformat() + \" VAD: speech detected -> IN_COMMAND\\n\")',
        1  # only first occurrence (in _before_cmd)
    )

    # 3. Log timeout_with_silence firing
    content = content.replace(
        'if self.timeout_with_silence',
        'if self.timeout_with_silence',
        # we will do a targeted replace below
    )
    # Find the timeout check block and add logging before the state change
    content = content.replace(
        'self.state = ListeningState.AFTER_COMMAND  # timed out before speech',
        'with open(\"/tmp/vel_vad_debug.log\", \"a\") as _f:\n'
        '                import datetime as _dt3; _f.write(_dt3.datetime.now().isoformat() + \" timeout_with_silence fired (no speech)\\n\")\n'
        '            self.state = ListeningState.AFTER_COMMAND  # timed out before speech',
        1
    )

    with open(path, 'w') as f:
        f.write(content)
    print('VAD debug patch applied to ' + path)
PYEOF"
echo "VAD debug patch done. Restart ovos-listener on device to activate:"
echo "  ssh ${MARK2_HOST} sudo systemctl restart ovos-listener"
echo "Then check /tmp/vel_vad_debug.log after a test."
