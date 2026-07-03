# v1 Content Budget

> What ships in v1 (Act I), by the numbers. This is the schedule: the counts here ARE the scope. Drafted 2026-06-12 from locked decisions + scope answers (10–15 h playtime, 3 weapons, boss per floor, Hades-style dialogue volume). Numbers are budgets, not designs — each line gets designed in its own doc/task later. **Change a number here = change the schedule; update this doc when scope moves.**

## The playtime math (sanity check)

Target: **10–15 hours** first run → emperor cliffhanger.

| Activity | Estimate |
| --- | --- |
| Runs: ~35–45 total (early deaths ~10–15 min, full clears 20–25 min) | ~8–10 h |
| Tech tree: 14 nodes × read + puzzle (~10–15 min each) | ~2.5–3.5 h |
| Town: dialogue, shopping, building between runs (~3–5 min/visit) | ~2–3 h |

Completionists stretch further via difficulty tiers; the spine fits the budget.

## Combat

| Item | Count | Notes |
| --- | --- | --- |
| **Weapons** | **3** — Sword, Bow, Daggers | Spear = designed-for data slot, post-v1. Each weapon: light combo + 1 special, **flat upgrade track (5 levels)**, **resonance track (4 effects)**. No aspects/forms in v1. Feel-tuning is human work — budget it per weapon. |
| **Etching abilities** (active) | **9** unlockable (3 per slot: RMB / Q / R) + dash (fixed) | Each: 3 upgrade levels (Resonance Dust). 1 weapon-synergy variant per ability (flagged in data, cheap). **Designed 2026-07-03: `etchings.md`** (Push/Bolt/Afterstrike, Snare/Ward/Lodestone, Shockwave/Surge/Sentinel). |
| **Passive Attunements** | **~7** persistent passive upgrades (max health, dash charges, regen, cooldowns, crit, armor, find-rate) | Each: 3 levels (Resonance Dust — shared currency with active etchings = build-choice tension). Flat stat bumps, no new art; cheap data. Vendor: Thomas's Hut, 2nd tab. |
| **Echo pool (in-run upgrades)** | **~50** | Categories: weapon mods, etching mods, dash mods, stat boosts, + ~8 synergy echoes (require 2 prior picks). Enough variety for ~40 runs without exhaustion. |
| **Enemy types** | **12** base | ~4–5 per floor with overlap; one dungeon theme so reuse is lore-correct. Elites = modifier system on base types (no new art), NOT new enemies. |
| **Bosses** | **5** — one per floor | The most expensive single items in the budget (design + arena + feel + tells). Floor-5 boss = final boss, drops Codex Shards. Difficulty tiers reuse all 5 with new patterns/modifiers, not new bosses. |
| **Room layouts** | **~30** combat layouts (shared across floors) + 5 boss arenas + 3 reprieve layouts + entry/exit rooms | One geometry kit (the nanobot learning-space). Floors differentiate by enemy mix + stratum profile + signature hazard (see rows below), never by biome art. |
| **Hazards** *(added 2026-07-03)* | **5 signature** (1/floor: vent plates, watcher nodes, burst crystals, sweep beams, drift fields) **+ 1 shared** (denial mist) | Scripted (timer + volume + telegraph, no physics/AI), dual-use (hurt enemies too). The cheap multiplier on layouts × enemies. Design rules + roster: `dungeon-strata.md`. |
| **Floor strata profiles** *(added 2026-07-03)* | **5** environment profiles + 2–4 unique props each | Pure data on the shared kit (palette/fog/light/emission — `data/floors/`). Lore: the imitation of Tycho's world thins with depth (reveal foreshadowing). Includes **5 human legibility passes** (telegraphs must stay readable per palette). Spec: `dungeon-strata.md`. |
| **Run structure** *(added 2026-07-03)* | **6 door sigils** + 1 peril mark (icons) + **1 Wellspring prop** (tinted per stratum) | Door-choice branching + the in-run healing economy — all cheap (icons + one prop + pure-function door generation). Spec: `run-structure.md`. |

## Learning layer

| Item | Count | Notes |
| --- | --- | --- |
| **Tech nodes** | **14** (11 Medieval + 3 Renaissance) | Already enumerated in the bible. Format per `tech-nodes/_TEMPLATE.md`. |
| — bespoke interactive puzzles | **8** (the KEY nodes) | Masonry-style scripted state machines. The expensive kind — gate-validated format first. |
| — light puzzles / quizzes | **6** (the support nodes) | Cheaper formats: ordering, prediction, spot-the-error. Still must pass delight-vs-homework. |
| **Codex artifact** | 1 model, **5–7 shard states** | Visible in the final-boss chamber, one new shard slots in per full clear. v1's mystery payoff. |

## Town

| Item | Count | Notes |
| --- | --- | --- |
| **Buildings** | **13** × 3 levels | Per the bible's table. Each level = visual change; budget ~2 model variants per building (L1, L2/L3 shared where possible) + Thomas's Hut never changes (1 model, by lore). |
| **Town map** | 1, with **2 age-skins** (Medieval, early-Renaissance) | The age turn must be *seen*. |
| **Shop/system UI screens** | **10** | Tech tree (per-age screens), etchings, forge, mayor/build, market, echo-pick HUD, codex viewer, dialogue box, achievements, save slots. |

## Story & dialogue (the big one)

Volume model: **Hades-style high volume** — fresh contextual dialogue on nearly every run return. This is v1's largest writing line item. Production approach per the working agreement: human owns voice, beats, and curation; agents batch-draft contextual snippets against the character voice guides for human edit/approval. Budget assumes heavy agent drafting.

| Item | Count | Notes |
| --- | --- | --- |
| **Story-spine scenes** | **~20** | The Act I skeleton — see `act1-story-beats.md`. |
| **Character-arc scenes** | **~28** (4 arcs × 6–8 beats) | Full arcs: Linnea, Tilly, Mara, Old Thomas. Wren + Herzog get flavor tracks only (escalating lines, no arc payoff in v1). |
| **Contextual snippet pool** | **~250** | Reactions to: deaths (per floor/boss), first kills, tech unlocks (1+ per node), building completions, resource milestones, age turn, weapon unlocks, codex shards. The Hades-vibrancy layer. |
| **Flavor barks** | **~60** | Repeatable per-character idle lines so the town is never mute when the pool runs dry. |
| **Cutscenes** | **~8** (opening, tree-unlock, first clear, first dream, age turn, ultimatum, climax, +1 spare) | Painterly stills + narration. ~2 stills each ≈ **16 images**. |
| **Character portraits** | **9 speakers** × ~3 expressions ≈ **27 images** | Tycho, Linnea, Thomas, Tilly, Mara, Herzog, Wren, the woman (dream-blurred variant), the emissary. The emperor stays faceless-until-named: 1 silhouette/banner image. |

## Audio & misc

| Item | Count | Notes |
| --- | --- | --- |
| Music | **~10 tracks** | Town (2: calm/late-act tension), dungeon (per-stratum tracks in v1 — the "3 intensity layers" moved post-v1, see `audio.md`), boss (2, reused), climax, dream theme, title. **Pipeline (2026-07-03): AI-gen (Suno/Udio) human-curated; CC0 placeholders first — `audio.md`.** |
| SFX | ~120 | Combat-feel critical subset (hits, dashes, pickups) gets human tuning time. **Pipeline (2026-07-03): Kenney/CC0 packs + jfxr one-offs; sfx-map as data — `audio.md`. Get placeholders in BEFORE the 20th-clear verdict.** |
| Achievements | **~25** at v1 | Event-hook system built early (prepare-for); achievement list itself is cheap data. |

## What's expensive vs. cheap (for sequencing)

- **Expensive / human-gated:** weapon feel ×3, boss design ×5, the 8 bespoke puzzles, voice/curation of 250+ snippets, the 5 per-stratum legibility passes. These dominate the calendar.
- **Cheap / agent-friendly:** all data tables, support quizzes, snippet drafting, buildings-as-data, achievements, UI plumbing, hazards (scripted timer+volume scenes), floor strata profiles (pure data).
- **Sequencing rule:** never start a new expensive line item before the relevant gate has validated its format (combat gate → weapons/bosses; content gate → puzzles; pipeline gate → all 3D asset lines).
