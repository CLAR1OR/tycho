# Style bible — the externalized visual imagination

> The reference images every visual accept/reject is judged against — **side-by-side on screen, never against memory** (the aphantasia workflow, `design/asset-pipeline.md`). Images live in `assets_src/anchors/` (in git, `.gdignore`'d so Godot never imports them); each anchor's generation prompt lives beside it in `assets_src/prompts/`. **Human picks every anchor**; agents only record the pick and derive candidates from it.

## Anchors

| Anchor | File | Picked | Covers |
|---|---|---|---|
| **THE look (gameplay)** | `assets_src/anchors/art-style.png` | human, 2026-08-13 | The in-engine 2.5D target: painterly surfaces, dusk lighting, corner-on camera, desaturated world with warm practicals. Also carries the Ember HUD layout. |
| **Silhouette + composition** *(demoted)* | `assets_src/anchors/town-style-anchor.png` | human, 2026-07-12 | **No longer the rendering target.** Still the reference for chunky building masses, town composition, and the per-building concept sheet (crop → image→3D refs). |
| **Ember HUD** | `in-run-hud-reference.png`, `weapon-menu-reference.png` | human, 2026-08-10 | The run HUD's language (built — `design/ui-hud.md`). |

**The fork (2026-08-13, human):** `art-style.png` **replaces** the town anchor as the game's look. The two are different art directions, not variations — flat/banded/outlined/saturated vs. soft/painterly/outline-free/desaturated. The banded toon shading and the inverted-hull outline were built for the old one; the painted-lite render layer replaced them the same day (`design/feel-tuning.md` § Style unification). The town anchor keeps its job for *shape*, loses it for *rendering*.

Wanted next (one canonical subject per class): a character anchor (Tycho), a dungeon-stratum anchor (floor 1), an icon anchor, a portrait anchor.

**Derived so far:** `TOWN_RAMP` + 3 `PALETTE_*` consts (2026-07-12, from the old anchor — see the palette table below, still valid as medieval-dusk colour); the **town-square fountain** (2026-08-10); the **painted-lite render layer** (2026-08-13 — soft ramp shading, warm practicals, AgX/glow/volumetric fog/SSAO/grade/vignette, corner-on telephoto camera).

## What carries the painted look (decomposed 2026-08-13)

The anchor is a 2D painting; the goal is that a screenshot *reads* like it at a glance. Ranked by value-per-effort, which is **not** the order you would guess:

1. **The lighting RATIO — dark cool ambient against bright warm local pools.** Not brighter lights: a *ratio*. The single biggest carrier and the cheapest. Town ambient went 0.8 near-white → 0.3 cool blue for exactly this. (Dials: `town.gd` `AMBIENT_*` / `PRACTICALS` / `KEY_*`.)
2. **The post stack** — AgX tonemap, additive glow on the practicals, volumetric haze, SSAO, grade, vignette. Zero asset cost. (`StyleEnvironment`.)
3. **Material density** — painted cobble, shingle, timber grain, baked AO. **The expensive one, and the new pipeline's primary output** (`design/asset-pipeline.md` § Stage 1). Simple geometry under good materials reads painted; detailed geometry under flat colour does not.
4. **Composition discipline** — the anchor's play area is *clean*; every busy thing is banked against walls and frame edges. Free, and it doubles as combat readability.
5. **Soft shading, no outlines, cool shadow / warm light.** (`SHADOW_WRAP`, ramps, `OUTLINES_ENABLED false`.)
6. **Camera** — corner-on (`cam_yaw` 45) and near-telephoto (`cam_fov` 40). Yaw is the only way two faces of a building are ever visible.
7. **Chunky silhouettes** — a *model-selection* criterion, not a dial. This is what the old town anchor is still for.

**Not chased** (won't survive the 2D→3D translation, by design): illustration-grade per-object detail, the dense villager crowd, everything-in-focus richness, hand-painted per-tile wobble.

**Combat compatibility** — the anchor is a dusk *exploration* painting: compressed dark values, warm-on-warm, near-black corners. Fast combat wants the opposite. The reconciliation is architectural, not a compromise on the look:
- **Split the value budget by layer.** World lives dark; actors stay on `NEUTRAL_RAMP` and read brighter than the floor beneath them (the pre-existing readability guard, unchanged by the fork).
- **Reserve saturation for gameplay.** `ADJ_SATURATION` 0.85 desaturates the world, which *is* the painted read AND leaves telegraph red / hazard amber / pickup cyan the only saturated pixels on screen. One dial, two jobs.
- **Clean playfield, clutter at edges** (carrier 4 above) — a layout rule, not a render one.
- **Telegraphs stay unshaded and on top** — `StyleMaterials`' skip rules already guarantee this; the fork did not touch them.
- **Practicals placed for readability**, not just mood: lamps at edges, ambient fill in the play area, nothing important inside the vignette.
- *Deferred, if F5 says combat is muddy:* lerp `ADJ_CONTRAST` / fog density toward "legible" on wave spawn and back on clear — the room breathes, and town/reprieve stay fully painterly.

## Extracted palette (from the town anchor, 2026-07-12 — still valid as medieval-dusk colour)

| Role | Hex | Where it went |
|---|---|---|
| Deep indigo (water/shadow) | `#21354B` | `TOWN_RAMP[0]` (dark stop) |
| Slate blue (roofs, water mid) | `#28475B` | `PALETTE_ROOF_SLATE` |
| Rust red (accent roofs) | `#9A4B20` | `PALETTE_ROOF_RUST` |
| Warm khaki (ground/paths) | `#B88B54` | informs `TOWN_RAMP[1]` (mid stop) |
| Window/torch glow | `#E8BC68` | `PALETTE_WINDOW_GLOW`; the town practicals' colour |
| Dark timber | `#4D3624` | `PALETTE_WOOD` |
| Wall stone grey | `#8A8588` | ≈ `PALETTE_STONE` |
| Olive grass | `#3B4227` / `#615325` | grass/shore dial candidates |
| Warm cream | `#D6B98F` | reserve (lit plaster / portrait skin) |

**Pending:** re-extract against `art-style.png` and re-dial `TOWN_RAMP` — its stops were picked for a flat banded shader and are now sampled continuously, so the mid stop in particular may want moving.

## Judging protocol (per anchor class)

> **Rendering a candidate:**
> - `godot --path . tools/render_compare.tscn` → `user://look_compare.png` — the REAL town scene at the game camera, composited **beside the anchor**. The whole-frame judgment, and the only validation the shader gets (GLSL cannot compile headless).
> - `godot --path . tools/render_prop.tscn` → `user://prop_render_{game,close}.png` — one prop at the game's camera angle under the project environment. The per-asset judgment.
> - Commands + caveats: `design/godot-conventions.md` § Tools.

1. Open the anchor and the candidate side by side.
2. Ask only "does the candidate read like the anchor at a glance?" — light story, palette, silhouette. Ignore detail fidelity.
3. Winners: asset kept + its prompt saved in `assets_src/prompts/`. Losers: deleted.
4. **Style drift is fixed at the dial/shader layer first, the asset layer second** (the unification-layer principle — unchanged by the fork, only its mechanism changed).
