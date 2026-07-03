# design/ — detailed design docs

The master design bible (`../Tycho Roguelite.md`) holds the **locked decisions and the big-picture shape**. To keep it readable, anything that goes into *fine detail* lives here instead, and the bible links to it.

## What lives here
- `prd.md` — **the v1 Product Requirements Document.** Synthesizes the bible + the docs below into one implementable spec (systems with trigger/state/resolution, MVP scope, balance risks, open questions). Start here to build; it points back to the detail docs. Does **not** override the bible — the bible wins on conflict.
- `content-budget.md` — v1 scope by the numbers; **this is the schedule.** Change a count = change the scope.
- `act1-story-beats.md` — the Act I spine, character arcs, and the dialogue-selection system spec.
- `architecture-schemas.md` — draft data schemas for the architectural prepare-fors + dialogue.
- `godot-conventions.md` — project structure, code rules, testing. Read before writing any code.
- `feel-tuning.md` — **the dial board for the combat-feel gate.** Every tunable `# FEEL:` number, what it does, and whether you change it in the Godot **Inspector** (`@export`) or the script (`const`). For hands-on playtest tuning.
- `tech-nodes/` — one file per authored tech-tree node (explanation → puzzle → "aha" → unlock). `_TEMPLATE.md` is the canonical format; copy it to author a new node.
- `dungeon-strata.md` — **floor differentiation:** the five strata (environment profiles + signature hazards on one geometry kit), the hazard roster + design rules, and the "imitation thins with depth" lore engine. Locked 2026-07-03 (revises IC-5's re-theme reading).
- `etchings.md` — **the 9 active abilities** (+ fixed dash): slot grammar (RMB Strike / Q Field / R Surge), per-ability design + levels + weapon synergies, Dust costs, echo handles, the Sentinel summon seed. Drafted 2026-07-03.
- `run-structure.md` — **the meso loop's decision layer:** sigil-marked door choice (reward previews, peril marks, pity rules, Cartography foresight), the echo-cadence decision (~12–17 picks/run), and the in-run healing economy (no full heals; % of missing HP via Wellsprings / boss clears / Recovery / healing echoes). Drafted 2026-07-03.
- `food-upkeep.md` — **the Well-Fed mechanic:** Food = day-tick town upkeep → production/Knowledge bonus (never a penalty); the `upkeep` effect kind is the Act-II army/city provisioning prepare-for. Drafted 2026-07-03.
- `audio.md` — **the audio pipeline:** SFX (Kenney CC0 + jfxr, sfx-map as data, human-tuned feel subset), music (AI-gen Suno/Udio human-curated, .ogg loops, per-stratum tracks), buses/formats/licensing, and the first-implementation-chunk spec. Drafted 2026-07-03.
- `voice-guides.md` — **how everyone talks:** house style (plain timeless, written-to-be-said, banned AI constructions), per-character stance/tell/approved-lines, the tech-unlocked vocabulary table, drafting workflow. **All dialogue writing goes through this doc.** Locked with the human 2026-07-03.
- (future) `weapons/`, `dialogue/`, `bosses/` — detailed specs as they get authored.

## Rules
- The bible stays the source of truth for **what the game is**; `design/` is the source of truth for **how a specific piece works in detail**.
- When a detailed doc here changes a locked decision or the big-picture shape, update the bible too (documentation is sacred — see `../CLAUDE.md`).
- One concept per file. Keep filenames kebab-case and prefixed by age/area where it helps (e.g. `medieval-masonry-the-arch.md`).

## Status
- `tech-nodes/medieval-masonry-the-arch.md` — **first authored node (the Content gate).** Validates the format before the rest of the tree is authored. Playtest this for *delight vs. homework* before scaling up.
- `content-budget.md`, `act1-story-beats.md`, `architecture-schemas.md`, `godot-conventions.md` — **drafted 2026-06-12** as PRD inputs. Beats are skeleton-level (gates + intent, not scripts); schemas are shape-contracts, not final field lists.
- `prd.md` — **drafted 2026-06-19** from the above. Status: pre-development; to be finalized after the Phase 0 gates pass (gate outcomes may revise counts/feel targets).
- `dungeon-strata.md` — **drafted 2026-07-03** (human decision, from the design-review discussion). Strata + hazards are design-locked; all numbers are playtest placeholders; nothing implemented yet.
- `etchings.md` — **drafted 2026-07-03** (fills the bible's empty etchings table). Names + mechanics are a first authored draft for human review; numbers are placeholders; nothing implemented yet.
- `run-structure.md` — **drafted 2026-07-03.** NOTE it decides an echo-cadence change (doors + post-boss instead of every-room) that retires current slice behavior when door choice gets built; nothing implemented yet.
- `food-upkeep.md` — **drafted 2026-07-03.** Fixes the dead Food resource; the `upkeep` effect kind lands in TownCore with its consumer; nothing implemented yet.
- `audio.md` — **drafted 2026-07-03.** Pipeline decided; the first implementation chunk was deferred behind uncommitted edits to `project.godot` + `feel_room.tscn` — **cleared later the same day** (they were the gdUnit4 install; committed), so the chunk is buildable. Human actions: download Kenney packs; pick Suno vs Udio.
- `voice-guides.md` — **locked 2026-07-03**, worked out live with the human (sample lines are human-approved anchors; register, humor density, character naming — sister **Sophia**, second bearer **Linnea**, swapped to the historical mapping same day — and the vocabulary-table idea are human decisions). Unblocks batch snippet drafting.
