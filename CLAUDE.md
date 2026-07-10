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
- **Strata + hazards (2026-07-10):** all five floors differ by env profile + props + a signature hazard; all six hazards live, dual-use, data-driven (`design/dungeon-strata.md` — implementation-status block up top).
- **Combat:** 3 weapons, 5/9 etchings castable, 7 passive attunements (the Dust two-sink baseline UNDER echoes), ~25 echoes (incl. healing + first etching-mod echoes, 2026-07-10), 5 enemy types, waves (`design/etchings.md`; `design/feel-tuning.md` = the dial board; F6 sandbox, F1 live sliders, F2 cheat panel).
- **Town:** build/survey panels, day tick + Well-Fed upkeep, unlock cascade b1–b4 (`design/food-upkeep.md`, `design/ui-hud.md`). **Tick amendment (2026-07-10, human — amends IC-7's magnitude, not its trigger):** the tick scales with rooms cleared (`TownCore.run_tick_scale`, PER_ROOM_TICK 0.1, nominal day = 10 rooms; the day counter stays 1/run); plus a first economy rebalance iterated against the sim (weapon/Dust costs, drops, caches, building L2/L3 gold — milestone table in `design/economy-sim.md`).
- **Learning:** tech research end-to-end incl. the interactive arch puzzle, shard turn-in, quiz-lock, Sophia auto-solve (`design/tech-nodes/`).
- **Dialogue:** full selection system + force-play + `!`/`!!` indicators; human-authored opening scripts are canonical (`design/act1-story-beats.md`, `design/voice-guides.md`; curation queue in `design/dialogue/`).
- **Story/save/audio/UI:** StoryState/TechState autoloads, codex + dissolve loop, save slots + profile, settings screen, placeholder SFX/music, every menu screen in Slate (`design/ui-hud.md`, `design/audio.md`, `design/architecture-schemas.md` carries per-section implementation status).

**Content vs budget (the real gap — the engine is done, the game is ~15% authored):** tech nodes 2/14 · echoes ~25/~50 · enemies 5/12 · bosses 1 placeholder/5 · buildings 4/13 · attunements 7/~7 (placeholder) · dialogue ~52/~370 pieces · achievements 0/~25 · spine ~9/~22 scenes (Phases C/D mostly unauthored). Counts: `design/content-budget.md`.

**Validation baseline:** **239 unit test cases** + **292 smoke ok-checks** (±1 known door-sigil nondeterminism) + editor pass clean. Commands + rules (throwaway slot 99, one smoke per invocation, profile.json is GLOBAL — the human's real profile): `design/godot-conventions.md` § Testing.

**Tools (2026-07-10):** headless economy sim (`tools/economy_sim.gd`, report + red flags in `design/economy-sim.md`; command in `design/godot-conventions.md` § Tools) + run telemetry (`Telemetry`/`TelemetryCore`, one JSONL record per run end/forfeit to `user://telemetry/runs.jsonl` — diagnostics only, outside `user://saves/`).

**Environment:** Godot binary `/home/clarior/Godot_v4.7-stable_linux.x86_64` (project on 4.7); F5 = the full game loop; Godot MCP wired in `~/.claude.json`.

**Known doc-vs-code drift (flagged 2026-07-10, unresolved):** Timber, the Woodcutter's Lodge, and the Market exist in the bible's tables but not in `data/` — either build them or cut Timber from v1 and sync the docs.

**Next actions (HUMAN):** (1) content-gate verdict — research Arithmetic then Masonry at Sophia's desk, judge *delight vs. homework*; (2) asset-pipeline gate — one rigged `.glb` per `assets/README.md`; (3) curate dialogue — `design/dialogue/drafts-review-2026-07-06.md` first (§6 has placeholder E2 lines), then `drafts-review-2026-07-04.md`; (4) ongoing dials — feel numbers, strata palettes + the 5 legibility passes, audio mix; Kenney packs + Suno-vs-Udio + the dream-motif instrument (`design/audio.md`).

**Next agent chunks (agreed order):** boss #1 design doc (`design/bosses/`, unblocked by the feel gate) → dialogue volume (define remaining arc beats first, add a `max_floor` counter) → remaining tech nodes (blocked on the content-gate verdict).

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
- **Assets:** working default is 2.5D (3D models on a fixed camera) — Tripo + Quaternius. Placeholder-first; validate look/feel before investing in final art.

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
  - `design/act1-story-beats.md` — story spine, character arcs, dialogue-system spec
  - `design/architecture-schemas.md` — data schemas + per-section implementation status (save, ledger, ages, tech, achievements, town, dialogue, floors/hazards, etchings)
  - `design/godot-conventions.md` — project structure, code rules, **testing commands** (read before writing any code)
  - `design/feel-tuning.md` — **dial board**: every tunable `# FEEL:` number + the data dials (abilities, strata, hazards)
  - `design/dungeon-strata.md` — floor differentiation: strata, hazards, the "imitation thins with depth" lore engine (built 2026-07-10)
  - `design/etchings.md` — the 9 active abilities (+ fixed dash); first slice built 2026-07-07
  - `design/run-structure.md` — door choice, echo cadence, in-run healing economy (built 2026-07-05)
  - `design/food-upkeep.md` — the Well-Fed mechanic (built 2026-07-05)
  - `design/audio.md` — the audio pipeline (first chunk built 2026-07-04)
  - `design/voice-guides.md` — how every character talks; ALL dialogue drafting goes through it
  - `design/ui-hud.md` — the Slate UI language: every built screen's converged spec + placeholder locations
  - `design/tech-nodes/` — one file per tech node; first authored node (the Content gate): `medieval-masonry-the-arch.md`
  - `design/dialogue/` — dialogue batch records + the human curation queue
- Asset resources: `Tycho Roguelite.md` → "notes" (Quaternius, Hotpot, Tripo, Blender)
