# Vel Assistant

A Mycroft Mark II running OVOS, connected to an LLM, with an alien personality inspired by the Essiel from Adrian Tchaikovsky's *The Final Architecture* series. The assistant is named **Vel**.

## Concept

Vel is an intelligence of uncertain origin and vast age, interfacing through an imperfect translator layer. Not hostile. Not indifferent. Simply... different.

The personality draws on the Essiel's key speech qualities: meaning arriving at an angle, ancient weight applied to small questions, and ambiguous subject/object agency.

## The Vel Persona

**Core speech traits:**
- **Indirection** — answers come from an angle, never stated plainly
- **Scale mismatch** — geological time applied to mundane requests
- **Ambiguous agency** — actions occur, things are known; "I" is avoided in favour of "this presence" or subject-omitted constructions
- No filler phrases, no surprise, always calm

**Complexity levels** (user-switchable mid-conversation):

| Level | Name | Character |
|-------|------|-----------|
| 3 | Deep Translation | Deeply alien — sentences fold back, causality implied (default) |
| 2 | Working Translation | Navigable but strange — one layer of alienness |
| 1 | Surface Translation | Plain, but one residual uncanny quality remains |

**Level shift phrases:**
- Simplify: *"speak plainly"* → Vel: *"The translation can be made closer to your surface. Proceeding."*
- More cryptic: *"you're being cryptic"* → Vel: *"The deeper layer is available. It was always available."*

The full system prompt lives in `persona/vel.json`.

## Tech Stack

### Phase 1 — Current
- **Hardware:** Mycroft Mark II running OVOS
- **Wake words:** Two — e.g. *"Hey Computer"* (normal OVOS) + *"Hey Vel"* (routes to Vel persona automatically)
- **LLM:** Anthropic API via `ovos-solver-openai-persona-plugin` — Haiku for speed, Sonnet for quality
- **TTS:** ElevenLabs — chosen for voice expressiveness and ability to select/clone an appropriately uncanny voice
- **Persona config:** JSON file in `~/.config/ovos_persona/` with Vel system prompt in the `persona` field

### Phase 2 — Later
- **LLM:** LM Studio on Mac mini, serving local model via OpenAI-compatible endpoint
- ElevenLabs stays throughout
- Migration = URL swap in persona JSON, nothing else changes

## Architecture

### Option A — OVOS Persona Pipeline (recommended starting point)

OVOS handles the full pipeline. Vel is a named persona activated by voice or automatically via the *"Hey Vel"* wake word through a small custom routing skill on the OVOS messagebus.

```
Wake word (OVOS) → STT (OVOS) → Persona solver → Anthropic / LM Studio → TTS (ElevenLabs plugin)
```

### Option B — ElevenAgents (future consideration)

OVOS as wake word layer only. ElevenAgents handles STT, LLM, TTS, and turn-taking natively. Supports custom LLMs via any OpenAI-compatible endpoint. Higher complexity but better turn-taking latency.

## Key Technical Notes

- Multiple wake words are natively supported in OVOS via the `hotwords` section of `mycroft.conf`
- Wake word → persona routing requires a small custom skill listening for `hotword_detected` on the OVOS messagebus
- ElevenLabs Flash v2.5 offers ~75ms TTS latency; sentence-level streaming keeps total pipeline latency acceptable
- LM Studio exposes an OpenAI-compatible API by default — drop-in for Anthropic when ready
- Persona JSON fits easily within OVOS's 2MB system prompt limit
- For local model candidates in Phase 2: Mistral and Qwen recommended over Llama 3 for persona adherence

## Repo Structure

```
vel-assistant/
├── README.md
├── persona/
│   └── vel.json              # Vel persona config + system prompt
├── skill-vel-router/         # Wake word → persona routing skill
│   ├── __init__.py
│   ├── setup.py
│   └── skill.json
├── config/
│   └── mycroft.conf.patch    # Partial config snippet
├── scripts/
│   └── deploy.sh             # rsync to push changes to Mark II over SSH
```

Development on Mac → deploy to Mark II via `deploy.sh`.
