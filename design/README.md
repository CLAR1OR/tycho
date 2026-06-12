# design/ — detailed design docs

The master design bible (`../Tycho Roguelite.md`) holds the **locked decisions and the big-picture shape**. To keep it readable, anything that goes into *fine detail* lives here instead, and the bible links to it.

## What lives here
- `tech-nodes/` — one file per authored tech-tree node (explanation → puzzle → "aha" → unlock). `_TEMPLATE.md` is the canonical format; copy it to author a new node.
- (future) `dungeons/`, `etchings/`, `weapons/`, `dialogue/`, `bosses/` — detailed specs as they get authored.

## Rules
- The bible stays the source of truth for **what the game is**; `design/` is the source of truth for **how a specific piece works in detail**.
- When a detailed doc here changes a locked decision or the big-picture shape, update the bible too (documentation is sacred — see `../CLAUDE.md`).
- One concept per file. Keep filenames kebab-case and prefixed by age/area where it helps (e.g. `medieval-masonry-the-arch.md`).

## Status
- `tech-nodes/medieval-masonry-the-arch.md` — **first authored node (the Content gate).** Validates the format before the rest of the tree is authored. Playtest this for *delight vs. homework* before scaling up.
