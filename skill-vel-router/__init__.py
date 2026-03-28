import json
import os
import subprocess

from ovos_workshop.skills import OVOSSkill
from ovos_bus_client.message import Message

VEL_VOICE_ID = "5AYcH1Cr8nW0XgDTtRI4"
MYCROFT_VOICE_ID = "0lp4RIz96WD1RUtvEu3Q"
MYCROFT_CONF = os.path.expanduser("~/.config/mycroft/mycroft.conf")


class VelRouterSkill(OVOSSkill):

    def initialize(self):
        self.vel_active = False
        self.add_event("recognizer_loop:wakeword", self.handle_wakeword)

    def handle_wakeword(self, message):
        utterance = message.data.get("utterance", "").lower().replace(" ", "_")
        if utterance == "awaken_vel":
            if not self.vel_active:
                self.activate_vel()
        elif self.vel_active:
            self.deactivate_vel()

    def activate_vel(self):
        self._set_voice(VEL_VOICE_ID)
        self.bus.emit(Message("ovos.persona.activate", {"name": "Alien"}))
        self.gui["image_url"] = "file://" + os.path.join(self.root_dir, "ui", "Vel.png")
        self.gui.show_page("background.qml")
        self.vel_active = True

    def deactivate_vel(self):
        farewell = os.path.join(self.root_dir, "ui", "vel_farewell.mp3")
        if os.path.exists(farewell):
            subprocess.run(["mpg123", "-q", farewell], check=False)
        self._set_voice(MYCROFT_VOICE_ID)
        self.bus.emit(Message("ovos.persona.deactivate"))
        self.gui.release()
        self.vel_active = False

    def _set_voice(self, voice_id):
        with open(MYCROFT_CONF, "r") as f:
            conf = json.load(f)
        conf.setdefault("tts", {}).setdefault(
            "ovos-tts-plugin-elevenlabs", {}
        )["voice_id"] = voice_id
        with open(MYCROFT_CONF, "w") as f:
            json.dump(conf, f, indent=4)
        self.bus.emit(Message("configuration.updated"))
