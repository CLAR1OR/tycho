# Godot Project Conventions

> How the Godot 4.7 project is structured and how agents work in it. Written 2026-06-12; **the project now exists (created 2026-06-19 to this spec, upgraded to Godot 4.7 on 2026-06-20)** — `project.godot` at the repo root, directory tree below in place. Keep this doc in sync with reality; a new agent should be productive from this page alone.
>
> **Run it:** open in the Godot editor and press F5, or headless-validate with `/home/clarior/Godot_v4.7-stable_linux.x86_64 --headless --editor --quit` (imports + compiles) / `--headless` (runs the main scene). **The main scene is the vertical-slice game loop** (`scenes/core/game.tscn`: slot-select boot screen → town → portal → run of rooms → town; a slot with a mid-run checkpoint resumes at floor start). The Phase 0 feel sandbox lives on at `scenes/combat/feel_room.tscn` (F6 / run-current-scene). **Milestone status (2026-07-04):** `EventBus`, `Ledger`, `SaveManager`, `StoryState`, `RunState`, `Sfx`, and `Music` autoloads exist and are registered, plus the pure core (`ledger_core.gd`, `save_data.gd`, `validate.gd`, `data_loader.gd`, `run_flow.gd`, `town_core.gd`, `echo_core.gd`, `tech_core.gd`, `weapon_core.gd`, `arch_puzzle_core.gd`, `dialogue_core.gd`, `story_core.gd`, `sfx_core.gd`, `music_core.gd`) and `data/` content (resources, ages, buildings, echoes, tech, weapons, dialogue, audio/sfx-map, audio/music-map). `StoryState` (thin, over pure `story_core.gd`) owns every EventBus-driven story-section mutation — run/death/boss counters, the has-`<resource>` pickup flags, the full-clear codex shard — satisfying the "signals in, no cross-domain calls" rule (§2); it registers right after `SaveManager` so it subscribes before the main scene and its counters land on disk before game.gd's deferred town-swap save. `TechState` is still target-only (tech state lives in the save dict, mutated via pure `tech_core.gd`). Audio buses live in `default_bus_layout.tres` (Master→Music/SFX/UI); profile `settings` audio volumes (linear 0..1) are applied to the buses in `Music._ready`.

## Language & engine
- **Godot 4.7, GDScript only** (no C#) — best agent fluency, no build toolchain. **Static typing mandatory** (`var x: int`, typed funcs); agents drift less with types, and the editor catches their mistakes.
- It is technically a **3D project with a fixed camera** (the 2.5D decision). The camera rig is one reusable scene (`camera_rig.tscn`) — nothing else may assume camera angles.

## Directory layout

```
res://
  src/            # GDScript by domain, mirrors the architecture
    autoload/     # EventBus, SaveManager, StoryState, Ledger, RunState, Sfx, Music (+ TechState later)
    combat/       # player, enemies, weapons, echoes (the roguelite pillar)
    town/         # buildings, shops, town tick
    learning/     # tech tree, puzzles
    dialogue/     # eligibility selector, scene player
    core/         # loaders, schema validation, migrations, utils
  scenes/         # .tscn by feature, same domain split as src/
  data/           # ALL game content as JSON (resources/, tech/, buildings/, dialogue/, achievements/, ages/, echoes/, enemies/)
  assets/         # models/, anims/, images/, audio/  (Tripo/Quaternius imports land here)
  tests/          # gdUnit4 suites, mirrors src/
  design -> ../design   # the design docs stay outside res:// (no symlink needed; agents read them from the repo root)
```

## Content = JSON in `data/`, code = generic
- Schemas per `architecture-schemas.md`. **Adding content must never require code** — if it does, the schema or the dispatch is wrong; fix that instead.
- One file per entity, filename = `id`, ids kebab-case matching the design docs.
- `src/core/validate.gd` checks every `data/` file against its schema on load **in debug builds** — agents get loud, early errors instead of silent nulls.

## Architecture rules (enforced by review, summarized from `architecture-schemas.md`)
1. **EventBus is the only cross-domain channel.** Signals down/calls up *within* a scene tree; events *across* domains. No `get_node("/root/...")` reaches into another pillar.
2. **Autoloads are thin state-holders**; logic lives in plain classes the autoload delegates to — that's what makes it unit-testable.
3. **Pure-function core:** dialogue eligibility, town tick, tech costs, echo offers — all pure `(state) -> result` functions. No engine types in their signatures where avoidable.
4. The decoupling test: *"could I delete the dungeon scenes and still run the town?"*

## Naming
- Files/dirs/node-paths: `snake_case`. Classes (`class_name`): `PascalCase`. Constants: `UPPER_SNAKE`.
- Signals: past tense, payload-typed (`signal boss_killed(boss_id: String, floor: int)`).
- Scenes: `noun.tscn` (`forge_shop.tscn`); scripts attached to a scene share its name.

## Testing
- **gdUnit4** (actively maintained for 4.x) is the framework — installed + enabled 2026-07-03 (`addons/gdUnit4`, v6.2.0-rc2, human via AssetLib). Required coverage: everything under rule 3 (pure logic) + save/migration round-trips + data validation. **Not** tested: combat feel, visuals, scene wiring — that's human playtesting.
- Suites live in `tests/core/*_test.gd` and extend `tests/test_suite.gd` — a thin base over `GdUnitTestSuite` that keeps the project's compact `check(cond, msg)` / `check_eq(got, want, msg)` helpers (they report through real gdUnit asserts; native `assert_that(...)` is equally fine in new tests). **Run headless:** `GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh -a res://tests/core --ignoreHeadlessMode` (exit 0 green / non-zero on failure; writes `reports/`, gitignored). In the editor the gdUnit panel runs suites with clickable results. On a fresh clone run `--headless --editor --quit` once first (class-name cache). *(A zero-dependency interim runner, `tests/test_runner.gd`, covered 2026-07-02→03 while the plugin awaited a human install; retired.)*
- **End-to-end smoke (agent tool):** `godot --headless res://tests/smoke/run_loop_smoke.tscn` boots the real game and drives a full run (slot-select → 2-floor clear incl. a mid-run quit + checkpoint resume → boss → town return → build/research/forge → death run → day tick), exit 0/1. It must run as a SCENE, not `-s` — `-s` scripts never get autoloads. Uses a throwaway save slot (99); the boot itself loads no slot.
- Agents run tests before every commit that touches `src/`.

## Git & workflow
- Work on `main` (solo project); branch only for risky experiments. Commit per meaningful change (working agreement), message prefixes: `feat: / fix: / content: / design: / chore:`.
- `.godot/` is already gitignored. **Commit `.import` files and `project.godot`** — asset imports must reproduce.
- Asset binaries (models/audio) are committed for now; revisit Git LFS if the repo passes ~1 GB.

## Agent etiquette (project-specific)
- Read `CLAUDE.md` → design bible → the relevant `design/` doc **before** touching a system; if code and design doc disagree, *stop and flag it* — don't pick a side silently.
- Feel-parameters (timings, knockback, camera shake, animation curves) get marked `# FEEL: human-tuned, do not optimize` — agents must not "clean up" magic numbers carrying tuned feel.
- Placeholder assets are fine everywhere; never block a system on final art.
