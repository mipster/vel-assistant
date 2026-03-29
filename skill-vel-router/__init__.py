import os
import subprocess

from ovos_workshop.skills import OVOSSkill
from ovos_bus_client.message import Message

VEL_VOICE_ID = "5AYcH1Cr8nW0XgDTtRI4"
MYCROFT_VOICE_ID = "0lp4RIz96WD1RUtvEu3Q"
VOICE_OVERRIDE_FILE = os.path.expanduser("~/.config/mycroft/vel_voice_override")


class VelRouterSkill(OVOSSkill):

    def initialize(self):
        self.vel_active = False
        self.vel_mic_opened = False
        self._set_voice(MYCROFT_VOICE_ID)
        self.add_event("persona:summon", self.handle_persona_summon)
        self.add_event("persona:release", self.handle_persona_release)
        self.add_event("recognizer_loop:audio_output_start", self.handle_audio_start)
        self.add_event("recognizer_loop:audio_output_end", self.handle_audio_end)
        # Debug instrumentation
        self.add_event("speak", self.dbg_speak)
        self.add_event("mycroft.mic.listen", self.dbg_mic_listen)
        self.add_event("recognizer_loop:record_begin", self.dbg_record_begin)
        self.add_event("recognizer_loop:record_end", self.dbg_record_end)
        self.add_event("recognizer_loop:utterance", self.dbg_utterance)

    # --- debug listeners (always active, not gated on vel_active) ---

    def dbg_speak(self, message):
        utterance = message.data.get("utterance", "")
        self.log.info(f"[DBG:speak] text='{utterance}'")

    def dbg_mic_listen(self, message):
        source = message.context.get("skill_id") or message.context.get("source") or "unknown"
        self.log.info(f"[DBG:mic.listen] requested by source='{source}' vel_active={self.vel_active}")

    def dbg_record_begin(self, message):
        self.log.info(f"[DBG:record_begin] mic is now HOT vel_active={self.vel_active}")

    def dbg_record_end(self, message):
        self.log.info(f"[DBG:record_end] mic closed vel_active={self.vel_active}")

    def dbg_utterance(self, message):
        utterances = message.data.get("utterances", [])
        self.log.info(f"[DBG:utterance] STT result={utterances} vel_active={self.vel_active}")

    # --- core handlers ---

    def handle_persona_summon(self, message):
        persona = message.data.get("persona") or message.data.get("name", "")
        if persona.lower() == "vel":
            self.log.info("[VelRouter] persona:summon for vel — activating GUI/voice")
            self.activate_vel()

    def handle_persona_release(self, message):
        if self.vel_active:
            self.log.info("[VelRouter] persona:release — deactivating")
            self.deactivate_vel()

    def handle_audio_start(self, message):
        self.log.info(f"[DBG:audio_output_start] vel_active={self.vel_active}")
        if self.vel_active:
            self.cancel_scheduled_event("vel_trigger_listen")
            self.cancel_scheduled_event("vel_auto_release")

    def handle_audio_end(self, message):
        self.log.info(f"[DBG:audio_output_end] vel_active={self.vel_active} mic_opened={self.vel_mic_opened}")
        if self.vel_active and not self.vel_mic_opened:
            # Greeting just finished — open mic for the user's question
            self.schedule_event(self._trigger_listen, 2, name="vel_trigger_listen")
        elif self.vel_active and self.vel_mic_opened:
            # Question answered — release after a brief pause
            self.log.info("[VelRouter] answer audio done, scheduling auto-release in 3s")
            self.schedule_event(self.deactivate_vel, 3, name="vel_auto_release")

    def activate_vel(self):
        self._set_voice(VEL_VOICE_ID)
        self.gui["image_url"] = "file://" + os.path.join(self.root_dir, "ui", "Vel.png")
        self.gui.show_page("background", override_idle=True)
        self.vel_active = True
        self.vel_mic_opened = False

    def _trigger_listen(self):
        self.log.info("[DBG:_trigger_listen] emitting mycroft.mic.listen")
        self.vel_mic_opened = True
        self.bus.emit(Message("mycroft.mic.listen"))

    def deactivate_vel(self):
        self.vel_active = False
        self.cancel_scheduled_event("vel_trigger_listen")
        farewell = os.path.join(self.root_dir, "ui", "vel_farewell.mp3")
        if os.path.exists(farewell):
            subprocess.run(["mpg123", "-q", farewell], check=False)
        self._set_voice(MYCROFT_VOICE_ID)
        self.gui.release()

    def _set_voice(self, voice_id):
        """Write voice_id to override file — read by the ElevenLabs plugin per call,
        no mycroft.conf write needed so the listener is never reloaded."""
        with open(VOICE_OVERRIDE_FILE, "w") as f:
            f.write(voice_id)
