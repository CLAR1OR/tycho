# Godot Project Conventions

> How the Godot 4.6 project is structured and how agents work in it. Written 2026-06-12, before the project exists — Phase 0 task 1 creates the project to this spec. Keep this doc in sync with reality once code exists; a new agent should be productive from this page alone.

## Language & engine
- **Godot 4.6, GDScript only** (no C#) — best agent fluency, no build toolchain. **Static typing mandatory** (`var x: int`, typed funcs); agents drift less with types, and the editor catches their mistakes.
- It is technically a **3D project with a fixed camera** (the 2.5D decision). The camera rig is one reusable scene (`camera_rig.tscn`) — nothing else may assume camera angles.

## Directory layout

```
res://
  src/            # GDScript by domain, mirrors the architecture
    autoload/     # EventBus, SaveManager, Ledger, TechState, StoryState, RunState
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
- **gdUnit4** (actively maintained for 4.x). Required coverage: everything under rule 3 (pure logic) + save/migration round-trips + data validation. **Not** tested: combat feel, visuals, scene wiring — that's human playtesting.
- Run headless: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd` — agents run tests before every commit that touches `src/`.

## Git & workflow
- Work on `main` (solo project); branch only for risky experiments. Commit per meaningful change (working agreement), message prefixes: `feat: / fix: / content: / design: / chore:`.
- `.godot/` is already gitignored. **Commit `.import` files and `project.godot`** — asset imports must reproduce.
- Asset binaries (models/audio) are committed for now; revisit Git LFS if the repo passes ~1 GB.

## Agent etiquette (project-specific)
- Read `CLAUDE.md` → design bible → the relevant `design/` doc **before** touching a system; if code and design doc disagree, *stop and flag it* — don't pick a side silently.
- Feel-parameters (timings, knockback, camera shake, animation curves) get marked `# FEEL: human-tuned, do not optimize` — agents must not "clean up" magic numbers carrying tuned feel.
- Placeholder assets are fine everywhere; never block a system on final art.
