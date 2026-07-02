# Architecture Schemas — the "prepare-for" drafts

> Draft data schemas for the architectural prepare-fors (CLAUDE.md → "prepare-for" requirements), plus the dialogue schema demanded by `act1-story-beats.md`. Drafted 2026-06-12 — these are contracts of *shape*, not final field lists. Implement as JSON content files + typed GDScript wrappers (see `godot-conventions.md`). Rule of thumb everywhere: **adding content is adding a data entry, never adding code.**
>
> **Implementation status (2026-07-02):** §1 save/profile (`src/core/save_data.gd` + `src/autoload/save_manager.gd`), §2 ledger (`src/core/ledger_core.gd` + `src/autoload/ledger.gd`), §5's EventBus (`src/autoload/event_bus.gd`), and the resources/ages/**buildings** data specs (`src/core/data_loader.gd` + `validate.gd`, content in `data/`) are **built and tested**. §6's town-as-data + day tick are live via pure `src/town/town_core.gd` (effect kinds `produce`/`knowledge` only so far; `multiplier`/`capability` land with their consumers); run/floor/room progression is pure `src/core/run_flow.gd` held by the `RunState` autoload. §4's tech nodes are live (`data/tech/` spec in DataLoader incl. `explanation`/`aha` text fields; pure `src/learning/tech_core.gd` + placeholder `tech_panel.gd` UI; typed building-unlocks gate town plots via `TownCore.is_unlocked`; `tech.active` added to the save's tech section; auto-solve ticks on run end). **Echoes** are live as a data domain (`data/echoes/`: `{id, name, desc, pool_weight, stackable, requires[], mods[{stat, add, mult}]}`) with a pure offer generator + stat-mod math in `src/combat/echo_core.gd` — in-run only on RunState, never saved (locked design). Tech/achievements/dialogue land with their systems.

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
    "playtime_s": 0, "age": 1, "act": 1, "runs": 0
  },
  "story":   { "flags": {"a1": true}, "counters": {"runs": 0, "deaths": 0, "boss_kills": 0, "full_clears": 0}, "seen": ["snippet-id"] },
  "tech":    { "researched": ["id"], "in_progress": {"id": 12.5}, "auto_solve_counters": {"id": 3} },
  "ledger":  { "gold": 0, "knowledge": 1.2, "resonance-ore": 0 },   // see §2
  "town":    { /* Town object, §6 */ },
  "combat":  { "weapons": {"sword": {"flat": 2, "resonance": ["echo-bite"]}}, "etchings": {"slots": {"rmb": "id", "q": "id", "r": "id"}, "unlocked": {"id": 2}}, "attunements": {"vitality": 2, "quickening": 1}, "assist_mode": {"enabled": false, "stacks": 0} },
  "codex":   { "shards": 1 },
  "pillars": { "strategy": {}, "space": {} }   // EMPTY in v1. Reserved keys so Acts II/III extend, never migrate.
}

// profile.json (shared across slots)
{ "profile_version": 1, "settings": { /* audio, controls, accessibility */ }, "achievements": {"id": {"unlocked_at": "…", "progress": 3}} }
```

- **No mid-run saves in v1**: save on town return + autosave checkpoints between floors (quit mid-run → resume at floor start). Runs are 20–25 min; floor-granularity is enough.
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
  "buildings": [{"id": "linneas-study", "level": 1}],
  "map_pos": null }                  // null until the strategy layer's overworld exists

// data/buildings/<id>.json
{ "id": "quarry", "name": "Quarry", "category": "production",   // production|research|infrastructure|shop
  "age": 1, "unlocked_by": {"type": "tech", "id": "med-masonry-arch"},
  "levels": [                        // exactly 3 per the bible
    {"cost": {"gold": 50, "timber": 20}, "effects": [{"kind": "produce", "resource": "stone", "per_day": 2}], "visual": "quarry_l1"},
    {…}, {…}
  ] }
```

`effects[].kind` is a small typed set (`produce | knowledge | multiplier | capability`) — strategy-era kinds (`defense`, `summon-capacity`) extend the set later. Production resolves on the **end-of-run tick** (1 day = 1 run, per locked decision): one `TownTick` pass that reads buildings → writes ledger → emits events.

## 7. Dialogue (contract with `act1-story-beats.md`)

```jsonc
// data/dialogue/<id>.json
{ "id": "c4-first-dream", "source": "spine",      // spine|arc|contextual|bark
  "speakers": ["tycho", "linnea"],
  "priority": 100, "once": true, "cooldown_runs": 0,
  "conditions": [ {"counter": "codex_shards", "gte": 2} ],   // vocabulary per act1-story-beats.md — flags, counters, tech, economy, has, talked_to
  "force_play": true,                              // spine cutscene-beats interrupt; max 1 per town visit
  "sets_flag": "c4",
  "scene": {"kind": "cutscene", "stills": ["…"], "lines": [{"who": "linnea", "text": "…"}]}   // or {"kind": "talk", lines:[…]} — supports 3+ speakers
}
```

Eligibility evaluation reads ONLY `story.flags/counters` + ledger + tech state — all of which are EventBus-maintained. The selector is a pure function `(save_state, character) -> snippet` → unit-testable without the engine running.

## 8. Summons (Act II seed — schema reserved, NOT implemented)

One abstraction, two contexts (dungeon auto-clearer / army unit): `{ id, tier, source_etching, stats {…}, contexts: ["dungeon","army"] }`. v1 ships zero summons and zero code — this entry exists so nobody designs etchings data in a shape that can't express them later.

---

## The decoupling rule (how the pillars stay separable)

- Systems communicate through **EventBus + the ledger + save sections** — never direct references across pillar boundaries.
- The roguelite reads/writes `combat`, `codex`, counters; the town reads/writes `town`, `ledger`, `tech`. Act II gets its own save section (`pillars.strategy`) and *subscribes to the same events*.
- Test for every new system: "could I delete the dungeon scenes and still compile the town?" If no, it's coupled wrong.
