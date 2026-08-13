# Godot Project Conventions

> How the Godot 4.7 project is structured and how agents work in it. Written 2026-06-12; **the project now exists (created 2026-06-19 to this spec, upgraded to Godot 4.7 on 2026-06-20)** — `project.godot` at the repo root, directory tree below in place. Keep this doc in sync with reality; a new agent should be productive from this page alone.
>
> **Run it:** open in the Godot editor and press F5, or headless-validate with `/home/clarior/Godot_v4.7-stable_linux.x86_64 --headless --editor --quit` (imports + compiles) / `--headless` (runs the main scene). **The main scene is the vertical-slice game loop** (`scenes/core/game.tscn`: slot-select boot screen → town → portal → run of rooms → town; a slot with a mid-run checkpoint resumes at floor start). The Phase 0 feel sandbox lives on at `scenes/combat/feel_room.tscn` (F6 / run-current-scene). **Milestone status (2026-07-05):** `EventBus`, `Ledger`, `SaveManager`, `StoryState`, `TechState`, `Achievements` (2026-07-11, thin over pure `achievement_core.gd` — evaluates `data/achievements/` defs against the EventBus signals, writes the profile), `RunState`, `Sfx`, and `Music` autoloads exist and are registered, plus the pure core (`ledger_core.gd`, `save_data.gd`, `validate.gd`, `data_loader.gd`, `run_flow.gd`, `town_core.gd`, `echo_core.gd`, `tech_core.gd`, `weapon_core.gd`, `arch_puzzle_core.gd`, `dialogue_core.gd`, `story_core.gd`, `sfx_core.gd`, `music_core.gd`) and `data/` content (resources, ages, buildings, echoes, tech, weapons, etchings, dialogue, floors [door + strata env/props/hazards fields], hazards, bosses, achievements, audio/sfx-map, audio/music-map). `StoryState` (thin, over pure `story_core.gd`) owns every EventBus-driven story-section mutation — run/death/boss counters, the has-`<resource>` pickup flags, the full-clear codex shard — satisfying the "signals in, no cross-domain calls" rule (§2); it registers right after `SaveManager` so it subscribes before the main scene and its counters land on disk before game.gd's deferred town-swap save. `TechState` (thin, over the existing pure `tech_core.gd`, no new core) now owns every mutation of the save's tech section — node selection (`set_active`), the invest transaction (`invest`, incl. its Ledger spends), completion (`complete` = `TechCore.complete` + the `tech_researched` emit, the single home of that pair), and Sophia's run_ended auto-solve (moved verbatim out of game.gd); it registers right after `StoryState`, same ordering guarantee. TechCore is return-a-new-dict, so call sites re-fetch `state["tech"]` after any TechState call. Audio buses live in `default_bus_layout.tres` (Master→Music/SFX/UI); profile `settings` audio volumes (linear 0..1) are applied to the buses in `Music._ready`.

## Language & engine
- **Godot 4.7, GDScript only** (no C#) — best agent fluency, no build toolchain. **Static typing mandatory** (`var x: int`, typed funcs); agents drift less with types, and the editor catches their mistakes.
- It is technically a **3D project with a fixed camera** (the 2.5D decision). The camera rig is one reusable scene (`camera_rig.tscn`) — nothing else may assume camera angles.

## Directory layout

```
res://
  src/            # GDScript by domain, mirrors the architecture
    autoload/     # EventBus, SaveManager, StoryState, TechState, Achievements, Ledger, RunState, Sfx, Music
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

## Tools
- **Economy simulator:** `/home/clarior/Godot_v4.7-stable_linux.x86_64 --headless --path . res://tools/economy_sim.tscn` — simulates 40 runs × 3 seeds through the REAL pure cores + `data/` numbers and writes its report to `design/economy-sim.md` (analysis tooling, not game code; assumptions + policies documented atop `tools/economy_sim.gd`).
- **Prop renderer:** `godot --path . tools/render_prop.tscn` — renders a generated prop offscreen **at the game's exact camera angle** under the town's own light/environment/toon sweep, and writes `user://prop_render_{game,close}.png`. This is the missing half of the style-bible judging protocol (open the anchor and the render side by side). **NOT `--headless`** — it needs a real GPU context (Forward+ for the water shader); it shrinks and corners its window to stay out of the way. Point it at a different prop by editing the one `TownFountain.new()` line.
- **Look compare (the look gate):** `godot --path . tools/render_compare.tscn` — instances the REAL `scenes/town/town.tscn`, renders it at the game camera, and composites it **side by side with the style anchor** (`assets_src/anchors/art-style.png`, left) into `user://look_compare.png`. This is the style-bible judging protocol with the manual image-editing step removed; it is also the only validation the shader gets, since **GLSL cannot be compiled headless** (a shader error shows as a magenta/unshaded frame). **NOT `--headless`** — Forward+ context required for volumetric fog + the water shader. Two notes: it seeds `SaveManager.state` from `SaveData.default_slot()` **in memory only** (never `create_slot`, which would write to the human's real save files); and `assets_src/` is `.gdignore`'d, so the anchor is read off disk with `Image.load()` rather than `load()` — it has no `.import`.
- **Overlay layout probe:** `godot --path . tools/render_hud.tscn` — renders the game's **overlay** surfaces (the Ember ones that float on live gameplay rather than replacing it) into a **1280×720 SubViewport** (the project's base viewport, never whatever size the window manager hands the probe) over a dark field with bright test patches, and writes `user://hud_render_{combat,low-hp-cleared,town,echo-offer}.png`. It fakes the state each would otherwise need a real run to reach — mid-wave with peril, low-HP/cleared, a fed town mid-toast, a three-mark offer with one hovered — and stands up a real `Player` so the ability dial shows real glyphs and cooldown arcs. **They share a probe because they share a problem:** each draws on a live world with no panel behind its text, so the check is identical (legible over a bright patch? anything colliding or off-screen?). **This is how the Tier A migration found the town screen's three-way top-band collision** — nothing else would have. **NOT `--headless`** (it reads the viewport texture back). It seeds `SaveManager.state` in memory only (never `create_slot`, which would write to the human's real saves — the rule `render_compare.gd` set). Add a state with an `await _shot(...)` block.
- **Menu layout probe:** `godot --path . tools/render_menu.tscn` — writes `user://menu_render_{catalogue,column,pause}.png`. The first two render a **specimen** screen (fake weapon-menu content matching `assets_src/anchors/weapon-menu-reference.png`) in both Ember menu layouts, exercising every menu primitive at once so the shared vocabulary can be judged **before** more screens migrate onto it (`design/ui-hud.md` § "Ember menu vocabulary"). The third renders the REAL `PauseMenu`, the only Control-*tree* screen in either probe — a `Theme` is exactly the kind of thing that looks right in source and wrong on screen, since every colour, font and stylebox arrives indirectly. Touches no game state, no `data/`, no save. **NOT `--headless`** (it reads the viewport texture back).
- **Fountain geometry probe:** `godot --headless --path . -s tools/fountain_probe.gd` — asserts `TownFountain`'s generated triangles face the right way (`generate_normals()` derives normals from the same winding convention the rasterizer culls by, so "do the normals point where the helper promised?" answers "is the winding right?") plus bounds/containment/collision sanity. Exit 0/1.

**Gotcha these two tools cost an hour to learn — do not re-learn it:**
- A `.tscn` `Transform3D`'s 9 basis floats are stored **row-major**, but `Basis(a, b, c)` takes **column** vectors. Transcribing a scene's rows straight into `Basis()` silently gives a different orientation (it flipped the town's key light upside down).
- **Never filter stderr when a headless run misbehaves.** A GDScript parse error makes `godot --headless -s` sit in a signal handler at 0% CPU forever — it looks exactly like an infinite loop, and the one line explaining it is on stderr.
- **The editor pass does NOT catch every parse error — the smoke is the real compiler.** Measured 2026-08-13: four `const`s in `echo_offer_panel.gd` shadowed members its new parent class declares (`FS_TITLE`/`FS_SUB`/`FS_MONO`/`FS_KEY` on `EmberHud`). `--headless --editor --quit` exited **0 with zero output**; the smoke then failed with four `Parse Error: The member "X" already exists in parent class` and a cascade of `Failed to compile depended scripts`. **So: after changing a base class or adding consts to one, run the smoke — a green editor pass proves nothing.** The cheap pre-check is a name-collision diff between the subclass's consts and the parent's.
- **A killed smoke leaves throwaway-save residue that poisons the NEXT run.** The smoke cleans up slot 99 and `profile.json` on the way out; kill it mid-run (a timeout) and both survive, so the next boot resumes the leftover mid-run checkpoint and fails at `fresh slot enters town (got combat_room.tscn)` — which looks like a real regression and is not. Delete `<user>/saves/save_slot_99.json` and `<user>/saves/profile.json` and re-run. (`profile.json` is GLOBAL — it is the human's real profile if they have one, so only remove it when the smoke created it.)
- **`pkill -f <pattern>` will kill your own shell.** The pattern matches the agent's own `bash -c '... <pattern> ...'` command line, not just the target process. Kill by PID from `ps`, or match the binary (`pgrep -f Godot_v4.7`) rather than the scene name.
- **A headless SCENE run hangs silently on never-imported new files.** After adding a new resource (a `.gdshader`, a `.tscn`) that something `preload`s, `godot --headless res://tests/smoke/...` can hang with **zero** output — it is not a parse error and there is nothing on stderr either. Run the editor pass first (`godot --headless --editor --quit --path .`, which is a required validation anyway) and the smoke runs normally. Cost an hour on 2026-08-13.
- **Pre-existing headless noise, not a regression:** the smoke prints ~22 `Parameter "material" is null` errors from the **dummy** renderer's `material_get_instance_shader_parameters` while freeing meshes. Measured on an unchanged tree 2026-08-13. Ignore it, like the ±1 door-sigil ok-count.

## Git & workflow
- Work on `main` (solo project); branch only for risky experiments. Commit per meaningful change (working agreement), message prefixes: `feat: / fix: / content: / design: / chore:`.
- `.godot/` is already gitignored. **Commit `.import` files and `project.godot`** — asset imports must reproduce.
- Asset binaries (models/audio) are committed for now; revisit Git LFS if the repo passes ~1 GB.

## Agent etiquette (project-specific)
- Read `CLAUDE.md` → design bible → the relevant `design/` doc **before** touching a system; if code and design doc disagree, *stop and flag it* — don't pick a side silently.
- Feel-parameters (timings, knockback, camera shake, animation curves) get marked `# FEEL: human-tuned, do not optimize` — agents must not "clean up" magic numbers carrying tuned feel.
- Placeholder assets are fine everywhere; never block a system on final art.
