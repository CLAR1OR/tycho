# Architecture Schemas — the "prepare-for" drafts

> Draft data schemas for the architectural prepare-fors (CLAUDE.md → "prepare-for" requirements), plus the dialogue schema demanded by `act1-story-beats.md`. Drafted 2026-06-12 — these are contracts of *shape*, not final field lists. Implement as JSON content files + typed GDScript wrappers (see `godot-conventions.md`). Rule of thumb everywhere: **adding content is adding a data entry, never adding code.**
>
> **Implementation status (2026-07-02):** §1 save/profile (`src/core/save_data.gd` + `src/autoload/save_manager.gd`), §2 ledger (`src/core/ledger_core.gd` + `src/autoload/ledger.gd`), §5's EventBus (`src/autoload/event_bus.gd`), and the resources/ages/**buildings** data specs (`src/core/data_loader.gd` + `validate.gd`, content in `data/`) are **built and tested**. §1's save points are fully in: save on town return, **per-floor autosave checkpoints** (the slot's `checkpoint` section — see §1 — written as each floor's first room loads, cleared on run end; quit mid-run → resume at floor start), and the **slot-select boot screen** (`src/core/slot_select.gd`, reading `SaveManager.list_slots()` meta incl. `checkpoint_floor` without loading a slot). §6's town-as-data + day tick are live via pure `src/town/town_core.gd` (production effect kinds `produce`/`knowledge` so far; `multiplier`/`capability` land with their consumers). **The Food upkeep pass is built (2026-07-05, `food-upkeep.md`):** `TownCore.tick(town, building_defs, food_stock)` now returns `{produced, food_consumed, well_fed}` — realized as a town-wide `upkeep = base + per-building` consume (constants in TownCore, not a per-building `upkeep` effect kind yet) that grants the **Well-Fed** status (+25% to all produced resources except Food; never a penalty). `game.gd`'s day tick spends the Food and stores `state.town.well_fed`; `data/resources/food.json` + the ungated `data/buildings/farm.json` are the content; run/floor/room progression is pure `src/core/run_flow.gd` held by the `RunState` autoload. **Door choice + the in-run healing economy are built (2026-07-05, `run-structure.md`):** pure `src/core/door_core.gd` lays out a floor's deterministic door plan (1-2 sigil doors/offer, boss door last, pity ≥2 echo + ≥1 reprieve, no sigil 3× consecutive) from the new **`data/floors/`** profile (`door_weights` + `peril_chance` — see §9) and owns the cache/peril/heal math; `RunState` holds the plan + chosen door (NOT saved — resume regenerates by seed); `combat_room.gd`/`game.gd` wire the door portals, the reprieve **Wellspring** (40% of missing HP), the boss valve (30% of missing + a guaranteed echo), the peril elite-spawn stub, and the cache payouts (`Ledger` reason `door-reward`, new `resonance-dust` resource). The every-combat-room echo offer is **retired** — echoes now come only from echo doors + the post-boss guarantee. §4's tech nodes are live (`data/tech/` spec in DataLoader incl. `explanation`/`aha` text fields; pure `src/learning/tech_core.gd` + placeholder `tech_panel.gd` UI; typed building-unlocks gate town plots via `TownCore.is_unlocked`; `tech.active` added to the save's tech section; auto-solve ticks on run end). §4's `puzzle` field is dispatched on `kind`: `{kind: "quiz", data}` uses the panel's built-in quiz screen, `{kind: "interactive", scene, data}` embeds a bespoke Control from `TechPanel.PUZZLES` (contract: `setup(data)` + a `solved` signal) — the first is `puzzle_arch` (`src/learning/puzzle_arch.gd` over pure `arch_puzzle_core.gd`), live on `med-masonry-arch`. §7.2 weapons are live as a data domain (`data/weapons/`: `{id, name, kind: melee|ranged, desc, mods[], projectile, flat: {damage_mult_per_level, costs[]}}` — mods are RELATIVE to the feel-tuned player exports, Sword = empty-mods baseline; pure `src/combat/weapon_core.gd`, shop UI `src/town/forge_panel.gd`; save carries `combat.current_weapon` + `combat.weapons.{id}.flat`, the `resonance` list is reserved). **Echoes** are live as a data domain (`data/echoes/`: `{id, name, desc, pool_weight, stackable, requires[], mods[{stat, add, mult}]}`) with a pure offer generator + stat-mod math in `src/combat/echo_core.gd` — in-run only on RunState, never saved (locked design). §7's dialogue is live in its first slice (2026-07-03): `data/dialogue/` spec in DataLoader (this section's shape, conditions per the act1-story-beats.md vocabulary — all of it implemented), pure selection/eligibility/mark_shown in `src/dialogue/dialogue_core.gd`, playback in `dialogue_panel.gd`, NPC talk spots + force-play (max 1/visit) in town.gd; `story` gained `talked_to`/`dialogue_last`/`arc_last`. **The unlock cascade (PRD §7.1) is live (2026-07-04):** pure `src/core/unlocks_core.gd` maps each town system to the story flag that opens it (weapons←b1, etchings←b2 [dormant], tech←b3, building←b4); `town.gd` gates the forge/desk/build-plots on `UnlocksCore.is_unlocked`. Two cascade beats added to `data/dialogue/` (B3 `b3-sophia-shards` + its runs≥6 fallback twin, B4 `b4-herzog-ledger`); `DialogueCore.eligible` gained a general rule — a snippet whose `sets_flag` is already set is inert — so twin-gated beats (a beat + its fallback copy sharing one flag) never both play under the AND-only, no-negation vocabulary. **Audio** is fully live in its first chunk (2026-07-04, `design/audio.md`): `data/audio/sfx-map.json` (id → {file, volume_db, pitch_jitter, bus} — a deliberate single-file exception to one-file-per-entity, loaded via `DataLoader.load_sfx_map()` with the same loud validation) feeds pure `src/core/sfx_core.gd` under the thin `Sfx` autoload; pickup/boss-kill sounds subscribe to EventBus like any other cross-domain consumer; buses in `default_bus_layout.tres`. **Music too:** `data/audio/music-map.json` (id → {file, volume_db}, same single-file exception, `DataLoader.load_music_map()`) feeds pure `src/core/music_core.gd` (resolve + equal-power crossfade curve) under the thin `Music` autoload (two players on the Music bus, ~1 s crossfade on scene swap). The profile's `settings` audio volumes (below) are now in code and applied to the Music/SFX/UI buses in `Music._ready`. **§1's story section is now owned by the `StoryState` autoload (2026-07-04)** over pure `src/core/story_core.gd`: every EventBus-driven mutation of `state.story` — the run/death/boss counters (run_ended/death/boss_killed), the `has-<resource>` first-pickup flags (resource_changed), and the full-clear codex shard + `meta.runs` mirror — moved out of `game.gd` into StoryState's handlers, leaving game.gd as scene-flow routing. StoryState registers immediately after SaveManager (whose state slice it owns), so it subscribes before the main scene and its counters are persisted before game.gd's deferred town-return save (the smoke re-reads the slot file to prove it). StoryCore mutates the story dict **in place** (not the return-a-new-dict style of TownCore/DialogueCore — live call-site refs to the counters dict must not go stale). **Dissolve loop (2026-07-07):** a full clear ends by walking into a codex-artifact pedestal in the final chamber (built in `combat_room.gd`/`game.gd`/`RunState`) → `EventBus.dissolved` → StoryState `record_dissolve` bumps a new `story.counters.dissolves` (separate from combat `deaths`) → then `run_ended(true)` grants the shard as before; `StoryCore.grant_codex_shard` now clamps at `CODEX_SHARDS_MAX` (placeholder 6). The A3 opener twins are re-gated death-vs-dissolve; E2 force-plays at max shards. **ESC pause menu (2026-07-07):** `src/core/pause_menu.gd` (`PauseMenu`, HUD-layer like the cheat panel, ESC/`ui_cancel` toggles, inert at slot select, ignores ESC while another panel owns the pause) offers Resume / Forfeit Run / Save & Quit. **Forfeit** and in-run **Save & Quit** obey the **Hades quit-gate** — `combat_room.can_menu_quit()` = `_cleared or not _damage_taken` (leave only after clearing a room or while untouched; town has no gate). Forfeit calls `game.gd.forfeit_run` (abort RunState with no signals via the new `RunState.abort_run()`, restore the portal-entry snapshot `game.gd._run_snapshot` incl. resetting the live Ledger, null the checkpoint, save, return to town). In-run Save & Quit aborts RunState and returns to slot select **without any disk write** (the no-mid-run-write invariant above); town Save & Quit does a real save first. No save-schema change (the snapshot is in-memory). **§4's tech section is now owned by the `TechState` autoload (2026-07-05)** over the same pure `tech_core.gd` (no new core — TechCore already IS the pure core): every mutation of `state.tech` routes through it — `set_active` (node selection), `invest` (the Knowledge/Shard transaction incl. its Ledger spends), `complete` (`TechCore.complete` + the `tech_researched` emit — the single home of that pair, previously duplicated in the panel, the cheat panel, and game.gd's auto-solve), and Sophia's run_ended auto-solve (moved verbatim out of game.gd). Unlike StoryCore, TechCore is **return-a-new-dict**, so TechState reassigns `state.tech` on each mutation and call sites must re-fetch it after any TechState call. TechState registers right after StoryState (same ordering guarantee: subscribes before the main scene, so the auto-solve result persists before game.gd's deferred town-return save). The age-advance hook on `tech_researched` stays in game.gd (it mutates town/meta.age, not the tech section). Achievements land with their system.

Notation below is JSON-ish with comments. All ids: kebab-case strings, matching the design docs (`med-masonry-arch` style).

---

## 1. Save system (multiple slots)

One file per slot + one shared profile file. Settings/accessibility are profile-level (survive slot deletion); achievements are profile-level (standard player expectation).

```jsonc
// save_slot_<n>.json
{
  "save_version": 1,            // int, bump on schema change; loader runs migration chain v1→v2→…
  "meta": {                     // shown on the slot-select screen WITHOUT loading the full save
    "name": "…", "created_at": "…", "updated_at": "…",
    "playtime_s": 0, "age": 1, "act": 1, "runs": 0, "act1_complete": false   // set by beat E1 → slot-screen badge (2026-07-03)
  },
  "story":   { "flags": {"a1": true}, "counters": {"runs": 0, "deaths": 0, "dissolves": 0, "boss_kills": 0, "full_clears": 0}, "seen": ["snippet-id"] },
             // deaths = combat only; dissolves = full-clear returns via the codex artifact (2026-07-07)
  "tech":    { "researched": ["id"], "in_progress": {"id": 12.5}, "auto_solve_counters": {"id": 3} },
  "ledger":  { "gold": 0, "knowledge": 1.2, "resonance-ore": 0 },   // see §2
  "town":    { /* Town object, §6 */ },
  "combat":  { "weapons": {"sword": {"flat": 2, "resonance": ["echo-bite"]}}, "etchings": {"slots": {"rmb": "id", "q": "id", "r": "id"}, "unlocked": {"id": 2}}, "attunements": {"vitality": 2, "quickening": 1}, "assist_mode": {"enabled": false, "stacks": 0} },
  "codex":   { "shards": 1 },   // clamped at StoryCore.CODEX_SHARDS_MAX (placeholder 6, PRD §7.11); grant at max is a no-op
  "checkpoint": null,           // per-floor autosave: null, or {run, run_number, echoes, player_health}
                                // snapshotted at floor start, cleared on run end (echoes never outlive a run)
  "pillars": { "strategy": {}, "space": {} }   // EMPTY in v1. Reserved keys so Acts II/III extend, never migrate.
}

// profile.json (shared across slots)
{ "profile_version": 1, "settings": { "music_volume": 1.0, "sfx_volume": 1.0, "ui_volume": 1.0, "window_mode": "windowed" /* linear 0..1 volumes applied to buses live by the settings screen (SET1, 2026-07-09) + at boot; window_mode "windowed"/"fullscreen" read via SettingsCore.window_mode (any other → windowed); controls + accessibility land with their screens */ }, "achievements": {"id": {"unlocked_at": "…", "progress": 3}} }
```

- **No mid-run saves in v1**: save on town return + autosave checkpoints between floors (quit mid-run → resume at floor start). Runs are 20–25 min; floor-granularity is enough. *(Implemented 2026-07-02 — `game.gd` writes the checkpoint as a floor's first room loads; `RunState.to_checkpoint()/resume_from()`.)* **Statistics invariant (2026-07-07):** because the resume re-reads the last floor-start checkpoint from disk, any counter earned after it (e.g. the final-boss `boss_kills` in the kill→pedestal window) is not yet persisted — quitting discards it and the resume re-earns it exactly once. This stays correct only as long as nothing writes to disk mid-run outside the floor-checkpoint snapshot, so the ESC menu's in-run **Save & Quit writes NOTHING to disk** (the checkpoint IS the save); **Forfeit** rolls the slot back to a portal-entry snapshot and re-saves that (overwriting the run's checkpoints).
- Migration: pure functions `migrate_v1_to_v2(dict) -> dict`, chained. Never read fields without defaults.

## 2. Resource ledger (generic)

The ledger is a dumb map; all *meaning* lives in resource definitions.

```jsonc
// data/resources/<id>.json
{
  "id": "stone", "name": "Stone", "icon": "…",
  "role": "material",            // research|money|material|energy|military|combat|story  (the bible's fixed roles)
  "age_active": 1,               // first age it exists
  "supersedes": "timber",        // or null — drives the "graceful retirement" UI fold
  "retired_by": "steel",         // or null — set when a later resource folds this one into baseline
  "sources": ["quarry", "run-drop"]   // documentation + achievement hooks, not logic
}
```

Ledger API (autoload): `get(id)`, `add(id, n)`, `try_spend(id, n) -> bool`. Every mutation emits `resource_changed(id, old, new, reason)` on the EventBus — dialogue gates, achievements, and UI all subscribe; nobody polls.

## 3. Age as data

```jsonc
// data/ages/<n>.json
{
  "id": 2, "name": "Renaissance",
  "entered_by": "any-tech-of-age",   // rule: first researched tech of age N advances the town to N
  "town_skin": "town_renaissance",   // scene/skin id — the visible age turn
  "retires_resources": [],           // fold-to-baseline list (e.g. age 3 retires timber/stone)
  "music": "…", "palette": "…"
}
```

Tech nodes, buildings, and resources each carry their own `age` field — an age file is just the *turn-the-page* bundle. **Adding an age = adding files, zero code** (the v1 test: ages 3–5 exist as stub files with empty content lists).

## 4. Tech node (typed unlocks)

```jsonc
// data/tech/<id>.json  — mirrors design/tech-nodes/<id>.md (the .md is the authoring source; the .json is the engine contract)
{
  "id": "med-masonry-arch", "name": "Masonry & the Arch",
  "age": 1, "tier": "key",          // key | support
  "cost_knowledge": 40,
  "prereqs": ["med-arithmetic-zero"],
  "unlocks": [                       // TYPED list — the load-bearing prepare-for
    {"type": "building", "id": "quarry"},
    {"type": "building", "id": "town-walls"}
    // future types, same shape: resource | capability | unit | strategy-building | space-tech
  ],
  "puzzle": {"scene": "puzzle_arch", "kind": "interactive"},   // or {"kind": "quiz", "data": "…"}
  "auto_solve_after_runs": 5,
  "thinking_tool": false             // the 🧠 flag
}
```

Unlock application is a dispatch on `type` — adding a new unlock type in Act II touches one match statement, no node data.

**Tech save-section shape** (`save.tech`, owned by the TechState autoload over pure TechCore):
```jsonc
"tech": {
  "researched": [],            // completed node ids
  "in_progress": {},           // {id: knowledge poured in} — investing spends Knowledge ONLY
  "auto_solve_counters": {},   // {id: runs the node has been active} → Sophia auto-solves at auto_solve_after_runs
  "quiz_locked": {},           // {id: true} — a wrong QUIZ answer locks that node's quiz; cleared on run_ended (waits one run). 2026-07-06
  "active": ""                 // the node Sophia works between runs
}
```
**Status (2026-07-06):** Knowledge Shards no longer auto-convert during invest — they are turned in for Knowledge at the desk (`TechState.turn_in_shards`, `SHARD_KNOWLEDGE_VALUE` = 5, Ledger reason `shard-turn-in`). A wrong quiz answer sets `quiz_locked[id]` (Ledger-free); `TechState._on_run_ended` clears all locks each run. `defaults-merge` fills `quiz_locked` for old saves.

## 5. Achievements (central event hook)

The **EventBus autoload is the spine of the whole architecture**, not just achievements: typed signals (`run_ended`, `boss_killed`, `tech_researched`, `resource_changed`, `building_built`, `dialogue_seen`, `codex_shard_added`, `death`, …). Achievements, dialogue-gating counters, stats, and future strategy systems are all *subscribers*. Systems never call each other for bookkeeping — they emit.

```jsonc
// data/achievements/<id>.json
{ "id": "first-clear", "name": "…", "icon": "…", "hidden": false,
  "trigger": {"event": "run_ended", "where": {"victory": true}, "count": 1} }   // count>1 = progress achievement
```

One generic evaluator reads these; new achievements are data entries. Unlocks live in `profile.json` (§1).

## 6. Town as data object

```jsonc
// in save: instantiated once in v1, N times in Act II
{ "id": "home", "name": "…", "age": 1,
  "buildings": [{"id": "sophias-study", "level": 1}],
  "map_pos": null,                   // null until the strategy layer's overworld exists
  "well_fed": false }                // last day-tick Food-upkeep status (food-upkeep.md, 2026-07-05)

// data/buildings/<id>.json
{ "id": "quarry", "name": "Quarry", "category": "production",   // production|research|infrastructure|shop
  "age": 1, "unlocked_by": {"type": "tech", "id": "med-masonry-arch"},
  "levels": [                        // exactly 3 per the bible
    {"cost": {"gold": 50, "timber": 20}, "effects": [{"kind": "produce", "resource": "stone", "per_day": 2}], "visual": "quarry_l1"},
    {…}, {…}
  ] }
```

`effects[].kind` is a small typed set (`produce | knowledge | multiplier | capability | upkeep`) — `upkeep` added 2026-07-03 (consumes a resource per tick, grants a status other effects read — Food/Well-Fed in v1, army/city provisioning in Act II; `food-upkeep.md`); strategy-era kinds (`defense`, `summon-capacity`) extend the set later. Production resolves on the **end-of-run tick** (1 day = 1 run, per locked decision): one `TownTick` pass that reads buildings → writes ledger → emits events — order: produce → upkeep/status → status-modified totals.

## 7. Dialogue (contract with `act1-story-beats.md`)

```jsonc
// data/dialogue/<id>.json
{ "id": "c4-first-dream", "source": "spine",      // spine|arc|contextual|bark
  "speakers": ["tycho", "sophia"],
  "priority": 100, "once": true, "cooldown_runs": 0,
  "conditions": [ {"counter": "codex_shards", "gte": 2} ],   // vocabulary per act1-story-beats.md — flags, counters, tech, economy, has, talked_to
  "force_play": true,                              // spine cutscene-beats interrupt; max 1 per town visit
  "sets_flag": "c4",
  "scene": {"kind": "cutscene", "stills": ["…"], "lines": [{"who": "sophia", "text": "…"}]}   // or {"kind": "talk", lines:[…]} — supports 3+ speakers
}
```

Eligibility evaluation reads ONLY `story.flags/counters` + ledger + tech state — all of which are EventBus-maintained. The selector is a pure function `(save_state, character) -> snippet` → unit-testable without the engine running.

## 8. Summons (Act II seed — schema reserved, NOT implemented)

One abstraction, two contexts (dungeon auto-clearer / army unit): `{ id, tier, source_etching, stats {…}, contexts: ["dungeon","army"] }`. v1 ships zero summons and zero code — this entry exists so nobody designs etchings data in a shape that can't express them later.

## 9. Floor strata + hazards (added 2026-07-03 — design source: `dungeon-strata.md`)

"Floor as data", sibling of §3's "age as data": each floor of the one dungeon is a **stratum profile** — environment (palette/fog/light on the shared geometry kit), a signature hazard, a small prop list. Hazards are their own data domain (scripted: timer + volume + telegraph; dual-use — `hurts_enemies` defaults true).

**Implementation status (strata built 2026-07-10):** `data/floors/<n>.json` now carries the DOOR fields (`door_weights` + `peril_chance` — `run-structure.md`, pure `DoorCore`) **plus the STRATA fields** — `name`, `environment` (colours as `#hex` + energies + fog), `props`, `hazards` (all additive; the door fields are byte-unchanged). `data/hazards/<id>.json` is a new DataLoader domain (`HAZARDS_SPEC`). Pure `StrataCore` (`src/combat/strata_core.gd`) owns `environment_of` (defaults-merge), `hazard_plan` (seeded, combat-rooms-only, density-interpolated, signature-first), and `placement_points`/`prop_plan`; `combat_room.gd` applies the env per-instance (the Environment + Ground/Wall/Obstacle sub-resources are `resource_local_to_scene`) + spawns props (`StrataProps`) + hazards (`Hazard`, group `hazards`, one class dispatched on `kind`). **`music_layer` is NOT added** (per-stratum tracks are deferred). The block below is the shipped shape; `environment` holds any subset of `{background_color, ambient_color, ambient_energy, light_color, light_energy, ground_color, wall_color, obstacle_color, fog_enabled, fog_color, fog_density}` (colours `#hex` strings), and `hazards.density` interpolates an expected count across the floor's rooms (fractional → seeded probability).

```jsonc
// data/floors/<n>.json
{ "id": 3, "name": "The Resonant Stratum",
  "environment": { "palette": "resonant", "fog_color": "#1a2438", "fog_density": 0.04,
                   "light_temp": 0.35, "emission": "crystal_teal" },
  "props": ["crystal-seam", "crystal-cluster"],
  "hazards": { "signature": "burst-crystal", "pool": ["vent-plate", "denial-mist"],
               "density": { "early_rooms": 0.2, "late_rooms": 0.5 } },
  "door_weights": { "gold": 3, "ore": 2, "dust": 1, "echo": 3, "reprieve": 2 },  // BUILT 2026-07-05 — run-structure.md (door choice; pity: ≥2 echo + ≥1 reprieve per floor)
  "peril_chance": 0.25 }                                                         // BUILT 2026-07-05 — elite-modifier doors (hp×1.5/dmg×1.25 at spawn) with doubled rewards
  // "music_layer": "dungeon_3"  — DEFERRED (per-stratum music tracks are a later chunk; NOT in the 2026-07-10 strata build)

// data/hazards/<id>.json  — BUILT 2026-07-10 (design/dungeon-strata.md). kind-specific optional
// fields: beam {length, rotate_deg_s} · node {range, projectile_speed} · drift {push_strength}
// · mist {drift_speed, tick_s}. Read by src/combat/hazard.gd (one class dispatched on `kind`).

// data/hazards/<id>.json
{ "id": "burst-crystal", "name": "Burst Crystal",
  "kind": "burst",                     // vent | node | burst | beam | drift | mist
  "telegraph_s": 0.6, "cycle_s": 0.0,  // cycle 0 = triggered, not periodic
  "damage": 20, "radius": 2.5, "hurts_enemies": true }
```

Enemy-telegraph colors are fixed across strata; palettes are chosen around them (per-floor human legibility pass — see `dungeon-strata.md`). All numbers are `# FEEL:`/tuning placeholders.

## 10. Etching abilities (added 2026-07-03 — design source: `etchings.md`)

**Implementation status (first slice built 2026-07-07):** the `data/etchings/` domain (spec `ETCHINGS_SPEC` in `data_loader.gd`, all 9 authored), pure `src/learning/etchings_core.gd` (unlock/level/cost/equip/`ensure_baseline`/`effective_behavior`), and the `EtchingsPanel` (`src/town/etchings_panel.gd`, opened from Thomas's meditation spot; town.gd `open_etchings_panel()`, B2-gated via UnlocksCore) + the player's RMB/Q/R casting framework are **built and tested**. Five abilities are castable (Push/Bolt/Snare/Shockwave/Surge); four are dormant (data ships, unlearnable in the panel) — implementation status is code (`EtchingsCore.IMPLEMENTED`), not data. The def gained an optional **`behavior`** dict (per-ability cast numbers = the dial board; `design/feel-tuning.md`); level entries carry `<field>_mult` scalars folded in by `effective_behavior`. Save's `combat.etchings` was unchanged (no migration). Deferred: L3 riders, weapon synergies, etching-mod Echoes, attunements.

The 9 active abilities (3 per slot; dash is fixed and not data). Save already carries `combat.etchings` (§1) — this is the content domain it references. `principle` is the rational-fiction tag (dialogue hooks read it); `summon_seed` marks Sentinel as the ability §8's summons hang off (`source_etching`).

```jsonc
// data/etchings/<id>.json
{ "id": "push", "name": "Push", "slot": "rmb",         // rmb | q | r
  "principle": "impulse",
  "cooldown_s": 5.0,
  "granted_by": "b2",                                    // beat id, or null = bought at Thomas's Hut
  "cost_unlock_dust": 0, "cost_levels_dust": [3, 5],       // [L2, L3]
  "behavior": { "damage_scale": 0.6, "cone_deg": 100.0,   // cast numbers (dial board, feel-tuning.md)
                "range": 5.0, "knockback": 16.0 },
  "levels": [ { }, { "cone_deg_mult": 1.3 }, { "rider": "bowling" } ],  // L1{} L2 <field>_mult L3 rider (unimpl.)
  "weapon_synergy": { "weapon": "sword", "effect": "combo_continues_bonus_finisher" },  // data only in v1
  "summon_seed": false }
```

---

## The decoupling rule (how the pillars stay separable)

- Systems communicate through **EventBus + the ledger + save sections** — never direct references across pillar boundaries.
- The roguelite reads/writes `combat`, `codex`, counters; the town reads/writes `town`, `ledger`, `tech`. Act II gets its own save section (`pillars.strategy`) and *subscribes to the same events*.
- Test for every new system: "could I delete the dungeon scenes and still compile the town?" If no, it's coupled wrong.
