# Tycho Roguelite — Product Requirements Document (v1 / Act I)

> Built with the `game-prd-builder` skill from the locked design bible (`../Tycho Roguelite.md`) and the `design/` detail docs. This PRD is the **single implementable spec for v1**: an engineer or agent should be able to start building from it without a verbal walkthrough. It synthesizes — it does not override. Where this doc and the bible disagree, **the bible wins**; fix this doc to match (per `../CLAUDE.md` working agreement).
>
> Scope of v1 = **the roguelite pillar only, finished end-to-end, climaxing at the end of Act I** (the emperor gets a face). Strategy (Act II) and Space (Act III) are *designed-for, not built*.

---

## 1. Document Info
- **Project:** Tycho Roguelite
- **Version:** 1.0 (PRD draft)
- **Date:** 2026-06-19
- **Status:** Pre-development. Design locked; Phase 0 gates not yet run. This PRD is an **input to**, and is finalized **after**, the Phase 0 gates pass (combat-feel, content, asset-pipeline) — gate outcomes may revise counts and feel targets.
- **Intended phase:** Drives Phase 1+ once Phase 0 gates are green (`../CLAUDE.md` → Build order).
- **Source docs:** `../Tycho Roguelite.md` (bible, source of truth), `content-budget.md` (the schedule), `act1-story-beats.md` (story spine + dialogue spec), `architecture-schemas.md` (data contracts), `godot-conventions.md` (code rules), `tech-nodes/` (authored nodes).

---

## 2. Product Summary
- **Pitch:** A 2.5D top-down **real-time action roguelite** wrapped around a **rational-fiction story** and a **real-science tech tree**. Medieval setting (1157 AD); "magic" is secretly nanobots. You raid a portal-dungeon for resources, then spend them in a town hub to research real historical technology — reading explanations and solving puzzles — which makes your next raid stronger. The roguelite is the engine; **the story + learning is the soul.**
- **Genre / subgenre:** Action roguelite (Hades-style feel) + light upgrade-hub meta + edutainment (history of technology, hard-science principles, rationality/thinking skills).
- **Core differentiator:** Combat does **not carry** the learning — it **rewards** it. The "cognitive pulse" deliberately alternates cerebral tension (town/tech/puzzles) with reflexive release (the dungeon). You think hard in town so you feel powerful in the dungeon. Players learn things that are actually true.
- **Target session length:** A successful run ≈ **20–25 min** (early deaths 10–15 min). Full v1 first playthrough = **10–15 hours**.
- **Target platform:** Linux desktop, single-player, Godot 4.7 (upgraded from 4.6 on 2026-06-20), GDScript. Keyboard + mouse (Space/dash, LMB/attack, RMB/Q/R abilities).

---

## 3. Design Goals
- **Player fantasy:** A witty, rational field-researcher who grows from a man-with-a-sword into someone whose *understanding* makes him powerful — and whose curiosity is slowly uncovering a cosmic secret.
- **Experience goals:**
  - Combat that feels good on its own terms (NOT a Hades clone — Hades is the *quality* reference). Reactive, fast, pattern-mastery satisfying.
  - Learning that reads as **delight, not homework** (the Content-gate bar).
  - A town that **visibly transforms** as you advance the ages — progression you can see.
  - A mystery that **assembles in plain sight** (the codex artifact) and pays off as *wonder*.
- **Replayability goals:** Run-to-run variety from the **Echo** in-run upgrade system (~50 echoes, synergy chains); persistent power growth (weapons, etchings, attunements, tech, town); Hades-style fresh dialogue nearly every return; difficulty tiers for completionists.
- **Constraints (hard):** Solo dev + AI agents; **game feel cannot be vibecoded** (human-tuned). Bounded dungeon: one world, one geometry kit — floors differ as data-driven *strata*, never as biome art lines (IC-5 as revised 2026-07-03). Documentation is sacred. Build the roguelite only — do not build strategy/space gameplay, but architect so they slot in.

---

## 4. Target Players
- **Core audience:** Players who like action roguelites (Hades, Dead Cells) **and** are curious about science/history/rationality — the rare overlap this game is built for. Faithfulness to the vision over mass-market reach; a niche audience is fine ("a game I wish existed").
- **Adjacent audience:** Edutainment-curious players who will use **assist mode** for combat; roguelite players who will use **auto-solve** for puzzles. Neither skill hard-gates content.
- **Required familiarity:** None assumed. The first run is the tutorial (sword + dash); systems unlock via a story cascade, one at a time, so complexity is paced.

---

## 5. Immutable Core
The non-negotiables. Each: **what is fixed / why / what may still expand.** (All locked 2026-06-07, updated 2026-06-12; see bible "Design Decisions — Locked.")

| # | Fixed rule | Why | What may still expand |
| --- | --- | --- | --- |
| IC-1 | **The soul is story + rational-fiction learning.** Education is a core product, not flavor — players learn true things. | The reason the game exists. | *How* lessons are delivered (puzzle formats, dialogue), how many nodes. |
| IC-2 | **The cognitive pulse:** cerebral tension (town) alternates with reflexive release (dungeon). Combat rewards learning; it does not carry it. | Reconciles real-time combat with a thinking-themed soul. | Tuning of the alternation cadence. |
| IC-3 | **Real-time action roguelite, Hades-style *feel*** (own feel is fine). | Load-bearing to the fantasy; chosen over turn-based/deckbuilder. | Specific combat verbs, weapons, enemy design. |
| IC-4 | **2.5D: 3D models on a fixed camera.** Static screens (portraits, cutscenes, tech cards) are painterly 2D. | 3D models dodge the 2D per-direction animation explosion for a solo dev; AI tooling is strong for 3D models + 2D images, weak for 2D sprite sheets. | Later camera flourishes; the eventual space stage. |
| IC-5 | **One dungeon world, one geometry kit** ("nanobot learning-space"); never re-themes by age; scales by **difficulty tier, not age.** *(Revised 2026-07-03:)* floors are **strata** — per-floor environment profiles (data) + 1 signature hazard + a small prop budget; independent biome art lines stay banned. | Bounds the expensive, un-vibecodeable content; the strata gradient (the imitation of Tycho's world thins with depth) doubles as reveal foreshadowing (`dungeon-strata.md`). | Enemy mix, hazards, layouts, tiers, stratum profiles. |
| IC-6 | **One endgame meta-puzzle**, assembled from codex shards **visibly in the final-boss chamber** — not a puzzle-door per level. | A single, watchable mystery; v1 payoff is the *growing* mystery (solving it is post-v1). | Number of shard states (5–7), the eventual reveal. |
| IC-7 | **1 in-game day = 1 run.** All "per day" passives fire on run completion (win or die). Nothing advances in real time. | Kills idle-game waiting; runs stay the heartbeat. | Production/research numbers. |
| IC-8 | **No death penalty — you keep everything.** Runs only ever add. | Tension comes from combat, not loss. | What drops, drop rates. |
| IC-9 | **No puzzle rooms in the dungeon** (cut 2026-06-12). Dungeon is pure release; learning-puzzles live in town. | Protects the cognitive pulse. | Reprieve/upgrade rooms stay. |
| IC-10 | **Graceful paths in both directions:** assist mode ("Reinforcement Protocol", nanobot-framed, capped stacking damage resist) for combat; Linnea auto-solve for puzzles. No content hard-gated behind either skill. | Inclusivity for the two audiences; diegetically the runs *are* learning trials. | Stack caps, auto-solve pacing. |
| IC-11 | **Diegetic frame:** magic = nanobots; death/retry = nanobots running learning trials; Tycho is immortal-but-capturable. | Justifies the loop in-fiction; foreshadows the second bearer; protect this. | Lore detail. |
| IC-12 | **v1 climaxes at end of Act I — the emperor gets a face** (named antagonist, ultimatum, summons-unlock seed, dream-glimpse of the captured bearer). NOT the alien reveal, NOT the war. | The cliffhanger hook into the strategy layer. | Exact staging of the climax scene. |
| IC-13 | **Architect for the future pillars** (strategy, space) as data/save/event seams; **do not build their gameplay.** | Avoid painting into a corner without scope-creeping v1. | Everything in Acts II/III. |
| IC-14 | **Resonance economy is era-independent** (Resonance Ore/Dust never modernize); the *civilian* economy modernizes by age. | Lore-correct (nanobot tech ≠ era tech); keeps the combat mental model stable. | Civilian resources per age. |

**Story immutables** (resolved 2026-06-12): second bearer = *captured but active* (long game from inside, dream-link intel, engineers own rescue); emperor = ordinary conqueror with **no alien foreknowledge** (cosmic dread is the *player's* discovery); Wren's meta-narration is **light and diegetic** (no fourth-wall breaks).

---

## 6. Core Loop

### 6.1 Moment-to-moment (micro — in the dungeon)
Move → dash to evade → attack (light combo) → fire abilities on cooldown (RMB/Q/R) → react to enemy tells → clear room. Player must be reactive; the win-feel is reading patterns and taking no hits.
- **Verbs:** WASD move, Space dash (fixed etching), LMB light-attack combo, RMB/Q/R slotted abilities, weapon special.
- **Success:** room cleared → door opens. **Failure:** HP to 0 → death → respawn in town (no penalty).

### 6.2 Mid-run (meso — one dungeon descent)
Enter floor → traverse **6–10 rooms** of RNG-ordered types (combat / boss / reprieve-upgrade) → collect **Echoes** (in-run upgrades that can synergize) → **boss at the end of each floor** (5 floors) → anticipation peaks at boss, relief on the kill → descend. **Full clear** = all 5 floors + final boss → a **codex shard** drops and **visibly slots into the artifact** in the final-boss chamber.
- **Run length target:** 20–25 min on a successful clear.
- **Run end (win OR die):** advances the **day tick** → town production + research fire once; new dialogue becomes eligible; everything collected is kept.

### 6.3 Full-run / meta (macro — between runs, in town)
Respawn/return to town → **dialogue** (story + arcs + contextual) → spend resources: **weapons** (Mara, Resonance Ore), **etchings + attunements** (Thomas, Resonance Dust), **tech research** (read + puzzle; Knowledge + Knowledge Shards), **town buildings** (Herzog, Gold + materials) → next run is stronger. Story unlocks new systems via a cascade (see §7.1). Loop tightens: stronger runs → more resources + faster research → stronger runs.
- **Win state (v1):** reach the Act I climax cascade (emperor named, ultimatum, dream-glimpse) → cliffhanger close. There is no "lose" state — death is a setback, not a loss.

---

## 7. Major Systems

For each: **purpose · trigger · state · resolution · player decision · content hooks · risks.** Data shapes are in `architecture-schemas.md`; this section is the behavioral contract.

### 7.0 EventBus + Ledger (the spine — build first)
- **Purpose:** the only cross-domain channel; the substrate that keeps pillars separable (IC-13).
- **Trigger:** every meaningful state change emits a typed signal (`run_ended`, `boss_killed`, `tech_researched`, `resource_changed`, `building_built`, `dialogue_seen`, `codex_shard_added`, `death`, …).
- **State:** none of its own; it routes. The **Ledger** autoload holds the generic resource map (`get/add/try_spend`, emits `resource_changed`).
- **Resolution:** subscribers (achievements, dialogue-gating, stats, town tick, future strategy) react. Systems **never call each other for bookkeeping — they emit.**
- **Player decision:** none (infra).
- **Risk:** if any system reaches across pillars with `get_node()` instead of events, the decoupling breaks. Enforced by review + the test "could I delete the dungeon scenes and still run the town?"

### 7.1 Progression & the unlock cascade
- **Purpose:** pace complexity — systems come online one at a time via the story, never all at once.
- **Trigger:** mixed gates (milestones + tech + run counters), per `act1-story-beats.md`. E.g. first Resonance Ore → weapons (Mara, B1); first Resonance Dust + visited Thomas → etchings/attunements screen (B2); 3rd cumulative boss kill → tech tree (Linnea, B3); gold ≥ first cost → town building (Herzog, B4).
- **State:** `story.flags`, `story.counters` in save; system-unlocked flags derived from them.
- **Resolution:** a gated scene fires, sets a flag, and the corresponding screen/vendor becomes available.
- **Player decision:** which systems to invest in first once unlocked.
- **Content hooks:** each unlock = a scripted scene (the cascade beats).
- **Risk:** gates mis-tuned → systems unlock too early (overwhelm) or too late (player rushes depth and stalls). See open questions in `act1-story-beats.md` (B3 fallback `OR runs >= 6`).

### 7.2 Combat — weapons
- **Purpose:** the reflexive-release verb set; the thing learning makes stronger.
- **Trigger:** player input in dungeon rooms; weapon switching in town/loadout.
- **State (persistent):** per weapon `{flat: <level 0–5>, resonance: [effect-ids]}`; current loadout. **v1 ships 3 weapons: Sword, Bow, Daggers** (Spear = post-v1 data slot). Each: light combo + 1 special.
- **Resolution:** **two upgrade tracks** at Mara's Forge — **flat** (standard refine, Resonance Ore; 5 levels of attack speed/damage etc.) and **resonance** (4 effects, e.g. "more damage when hitting the same enemy"). Forge L2 (via Metallurgy tech) = cheaper/stronger.
- **Player decision:** which weapon to main; where to spend scarce Resonance Ore (flat vs. effects vs. across weapons).
- **Content hooks:** `data/` weapon defs; ~1 weapon-synergy variant per etching ability (flagged cheaply).
- **Risk:** dominant weapon/effect. **Feel is human-tuned** (`# FEEL:` markers; agents must not "optimize" tuned numbers). The combat-feel gate is the go/no-go for the whole project.

### 7.3 Combat — etchings (active abilities)
- **Purpose:** Tycho's "magic" loadout — the nanobot abilities.
- **Trigger:** unlocked at B2; configured at Thomas's Hut; fired in dungeon on RMB/Q/R (Space/dash is fixed and always available from A1).
- **State:** `etchings.slots {rmb, q, r}`, `etchings.unlocked {id: level}`. **9 abilities** unlockable (3 per slot), each **3 upgrade levels** (Resonance Dust). Each has exactly 1 weapon-synergy variant. *(Designed 2026-07-03 — `etchings.md`:)* slot grammar **RMB=Strike / Q=Field / R=Surge**; RMB **Push** (free at B2) / **Bolt** / **Afterstrike**; Q **Snare** / **Ward** / **Lodestone**; R **Shockwave** / **Surge** / **Sentinel**. Cooldowns only, no mana; mouse-aimed.
- **Resolution:** spend Resonance Dust to unlock/upgrade; swap which ability fills each slot. L3 of each ability adds a small rider behavior. **Sentinel is the Act-II summon seed** (`source_etching`, schema §8; `summon_seed: true` in data).
- **Player decision:** slot loadout; build identity (which 3 + dash define your kit); active-vs-passive Dust spend (see 7.4).
- **Content hooks:** `data/etchings/` ability defs + weapon-synergy variants; the Echo pool's etching-mod category authors against these handles (`etchings.md`).
- **Risk:** shares Dust with attunements — must be tuned so neither starves the other into a no-brainer. Ward vs ranged pressure, Lodestone→Shockwave dominance, rotation homogenization — watch-list in `etchings.md`.

### 7.4 Combat — Passive Attunements (persistent passive upgrades) *(added 2026-06-19)*
- **Purpose:** always-on growth to Tycho's body/base kit — the nanobots *reinforcing the host* (vs. etchings *configuring* abilities).
- **Trigger:** same screen unlock as etchings (B2); purchased at Thomas's Hut, 2nd tab.
- **State:** `combat.attunements {id: level}` (persistent). **~7 attunements**, 3 levels each: Vitality (+max HP), Recovery (regen/heal-on-clear), Quickening (+dash charges / shorter dash CD), Resonance Flow (faster ability CDs), Focus (+crit/damage), Resilience (flat damage reduction), Attunement (+Dust/Ore find rate). Final list + numbers TBD in tuning.
- **Resolution:** spend **Resonance Dust** (shared currency with active etchings — deliberate build-choice tension); flat stat bumps, no in-run RNG. Applied as the run's **baseline**, *under* in-run Echoes.
- **Player decision:** raw power (attunements) vs. abilities (etchings) with one currency; which stats to prioritize for your build.
- **Content hooks:** cheap data table, no new art.
- **Risk:** find-rate attunement (Attunement) is **compounding meta** — cap it or curve it so it can't snowball resource income. Vitality + Resilience + assist mode stacking could trivialize difficulty — see Balance §10.

### 7.5 In-run upgrades — Echoes
- **Purpose:** run-to-run variety and the synergy high; the roguelite's build-of-the-run.
- **Trigger:** *(cadence designed 2026-07-03 — `run-structure.md`:)* **Echo doors** (≥2 offered per floor, pity-weighted) + **one guaranteed pick after every floor boss** → HUD auto-opens with **3 choices**. Target ≈ 12–17 picks per full run. (The slice's every-combat-room offer is a placeholder, retired when door choice is built.) Diegetically the etchings glow — nanobots trying configurations.
- **State:** in-run only (NOT persisted past the run) — sits on top of the persistent attunement baseline.
- **Resolution:** pick 1 of 3. **~50 echoes**: weapon mods, etching mods, dash mods, stat boosts, + **~8 synergy echoes** that require 2 prior picks.
- **Player decision:** chase a synergy vs. take safe value; commit to a build mid-run.
- **Content hooks:** `data/echoes/`; synergy prerequisites as data.
- **Risk:** dominant synergy chains; dead offers (3 useless picks). Needs offer-weighting + RNG protection (§10). Pure-function offer generator (testable).

### 7.6 Dungeon generation
- **Purpose:** the release space; structured variety without bespoke per-run authoring.
- **Trigger:** run start; floor entry.
- **State:** current floor (1–5), room index, room type sequence (RNG), difficulty tier.
- **Resolution:** **5 floors × 6–10 rooms**, RNG-ordered from **~30 shared combat layouts** + 5 boss arenas + 3 reprieve layouts + entry/exit. One geometry kit; each floor is a **stratum** (IC-5 as revised 2026-07-03, spec `dungeon-strata.md`): a data-driven environment profile (palette/fog/light) + **one signature hazard** + 2–4 props. Floors differ by **enemy mix + stratum profile + signature hazard**, never by biome art. Hazards are scripted (timer + volume + telegraph), dual-use (hurt enemies too), density-tuned per floor. Boss at the end of every floor.
- **Player decision:** **door choice** *(designed 2026-07-03 — `run-structure.md`)*: after each clear, two sigil-marked exit doors preview the next room's **reward** (gold/ore/dust/echo/reprieve-heal; boss door alone at floor end; peril marks = elite modifiers + boosted pay = the risk/reward lever); choice is final. **In-run healing** rides the same system: no full heals, all healing = % of *missing* HP (Wellspring behind Reprieve doors ~40%, floor-boss clear ~30%, Recovery attunement, 2–3 healing echoes) — damage costs choices, not progress. Cartography's effect = door **foresight** (sigils one room further ahead). Positioning play around dual-use hazards.
- **Content hooks:** layouts, room-type weights per floor, floor profiles (`data/floors/` — now incl. `door_weights` + `peril_chance`), hazards (`data/hazards/`), 6 door sigils + Wellspring prop.
- **Risk:** repetition fatigue (mitigated by Echoes + hazards + dialogue novelty + tiers); generation producing unfair/empty rooms (hazards must never block the only path — §10); stratum palettes drowning enemy telegraphs (fixed telegraph colors + a human legibility pass per floor — `dungeon-strata.md`); door pity rules per §10 (≥2 echo + ≥1 reprieve per floor); heal-stacking cap watch (`run-structure.md`).

### 7.7 Enemies & bosses
- **Purpose:** the pattern-mastery substrate.
- **State:** **12 base enemy types** (~4–5 per floor with overlap); **elites = a modifier system on base types** (no new art); **5 bosses, one per floor**, floor-5 = final boss (drops Codex Shards). Difficulty tiers reuse all 5 with new patterns/modifiers.
- **Resolution:** standard real-time AI (telegraphed attacks, tells); boss = arena + multi-phase patterns.
- **Risk:** bosses are the **most expensive single budget items** (design + arena + feel + tells) — human-gated. Elite modifiers must not produce unfair combos.

### 7.8 Tech tree (the learning layer)
- **Purpose:** the soul — real history of tech + science + thinking tools; the main early progress driver.
- **Trigger:** unlocked at B3; player selects an active node; research accrues on the day tick + Knowledge Shard dumps.
- **State:** `tech.researched[]`, `tech.in_progress {id: knowledge}`, `tech.auto_solve_counters`. Each node: `age`, `tier` (key/support), `cost_knowledge`, `prereqs`, **typed `unlocks[]`** (building/resource/capability now; unit/strategy-building/space-tech later — do NOT hardcode unlock kinds), `puzzle`, `auto_solve_after_runs`, `thinking_tool` (🧠).
- **Resolution:** accrue Knowledge into the active node → at threshold, **read explanation → solve puzzle/quiz → unlock fires** (typed dispatch applies the unlock). Linnea **auto-solves over ~5 runs** for players who skip puzzles (reward thinking, don't hard-gate). Each first-researched tech of an age **advances the town to that age** (visible skin change).
- **Player decision:** which node to pursue; spend Knowledge Shards now vs. save; solve vs. auto-solve.
- **Content hooks:** `data/tech/<id>.json` (engine contract) mirrors `design/tech-nodes/<id>.md` (authoring source). **v1: 14 nodes** = 11 Medieval (full) + 3 Renaissance (first sliver). 8 KEY nodes = bespoke interactive puzzles; 6 support = light quizzes. Ages III–V = stub data files only.
- **Risk:** puzzles reading as **homework not delight** (the Content gate validates the format on ONE node first — `medieval-masonry-the-arch.md`). Research pacing between runs (open tuning question).

### 7.9 Town & economy (upgrade-hub model)
- **Purpose:** the cerebral hub + visible age-progression; NOT a city-builder (no worker assignment, no supply chains).
- **Trigger:** town visit (between runs); the **day tick fires once per run-end** (TownTick reads buildings → writes ledger → emits events).
- **State:** Town as a **data object** (`{id, name, age, buildings[{id, level}], map_pos:null}`) — instantiated once in v1, N times in Act II. Buildings: category (production/research/infrastructure/shop), `unlocked_by`, exactly **3 levels** each (cost + typed `effects[]` + `visual`).
- **Resolution:** build/upgrade at Herzog (Gold + Timber/Stone). **13 buildings** (Medieval + early-Renaissance). Each level changes the **visual** — the town visibly grows. Production resolves on the day tick.
- **Player decision:** what to build/upgrade with limited Gold + materials; research vs. production vs. infrastructure.
- **Content hooks:** `data/buildings/`; effect kinds (`produce|knowledge|multiplier|capability`; strategy kinds `defense|summon-capacity` extend later).
- **Risk:** economy numbers unbalanced (open tuning question); Thomas's Hut must **never change across ages** (lore, IC-14) — 1 model.

### 7.10 Resource economy
- **Purpose:** connect runs → upgrades → stronger runs; lean, anti-overwhelm.
- **Model:** **fixed roles, evolving instances** — the player tracks ~5–6 *roles*; what fills each modernizes per age; resources **retire** (fold to baseline), they don't accumulate endlessly.
- **Player-collected (from runs):** Knowledge Shards (stage bosses → research, main early driver), Codex Shards (final boss → meta-puzzle, story only), Resonance Dust (rare drops → etchings + attunements), Resonance Ore (find/harvest → weapons), Gold (drops + market → buildings).
- **Town-produced (day tick):** Knowledge (Study→Library→Observatory→University), Timber (Lodge), Stone (Quarry), Food (Farm — **upkeep → Well-Fed bonus**: town consumes Food per tick; covered = +% to all other production incl. Knowledge, short = no bonus, never a penalty; the upkeep mechanism is the Act-II army/city prepare-for — `food-upkeep.md`, designed 2026-07-03), Gold (Market).
- **Resolution:** generic ledger; resource defs carry `role`, `age_active`, `supersedes`, `retired_by`. **Resonance + Knowledge + Gold roles never change** (IC-14); **Material/Energy/Military roles modernize** (Energy/Military are born in later ages — data slots now). The **Industrial age is the deliberate complexity spike**; other ages stay light; Future eases (post-scarcity).
- **Risk:** too many simultaneous resources → overwhelm (mitigated by retirement/fold UI). Resonance economy starvation across two sinks (weapons vs. etchings/attunements).

### 7.11 Codex meta-puzzle (the mystery)
- **Purpose:** v1's payoff — the growing mystery itself (solving it = the alien reveal, post-v1).
- **Trigger:** each **full clear** drops a Codex Shard → it **visibly slots into the artifact** in the final-boss chamber.
- **State:** `codex.shards` count; 5–7 shard visual states.
- **Resolution:** v1 only *assembles* it in plain sight; once complete, the player may solve or do more runs for hints/auto-solve (the reveal is post-v1). Dream-link beats escalate per shard (story).
- **Risk:** none mechanical; ensure the visible assembly reads as meaningful, not a collectible counter.

### 7.12 Dialogue system
- **Purpose:** the Hades-style vibrancy + story delivery; the largest writing line item.
- **Trigger:** on each town visit, build the eligible set per character; spine/cutscene beats can **force-play** (banner icon), max **1 forced scene per visit**.
- **State:** every snippet is data: `id, speakers[], source (spine|arc|contextual|bark), conditions[], priority, once, cooldown_runs, force_play, sets_flag, scene`. `story.seen[]` tracks shown.
- **Resolution:** each character offers their single highest-priority eligible item; **priority spine > arc > contextual > bark**; `cooldown_runs` prevents back-to-back same-arc beats; barks repeatable. Selector is a **pure function `(save_state, character) -> snippet`** (unit-testable). Conditions read only EventBus-maintained state (flags/counters/ledger/tech). **Dialogues are fully scripted — the player never chooses** (all decisions happen in other systems). Supports 3+ speakers and cutscenes (painterly stills + narration).
- **Content hooks:** ~20 spine + ~28 arc (4 full arcs: Linnea, Tilly, Mara, Thomas) + ~250 contextual + ~60 barks + ~8 cutscenes. Condition vocabulary in `act1-story-beats.md` §spec is the engine contract.
- **Risk:** dumping multiple story scenes after one run (mitigated by 1-forced-per-visit rule); content volume (agent-drafted, human-curated).

### 7.13 Save system & accessibility
- **Save:** **multiple slots** (one file per slot + shared `profile.json` for settings/achievements). `save_version` with a migration chain (`migrate_vN_to_vN+1`, never read fields without defaults). **No mid-run saves in v1** — save on town return + per-floor autosave checkpoints (quit mid-run → resume at floor start). `pillars.{strategy,space}` reserved-empty so Acts II/III extend without migration.
- **Achievements:** generic evaluator over `data/achievements/` reading EventBus signals; ~25 at v1; unlocks in profile.
- **Accessibility:** assist mode (IC-10) + auto-solve (IC-10); accessibility settings are profile-level (survive slot deletion).

---

## 8. Content Model
All content = **JSON in `data/`, one file per entity, filename = kebab-case id**; code is generic; **adding content must never require code** (if it does, fix the schema/dispatch). Debug builds validate every file against its schema on load.

- **Entities:** resources, tech nodes, buildings, dialogue snippets, achievements, ages, echoes, enemies, weapons, etchings/attunements, floor strata profiles, hazards, summons (reserved, unimplemented).
- **Typed extensibility (load-bearing):** tech `unlocks[]` is a typed list; building `effects[].kind` is a typed set; both extend for Acts II/III by adding match arms, not data shapes.
- **Theme-agnostic vs. theme-bound:** system semantics (roles, effect kinds, unlock types) are theme-free; *content skinning* (names, icons, age palettes, town skins) is data — an age is a "turn-the-page" bundle (`town_skin`, `palette`, `music`, `retires_resources`).
- **Rarity / weighting:** Echo offers and room-type sequences are weighted (data); no formal rarity tiers in v1 beyond echo synergy prerequisites.
- **Authoring vs. engine split:** tech nodes authored as `design/tech-nodes/<id>.md` (human/agent prose + puzzle), mirrored to `data/tech/<id>.json` (engine contract).

---

## 9. UX & Feedback
- **Must be visible:** current HP / resources / active Echoes (in-run HUD); room/floor progress + minimap (Cartography tech reveals more — incl. door foresight, `run-structure.md`); **door reward sigils** (+ peril marks; first encounter of each sigil gets a one-line tooltip); active tech node + progress; building costs vs. owned resources; which dialogue is a forced story beat (banner icon).
- **Must be immediate:** hit/dash/pickup feedback (the feel-critical SFX subset gets human tuning); ability cooldown states; Echo-pick HUD (auto-opens).
- **Needs recap/history:** codex shard assembly (visible artifact); achievements page; tech tree per-age screens (researched=green, current=blue, available=normal, locked=greyed); seen-dialogue tracking (no repeats of `once` snippets).
- **Must be explainable on failure:** death cause readable (what hit you); why a tech/building is locked (missing prereq/resource shown); why a dialogue/system isn't available yet (gated).
- **Screens (10):** tech tree (per-age), etchings+attunements, forge, mayor/build, market, echo-pick HUD, codex viewer, dialogue box, achievements, save slots. Static screens render in **painterly 2D**; gameplay in 2.5D.

---

## 10. Balance & Risk Controls
- **Infinite-scaling risks:**
  - **Attunement (find-rate) compounding** → cap/curve so resource income can't snowball (§7.4).
  - **No death penalty (IC-8) + per-run day tick** → research/production accrue every run regardless of outcome; ensure costs scale so this is steady progress, not runaway. Knowledge Shards are the intended early accelerator — bound shard yields.
  - **Assist mode stacking** is **capped** by design (IC-10) — verify the cap can't combine with Vitality/Resilience to trivialize all tiers.
- **Dominant-strategy risks:** a best weapon/effect, a best etching loadout, or a degenerate Echo synergy chain. Mitigation: offer-weighting, synergy prerequisites as data (tunable), human feel-tuning, and tier modifiers that punish one-note builds.
- **Dead-roll / unwinnable risks:** Echo offers of 3 useless picks → guarantee at least one build-relevant offer via weighting; dungeon generation must never produce impassable/empty rooms (validate layouts). **There is no unwinnable run** — death has no penalty and assist mode guarantees eventual clears.
- **RNG protection:** weighted (not uniform) Echo/room generation; pity rules for rare drops if playtest shows starvation (esp. Resonance Dust feeding two sinks).
- **Caps / soft caps:** Food upkeep is bonus-only (Well-Fed or not — no starvation state, no spiral; `food-upkeep.md`); buildings cap at L3; attunements/etchings cap at 3 levels; weapons flat at 5 / resonance at 4 effects; assist-mode resist capped.
- **Tuning is human-gated:** all feel numbers + the economy curve are playtest-tuned, not solved on paper. Numbers in the bible/budget are **targets**.

---

## 11. MVP Scope

### Must-have systems (v1)
EventBus + Ledger; save/slots/migration + profile; the unlock cascade; combat (3 weapons, 9 etchings, ~7 attunements, dash); Echoes (~50); dungeon gen (5 floors as strata: profiles + 5 signature hazards + 1 shared); 12 enemies + 5 bosses + elite modifiers; tech tree (14 nodes, 8 bespoke + 6 light puzzles, auto-solve); town (13 buildings × 3 levels) + day tick; resource economy (Medieval roles + retirement scaffolding); codex assembly; dialogue system (~358 pieces total) + cutscenes; achievements (~25); assist mode + auto-solve; 2.5D rendering + painterly static screens.

### Recommended first content volume
Per `content-budget.md` (the schedule): authored for **10–15 h** first playthrough. Author **one** of each expensive type to validate format **before** scaling (one tech node — done: Masonry; then one weapon, one boss, one cutscene). **Sequencing rule: never start an expensive line item before its gate validates the format** (combat gate → weapons/bosses; content gate → puzzles; pipeline gate → all 3D asset lines).

### Explicit non-goals (v1)
- **No strategy gameplay** (no armies, no overworld map, no multiple towns, no summons logic — schema reserved only).
- **No space stage.**
- **No alien reveal / no solving the codex meta-puzzle** (it only assembles).
- **No worker assignment / supply chains / city-builder economy.**
- **No dungeon puzzle rooms** (cut).
- **No weapon aspects/forms; no Spear** (data slot).
- **No mid-run saves; no real-time idle progression.**
- **No turn-based / deckbuilder combat.**
- **Ages III–V (Industrial/Modern/Future): stub data files only, unauthored.**

### Deferred / future-extension hooks (designed-for, not built)
- **Summons** = one abstraction, two contexts (dungeon auto-clearer / army unit) — schema reserved.
- **One town → many towns** (Town is already a data object; `map_pos:null` until overworld exists).
- **Tech `unlocks[]` typed list** extends to unit/strategy-building/space-tech.
- **Building `effects[].kind`** extends to `defense`, `summon-capacity`.
- **Town Walls** = the literal Act-II seed (flavor now, defense stat later); **Cartography** = the strategic-map hook.
- **`pillars.{strategy,space}`** save sections reserved-empty.
- Resonance-derived **summon/military resource** role (lore-fit: emperor's summons are artefact-powered).

---

## 12. Production Notes
- **Stack:** Godot 4.7, **GDScript only, static typing mandatory.** Technically a 3D project with one reusable `camera_rig.tscn` (the 2.5D decision); nothing else assumes camera angles.
- **Data-driven:** all content is JSON in `data/`; `src/core/validate.gd` validates against schema on load in debug builds. Autoloads are thin state-holders; logic in plain classes (testable).
- **Architecture rules:** EventBus is the only cross-domain channel; pure-function core (dialogue eligibility, town tick, tech costs, echo offers); decoupling test "could I delete the dungeon and still run the town?"
- **Directory layout & naming:** per `godot-conventions.md` (`src/` by domain, `scenes/`, `data/`, `assets/`, `tests/`; snake_case files, PascalCase classes, past-tense typed signals).
- **Telemetry/debug:** schema-validation errors loud in debug; feel-parameters marked `# FEEL: human-tuned, do not optimize`.
- **Testing:** **gdUnit4**, headless before any `src/` commit. Required coverage: all pure logic + save/migration round-trips + data validation. **Not** tested: combat feel, visuals, scene wiring (human playtesting).
- **Assets:** 2.5D pipeline = Tripo (models) → rig → Quaternius/UAL (animation retarget) → fixed-camera scene; painterly 2D (portraits/cutscenes/cards) via AI image tools in the candlelit-cosmic oil style. **Placeholder-first everywhere; never block a system on final art.** Commit `.import` + `project.godot`; revisit Git LFS past ~1 GB.
- **Git:** work on `main` (solo); commit per meaningful change; prefixes `feat:/fix:/content:/design:/chore:`.
- **Milestones (suggested):**
  1. **Phase 0 gates** (go/no-go before this PRD is finalized): combat-feel gate; content gate (done: Masonry node authored — playtest pending); asset-pipeline gate.
  2. **Skeleton:** Godot project + EventBus + Ledger + save/slots + data-loader/validator.
  3. **Vertical slice:** one floor, one weapon, dash, 2–3 enemies, one boss, Echo HUD, town return, one building, one tech node end-to-end, save/load — proves the full loop.
  4. **Breadth:** scale to full counts per `content-budget.md`, gated format-first.
  5. **Story + dialogue pass:** spine + arcs + contextual volume; cutscenes.
  6. **Climax + polish:** Act I cliffhanger; balance; accessibility; achievements.

---

## 13. Open Questions
Resolve in playtest / as work proceeds — **do not** silently pick answers.
- **Combat feel (the project go/no-go):** does a single room pass the "20th clear, still want one more" bar? Until this passes, everything downstream is provisional.
- **Puzzle format delight-vs-homework:** validated on the Masonry node yet? The authored format gates the other 13 nodes.
- **Economy numbers:** resource costs, drop rates, Knowledge/day curve, two-sink Resonance balance — all unset; tune in play.
- **Tech-puzzle pacing between runs:** how many puzzles per run-cadence before it drags? (`content-budget.md` second-order unknown.)
- **Gate tuning:** B3 tech-tree gate ("3rd boss kill") too late for depth-rushers? Fallback `OR runs >= 6` (`act1-story-beats.md`). C4 dream gate (`codex_shards >= 2`) — does it land mid-act at real pace (~run 15–20)?
- **How many weapons/etchings does v1 actually need** for build variety without bloat? (Budget says 3/9 — validate in play.)
- **D5 climax:** single scene or short playable epilogue walk through the changed town? (Decide after the climax is drafted.)
- **Difficulty-tier design:** how many tiers, what modifiers, for completionist replay?
- **Attunement find-rate curve:** exact cap to prevent resource snowball.
- **Space stage (Act III):** still genuinely unsolved at the concept level (post-scarcity makes resources/dungeon-runs moot) — out of v1 scope, flagged so no v1 decision forecloses it.

---

## Appendix — Checklist sign-off (`design-checklist.md`)
- **Core integrity:** all 14 immutable rules + 3 story immutables preserved (§5); immutable vs. expandable separated; genre unchanged. ✅
- **System clarity:** every major system has trigger/state/resolution (§7); entities defined as data (§8, `architecture-schemas.md`). ✅
- **Game-specific depth:** replay (Echoes + persistent growth + dialogue novelty + tiers, §3/§7.5); build identity (weapon + etching loadout + attunements + Echo synergies, §7.2–7.5); risk-vs-stability (Echo synergy chasing, two-sink Resonance spend, route choices, §7.5/§7.4/§7.6); failure pressure & recovery (boss pressure; no-penalty death + assist mode, §6/§10). ✅
- **Expansion readiness:** semantics vs. skinning separated (§8); future hooks explicit (§11 deferred); unlock-later content stated (§7.1, §11). ✅
- **Balance safety:** infinite-growth, dominant-strategy, dead-roll, unwinnable all flagged with controls (§10). ✅
- **MVP discipline:** must-have vs. future separated; vertical slice proves fun small; content volume gated format-first (§11/§12). ✅
- **Document quality:** specific not aspirational; open questions explicit (§13); non-goals written (§11); usable without a walkthrough. ✅
