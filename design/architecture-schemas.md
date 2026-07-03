# Architecture Schemas — the "prepare-for" drafts

> Draft data schemas for the architectural prepare-fors (CLAUDE.md → "prepare-for" requirements), plus the dialogue schema demanded by `act1-story-beats.md`. Drafted 2026-06-12 — these are contracts of *shape*, not final field lists. Implement as JSON content files + typed GDScript wrappers (see `godot-conventions.md`). Rule of thumb everywhere: **adding content is adding a data entry, never adding code.**
>
> **Implementation status (2026-07-02):** §1 save/profile (`src/core/save_data.gd` + `src/autoload/save_manager.gd`), §2 ledger (`src/core/ledger_core.gd` + `src/autoload/ledger.gd`), §5's EventBus (`src/autoload/event_bus.gd`), and the resources/ages/**buildings** data specs (`src/core/data_loader.gd` + `validate.gd`, content in `data/`) are **built and tested**. §1's save points are fully in: save on town return, **per-floor autosave checkpoints** (the slot's `checkpoint` section — see §1 — written as each floor's first room loads, cleared on run end; quit mid-run → resume at floor start), and the **slot-select boot screen** (`src/core/slot_select.gd`, reading `SaveManager.list_slots()` meta incl. `checkpoint_floor` without loading a slot). §6's town-as-data + day tick are live via pure `src/town/town_core.gd` (effect kinds `produce`/`knowledge` only so far; `multiplier`/`capability` land with their consumers); run/floor/room progression is pure `src/core/run_flow.gd` held by the `RunState` autoload. §4's tech nodes are live (`data/tech/` spec in DataLoader incl. `explanation`/`aha` text fields; pure `src/learning/tech_core.gd` + placeholder `tech_panel.gd` UI; typed building-unlocks gate town plots via `TownCore.is_unlocked`; `tech.active` added to the save's tech section; auto-solve ticks on run end). §4's `puzzle` field is dispatched on `kind`: `{kind: "quiz", data}` uses the panel's built-in quiz screen, `{kind: "interactive", scene, data}` embeds a bespoke Control from `TechPanel.PUZZLES` (contract: `setup(data)` + a `solved` signal) — the first is `puzzle_arch` (`src/learning/puzzle_arch.gd` over pure `arch_puzzle_core.gd`), live on `med-masonry-arch`. §7.2 weapons are live as a data domain (`data/weapons/`: `{id, name, kind: melee|ranged, desc, mods[], projectile, flat: {damage_mult_per_level, costs[]}}` — mods are RELATIVE to the feel-tuned player exports, Sword = empty-mods baseline; pure `src/combat/weapon_core.gd`, shop UI `src/town/forge_panel.gd`; save carries `combat.current_weapon` + `combat.weapons.{id}.flat`, the `resonance` list is reserved). **Echoes** are live as a data domain (`data/echoes/`: `{id, name, desc, pool_weight, stackable, requires[], mods[{stat, add, mult}]}`) with a pure offer generator + stat-mod math in `src/combat/echo_core.gd` — in-run only on RunState, never saved (locked design). §7's dialogue is live in its first slice (2026-07-03): `data/dialogue/` spec in DataLoader (this section's shape, conditions per the act1-story-beats.md vocabulary — all of it implemented), pure selection/eligibility/mark_shown in `src/dialogue/dialogue_core.gd`, playback in `dialogue_panel.gd`, NPC talk spots + force-play (max 1/visit) in town.gd; `story` gained `talked_to`/`dialogue_last`/`arc_last`. **Audio** is live in its SFX slice (2026-07-04, `design/audio.md`): `data/audio/sfx-map.json` (id → {file, volume_db, pitch_jitter, bus} — a deliberate single-file exception to one-file-per-entity, loaded via `DataLoader.load_sfx_map()` with the same loud validation) feeds pure `src/core/sfx_core.gd` under the thin `Sfx` autoload; pickup/boss-kill sounds subscribe to EventBus like any other cross-domain consumer; buses in `default_bus_layout.tres`. Achievements land with their system.

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
  "story":   { "flags": {"a1": true}, "counters": {"runs": 0, "deaths": 0, "boss_kills": 0, "full_clears": 0}, "seen": ["snippet-id"] },
  "tech":    { "researched": ["id"], "in_progress": {"id": 12.5}, "auto_solve_counters": {"id": 3} },
  "ledger":  { "gold": 0, "knowledge": 1.2, "resonance-ore": 0 },   // see §2
  "town":    { /* Town object, §6 */ },
  "combat":  { "weapons": {"sword": {"flat": 2, "resonance": ["echo-bite"]}}, "etchings": {"slots": {"rmb": "id", "q": "id", "r": "id"}, "unlocked": {"id": 2}}, "attunements": {"vitality": 2, "quickening": 1}, "assist_mode": {"enabled": false, "stacks": 0} },
  "codex":   { "shards": 1 },
  "checkpoint": null,           // per-floor autosave: null, or {run, run_number, echoes, player_health}
                                // snapshotted at floor start, cleared on run end (echoes never outlive a run)
  "pillars": { "strategy": {}, "space": {} }   // EMPTY in v1. Reserved keys so Acts II/III extend, never migrate.
}

// profile.json (shared across slots)
{ "profile_version": 1, "settings": { /* audio, controls, accessibility */ }, "achievements": {"id": {"unlocked_at": "…", "progress": 3}} }
```

- **No mid-run saves in v1**: save on town return + autosave checkpoints between floors (quit mid-run → resume at floor start). Runs are 20–25 min; floor-granularity is enough. *(Implemented 2026-07-02 — `game.gd` writes the checkpoint as a floor's first room loads; `RunState.to_checkpoint()/resume_from()`.)*
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
  "map_pos": null }                  // null until the strategy layer's overworld exists

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

```jsonc
// data/floors/<n>.json
{ "id": 3, "name": "The Resonant Stratum",
  "environment": { "palette": "resonant", "fog_color": "#1a2438", "fog_density": 0.04,
                   "light_temp": 0.35, "emission": "crystal_teal" },
  "props": ["crystal-seam", "crystal-cluster"],
  "hazards": { "signature": "burst-crystal", "pool": ["vent-plate", "denial-mist"],
               "density": { "early_rooms": 0.2, "late_rooms": 0.5 } },
  "door_weights": { "gold": 3, "ore": 2, "dust": 1, "echo": 3, "reprieve": 2 },  // added 2026-07-03 — run-structure.md (door choice; pity: ≥2 echo + ≥1 reprieve per floor)
  "peril_chance": 0.25,                                                          // elite-modifier doors with boosted rewards
  "music_layer": "dungeon_3" }

// data/hazards/<id>.json
{ "id": "burst-crystal", "name": "Burst Crystal",
  "kind": "burst",                     // vent | node | burst | beam | drift | mist
  "telegraph_s": 0.6, "cycle_s": 0.0,  // cycle 0 = triggered, not periodic
  "damage": 20, "radius": 2.5, "hurts_enemies": true }
```

Enemy-telegraph colors are fixed across strata; palettes are chosen around them (per-floor human legibility pass — see `dungeon-strata.md`). All numbers are `# FEEL:`/tuning placeholders.

## 10. Etching abilities (added 2026-07-03 — design source: `etchings.md`)

The 9 active abilities (3 per slot; dash is fixed and not data). Save already carries `combat.etchings` (§1) — this is the content domain it references. `principle` is the rational-fiction tag (dialogue hooks read it); `summon_seed` marks Sentinel as the ability §8's summons hang off (`source_etching`).

```jsonc
// data/etchings/<id>.json
{ "id": "push", "name": "Push", "slot": "rmb",         // rmb | q | r
  "principle": "impulse",
  "cooldown_s": 5.0,
  "granted_by": "b2",                                    // beat id, or null = bought at Thomas's Hut
  "cost_unlock_dust": 0, "cost_levels_dust": [3, 5],
  "levels": [ { }, { "damage_mult": 1.3 }, { "rider": "bowling" } ],
  "weapon_synergy": { "weapon": "sword", "effect": "combo_continues_bonus_finisher" },
  "summon_seed": false }
```

---

## The decoupling rule (how the pillars stay separable)

- Systems communicate through **EventBus + the ledger + save sections** — never direct references across pillar boundaries.
- The roguelite reads/writes `combat`, `codex`, counters; the town reads/writes `town`, `ledger`, `tech`. Act II gets its own save section (`pillars.strategy`) and *subscribes to the same events*.
- Test for every new system: "could I delete the dungeon scenes and still compile the town?" If no, it's coupled wrong.
