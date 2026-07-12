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
| **Etching abilities** (active) | **9** unlockable (3 per slot: RMB / Q / R) + dash (fixed) | Each: 3 upgrade levels (Resonance Dust). 1 weapon-synergy variant per ability (flagged in data, cheap). **Designed 2026-07-03: `etchings.md`** (Push/Bolt/Afterstrike, Snare/Ward/Lodestone, Shockwave/Surge/Sentinel). **First slice built 2026-07-07:** 5 of 9 castable (Push/Bolt/Snare/Shockwave/Surge), 4 dormant; L3 riders + weapon synergies deferred (data ships). |
| **Passive Attunements** | **7 — BUILT (placeholders) 2026-07-10** (Vitality, Recovery, Quickening, Resonance Flow, Focus, Resilience, Attunement) | Each: 3 levels (Resonance Dust — shared currency with active etchings = build-choice tension; ~63 Dust to max all 7, near the ability kit's ≈60–70). ABSOLUTE/replace levels; flat stat bumps, no new art; cheap data. Vendor: Thomas's Hut 2nd tab (the `THE BODY` page on `EtchingsPanel`). See `design/etchings.md` implementation-status block. |
| **Echo pool (in-run upgrades)** | **~50** (**~25 built** 2026-07-10) | Categories: weapon mods, etching mods, dash mods, stat boosts, healing echoes, + synergy echoes (require 2 prior picks). Enough variety for ~40 runs without exhaustion. **Shipped ~25** in `data/echoes/*.json` incl. the 3 healing echoes + first etching-mod echoes + 3 synergies; numbers are placeholders. |
| **Enemy types** | **12** base | ~4–5 per floor with overlap; one dungeon theme so reuse is lore-correct. Elites = modifier system on base types (no new art), NOT new enemies. **5 built (placeholders) as of 2026-07-06:** Brute, Skirmisher, Archer, Slammer (windup AoE), Charger (line-telegraph dash). Combat rooms now run **2–3 sequential waves** (Hades-style; pure seeded `WaveCore` picks count/size/mix — placeholders). |
| **Bosses** | **5** — one per floor (**1 real built 2026-07-10:** floor 1's Den-Warden, data-driven via `data/bosses/` + `BossCore`/`enemy_boss.gd`; floors 2–5 fall back to the stats-pumped placeholder) | The most expensive single items in the budget (design + arena + feel + tells). Floor-5 boss = final boss, drops Codex Shards. Difficulty tiers reuse all 5 with new patterns/modifiers, not new bosses. Grammar + reusable framework: `design/bosses/floor-1-boss.md` — bosses 2–5 are now a def file + a design doc each. |
| **Room layouts** *(**built 2026-07-12**)* | **30/30** combat (shared across floors) + **5/5** boss arenas (one per floor) + **3/3** reprieve; entry/exit rooms are not separate layouts in v1 | One geometry kit (the nanobot learning-space). Floors differentiate by enemy mix + stratum profile + signature hazard (see rows below), never by biome art. **Shipped as `data/layouts/*.json`** — pillar/block arrangements on the shared 56×56 room, seeded pick + flood-fill validation via pure `LayoutCore`; **placeholder arrangements, human dial pass pending**. Spec: `dungeon-strata.md` § Room layouts. |
| **Hazards** *(added 2026-07-03; **built placeholders 2026-07-10**)* | **5 signature** (1/floor: vent plates, watcher nodes, burst crystals, sweep beams, drift fields) **+ 1 shared** (denial mist) | Scripted (timer + volume + telegraph, no physics/AI), dual-use (hurt enemies too). The cheap multiplier on layouts × enemies. **All six built** as `data/hazards/*.json` + one `Hazard` class dispatched on `kind` (`src/combat/hazard.gd`); numbers are dials. Design rules + roster: `dungeon-strata.md`. |
| **Floor strata profiles** *(added 2026-07-03; **built placeholders 2026-07-10**)* | **5** environment profiles + 2 unique props each | Pure data on the shared kit (palette/fog/light — `data/floors/*.json` `environment`/`props`/`hazards`, applied per-instance by `combat_room.gd` via pure `StrataCore`). Lore: the imitation of Tycho's world thins with depth (reveal foreshadowing). **5 human legibility passes still pending** (telegraphs must stay readable per palette). Spec: `dungeon-strata.md`. |
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
| **Buildings** | **9 buildable + 2 shops** (2026-07-10, `town-economy.md` — Timber/Woodcutter/Cart cut; University = the Library's Renaissance band; Cathedral Great Work added). **DATA: 9/9 built 2026-07-10** (all Age-I bands + the University L4 opener + 3 Cathedral stages + the Market logic/caravan table; the 2 shops were already live) — **models 0/9** (placeholder boxes/monograms). | v1 authors the Age-I band (3 levels each) + the Library→University L4 opener + 3 Cathedral stages. Each level = visual change; budget ~2 model variants per building (L1, L2/L3 shared where possible) + Thomas's Hut never changes (1 model, by lore) + 3 Cathedral stage models + 1 University variant. |
| **Town map** | 1, with **2 age-skins** (Medieval, early-Renaissance) | The age turn must be *seen*. |
| **Shop/system UI screens** | **11** | Tech tree (per-age screens), etchings, forge, mayor/build, market, echo-pick HUD, codex viewer, dialogue box, achievements (page + unlock toast **built 2026-07-11**), save slots, ESC pause menu (Resume / Forfeit / Save & Quit, built 2026-07-07). |

## Story & dialogue (the big one)

Volume model: **Hades-style high volume** — fresh contextual dialogue on nearly every run return. This is v1's largest writing line item. Production approach per the working agreement: human owns voice, beats, and curation; agents batch-draft contextual snippets against the character voice guides for human edit/approval. Budget assumes heavy agent drafting. **The voice guides exist (2026-07-03): `voice-guides.md`** — house style, per-character tells + human-approved sample lines, tech-unlocked vocabulary; snippet drafting is unblocked.

| Item | Count | Notes |
| --- | --- | --- |
| **Story-spine scenes** | **~22** | The Act I skeleton incl. Phase E post-climax endgame beats (added 2026-07-03) — see `act1-story-beats.md`. ***SPINE COMPLETE through E1 (2026-07-10):** A3/A4, B1–B5, C1–C6 (C5 = 4 dream scenes), D1–D5, E1, E2 — human-authored openers + agent drafts (curation pending, `design/dialogue/drafts-review-2026-07-10.md`). Twins/copies don't change the ~22 count.* |
| **Character-arc scenes** | **~28** (4 arcs × 6–8 beats) | Full arcs: Sophia, Tilly, Mara, Old Thomas. Wren + Herzog get flavor tracks only (escalating lines, no arc payoff in v1). **First 17 beats drafted + integrated 2026-07-04; +6 more 2026-07-10 (awe/telescope/depth/command/designs/ages — now tabled in `act1-story-beats.md`); ~23/28, curation pending.** |
| **Contextual snippet pool** | **~250** | Reactions to: deaths (per floor/boss), first kills, tech unlocks (1+ per node), building completions, resource milestones, age turn, weapon unlocks, codex shards. The Hades-vibrancy layer. **~27 drafted + integrated (3 pre-07-10, 24 on 2026-07-10 — incl. the floor-1-boss hooks + 5 per-stratum Sophia reports on the new `max_floor` counter).** |
| **Flavor barks** | **~70** | Repeatable per-character idle lines so the town is never mute when the pool runs dry — incl. ~10 post-climax barks (drills, watch-rotas, the west) so the endgame town isn't frozen pre-war (added 2026-07-03). **First 20 drafted + integrated 2026-07-04; +16 on 2026-07-10 incl. the full 10-bark E3 post-climax set — ~36/70 (curation pending).** |
| **Cutscenes** | **~8** (opening, tree-unlock, first clear, first dream, age turn, ultimatum, climax, +1 spare) | Painterly stills + narration. ~2 stills each ≈ **16 images**. |
| **Character portraits** | **9 speakers** × ~3 expressions ≈ **27 images** | Tycho, Sophia, Thomas, Tilly, Mara, Herzog, Wren, the woman (dream-blurred variant), the emissary. The emperor stays faceless-until-named: 1 silhouette/banner image. |

## Audio & misc

| Item | Count | Notes |
| --- | --- | --- |
| Music | **~10 tracks** | Town (2: calm/late-act tension), dungeon (per-stratum tracks in v1 — the "3 intensity layers" moved post-v1, see `audio.md`), boss (2, reused), climax, dream theme, title. **Pipeline (2026-07-03): AI-gen (Suno/Udio) human-curated; CC0 placeholders first — `audio.md`. Placeholders IN (2026-07-04: 4 synthesized seamless loops — title/town/dungeon/boss — via the `Music` autoload, crossfade live).** |
| SFX | ~120 | Combat-feel critical subset (hits, dashes, pickups) gets human tuning time. **Pipeline (2026-07-03): Kenney/CC0 packs + jfxr one-offs; sfx-map as data — `audio.md`. Placeholders IN (2026-07-04: 15 synthesized sounds, all phase-1 hooks live) — the 20th-clear verdict can be judged with sound.** |
| Achievements | **~25** at v1 — **26/25 authored 2026-07-11** | Event-hook system built early (prepare-for); achievement list itself is cheap data. **System + data BUILT 2026-07-11** (`architecture-schemas.md` §5: pure `AchievementCore` + `Achievements` autoload + unlock toast + Slate page) — names/descs are PLACEHOLDER copy, human curation pending. |

## What's expensive vs. cheap (for sequencing)

- **Expensive / human-gated:** weapon feel ×3, boss design ×5, the 8 bespoke puzzles, voice/curation of 250+ snippets, the 5 per-stratum legibility passes. These dominate the calendar.
- **Cheap / agent-friendly:** all data tables, support quizzes, snippet drafting, buildings-as-data, achievements, UI plumbing, hazards (scripted timer+volume scenes), floor strata profiles (pure data).
- **Sequencing rule:** never start a new expensive line item before the relevant gate has validated its format (combat gate → weapons/bosses; content gate → puzzles; pipeline gate → all 3D asset lines).
