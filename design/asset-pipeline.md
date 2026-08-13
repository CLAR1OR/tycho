# Asset pipeline — the operator's guide

> **How assets get made and brought into the game, step by step.** Written so a future agent can drive the human through a session without re-deriving anything. The inventory of WHAT to make: `design/asset-list.md`. Folder layout: `assets/README.md`. The look being matched: `design/style-bible.md`.
>
> **Rewritten 2026-08-13 for the painted-lite fork.** The previous version was researched 2026-07-11 against the flat/banded town anchor; the look target changed and most of the strategy inverted with it (see § The finding, below). Pricing/licensing was web-verified 2026-07-11 — **re-verify before subscribing, this market moves fast.**
>
> **Status:** plan. Nothing here is proven in-project until **Stage 0 (the pipeline gate) runs** — still Phase 0's one open gate.
>
> **Budget constraint (human, 2026-08-13): gen-AI only.** No paid asset packs. Free CC0 stock stays available and is used differently than before (§ Stage 3).

---

## The finding (REVISED — read this even if you skip the rest)

The old finding was: *"generation buys shape, Godot buys style — one toon shader makes mismatched gens read as one game, and we probably need no texture generation at all."*

Half of that survives. **In-engine unification is still the whole strategy.** But the mechanism inverted:

| | Old (flat anchor) | New (painted anchor) |
|---|---|---|
| What unifies | A toon shader flattening everything to bands | A **shared material library** + lighting + post |
| Texture generation | *"probably not needed at all"* | **The primary pipeline output** |
| Detail lives in | Silhouette only (camera hides texture) | Silhouette **and** surface |
| Tripo's job | Model + texture | **Geometry only — discard its textures** |

**And the constraint turns out to be favourable.** Gen-AI's strongest output is 2D raster: seamless tileable materials, painted backdrops, icons. Its weakest is textured 3D models. The painted look needs a lot of the former and little of the latter — the quality moved off the *model* layer and onto the *material* layer, which is 2D. Geometry only has to carry silhouette, because it gets triplanar-textured with generated materials anyway.

**The one sentence version:** *make ~10 excellent tileable materials first; then simple geometry starts reading painted, and everything downstream gets cheaper.*

---

## Order of operations (do not reorder — each stage de-risks the next)

```
Stage 0  Pipeline gate .............. ONE character, end to end. Blocks everything.
Stage 1  Material library ........... ~10 tileable materials. The look lives here.
Stage 2  Backdrops .................. 6 painted panoramas. Cheapest fidelity win.
Stage 3  Props & buildings .......... volume. Geometry only + project materials.
Stage 4  Characters ................. the expensive category. Textures kept here.
Stage 5  Icons ...................... ~110, style-locked batch.
Stage 6  VFX ........................ in-engine, not gen-AI.
```

Stages 1 and 2 need **no 3D generation at all** and can start on a Recraft-only month.

---

## Stage 0 — the pipeline gate (**never run — this is the unblocker**)

`scenes/core/asset_pipeline_gate.tscn` exists and is ready. **Re-scoped by the fork:** it used to ask only "does the rig/retarget chain work?" It now also has to answer "does a generated model read like the anchor under our render layer?"

**HUMAN does:** generate one character in Tripo (a **paid** month — free-tier output is public + non-commercial), download uncompressed `.glb`, drop it in `assets/models/characters/`.
**AGENT does:** import, retarget, wire the animation library, apply project materials, render it through `tools/render_prop.tscn`, report.
**HUMAN judges:** side by side against the anchor.

Pass = all four: (a) glb imports clean, (b) BoneMap retarget produces non-broken animation, (c) it reads as the same world as `art-style.png` at camera distance, (d) the whole loop took under ~an hour.

Failure ≠ project no-go. Fallbacks in order: Tripo's own preset animations → AccuRig 2 → CC0 Quaternius/KayKit rigged characters as the base mesh. Detail: § Stage 4.

> **Do Stage 1 before Stage 0 if you want the gate to be a fair test** — a character judged under placeholder materials is judged against the wrong bar. Stage 1 needs no 3D tooling, so this costs nothing but ordering.

---

## Stage 1 — the material library (**DO THIS FIRST**)

**The highest-leverage stage in the whole pipeline.** ~10 tileable hand-painted materials, triplanar-mapped onto simple geometry. This is what makes blockout boxes read as painted architecture, and it is the thing gen-AI is genuinely excellent at.

**The set** (start here; append as needed — one row each in `design/asset-list.md`):

| Material | Used by |
|---|---|
| `cobble` | town plaza, dungeon floors |
| `plaster` | building walls |
| `timber` | beams, frames, carts, crates |
| `slate` | roofs |
| `thatch` | roofs (accent) |
| `stone_block` | walls, fountain, ruins |
| `iron` | fittings, hazards, weapons |
| `cloth` | banners, awnings, tents |
| `dirt` | paths, dungeon ground |
| `moss_overlay` | the "lived-in" pass over stone/cobble |

**HUMAN does — per material:**
1. Generate **8 seamless-tile variants** in Recraft (or any 2D gen with a tiling mode). Prompt shape: `hand-painted seamless tileable {material} texture, top-down, muted desaturated palette, soft painterly brushwork, baked ambient occlusion in the crevices, no lighting direction, no specular highlights, game texture`.
2. **Critical prompt rules:** *no lighting direction* and *no specular* — baked directional light fights the engine's lighting and is the #1 way generated textures look wrong in motion. Baked **occlusion** is wanted; baked **sun** is not.
3. Pick 1–2 survivors per material against the anchor. Save the winning prompt in `assets_src/prompts/`.

**AGENT does:**
4. Verify tiling (`magick` 2×2 montage — visible seams = reject, regenerate).
5. Import at `Filter: Linear Mipmap`, `Repeat: Enabled`.
6. Extend `tycho_toon.gdshader` with **triplanar** sampling + a per-material tint/scale uniform, and add a `StyleMaterials.painted_material(id, tint)` factory beside `toon_material()`. Keep all new numbers as `# style:` dials.
7. Re-render the town via `tools/render_compare.tscn` after each material lands.

**Accept:** side by side with the anchor, the town's ground and walls read as *surfaces*, not as coloured boxes.

> **Why tileable + triplanar rather than per-asset UV textures:** no UV unwrapping, no per-asset texture generation, no atlas management, and total consistency for free. Ten materials clothe a hundred props. This is the single biggest cost saving in the plan.

---

## Stage 2 — backdrops (cheapest fidelity win on the board)

Rooms are box-walled with `background_color` beyond them; the anchor's entire top-right quadrant is scenery you never walk into. A painted band above the wall line buys a lot of depth for one image per stratum.

**HUMAN does:** generate **6 panoramas** (5 strata + town) — 4–8 variants each, pick one. Prompt shape: `painterly {cavern / ruins / void} backdrop, wide panorama, dusk, desaturated, atmospheric depth, no foreground detail, no characters`.
**AGENT does:** build a `StyleBackdrop` helper (a cylinder or curved plane on an unshaded material, `style_skip` metadata so the sweep leaves it alone, drawn behind the walls and above the horizon line), plus a per-floor `backdrop` key in `data/floors/*.json` mirroring the existing optional `ramp` key.
**Accept:** the horizon reads as somewhere, not as a flat colour.

---

## Stage 3 — props & buildings (volume)

**The rule that makes the budget work: Tripo generates GEOMETRY. Its textures are discarded.** Tripo's meshes are decent; its textures are mush. Skipping retexture also stretches the credit budget a long way.

**HUMAN does:**
1. *(Recommended)* Generate a 2D concept first with the style anchor as reference, then use **image→3D** — far more controllable than text→3D, and it is how style crosses from the anchor into geometry. Generic clutter can be text→3D or CC0 stock.
2. Poly budget: small props 300–1.5k tris, furniture 1–3k, buildings 2–8k. Lowest count that holds the **silhouette at camera distance** — never the raw sculpt.
3. Judge silhouettes against the old **town anchor** (chunky masses, oversized roofs, squat walls — that is still its job).

**AGENT does:**
4. Import preset "Prop" (root Node3D, no skeleton). Auto-LOD on; the fixed camera never switches meaningfully.
5. **Strip the generated texture**, apply the Stage 1 material by role.
6. Collision: simple primitives from the mesh AABB in the **inherited scene** — never "generate from visual mesh" for gameplay-critical props.
7. Render through `tools/render_prop.tscn`; append the row to `design/asset-list.md`.

**CC0 stock, reconsidered.** Quaternius / Kenney / KayKit are free, so the budget constraint doesn't touch them, and under this plan their weakness stops mattering — their flat-colour textures were the problem, and those get discarded anyway. **They are now blockout geometry / silhouette donors.** (KayKit was removed 2026-08-10 after a test; it can come back on these terms.)

> **The known weak link:** faceted low-poly under soft painterly light shows its facets. Acceptable on placeholders. If it survives into real assets, the fix is a Blender smoothing/decimation pass — the one place the gen-AI-only constraint costs something real.

**Foliage — the exception, and a big one.** Flowers, grass, vines and bushes are a large fraction of the anchor's frame and should **not** be modelled. Generate alpha-cut **card textures** (2D, cheap, gen-AI is great at it) and scatter them on `MultiMesh`. Highest coverage-per-effort in the entire pipeline. A `GrassPatch` precedent already exists.

---

## Stage 4 — characters (the expensive category)

**The one place generated textures are KEPT** — faces and clothing need unique albedo. Grade them toward the palette rather than replacing them.

**HUMAN does:**
1. Generate a 2D character sheet (front + ¾, **T-pose**, flat background) with the style anchor → feed **image→3D**.
2. Tripo generate, low-poly/retopo, 3k–10k tris. Save the prompt beside the asset.
3. Auto-rig: Tripo's built-in (standard biped names; weak shoulders, irrelevant top-down). Fallback **AccuRig 2** (free, cleanest weights — normalize scale/orientation first). Mixamo last resort. **Avoid Meshy's rig** (bad hip placement, non-standard names).
4. Export **uncompressed .glb** — Godot has NO Draco support; a Draco glb errors on import.

**AGENT does:**
5. Advanced Import → Skeleton3D → Retarget → **BoneMap + SkeletonProfileHumanoid**. Fix magenta bones (one wrong bone silently ruins everything). **Save the BoneMap as `.tres`** in `assets/anims/bonemaps/` — reused by every character from the same generator.
6. Rest-pose fixers (where retargets live or die): **Overwrite Axis ON**, **Fix Silhouette ON** if A-posed, Remove Tracks → Unimportant Positions + Unmapped Bones ON, **Normalize Position Tracks ON** on animation imports (one clip set serves different-sized characters without foot-skating).
7. Import **Quaternius UAL 1+2 ONCE** as a shared Animation Library (`assets/anims/ual_library.res`) with its own BoneMap; per character, link the library + the shared AnimationTree. Use **in-place** clips — velocity is code-driven.
8. Keep the model on `NEUTRAL_RAMP` (the readability guard) and grade its albedo toward the palette.

**Failure table:** crumpled ball = BoneMap mis-assignment · T-pose slide = library not retargeted · foot slide = stray position tracks, use in-place clips · 100× scale = FBX cm vs glTF m (fix import root scale) · twisted forearms = missing Fix Silhouette / Overwrite Axis. Blender is an escape hatch only (decimate, delete junk nodes, merge clips). Community BoneMap references: `catprisbrey/Godot4-OpenAnimationLibraries`.

---

## Stage 5 — 2D icons / portraits / illustrations

Icons 2–5 min each, portraits 10–15 min, after ~1 hr of anchor work per class.

1. One locked **style anchor per class** (icon, portrait, tech card) — never generate the ~110-icon set before 3–5 approved refs exist. All generation via style-reference (Recraft custom style; Gemini multi-ref for portraits: one approved portrait per character → all emotions derived from it, so faces never get re-described — the aphantasia fit).
2. Batch post-process, fully agent-scriptable: **rembg** (`rembg p in/ out/`, model `isnet-general-use`) → **ImageMagick** (`magick in.png -trim +repage -resize 256x256 -gravity center -background none -extent 256x256 out.png`).
3. **PNG, not SVG** (AI output is raster; Godot's SVG import is limited). UI textures: Mipmaps OFF, Filter Linear, lossless. Portraits on 3D quads get mipmaps. Commit `.import` sidecars.
4. Text in diagrams: generate **unlabeled** line art and add labels in Godot — sidesteps both bad AI text and localization.

> The Ember HUD's ability marks and resource crystals are **code-drawn vector glyphs** with a single swap point (`EmberHud._glyph()`), so the run HUD has no asset-gate dependency at all. Swapping them for icons is optional polish, not a blocker.

---

## Stage 6 — VFX (in-engine, not gen-AI)

Gen-AI is the wrong primary tool here — combat-VFX quality lives in timing curves, authored in-engine.

1. Primary: **GPUParticles + shaders**, adapting `haowg/GODOT-VFX-LIBRARY` (35+ Godot 4 effects), Kenney Particle Pack, MrMinimal flipbooks (all CC0).
2. Slash arcs: textured quad/trail + scrolling alpha gradient over ~0.15s. The swoosh texture is one grayscale image — trivially AI-generatable.
3. AI's role: one-off flipbook sheets and static particle textures (smoke wisp, rune glyph). **Combat-readability quality unverified — trial one before depending on it.**
4. Particle colours come from the palette's **reserved gameplay hues** (§ style-bible, combat compatibility) with additive blending — they must stay the most saturated things on screen.

---

## Tool stack

| Slot | Tool | Cost | Notes |
|---|---|---|---|
| **2D materials, backdrops, icons, cards** | **Recraft** ([recraft.ai](https://www.recraft.ai/pricing)) | $10/mo Basic, 1000 credits, full ownership | **Now the primary tool** (was secondary). Custom style locked from 3–5 uploaded refs. ⚠ Confirm in-app that Basic includes custom styles before subscribing. |
| 3D geometry + auto-rig | **Tripo Pro** ([tripo3d.ai](https://www.tripo3d.ai/pricing)) | ~$14–20/mo, ~120 models/mo | Polycount control, quad retopo, .glb; only tool with quadruped/serpentine rigs → monsters. **Textures discarded for props** → credits go much further than the old plan assumed. |
| Portraits + diagrams | Gemini image API / GPT Image | pay-as-you-go, ~$3–10/mo | Multi-ref portraits; unlabeled diagrams. |
| Animations | **Quaternius UAL 1+2** (CC0) + Tripo auto-rig; AccuRig 2 / Mixamo fallback | $0 | UAL2 (Jan 2026): 130+ clips incl. per-hit melee combos with recoveries; root-motion AND in-place; explicit Godot support. |
| Blockout geometry | Quaternius / Kenney / KayKit (CC0) | $0 | Silhouette donors; their textures are discarded. |
| VFX | Godot particles + CC0 shader libraries | $0 | See Stage 6. |
| $0 endgame (needs 12–16 GB GPU) | ComfyUI + a style LoRA trained on Recraft keepers · TRELLIS (MIT, local text→3D) · VNCCS | $0 | Bootstrap style in paid tools, then generate unlimited on-style locally. FLUX.2-dev outputs are NOT commercial-safe; use FLUX.2 klein 4B (Apache 2.0) / SDXL. |

**Skip:** Meshy as primary (non-standard bone names) · Rodin (photoreal, pricey) · **Hunyuan3D (license excludes the EU — we are in Germany)** · Midjourney (style-adjacent, not style-locked) · Luma Genie / withpoly (dead).

**Rough monthly:** a Recraft-only month (~$10) covers Stages 1, 2 and 5. Add Tripo only for the months you actually generate geometry.

---

## The aphantasia workflow (how taste decisions work without a mind's eye)

1. **Externalize the moodboard.** Per class, generate 20–30 wildly varied candidates; human picks survivors; 2–3 rounds. Winners become the style bible — a checked-in folder that *is* the visual imagination.
2. **Lock style before volume.** Never generate the set until 3–5 approved refs exist. All consistency mechanisms are image-upload based — zero drawing anywhere.
3. **Batch-and-pick over prompt-perfecting.** 4–8 variants per asset; comparative judgment ("which of these is right?") works fine without visualization.
4. **Every accept/reject is a side-by-side on screen, never against memory.**

## Validation loop (screenshots replace the mind's eye)

- `tools/render_compare.tscn` → the whole frame beside the anchor. **Also the shader's only validation** — GLSL cannot compile headless.
- `tools/render_prop.tscn` → one prop at the game camera under the project environment.
- **Wanted:** a lineup mode (instance every asset of a class in a grid under the real camera) — judging 20 in context beats one in a turntable. Build it when Stage 3 volume starts.
- **Wanted:** an asset lint in the test suite listing missing/orphaned assets vs `data/` defs, once the first real assets land.

## Project organization + agent conventions

```
assets_src/            # .gdignore'd — Godot never imports it
  anchors/             # style-bible reference images
  prompts/             # per-asset generation prompt .txt, named like the asset
  raw/                 # raw generator downloads pre-cleanup
assets/
  models/{characters,props,buildings}/   # id matches the data/ def key
  anims/               # ual_library.res, bonemaps/*.tres
  images/{icons,portraits,cards}/
  materials/           # shaders, ramps, the Stage 1 tileable set
  vfx/
```

- **Never edit imported glb scenes — inherit them.** Regenerating the glb over the old file keeps all wiring intact.
- **Naming = the data key** (`enemy_skitterer` def ⇔ `.glb` ⇔ `.tscn`) so agents can wire assets mechanically.
- **Post-import automation:** an `EditorScenePostImport` script in the preset auto-applies materials, strips generator junk, adds AABB collision — the glue that makes per-asset cost near-zero. **Build this at the start of Stage 3**, not after.
- Keep `assets_src/` in git (prompt→asset provenance enables regeneration). Binaries + `.import` committed; LFS past ~1 GB.

## Licensing (for the eventual commercial ship)

- **Steam AI disclosure (rules of 2026-01-16):** shipped AI-generated content must be disclosed in the Content Survey — disclosure, not prohibition. AI code assistants explicitly exempt: Tripo models and Recraft textures = disclose; Claude-written GDScript = exempt.
- Raw AI output isn't copyrightable (USCO 2025 guidance); the human selection / rigging / kitbash passes are. Paid-tier "ownership" is contractual + privacy, still worth paying for.
- **Non-commercial traps:** Tripo free (public + no commercial), Recraft free, Scenario free, FLUX.2-dev outputs, DeepMotion/Rokoko free. **EU trap:** Hunyuan3D. **Attribution:** Meshy free, any CC-BY (a credits screen suffices).
- The all-CC0 stock stack carries zero obligations. Sketchfab free downloads are terminal — archive any CC0/CC-BY finds now, with a licence screenshot.

## Time estimates (steady state, after Stage 1)

Material 10–20 min · backdrop 10–15 min · prop 10–20 min · building 20–40 min · character 30–60 min · icon 2–5 min · portrait 10–15 min · VFX effect 30–60 min. Stage 1 itself: one focused session.

## Open / unverified (re-check before relying)

- **Tripo-rig ↔ UAL retarget in Godot specifically** — components individually verified, the exact combo has no published write-up. **Stage 0 IS the experiment.**
- Triplanar + the painted shader at the town's scale — perf unmeasured (expected fine on Forward+ desktop).
- Recraft Basic's inclusion of custom styles — confirm in-app first.
- AI flipbooks for combat-readable VFX.
- Whether faceted CC0 geometry survives soft painterly light without a Blender pass (§ Stage 3).
- Pricing across the whole table is 2026-07-11 research — **re-verify before subscribing.**
