# Asset list — the master inventory (LIVING DOC)

> **Every visual/audio asset v1 needs, categorized.** Compiled 2026-07-11 from the design docs + actual `data/` def counts. This is a **living document**: it is only useful if it stays complete.
>
> **⚠ APPEND PROTOCOL (agents — this is a working-agreement rule, see `CLAUDE.md`):** any chunk that adds content needing an asset — a new enemy, boss, building, echo, tech node, hazard, NPC, screen, cutscene, VFX, SFX hook, anything — must **add/update the matching row here in the same change**. Bump counts, add named rows, keep `name = data key` (e.g. def `enemy_skitterer` ⇔ `assets/models/characters/enemy_skitterer.glb`). An asset the list doesn't know about is a scope leak.
>
> Status legend: **⬜ pure placeholder** (code-drawn / primitive) · **🟨 partial / placeholder file swappable** · **✅ real asset committed**. How assets get MADE: `design/asset-pipeline.md`. Where they live: `assets/README.md`.

## Global constraints (apply to every line below)

- **2.5D fixed camera** — every 3D asset is judged at the game's camera angle (`scenes/core/camera_rig.tscn`), never in a free-orbit turntable.
- **Asset-pipeline gate first** — no 3D art line proceeds until one character passes `scenes/core/asset_pipeline_gate.tscn` (Tripo → rig → UAL retarget → reads well under the camera).
- **One geometry kit** (IC-5) — floors differ by palette/fog/light data + 1 hazard + 2–4 props. No per-floor biome art lines.
- **"Imitation thins with depth"** — floors 1→5 grade from convincing cave to clean impossible void; floors 1–4 stay deniable, only floor 5 is unambiguous. Governs floor palettes, props, boss silhouettes, even the Wellspring tint.
- **Readability guard** — enemy/telegraph/hazard colours are FIXED across all strata; floor palettes are chosen around them.
- **Slate UI language** — engraved-Roman/candlelit-cosmic; all UI copy/colours ship as placeholders the human dials.
- **Placeholder-first** — never block a system on final art.

**Current reality check:** `assets/models|images|anims` are **empty**. Real assets in: 3 OFL fonts ✅, 15 synthesized placeholder SFX 🟨, 4 synthesized placeholder music loops 🟨. Everything else below is ⬜.

---

## 1. 3D animated characters (the expensive category)

All need: humanoid (or creature) rig + Quaternius UAL retarget, in-place clip variants (velocity is code-driven).

### Player
| Asset | Count | Animations | Status |
|---|---|---|---|
| **Tycho** | 1 | idle, walk/run, dash, hurt, death, **dissolve** (the ending), meditation pose, etching cast poses, **3 weapon movesets** (sword / bow / daggers: light 1/2/finisher + special each) | ⬜ capsule |

### Enemies — 5 built / **12 v1 target** (elites are a modifier system → no new art)
| Asset | Animations / tells | Status |
|---|---|---|
| Brute | idle, walk, melee, death | ⬜ |
| Skirmisher | idle, walk, quick strike, death | ⬜ |
| Archer | idle, walk, bow-loose, death | ⬜ |
| Slammer | windup → AoE slam, death | ⬜ |
| Charger | line-dash telegraph, recover, death | ⬜ |
| +7 base types (undesigned budget slots) | readable telegraphs each | — |

### Bosses — 1 real / **5 v1 target** (multi-phase, reconfiguration beat, phase 2 wields the floor hazard)
| Asset | Needs | Status |
|---|---|---|
| F1 **Den-Warden** (rename pending) | burrowing-beast silhouette; lunge/swipe/circle, burrow→erupt, vent-plate calls; nest/bones arena prop | ⬜ capsule (logic ✅) |
| F2–F5 bosses (F5 = The Core, drops Codex Shards) | design + model + tells each | ⬜ stats-pumped dummy fallback |

### Town / story NPCs — low-anim models (idle + talk/gesture loop)
| Asset | Notes | Status |
|---|---|---|
| Sophia, Old Thomas, Mara, Herzog, Tilly, Wren | 6 town models | ⬜ boxes |
| The Woman ("Linnea") | dream/portrait only — **no town model** | — |
| The emissary | one scene (D3); model or cutscene still + black-and-gold banner | ⬜ |
| The Emperor | **stays faceless** — silhouette/banner image only (see §6), no model | — |

## 2. 3D static models

### Town buildings — data 9/9 ✅, models **0/9**. Age-I band = ~2 model variants each (L1, L2/3) + specials
| Asset | Variants | Status |
|---|---|---|
| Farm, Quarry, Sophia's Study, Observatory, Mill, Market, Town Walls | ~2 each | ⬜ |
| Library → **University** | 2 + 1 L4 transform (the C6 age-turn showpiece) | ⬜ |
| Cathedral (Great Work) | **3 stage models** (scaffolding → structure → finished) | ⬜ |
| Mara's Forge (shop) | L1 + L2 (Metallurgy) | ⬜ |
| Thomas's Hut (shop) | **1 model, never changes** (lore IC-14) | ⬜ |
| Town map/plots | 1 layout × **2 age-skins** (Medieval, early-Renaissance) | ⬜ |
| Planning Table prop | 1 | ⬜ |
| Narrative props: cannon (D2), palisade→stone-wall swap (B5) | 2 | ⬜ |

### Dungeon geometry kit + props (2–4 unique props per stratum; props glow on F3/F5; no collision — dead-roll rule)
| Asset | Status |
|---|---|
| Geometry kit: ~30 combat layouts + 5 boss arenas + 3 reprieve + entry/exit rooms (one modular kit) | ⬜ |
| F1 rock formations (repeat too evenly — the tell) · F2 arches/columns/ruin (every arch identical) · F3 crystal seam/cluster/shard · F4 clean planes/floating masses/repetition blocks · F5 void geometry/starfield/circuitry-trace | ⬜ |
| Boss-1 nest/bones arena dressing | ⬜ |

### Hazards — 6/6 logic ✅, all ⬜ primitives
Vent plate (F1) · Watcher node (F2) · Burst crystal (F3) · Sweep beam (F4) · Drift field (F5) · Denial mist (shared).

### Pickups / run props
| Asset | Status |
|---|---|
| Wellspring (1 prop, tinted per stratum — less water-like with depth) | ⬜ |
| **Codex artifact** — 1 model with 5–7 shard states + dissolve pedestal | ⬜ |
| Resource pickup meshes (ore, dust, gold, shards drop in runs) | ⬜ |
| Door portals carrying the 6 sigils + peril mark (emissive) | ⬜ |
| Held weapon meshes: sword, bow, daggers | ⬜ |

## 3. Environment / level art

- **5 floor env profiles** — pure data (`data/floors/*.json`: bg/ambient/light/ground/wall/fog hex + energies). Built 🟨, every colour a human dial; **5 legibility passes pending**.
- Town environment: 2 age-skins + calm-vs-tension lighting. ⬜
- Town water: shader-generated (`WaterPlane` + `water_absorption.gdshader`, CC0 Malido — depth absorption, edge foam, caustics, wind waves, walk-in ripples; sloped generated bed). ✅ PLACED 2026-07-11 — the town's south border (WallS mesh hidden, collision kept); needs Forward+ + the project shader globals (`project.godot [shader_globals]`)
- Town grass: shader-generated (`GrassPatch` + `grass_blade.gdshader`, CC0 @_Malido — wind sway + walk-through bend; demo `scenes/core/grass_demo.tscn`). ✅ PLACED in town 2026-07-11 — meadow around the KayKit trees/player spawn, blades = the human's `assets/models/GrassMesh.res` (via the `blade_mesh` export), bent by the Player
- Title/slot-select night sky (gradient, stars, cyan constellation, ridge) — code-drawn ⬜.
- Skyboxes/backdrops per scene: none authored ⬜.

## 4. VFX (primitive meshes in `src/combat/fx.gd` today; likely Godot particles + shaders, not gen-AI — see pipeline doc §VFX)

| Group | Items | Status |
|---|---|---|
| Etchings ×9 + dash | Push cone, Bolt dart, Afterstrike replay, Snare field, Ward barrier arc, Lodestone pull, Shockwave blast, Surge overdrive+ghost trail, **Sentinel construct (a mini-model!)**; dash ghost | ⬜ (dash ghost 🟨) |
| Combat feedback | hit/finisher/kill, hitstop/screenshake (✅ code), damage numbers | 🟨 |
| Boss telegraphs | lunge line, swipe arc, chained circles, burrow/erupt, reconfiguration glow + sting | ⬜ |
| Hazard FX ×6 | FIXED colours (readability guard) | ⬜ |
| Signature moments | **dissolve ending**, codex assembly per shard (E2), door-sigil glow, Wellspring heal, peril elite aura, echo-pick bloom (O1) | ⬜ |

## 5. 2D UI / HUD (all code-drawn Slate monograms/primitives today; painterly pass deferred)

### Icon sets
| Set | Built / v1 target | Status |
|---|---|---|
| Echo icons | 25 / **~50** | ⬜ monogram tiles |
| Etching sigils + dash | 9 + 1 | ⬜ placeholder registry |
| Attunement icons | 7 / ~7 | ⬜ |
| Resource icons | 7 / 7 (gold, stone, food, knowledge, shards, ore, dust) | ⬜ coloured text |
| Achievement icons | 26 / ~26 | ⬜ monogram strings |
| Tech-node icons/stars | 2 / **14** (11 Medieval + 3 Renaissance) | ⬜ constellation stars |
| Building icons | 9 | ⬜ silhouette polys |
| Weapon icons | 3 | ⬜ silhouette polys |
| Door sigils + peril mark | 6 + 1 | ⬜ |

### Portraits — **9 speakers × ~3 expressions ≈ 27** + 1 Emperor silhouette/banner
Tycho, Sophia, Thomas, Tilly, Mara, Herzog, Wren, The Woman (dream-blurred), emissary. None exist ⬜ (DialoguePanel shows tinted names).

### Screens & fonts
- ~15 built Slate screens (RunHud, TownHud, pause, settings, tech chart, etchings, forge, build/survey, market, echo offer, dialogue, slot select/title, achievements + toast, codex) — all 🟨 code-drawn, human restyles freely.
- Fonts ✅: Cinzel SemiBold, JetBrains Mono Medium, EB Garamond Medium (OFL, committed).

## 6. 2D illustrations (painterly pass — none exist)

| Asset | Count | Status |
|---|---|---|
| Cutscene stills (~8 cutscenes × ~2) | ~16 | ⬜ |
| Codex artifact art + 5–7 shard-state illustrations | ~7 | ⬜ |
| Tech-node diagrams/puzzle art (8 bespoke puzzles + 6 light) | ~14 | ⬜ (`puzzle_arch.gd` self-draws) |
| Title screen art | 1 | ⬜ |
| Emperor banner/silhouette + emissary banner | 2 | ⬜ |

## 7. Audio — counts only; owning doc `design/audio.md`

| Category | Built / v1 target |
|---|---|
| Music tracks (town ×2, strata ×5, boss ×2, climax, dream, title; optional Woman's-motif instrument in exactly 2 places) | 4 synth 🟨 / **~10** |
| SFX (feel-critical subset human-tuned; missing: hazard SFX, all etching SFX, boss reconfiguration sting) | 15 synth 🟨 / **~120** |

---

## Rough priority (art follows the gates)

1. **The pipeline-gate character** — unblocks every 3D line (human action, `assets/README.md`).
2. The style-unification layer + style bible (`design/asset-pipeline.md`) — before ANY volume generation.
3. Tycho + the 5 built enemies + Den-Warden (the whole current game, visible).
4. Icon anchors → echo/etching/resource icon sets (highest count-per-effort, pure 2D).
5. Portraits (9 anchors → emotion sets), town buildings, strata props.
6. Cutscene stills, codex art, remaining enemies/bosses as they get designed.
