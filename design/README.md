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
- (future) `dungeons/`, `etchings/`, `weapons/`, `dialogue/`, `bosses/` — detailed specs as they get authored.

## Rules
- The bible stays the source of truth for **what the game is**; `design/` is the source of truth for **how a specific piece works in detail**.
- When a detailed doc here changes a locked decision or the big-picture shape, update the bible too (documentation is sacred — see `../CLAUDE.md`).
- One concept per file. Keep filenames kebab-case and prefixed by age/area where it helps (e.g. `medieval-masonry-the-arch.md`).

## Status
- `tech-nodes/medieval-masonry-the-arch.md` — **first authored node (the Content gate).** Validates the format before the rest of the tree is authored. Playtest this for *delight vs. homework* before scaling up.
- `content-budget.md`, `act1-story-beats.md`, `architecture-schemas.md`, `godot-conventions.md` — **drafted 2026-06-12** as PRD inputs. Beats are skeleton-level (gates + intent, not scripts); schemas are shape-contracts, not final field lists.
- `prd.md` — **drafted 2026-06-19** from the above. Status: pre-development; to be finalized after the Phase 0 gates pass (gate outcomes may revise counts/feel targets).
