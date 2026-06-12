# CLAUDE.md — Tycho Roguelite

Working doc for AI agents (and humans) building **Tycho Roguelite**. **Read this first**, then the design bible: **`Tycho Roguelite.md`** (its top section, "Design Decisions — Locked", is the source of truth for what the game is).

---

## ⬇ Inbox — playtest feedback & quick to-dos
> The human drops notes here; agents triage them into the roadmap below. Newest on top. (Empty for now.)

-

---

## What this is (30-second version)
A 2.5D top-down **real-time action roguelite** (Hades-style *feel*) wrapped around a **rational-fiction story** and a **real-science tech tree**. Medieval setting; "magic" is secretly nanobots. The roguelite is the engine; **the story + learning is the soul.** Full vision + locked decisions: `Tycho Roguelite.md`.

## Current status (2026-06-12)
- **Phase: pre-development.** Design refined, decisions locked, **all four open story threads resolved**, 2.5D rendering confirmed (see `Tycho Roguelite.md` → "Story decisions — resolved" and "Combat & presentation").
- **Git repo initialized** (branch `main`, Godot 4 `.gitignore` in place). **No Godot project or code yet.**
- **Next concrete action:** Phase 0 below — create the Godot 4.6 project, then the combat-feel gate.

## Working agreement
- **Documentation is sacred.** Keep `Tycho Roguelite.md` (design bible) and this file accurate and current. A new agent must be able to pick up the project from these two docs alone. Update them as part of any task that changes scope, decisions, or structure.
- **Commit with git** after every meaningful change, with clear messages. (Repo not yet initialized — the first dev task initializes it.)
- **Push back** when something doesn't make sense — a workflow, an ordering, or a contradiction with the locked decisions. Don't silently comply.
- **Stack:** Godot 4.6, Linux, single-player.
- **Solo dev + AI:** the human owns ideas, story, playtesting, and combat-feel tuning; agents own systems, content, UI, and plumbing. **Game feel cannot be vibecoded** — leave feel-tuning to hands-on human iteration.
- **Assets:** working default is 2.5D (3D models on a fixed camera) — Tripo + Quaternius. Placeholder-first; validate look/feel before investing in final art.

## Build order (do in this order — earlier phases de-risk later ones)

### Phase 0 — Skeleton + the two gates (DO THIS FIRST)
1. Initialize a git repo and a Godot 4.6 project.
2. **Combat-feel gate:** one throwaway room, one Tycho, one enemy, dash + light attack, placeholder models. Iterate ONLY on feel until clearing it feels genuinely good. **This is the go/no-go for the entire project** — if a single room can't feel good, no story or tech tree will save it.
3. **Content gate:** author one complete tech-tree node end-to-end (explanation → puzzle → "aha"); playtest whether it reads as *delight* or *homework*. Fix the format before authoring the rest.

### Architectural "prepare-for" requirements (bake in from the start)
v1 builds only the roguelite, but must not paint us into a corner. Set these up early even though their full payoff is later:
- **Save system with multiple slots** — design the save schema before there's much to save.
- **Achievements** — a central event hook other systems fire into.
- **Age/era as data** — town, tech tree, and content keyed by age, so adding an age is data, not a rewrite.
- **Separable pillars** — keep roguelite / strategy / space concerns decoupled so Acts II (strategy) and III (space) can slot in later. **Do NOT build strategy or space gameplay in v1.**

### Phase 1+ — the v1 roguelite (detail TBD — do NOT pre-build)
Town hub, dialogue system, characters, tech tree, weapons, etchings, dungeon generation, enemies/bosses, meta-progression, resource economy. **Broken into real tasks only after the Phase 0 gates pass.** Too much is still open to plan in detail now — see the design bible's open authorial threads, plus second-order unknowns: puzzle pacing within the run loop, resource-economy numbers, and how many weapons/etchings v1 needs.

## v1 finish line
End of Act I — the **evil emperor enters** as the antagonist (cliffhanger into the future strategy layer). NOT the alien reveal, NOT the war.

## Pointers
- Design bible / full vision: `Tycho Roguelite.md`
- Asset resources: `Tycho Roguelite.md` → "notes" (Quaternius, Hotpot, Tripo, Blender)
