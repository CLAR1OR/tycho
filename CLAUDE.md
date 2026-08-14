# CLAUDE.md — Tycho Roguelite

Working doc for AI agents (and humans) building **Tycho Roguelite**. **Read this first**, then the design bible: **`Tycho Roguelite.md`** (its top section, "Design Decisions — Locked", is the source of truth for what the game is).

---

## ⬇ Inbox — playtest feedback & quick to-dos
> The human drops notes here; agents triage them into the roadmap below. Newest on top. (Empty for now.)

-

---

## What this is (30-second version)
A 2.5D top-down **real-time action roguelite** (Hades-style *feel*) wrapped around a **rational-fiction story** and a **real-science tech tree**. Medieval setting; "magic" is secretly nanobots. The roguelite is the engine; **the story + learning is the soul.** Full vision + locked decisions: `Tycho Roguelite.md`.

## Current state (2026-07-10)

> A snapshot, deliberately short. The full dated chunk-by-chunk log lives in **`design/history.md`**; the deep spec for any system lives in its `design/` doc. When an entry here is superseded, its detail moves to history.

**Phase 0 gates:** combat-feel **✅ PASSED 2026-07-10** (human verdict, 20th-clear bar, judged with sound — the project go/no-go is green). Content gate: the arch puzzle is playable in its intended form at Sophia's desk — **verdict pending**. Asset-pipeline gate: **never run** (no Tripo model produced yet; `scenes/core/asset_pipeline_gate.tscn` + `assets/README.md` are ready).

**Systems — essentially all v1 plumbing is BUILT, tested, and speaks the Slate UI language:**
- **Run loop:** doors + peril + healing economy + 2–3-wave rooms + the dissolve ending (`design/run-structure.md`); per-floor checkpoints, forfeit/save-quit with the Hades quit-gate + statistics invariant (PRD §7.13).
- **Strata + hazards (2026-07-10):** all five floors differ by env profile + props + a signature hazard; all six hazards live, dual-use, data-driven; **room-layout pool BUILT 2026-07-12** — 30 combat + 3 reprieve + 5 boss arenas (`data/layouts/` + pure seeded `LayoutCore`: no-repeat-per-floor pick, flood-fill validation, footprint keep-outs; placeholder arrangements, human dial pass pending) (`design/dungeon-strata.md` — implementation-status block up top).
- **Combat:** 3 weapons, 5/9 etchings castable, 7 passive attunements (the Dust two-sink baseline UNDER echoes), ~25 echoes (incl. healing + first etching-mod echoes, 2026-07-10), 5 enemy types, waves, **boss #1 built 2026-07-10 — the Den-Warden, data-driven (`data/bosses/` + pure `BossCore` + `enemy_boss.gd`; floors 2–5 keep the placeholder fallback; `design/bosses/floor-1-boss.md` status block)** (`design/etchings.md`; `design/feel-tuning.md` = the dial board; F6 sandbox, F1 live sliders, F2 cheat panel).
- **Town:** build/survey panels, day tick + Well-Fed upkeep, unlock cascade b1–b4 (`design/food-upkeep.md`, `design/ui-hud.md`). **Tick amendment (2026-07-10, human — amends IC-7's magnitude, not its trigger):** the tick scales with rooms cleared (`TownCore.run_tick_scale`, PER_ROOM_TICK 0.1, nominal day = 10 rooms; the day counter stays 1/run). **Economy v2 BUILT 2026-07-10** (`design/town-economy.md` — status block up top): 9/9 buildable defs, age-banded per-level tech gates (unauthored techs = dormant forward refs), multiplier tick fold, Market (auto-sell + exchange + caravan panel) + Cathedral (shard-bonus capability); sim regenerated (`design/economy-sim.md`).
- **Learning:** tech research end-to-end incl. the interactive arch puzzle, shard turn-in, quiz-lock, Sophia auto-solve (`design/tech-nodes/`).
- **Dialogue:** full selection system + force-play + `!`/`!!` indicators; human-authored opening scripts are canonical. **Volume pass 2026-07-10:** pool 52→112 files, spine COMPLETE through E1 (C1–C6, D1–D5, E1 + the flag-chained C5 dreams), +6 arc beats/+24 contextuals/+16 barks — all agent drafts awaiting curation; new `max_floor >= N` condition; `linnea` renders as "The Woman" via `DialogueCore.display_name`; a pool-wide unit lint enforces the voice bans (`design/act1-story-beats.md`, `design/voice-guides.md`; queue in `design/dialogue/`).
- **Story/save/audio/UI:** StoryState/TechState autoloads, codex + dissolve loop, save slots + profile, settings screen, placeholder SFX/music; **all 16 UI surfaces are on Ember** (Slate retired) — see below (`design/ui-hud.md`, `design/audio.md`, `design/architecture-schemas.md` carries per-section implementation status).
- **Look = PAINTED-LITE (forked 2026-08-13, human):** `assets_src/anchors/art-style.png` **replaces** the town anchor as THE look — soft painterly shading, no outlines, dusk lighting, desaturated world (`design/style-bible.md`). Render layer BUILT + human-approved same day: `tycho_toon.gdshader` samples the ramp **continuously** (banding retired) and gained an **omni/spot branch** so warm practicals finally light the scene; new `StyleEnvironment` (AgX + glow + volumetric fog + SSAO + grade + vignette) replaced three near-empty inline Environments; camera went corner-on telephoto (`cam_yaw` 45 / `cam_fov` 40, WASD now camera-relative). `StyleCore` ramps, per-stratum derivation and the FX/telegraph readability guard all survived unchanged. Combat legibility is carried by `ADJ_SATURATION` 0.85 (world desaturated → telegraph/hazard/pickup hues are the only saturated pixels) — see style-bible § Combat compatibility. Dials: `design/feel-tuning.md`. Judge with `tools/render_compare.tscn`.
- **Asset plan (REWRITTEN 2026-08-13 for the fork):** `design/asset-list.md` (LIVING master list, append protocol) + `design/asset-pipeline.md` (now a **step-by-step operator's guide**, Stages 0–6). **The strategy inverted:** texture generation went from "probably not needed" to **the primary pipeline** — ~10 tileable hand-painted materials triplanar-mapped onto simple geometry, with Tripo used for **geometry only** (its textures discarded for props; kept for characters). Budget is **gen-AI only** (human, no paid packs); CC0 packs return as blockout/silhouette donors. Zero real visual assets yet — **the pipeline gate (Stage 0) stays the unblocker, and Stage 1 (materials) should run first so the gate is judged against the right bar.**
- **Town-square fountain (2026-08-10):** the town's first anchor-derived prop — `TownFountain` (`src/core/town_fountain.gd`, the @tool/save-hygiene contract of GrassPatch/WaterPlane/ShoreTerrain), generated geometry (step → block rim → teal pool → column + spill bowl), placed at town centre (0, 0, −0.5). No model file: the asset-pipeline gate has not run. Water reuses the lake's shader via a new `WaterPlane.build_material()`. Dials: `design/feel-tuning.md` § Style unification → Town fountain; two new tools (offscreen prop renderer at the game camera angle + a geometry-winding probe) in `design/godot-conventions.md` § Tools. **HUMAN:** judge in F5 against the anchor and re-dial — every number is a placeholder.
- **UI = "Ember" — MIGRATION COMPLETE 2026-08-14 (Ember 16 / Slate 0):** the language is **no panels** — everything floats on hairlines, thin rings and negative space, gold reserved for state; anchors `assets_src/anchors/in-run-hud-reference.png` + `weapon-menu-reference.png`. `EmberHud` owns the palette, both primitive sets and **22 code-drawn glyphs** (no icon assets → the whole UI is independent of the asset gate); pure `EmberMenuCore` owns the layout grammar, `EmberTheme` the Control-tree half (Panel = **transparent**), `EmberPips` the one level track, `EmberFrame` the packable hairline/dashed/ring bounds, and Alegreya Sans is the fourth font. Tiers A (4 overlays) + B (6 town screens) + C (tech, slot-select, settings, achievements, dialogue) all shipped 2026-08-13/14 as **restyles with byte-identical APIs**; all 7 helper draw classes moved too. **`SlateHud`/`SlateTheme` now have ZERO references — orphaned files, and Tier D is a pure deletion.** Probes: `tools/render_hud.tscn` (4 overlays) + `tools/render_menu.tscn` (**16** states — the specimen plus every real screen). **HUMAN:** every value is a placeholder — judge the probes + F5 (`design/ui-hud.md` § "Migrating to Ember"; dials: `design/feel-tuning.md` §§ Ember HUD / Ember menus / Ember Tier A / B / C).
- **Screens are fully OPAQUE (human directive, 2026-08-14):** `EmberHud.COL_SCRIM` is alpha 1.0 — it shipped at 0.90 and the town showing faintly behind the forge read as distraction, not depth. Ember's no-panels argument is about panels *inside* a screen; a fullscreen backdrop is the page itself. Two deliberate exceptions, both in-world rather than screens: `EchoOfferPanel.DIMMER` (0.62 — you are still reading the battlefield) and `DialoguePanel` (its box gets a solid ground of its own; you must see who is speaking).
- **No on-screen instructions (human directive, 2026-08-14):** the run HUD's contextual hint (`Clear the room`, …), the town HUD's `WASD move · E interact · …`, the achievements `Esc — back`, the dialogue `E / click — continue` and the star chart's hint chip are all **deleted**. The line: **control prompts go, descriptive copy in the game's voice stays.** The world carries the affordance (the lit portal, the door sigils, the Wellspring). Consequence: the run HUD's objective rows are the only words on screen, so **a row must read as state, never an instruction** (`Room cleared`, not "now choose a door") — noted at `HudCore.task_rows` (`design/ui-hud.md` § "No on-screen instructions").
- **Achievements (2026-07-11):** the prepare-for made real — pure `AchievementCore` evaluator over a new `data/achievements/` domain (26 defs, placeholder copy), thin `Achievements` autoload (subscribes to 11 EventBus signals, owns the signal→payload contract, writes `profile.json` on change only), unlock toast + a Slate achievements page off the pause menu; `dialogue_seen` gained its emitter (schemas §5 status block).

**Content vs budget (the real gap — the engine is done, the game is ~15% authored):** tech nodes 2/14 · echoes ~25/~50 · enemies 5/12 · bosses 1 real/5 (placeholder fallback on 2–5) · buildings 9/9 data (+2 shops; models 0/9) · attunements 7/~7 (placeholder) · room layouts 38/38 (placeholder arrangements) · dialogue ~112/~370 pieces · achievements 26/~25 (placeholder copy, curation pending) · spine COMPLETE through E1 (~22/~22 drafted; most awaiting curation). Counts: `design/content-budget.md`.

**Validation baseline:** **364 unit test cases** + **~364 smoke ok-checks** + editor pass clean. Commands + rules (throwaway slot 99, one smoke per invocation, profile.json is GLOBAL — the human's real profile): `design/godot-conventions.md` § Testing. **Known smoke flakiness (measured 2026-08-10, pre-existing — NOT a regression signal):** besides the ±1 door-sigil nondeterminism, the two healing asserts (`Wellspring healed 40% of missing`, `boss kill healed 30% of missing`) fail in roughly 1 run in 4 on an unchanged tree — they compare against BASE percentages while the run may have picked up healing echoes. Re-run before believing a smoke failure; fixing the asserts to account for echo modifiers is an open to-do.

**Tools (2026-07-10):** headless economy sim (`tools/economy_sim.gd`, report + red flags in `design/economy-sim.md`; command in `design/godot-conventions.md` § Tools) + run telemetry (`Telemetry`/`TelemetryCore`, one JSONL record per run end/forfeit to `user://telemetry/runs.jsonl` — diagnostics only, outside `user://saves/`).

**Environment:** Godot binary `/home/clarior/Godot_v4.7-stable_linux.x86_64` (project on 4.7); F5 = the full game loop; Godot MCP wired in `~/.claude.json`.

**Doc-vs-code drift:** RESOLVED 2026-07-10 — Timber/Woodcutter/Cart cut, docs synced, and all 9 buildable defs now exist in `data/` (`design/town-economy.md`). Library/Observatory/Mill wait on unauthored gate techs by design (dormant forward refs, not drift).

**Next actions (HUMAN):** (0) **judge Ember + dial it** — `tools/render_menu.tscn` (16 states: the specimen beside `assets_src/anchors/weapon-menu-reference.png`, plus every real screen) + `tools/render_hud.tscn` (4 overlays), then F5 from the title screen through town + a run; the shared numbers (`EmberHud`, `EmberMenuCore`) now move **all sixteen** screens at once, so dial there first; (1) content-gate verdict — research Arithmetic then Masonry at Sophia's desk, judge *delight vs. homework*; (2) **asset pipeline — start at `design/asset-pipeline.md` Stage 1 (materials, Recraft-only month ~$10, no 3D tooling), then Stage 0 (the gate: one rigged `.glb`, needs a paid Tripo month — free-tier outputs are public/non-commercial)**; (3) curate dialogue — `design/dialogue/drafts-review-2026-07-06.md` first (§6 has placeholder E2 lines), then `drafts-review-2026-07-04.md`, then `drafts-review-2026-07-10.md` (the whole spine + the boss rename); (4) ongoing dials — feel numbers, strata palettes + the 5 legibility passes, audio mix; Kenney packs + Suno-vs-Udio + the dream-motif instrument (`design/audio.md`).

**Next agent chunks (agreed order):** **UI migration to Ember is DONE** — menu base + Tier A (2026-08-13), Tier B + Tier C (2026-08-14). Only **Tier D** remains and it is a pure deletion of two orphaned files (`SlateHud` + `SlateTheme`), unblocked whenever the human wants it — tiers + rules in `design/ui-hud.md` § "Migrating to Ember". → remaining tech nodes (blocked on the content-gate verdict; 8 are forward-referenced by building gates — see `design/town-economy.md` § tech payoff; 3 dialogue pieces also sit dormant on them). Other unblocked candidates: enemies 5→12, echoes ~25→~50, bosses 2–5.

## Working agreement
- **Documentation is sacred.** Keep `Tycho Roguelite.md` (design bible) and this file accurate and current. A new agent must be able to pick up the project from these two docs alone. Update them as part of any task that changes scope, decisions, or structure.
- **Always update ALL affected md files in the same change — never just one.** Any change to scope, decisions, systems, or structure must propagate to every doc that touches it, so the docs never disagree. If docs conflict, the bible wins — fix the others to match.
- **Status discipline (2026-07-10):** a "Current state" entry here is **≤10 lines** — what/where/counts/deferred + a pointer to the owning `design/` doc, which carries the deep detail (the builder writes it there anyway). Dated long-form chunk records go to **`design/history.md`** (newest on top), NOT here. This file must stay ~5k tokens — it is loaded into every AI session; its size is a tax on everything.
- **AI workflow — token discipline (2026-07-10):**
  - **Chunk pattern:** orchestrator writes a tight spec → a builder subagent builds + self-validates (builders NEVER git-commit) → orchestrator reviews, validates, commits.
  - **Tiered review:** mechanics-touching code (combat, save, run flow) = full diff review + all validations. Additive systems behind a pure core = review the core + integration points, skim the rest, smoke once. Data/content-only chunks = run tests (they catch schema breaks), spot-check 2–3 files, commit.
  - **Tests are cheap — keep them:** unit suite before every `src/` commit; the full smoke for anything touching game flow/save/run loop; content-only chunks may skip the smoke.
  - **Model tiering:** frontier builder for real systems chunks; a cheaper model for mechanical ones (data tables, doc syncs) under a tight spec.
  - **Keep chunks big:** per-chunk overhead (orient, validate, doc-sync) is fixed — one well-spec'd large chunk beats five small ones.
- **Commit with git** after every meaningful change, with clear messages (prefixes `feat:/fix:/content:/design:/chore:`).
- **Push back** when something doesn't make sense — a workflow, an ordering, or a contradiction with the locked decisions. Don't silently comply.
- **Stack:** Godot 4.7, Linux, single-player.
- **Solo dev + AI:** the human owns ideas, story, playtesting, and combat-feel tuning; agents own systems, content, UI, and plumbing. **Game feel cannot be vibecoded** — leave feel-tuning to hands-on human iteration. Agents never change `# FEEL:` values, `feel_room.tscn`, human-authored dialogue, or existing game-copy strings (sanctioned changes only). All new UI copy / visual numbers ship as placeholders the human dials.
- **Assets:** working default is 2.5D (3D models on a fixed camera) — Tripo + Quaternius. Placeholder-first; validate look/feel before investing in final art. **Any chunk that adds content needing an asset (model, icon, portrait, VFX, SFX hook, …) must append/update its row in `design/asset-list.md` in the same change** — an asset the list doesn't know about is a scope leak. Tools + workflows: `design/asset-pipeline.md`.

## Build order (do in this order — earlier phases de-risk later ones)

### Phase 0 — Skeleton + the two gates (DO THIS FIRST)
1. Initialize a git repo and a Godot project (done — created on 4.6, since upgraded to 4.7).
2. **Combat-feel gate — ✅ PASSED 2026-07-10 (human verdict, judged with sound):** one throwaway room, one Tycho, one enemy, dash + light attack, placeholder models. Iterate ONLY on feel. **Pass bar: after the 20th clear of the same room, you still want one more.** It does NOT need to feel like Hades — its own feel is fine (Hades = quality reference, not cloning target). This was the go/no-go for the entire project — it is green. Feel tuning remains open-ended human work (`# FEEL:` numbers never freeze).
3. **Content gate:** author one complete tech-tree node end-to-end (explanation → puzzle → "aha"); playtest whether it reads as *delight* or *homework*. Fix the format before authoring the rest.
4. **Asset-pipeline gate** (validate, can run parallel to #2): ONE character Tripo → rig → Quaternius/UAL animation retarget → animated in a Godot scene under the fixed camera. De-risks the 2.5D pipeline assumption before any 3D asset work; failure ≠ no-go (fallback: stock Quaternius models, or learn Blender).

### Architectural "prepare-for" requirements (bake in from the start)
v1 builds only the roguelite, but must not paint us into a corner. Set these up early even though their full payoff is later:
- **Save system with multiple slots** — design the save schema before there's much to save.
- **Achievements** — a central event hook other systems fire into.
- **Age/era as data** — town, tech tree, and content keyed by age, so adding an age is data, not a rewrite.
- **Separable pillars** — keep roguelite / strategy / space concerns decoupled so Acts II (strategy) and III (space) can slot in later. **Do NOT build strategy or space gameplay in v1.**

### Phase 1+ — the v1 roguelite (detail TBD — do NOT pre-build)
Town hub, dialogue system, characters, tech tree, weapons, etchings, dungeon generation, enemies/bosses, meta-progression, resource economy. **Broken into real tasks only after the Phase 0 gates pass.** Too much is still open to plan in detail now — see the design bible's open authorial threads, plus second-order unknowns: tech-puzzle pacing between runs, resource-economy numbers, and how many weapons/etchings v1 needs.

## v1 finish line
End of Act I — the **evil emperor enters** as the antagonist (cliffhanger into the future strategy layer). NOT the alien reveal, NOT the war.

## Pointers
- Design bible / full vision: `Tycho Roguelite.md`
- **Project history (dated chunk log): `design/history.md`** — the full record of every built chunk
- Detailed design docs: `design/` (see `design/README.md`):
  - `design/prd.md` — **the v1 PRD** (start here to build; synthesizes everything below into an implementable spec)
  - `design/content-budget.md` — v1 scope by the numbers (the schedule)
  - `design/asset-list.md` — **the master asset inventory (LIVING)**: every visual/audio asset v1 needs; content chunks append here
  - `design/asset-pipeline.md` — the asset maker-pipeline: gen-AI tool stack, per-type workflows, style unification, licensing
  - `design/act1-story-beats.md` — story spine, character arcs, dialogue-system spec
  - `design/architecture-schemas.md` — data schemas + per-section implementation status (save, ledger, ages, tech, achievements, town, dialogue, floors/hazards, etchings)
  - `design/godot-conventions.md` — project structure, code rules, **testing commands** (read before writing any code)
  - `design/feel-tuning.md` — **dial board**: every tunable `# FEEL:` number + the data dials (abilities, strata, hazards)
  - `design/dungeon-strata.md` — floor differentiation: strata, hazards, the "imitation thins with depth" lore engine (built 2026-07-10)
  - `design/etchings.md` — the 9 active abilities (+ fixed dash); first slice built 2026-07-07
  - `design/run-structure.md` — door choice, echo cadence, in-run healing economy (built 2026-07-05)
  - `design/food-upkeep.md` — the Well-Fed mechanic (built 2026-07-05)
  - `design/town-economy.md` — buildings, age-banded levels, Market/Cathedral sinks (built 2026-07-10)
  - `design/audio.md` — the audio pipeline (first chunk built 2026-07-04)
  - `design/voice-guides.md` — how every character talks; ALL dialogue drafting goes through it
  - `design/ui-hud.md` — the Slate UI language: every built screen's converged spec + placeholder locations
  - `design/tech-nodes/` — one file per tech node; first authored node (the Content gate): `medieval-masonry-the-arch.md`
  - `design/dialogue/` — dialogue batch records + the human curation queue
- Asset resources: `Tycho Roguelite.md` → "notes" (Quaternius, Hotpot, Tripo, Blender)
