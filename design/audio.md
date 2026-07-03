# Audio — pipeline & integration

> Closes the "budgeted but no pipeline" gap: ~10 music tracks + ~120 SFX exist in `content-budget.md` with no stated production path. **Drafted 2026-07-03; the SFX half of the first chunk is BUILT 2026-07-04** (buses, `Sfx` autoload over pure `SfxCore`, `data/audio/sfx-map.json`, all phase-1 hooks, 15 agent-synthesized placeholder wavs — see the chunk spec below for what's done vs. open). Philosophy matches the asset rule: **placeholder-first, never block a system on final audio** — and one addition: **the combat-feel gate should not be judged silent.** Hit/dash/kill sounds are a large fraction of perceived game feel; hitstop and screen-shake are currently compensating for a missing channel. Placeholder SFX are now in — the 20th-clear bar can be judged with sound.

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

## Why the first pass was NOT implemented with this spec

The natural first audio chunk touches `project.godot` (bus layout, autoload registration) and the combat scenes — and at drafting time the working copy had **uncommitted human edits to `project.godot` and `feel_room.tscn`**. *(Resolved 2026-07-03: those edits turned out to be the gdUnit4 plugin install + an editor resave, both committed — the blocker is gone and the chunk below is buildable as-is.)*

## The first implementation chunk (status 2026-07-04)

1. Human (once): download 2–3 Kenney CC0 packs → drop into `assets/audio/sfx/raw/`; note pack names in `SOURCES.md`. **Still open** — meanwhile the 15 placeholder wavs in `assets/audio/sfx/` are **agent-synthesized** (deterministic script, the jfxr register this doc sanctions; provenance in `SOURCES.md`). Replacing one = editing its `sfx-map.json` row.
2. Agent: bus layout; `Sfx` autoload + `data/audio/sfx-map.json` (DataLoader spec + validation); wire the phase-1 hook points; pitch jitter; a headless check that every mapped file exists + loads. **DONE 2026-07-04** — `default_bus_layout.tres` (Master→Music/SFX/UI); pure `src/core/sfx_core.gd` (resolve + jitter math) under thin `src/autoload/sfx.gd` (3D/2D player pools, PROCESS_MODE_ALWAYS so pause-panel UIs still click; pickup + boss-kill ride EventBus); `DataLoader.load_sfx_map()` (single-file map — a deliberate exception to one-file-per-entity: a mix wants one page); hooks: combo hits ×3 + kill (beside hitstop in `_apply_attack_hits`), dash, player-hurt, arrow loose/impact, exit-portal open, echo offer open/pick, day-tick chime, ui-click via the three panels' `_button` factories; tests in `tests/core/sfx_core_test.gd` incl. the exists+loads sweep and a feel-critical-ids guard.
3. Agent: `Music` autoload + town/dungeon/boss placeholder tracks (FreePD) with crossfade; volumes in profile settings (data only — the settings UI can lag). **Still open — the next audio chunk.**
4. Human: run the feel sandbox with sound; re-judge the 20th-clear bar. **The gate verdict should postdate this chunk.** Ready now — F6 the sandbox; dial a sound in `data/audio/sfx-map.json` (volume_db/pitch_jitter/file), no code.

Known shutdown notice: sounds mid-play at quit print "N resources still in use at exit" — AudioServer playback release order, engine noise, not a leak (documented in `sfx.gd`).

## Open questions

- Suno vs Udio (or both trials) — human taste call; budget one evening of generation + curation per 3–4 tracks.
- Does the dream/title theme want a distinct instrument identity (the *woman's* motif — a musical dream-link tell that pays off in Act II)? Cheap to decide now, powerful later. Recommended: yes — pick one instrument now, use it in exactly two places (title, first dream), never explain it.
- SFX for hazards + etchings land with their systems (the sfx-map makes that data).
