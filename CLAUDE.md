# CLAUDE.md — Tycho Roguelite

Working doc for AI agents (and humans) building **Tycho Roguelite**. **Read this first**, then the design bible: **`Tycho Roguelite.md`** (its top section, "Design Decisions — Locked", is the source of truth for what the game is).

---

## ⬇ Inbox — playtest feedback & quick to-dos
> The human drops notes here; agents triage them into the roadmap below. Newest on top. (Empty for now.)

-

---

## What this is (30-second version)
A 2.5D top-down **real-time action roguelite** (Hades-style *feel*) wrapped around a **rational-fiction story** and a **real-science tech tree**. Medieval setting; "magic" is secretly nanobots. The roguelite is the engine; **the story + learning is the soul.** Full vision + locked decisions: `Tycho Roguelite.md`.

## Current status (2026-06-19)
- **Phase: Phase 0 — combat-feel gate (in human-playtest).** Design refined, decisions locked, **all four open story threads resolved**, 2.5D rendering confirmed, **pacing/economy/accessibility locked** (1 day = 1 run, 20–25 min runs, 5 floors × 6–10 rooms, no death penalty, no dungeon puzzle rooms, nanobot assist mode, combat-feel pass bar) — see `Tycho Roguelite.md` → "Story decisions — resolved", "Combat & presentation", "Pacing, economy & accessibility".
- **Git repo initialized** (branch `main`, Godot 4 `.gitignore` in place).
- **Godot 4.6 project created (2026-06-19)** to `design/godot-conventions.md` spec: `project.godot` (3D, GDScript, static typing, input map for WASD/dash/attack/RMB/Q/R), directory tree (`src/` by domain, `scenes/`, `data/`, `assets/`, `tests/`), reusable `scenes/core/camera_rig.tscn` (the one scene allowed to assume camera angles). Validated importing + compiling clean headless on Godot v4.6.3.
- **Combat-feel gate prototype built (2026-06-19)** — the Phase 0 go/no-go sandbox: `scenes/combat/feel_room.tscn` (main scene). One Tycho (`player.gd`: move + dash w/ i-frames + light-attack combo, faces mouse), a wave of real enemies (`enemy_dummy.gd`: chase → telegraph → strike → recover, stats `@export`ed so variants are data; two variants — Brute `enemy_dummy.tscn` + faster/weaker Skirmisher `enemy_skirmisher.tscn`; boids-style separation so they don't stack; `ENEMY_COUNT` mixed per wave, clear the wave to score a clear), placeholder primitive meshes, a clears counter + HP HUD. All feel numbers marked `# FEEL:`. **This builds the mechanism; the go/no-go is a human feel-tuning playtest** (game feel cannot be vibecoded) — pass bar: *after the 20th clear, you still want one more.*
- **Combat juice pass (2026-06-20):** camera shake on taking a hit (`camera_rig.gd` `shake()`), a swept blade visual + a translucent hitbox volume shown during the active frames so you can see what a swing covers (`player.gd` `_update_swing_visual`, nodes in `player.tscn`), and a bright slash streak left at each landed hit that fades over ~0.9 s (`slash_fx.tscn`/`.gd`). All cosmetic; all tunable via `# FEEL:` consts.
- **Combat depth pass (2026-06-20):** light attack is now a **3-hit combo** — hits 1 & 2 quick, hit 3 a finisher (more damage, wider arc, longer recovery); waiting longer than `COMBO_CONTINUE_WINDOW` resets the sequence (`player.gd`). **Floating damage numbers** on every hit (white normal / gold finisher / red on the player), via a small FX factory `CombatFX` (`src/combat/fx.gd`) spawning `damage_number.tscn` (billboard `Label3D`) and the slash. Enemy **separation** + variant system added (see enemies bullet above).
- **Asset-pipeline gate scene built (2026-06-20)** — Phase 0 gate 3 stage: `scenes/core/asset_pipeline_gate.tscn` (`character_stage.gd`). Loads a rigged/animated `.glb` (drop at `assets/models/gate_character.glb` or assign `model_scene`), finds its `AnimationPlayer`, force-loops + cycles clips under the **same fixed `camera_rig`**; A/D cycle clips, Space toggles a turntable. Runs a bobbing-capsule placeholder until a real model is dropped in. **Needs a human to produce/drop a model to actually validate the gate** — full step-by-step pipeline in `assets/README.md`.
- **Design-input docs drafted (2026-06-12):** v1 content budget, Act I story-beat skeleton (incl. dialogue-system spec), architecture schemas for the prepare-fors, Godot project conventions — all in `design/`. These are the inputs for the PRD.
- **PRD drafted (2026-06-19):** `design/prd.md` — the single implementable v1 spec, synthesized from the bible + design docs (systems with trigger/state/resolution, immutable core, MVP scope, balance risks, open questions). **Living doc, pre-development:** to be finalized after the Phase 0 gates pass (gate outcomes may revise counts/feel targets). It synthesizes, never overrides — the bible wins on conflict.
- **Passive Attunements layer added (2026-06-19):** persistent passive upgrades (max life, dash charges, regen, etc.) alongside the active etchings — bought with Resonance Dust at Thomas's Hut, distinct from in-run Echoes. See `Tycho Roguelite.md` → "Etchings" → "Passive Attunements"; budget in `design/content-budget.md`; save schema in `design/architecture-schemas.md`.
- **Next concrete action (HUMAN):** (1) playtest the combat-feel gate — run in the Godot editor (F5) or `/home/clarior/Godot_v4.6.3-stable_linux.x86_64 --path .`. Iterate on the `# FEEL:` numbers in `src/combat/player.gd`, `src/combat/enemy_dummy.gd`, `src/core/camera_rig.gd` until it's genuinely good (the 20th-clear bar). This is the project go/no-go. (2) In parallel, run the asset-pipeline gate (`scenes/core/asset_pipeline_gate.tscn`): produce a rigged+animated `.glb` per `assets/README.md` and drop it in. Only after the feel gate passes do we build the Skeleton milestone (EventBus + Ledger + save/slots + data loader/validator — PRD §7.0, §12).

## Working agreement
- **Documentation is sacred.** Keep `Tycho Roguelite.md` (design bible) and this file accurate and current. A new agent must be able to pick up the project from these two docs alone. Update them as part of any task that changes scope, decisions, or structure.
- **Always update ALL affected md files in the same change — never just one.** Any change to scope, decisions, systems, or structure must propagate to every doc that touches it, so the docs never disagree. Before finishing such a task, check (and update where relevant): `CLAUDE.md` (status + working agreement), `Tycho Roguelite.md` (design bible — the source of truth), and the relevant `design/` files (`content-budget.md`, `act1-story-beats.md`, `architecture-schemas.md`, `godot-conventions.md`, `tech-nodes/`, `README.md`). Date new decisions and record them in the CLAUDE.md status. If docs conflict, the bible wins — fix the others to match.
- **Commit with git** after every meaningful change, with clear messages. (Repo not yet initialized — the first dev task initializes it.)
- **Push back** when something doesn't make sense — a workflow, an ordering, or a contradiction with the locked decisions. Don't silently comply.
- **Stack:** Godot 4.6, Linux, single-player.
- **Solo dev + AI:** the human owns ideas, story, playtesting, and combat-feel tuning; agents own systems, content, UI, and plumbing. **Game feel cannot be vibecoded** — leave feel-tuning to hands-on human iteration.
- **Assets:** working default is 2.5D (3D models on a fixed camera) — Tripo + Quaternius. Placeholder-first; validate look/feel before investing in final art.

## Build order (do in this order — earlier phases de-risk later ones)

### Phase 0 — Skeleton + the two gates (DO THIS FIRST)
1. Initialize a git repo and a Godot 4.6 project.
2. **Combat-feel gate:** one throwaway room, one Tycho, one enemy, dash + light attack, placeholder models. Iterate ONLY on feel. **Pass bar: after the 20th clear of the same room, you still want one more.** It does NOT need to feel like Hades — its own feel is fine (Hades = quality reference, not cloning target). **This is the go/no-go for the entire project** — if a single room can't feel good, no story or tech tree will save it.
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
- Detailed design docs: `design/` (see `design/README.md`):
  - `design/prd.md` — **the v1 PRD** (start here to build; synthesizes everything below into an implementable spec)
  - `design/content-budget.md` — v1 scope by the numbers (the schedule)
  - `design/act1-story-beats.md` — story spine, character arcs, dialogue-system spec
  - `design/architecture-schemas.md` — draft schemas for the prepare-fors (save, ledger, ages, tech, achievements, town, dialogue)
  - `design/godot-conventions.md` — project structure, code rules, testing (read before writing any code)
  - `design/tech-nodes/` — one file per tech node; first authored node (the Content gate): `medieval-masonry-the-arch.md`
- Asset resources: `Tycho Roguelite.md` → "notes" (Quaternius, Hotpot, Tripo, Blender)
