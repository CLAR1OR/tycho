# Audio — pipeline & integration

> Closes the "budgeted but no pipeline" gap: ~10 music tracks + ~120 SFX exist in `content-budget.md` with no stated production path. **Drafted 2026-07-03.** Decisions here; the first implementation pass is specced at the bottom (deliberately not built yet — see the note). Philosophy matches the asset rule: **placeholder-first, never block a system on final audio** — and one addition: **the combat-feel gate should not be judged silent.** Hit/dash/kill sounds are a large fraction of perceived game feel; hitstop and screen-shake are currently compensating for a missing channel. Get placeholder SFX in before calling the 20th-clear bar.

---

## Production paths (the pipeline decisions)

### SFX (~120; the feel-critical subset is human-tuned)

| Stage | Source | Notes |
| --- | --- | --- |
| **Placeholder (now)** | **CC0 packs**: Kenney (kenney.nl — impact/interface/RPG packs) + freesound CC0 | Zero legal risk, zero cost, good-enough for feel-tuning. A human downloads once and drops into `assets/audio/sfx/` (agents can then wire everything). |
| **Custom one-offs** | **jfxr / bfxr / sfxr** (browser, free) | Retro-synth generators — perfect for etching/nanobot UI blips and any gap a pack doesn't cover. Export WAV. |
| **Final pass** | curated packs + light editing (**Audacity**, free) — pitch/trim/layer | Layering two CC0 sounds is how "custom" usually happens. Genuinely bespoke recordings: out of v1 scope. |

**Feel-critical subset** (human-tuned like `# FEEL:` numbers, with the F1-panel workflow: swap file → hit F6 → feel): melee hits ×3 (combo 1/2/finisher), kill, player-hurt, dash, arrow loose + impact, pickup, echo-pick, door open. Everything else is set-and-forget.

### Music (~10 tracks per the budget)

| Stage | Source | Notes |
| --- | --- | --- |
| **Placeholder (now)** | CC0/public-domain: FreePD, Kevin MacLeod (CC-BY, credit) | Enough to test mood + the loop points. |
| **Real (v1)** | **AI-generated — Suno or Udio** (subscription; consistent with the Tripo/asset-subs stance) | Prompt in the game's register (the candlelit-cosmic painterly mood has a musical equivalent: warm medieval acoustic + low cosmic drones deepening per stratum). Generate long, pick ruthlessly — expect ~10 keepers from ~100 generations. Human curates; this is a *taste* task, agent-assisted at the prompt level only. |
| **Loop editing** | Audacity / ffmpeg: cut intro + seamless loop; export **OggVorbis** with loop points | Godot 4 imports .ogg loop metadata; music = .ogg, SFX = .wav (16-bit, 44.1 kHz). |

**Licensing rule:** CC0 preferred; CC-BY acceptable with a `CREDITS.md` in `assets/audio/`; nothing NC/SA; AI-gen per the service's commercial terms. Track provenance per file in `assets/audio/SOURCES.md` from day one (retrofitting provenance is misery).

## Integration architecture (small, matches conventions)

- **Buses:** `Master → Music / SFX / UI` (+ `SFX/Combat` child if ducking is ever wanted). Volumes are **profile settings** (schemas §1) — sliders land in the settings screen eventually; bus setup is a one-time `default_bus_layout.tres`.
- **`Sfx` autoload** (thin, per conventions): `Sfx.play(id, at: Vector3)` — a small pool of `AudioStreamPlayer3D`s (combat) + `AudioStreamPlayer`s (UI); `data/audio/sfx-map.json` maps `id → {file, volume_db, pitch_jitter}` so swapping a sound is data, not code. Pitch jitter (±5–10%) is the single cheapest anti-repetition trick — on by default for combat sounds.
- **Hook points, phase 1** (all existing emit sites): `fx.gd` hit/finisher/kill (beside hitstop — the sound IS part of the hit weight), player dash + hurt, arrow loose/impact, pickup (`resource_changed` with a run-drop reason), echo-pick open/confirm, exit-portal/door, boss kill, UI clicks (panels), day-tick chime (town).
- **Music, phase 1:** one `Music` autoload streaming per-scene tracks — town, dungeon (per-floor via the stratum profile's existing `music_layer` field), boss, title. **Crossfade on scene swap (~1 s).** The budget's "3 intensity layers" for dungeon music = **post-v1 nicety**; per-stratum tracks deliver the same felt progression for a fraction of the plumbing (and the strata want to *sound* like the imitation thinning — drones deepen with depth).
- **Not in v1:** adaptive/vertical layering, reverb zones, footstep surface switching, sidechain ducking.

## Why the first pass is NOT implemented in this change

The natural first audio chunk touches `project.godot` (bus layout, autoload registration) and the combat scenes — and the working copy currently has **uncommitted human edits to `project.godot` and `feel_room.tscn`** (live feel-tuning). Building it now from a branch would collide with that work at merge. **Spec below; build it as its own chunk once the tuning session's keepers are committed.**

## The first implementation chunk (spec for the next agent)

1. Human (once): download 2–3 Kenney CC0 packs → drop into `assets/audio/sfx/raw/`; note pack names in `SOURCES.md`.
2. Agent: bus layout; `Sfx` autoload + `data/audio/sfx-map.json` (DataLoader spec + validation); wire the phase-1 hook points; pitch jitter; a headless smoke check that every mapped file exists + loads.
3. Agent: `Music` autoload + town/dungeon/boss placeholder tracks (FreePD) with crossfade; volumes in profile settings (data only — the settings UI can lag).
4. Human: run the feel sandbox with sound; re-judge the 20th-clear bar. **The gate verdict should postdate this chunk.**

## Open questions

- Suno vs Udio (or both trials) — human taste call; budget one evening of generation + curation per 3–4 tracks.
- Does the dream/title theme want a distinct instrument identity (the *woman's* motif — a musical dream-link tell that pays off in Act II)? Cheap to decide now, powerful later. Recommended: yes — pick one instrument now, use it in exactly two places (title, first dream), never explain it.
- SFX for hazards + etchings land with their systems (the sfx-map makes that data).
