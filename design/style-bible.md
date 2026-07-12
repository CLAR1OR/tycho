# Style bible — the externalized visual imagination

> The reference images every visual accept/reject is judged against — **side-by-side on screen, never against memory** (the aphantasia workflow, `design/asset-pipeline.md`). Images live in `assets_src/anchors/` (in git, `.gdignore`'d so Godot never imports them); each anchor's generation prompt lives beside it in `assets_src/prompts/`. **Human picks every anchor**; agents only record the pick and derive candidates from it. Started 2026-07-12 with the town anchor.

## Anchors

| Anchor | File | Picked | Covers |
|---|---|---|---|
| **Town (gameplay look)** | `assets_src/anchors/town-style-anchor.png` | human, 2026-07-12 | The in-engine 2.5D target: town scene, buildings, palette, dusk lighting, toon banding + outlines. Also a per-building concept sheet (crop → image→3D refs). |

Wanted next (one canonical subject per class, per the workflow): a character anchor (Tycho), a dungeon-stratum anchor (floor 1), an icon anchor, a portrait anchor (the bible's painterly oil prompt is the starting point for that separate 2D context).

## What carries the town look (decomposed 2026-07-12)

The anchor is a 2D painting; the in-game goal is that a screenshot *reads* like it at a glance. Five carriers, four of which are existing dials:

1. **Palette** — warm amber/timber vs cool indigo shadow and water (extracted values below). → `StyleCore.TOWN_RAMP` + `PALETTE_*` (`src/core/style_core.gd`).
2. **Dusk lighting** — one warm low-angle key light against cool blue ambient; the toon shader quantizes it into the bands. → town-scene DirectionalLight + WorldEnvironment (dial pass still pending).
3. **Emissive windows** — the "cozy, lived-in" read is mostly warm glowing rectangles. → convention: building models get a `window_glow` surface with `PALETTE_WINDOW_GLOW` emission, applied by the post-import script (not built yet — lands with the first real building).
4. **Outlines + 2-band toon** — built (`tycho_toon.gdshader` + `tycho_outline`). Anchor's outlines are thin and dark-warm, not black.
5. **Chunky silhouettes** — oversized roofs, squat walls, simple masses. A *model-selection* criterion, not a shader dial — judge generated/stock buildings against the anchor for this.

**Not chased** (won't survive the 2D→3D translation, by design): painterly per-tile texture wobble, the dense villager crowd, illustration-grade everything-in-focus richness.

## Extracted palette (ImageMagick 14-color quantization + bright-pixel pass, 2026-07-12)

| Role | Hex | Where it went |
|---|---|---|
| Deep indigo (water/shadow) | `#21354B` | `TOWN_RAMP[0]` (dark stop) |
| Slate blue (roofs, water mid) | `#28475B` | `PALETTE_ROOF_SLATE` |
| Rust red (accent roofs) | `#9A4B20` | `PALETTE_ROOF_RUST` |
| Warm khaki (ground/paths) | `#B88B54` | informs `TOWN_RAMP[1]` (mid stop) |
| Window/torch glow | `#E8BC68` | `PALETTE_WINDOW_GLOW`; informs `TOWN_RAMP[2]` (light stop, lifted toward cream) |
| Dark timber | `#4D3624` | `PALETTE_WOOD` |
| Wall stone grey | `#8A8588` | ≈ existing `PALETTE_STONE` (unchanged) |
| Olive grass | `#3B4227` / `#615325` | candidates for the grass/shore dials (pending) |
| Warm cream | `#D6B98F` | reserve (lit plaster / portrait skin candidate) |

First `TOWN_RAMP` pass applied 2026-07-12 (human-directed, from this table): indigo shadow → warm khaki mid → glow-cream light. **All values stay `# style:` dials — judge in F5 against the anchor and re-dial freely** (dial board: `design/feel-tuning.md` § Style unification). Pending dial passes: town scene lighting (warm key / cool ambient), grass + shore colors toward the olive/khaki rows, outline color (dark-warm?).

## Judging protocol (per anchor class)

1. Open the anchor and the candidate (screenshot / contact sheet) side by side.
2. Ask only "does the candidate read like the anchor at a glance?" — palette, light story, silhouette. Ignore detail fidelity.
3. Winners: asset kept + its prompt saved in `assets_src/prompts/`. Losers: deleted.
4. Style drift is fixed at the dial/shader layer first, the asset layer second (the unification-layer principle).
