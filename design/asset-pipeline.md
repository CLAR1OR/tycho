# Asset pipeline — tools, stack, and workflows

> **How assets get made and brought into the game.** Researched 2026-07-11 (web-verified pricing/licensing as of that date — re-verify before subscribing; this market moves fast). The inventory of WHAT to make: `design/asset-list.md`. The folder layout + the pipeline gate: `assets/README.md`. Human owns all taste decisions; agents own the mechanical steps.
>
> **Status:** research + plan. Nothing here is proven in-project until the asset-pipeline gate runs (`scenes/core/asset_pipeline_gate.tscn` — still Phase 0's open gate 3).

## The one strategic finding (read this even if you skip the rest)

**Don't try to make AI outputs match each other at generation time — you can't, reliably. Unify in-engine instead.** Generation buys *shape*; Godot buys *style*: one toon/ramp shader on every 3D mesh + one outline pass + one project palette makes wildly mismatched gens read as one game. Doubly right for Tycho: the fixed top-down camera hides most texture detail anyway, and the per-stratum ramp swap maps 1:1 onto the existing env-profile data. **The unification layer is a first-class pipeline stage, not polish** — build it before generating assets in volume.

## Recommended stack (~$24/mo fixed + ~$5 pay-as-you-go — under budget)

| Slot | Tool | Cost | Why |
|---|---|---|---|
| 3D models + auto-rig + retexture | **Tripo Pro** ([tripo3d.ai](https://www.tripo3d.ai/pricing)) | $13.93/mo promo ($19.90 list); ~120 models/mo | Still best-in-class for stylized game assets (polycount control, quad retopo, .glb); only tool with quadruped/serpentine rigs → monsters. **Free tier outputs are PUBLIC + commercial rights are paid-only — run the gate and anything that ships on a paid month.** |
| Icons / UI / vector (custom style) | **Recraft Basic** ([recraft.ai](https://www.recraft.ai/pricing)) | $10/mo, 1,000 credits, full ownership | Custom style locked from 3–5 uploaded refs; documented ~100-icon consistent runs — built for exactly our ~50-echo + ~60-other icon problem. ⚠ Confirm in-app that Basic includes custom styles + SVG before subscribing (the one stack-critical unknown). |
| Portraits (emotion sets) + science diagrams | **Gemini image API ("Nano Banana 2") / GPT Image** | pay-as-you-go, ~$3–10/mo at our volume | One approved portrait per character → all emotions derived from it (no re-describing faces — the aphantasia fit). GPT Image/Ideogram for legible-text diagrams; better: generate unlabeled line art, add labels in Godot (solves localization). |
| Animations | **Quaternius UAL 1+2** (CC0) + Tripo auto-rig; AccuRig 2 / Mixamo free fallbacks | $0 | UAL2 (Jan 2026): 130+ clips incl. per-hit melee combos with recoveries — maps onto Hades-style chains; root-motion AND in-place variants (use **in-place**; velocity is code-driven); explicit Godot support. |
| Stock models | **Quaternius + Kenney + KayKit** (all CC0) | $0 | KayKit is the new addition: Dungeon Pack Remastered (200+ modular top-down pieces) + rigged Adventurers/Skeletons — style-compatible with the others. Mix freely under the unification shader. |
| Textures | Palette atlas / vertex colors; ambientCG + PolyHaven CC0 if ever needed | $0 | **We probably need no texture generation at all** — flat-colour low-poly under a fixed camera is the palette-atlas workflow; keeps look inside the human-dialed strata palettes. |
| VFX | Godot GPUParticles + shader libraries (haowg/GODOT-VFX-LIBRARY, Kenney Particle Pack CC0, MrMinimal flipbooks CC0) | $0 | Gen-AI is the wrong primary tool for combat VFX — feel lives in timing curves, authored in-engine. |
| Occasional months | Scenario ($45/mo, train a private style model) · Cascadeur Indie ($8/mo annual, AI-assisted one-off clips e.g. boss telegraphs) | on demand | Rent for a big themed batch, don't keep year-round. |
| $0 endgame (optional, needs 12–16GB GPU) | TRELLIS (MIT, local text→3D) · ComfyUI + style LoRA (train on Recraft keepers) · VNCCS (local character×emotions) | $0 | Bootstrap style in paid tools, then generate unlimited on-style locally. FLUX.2-dev outputs are NOT commercial-safe; use FLUX.2 klein 4B (Apache 2.0)/SDXL. |

**Skip:** Meshy as primary (non-standard bone names; keep its free tier as a second opinion — attribution required), Rodin (photoreal-leaning, pricey), **Hunyuan3D (license excludes the EU — we're in Germany)**, Midjourney (style-adjacent, not style-locked; no free tier), Luma Genie (dead), withpoly.com (dead).

## The aphantasia workflow (how taste decisions work without a mind's eye)

1. **Externalize the moodboard.** For ONE canonical object per class (a health-flask icon, one portrait, one dungeon wall), generate 20–30 wildly varied style candidates; the human picks survivors; iterate 2–3 rounds. The winners become the **style bible** — a checked-in folder of reference images that *is* the visual imagination, externalized (`assets_src/anchors/` + `design/style-bible.md` — **STARTED 2026-07-12** with the human-picked town anchor; the bible carries the extracted palette + the five look-carriers + the judging protocol).
2. **Lock style before volume.** Never generate the 100-icon set until 3–5 approved refs exist; feed them to Recraft's custom style (or a LoRA). All consistency mechanisms are image-upload based — zero drawing anywhere.
3. **Batch-and-pick over prompt-perfecting.** Generate 4–8 variants per asset; comparative judgment ("which of these is right?") works fine without visualization; regenerate the bottom 20%.
4. **Every accept/reject is a side-by-side on screen against the bible, never against memory.** Agents produce contact-sheet screenshots (see Validation loop); human decisions take seconds.

## Per-asset-type pipelines

### A. Animated character (Tycho, enemies, bosses, NPCs) — first: half a day (the gate); steady state 30–60 min

1. *(Recommended)* Generate a 2D character sheet first (front + ¾, **T-pose**, flat background) with the style anchor → feed **image→3D** (more controllable than text→3D; this is how style crosses characters).
2. **Tripo** generate, low-poly/retopo output, 3k–10k tris (detail beyond that is invisible top-down). Save the prompt next to the asset.
3. **Auto-rig:** Tripo's built-in (standard biped names; weak shoulders — irrelevant top-down). Fallback: **AccuRig 2** (free, cleanest weights; normalize scale/orientation first). Mixamo = last resort (zombie-mode but alive). Avoid Meshy's rig (bad hip placement, non-standard names).
4. Export **uncompressed .glb** (Godot has NO Draco support — a Draco glb errors on import).
5. Godot: Advanced Import → Skeleton3D → Retarget → **BoneMap + SkeletonProfileHumanoid**; fix any magenta bones (one wrong bone silently ruins everything). **Save the BoneMap as `.tres`** (`assets/anims/bonemaps/`) — reused by every character from the same generator.
6. Rest-pose fixers (where retargets live or die): **Overwrite Axis ON**, **Fix Silhouette ON** if A-posed, Remove Tracks → Unimportant Positions + Unmapped Bones ON, **Normalize Position Tracks ON** on animation imports (one clip set serves different-sized characters without foot-skating).
7. **UAL imported ONCE** as a shared Animation Library (`assets/anims/ual_library.res`) with its own BoneMap; per character just link the library + the shared AnimationTree.
8. **Judge in the gate scene** at the real camera angle before accepting.

Failure table: crumpled ball = BoneMap mis-assignment; T-pose slide = library not retargeted; foot slide = stray position tracks / use in-place clips; 100× scale = FBX cm vs glTF m (fix import root scale); twisted forearms = missing Fix Silhouette/Overwrite Axis. Blender's role: escape hatch only (decimate, delete junk nodes, merge clips). Community BoneMap references: catprisbrey/Godot4-OpenAnimationLibraries.

### B. Static props & buildings — 10–20 min each; a themed set of 10 per afternoon

1. Tripo (or TRELLIS locally) from style-locked concept image; generic clutter can be text→3D or stock (Quaternius/Kenney/KayKit).
2. Poly budget: small props 300–1.5k tris, furniture 1–3k, buildings 2–8k — lowest count that holds the **silhouette at camera distance**; never the raw 100k sculpt.
3. Import preset "Prop" (root Node3D, no skeleton). LODs: leave Godot's auto-LOD on, no manual work (fixed camera never switches meaningfully).
4. Collision: simple primitives (box/capsule from mesh AABB — agent-addable programmatically) in the **inherited scene**; never "generate from visual mesh" for gameplay-critical props. (`-col` suffixes work on *node* names only.)
5. Apply the unification material (below) + palette; screenshot in the lineup scene.

### C. Style unification layer (build FIRST, before volume) — 1–2 days once, then dial-tuning

> **BUILT 2026-07-11** — `tycho_toon.gdshader` + `tycho_outline.gdshader` + `StyleCore`/`StyleMaterials` (`src/core/`); per-floor optional `ramp` env key; characters on `NEUTRAL_RAMP` + outline, town on `TOWN_RAMP`, room geometry/props on the derived stratum ramp; skip rules protect all unshaded/translucent FX; `feel_room` exempt. All values are `# style:` dials (`design/feel-tuning.md` § Style unification).

1. **One toon/cel shader** on every 3D mesh (adapt Flexible Toon Shader / Complete Toon Shader from godotshaders.com): 2–4 light bands, single-dominant-light trick so multi-light rooms don't fragment the look.
2. **One ramp/gradient texture per stratum** drives band colours (shadows toward OUR hue regardless of what the AI baked) — the highest-leverage dial; maps straight onto `data/floors/*.json` env profiles.
3. **Palette discipline:** props/buildings = discard AI textures, flat per-surface materials from a project palette constant (or Gradient Snapper in Blender for atlas UVs); hero characters = keep AI albedo but posterize/LUT toward the palette in-shader, or Meshy Retexture to converge.
4. **One outline pass** — inverted hull via `next_pass` (cull_front, normals push); separates characters from floor at top-down distance. Gotcha: hard-edged low-poly needs smooth normals or the vertex-colour-width variant.
5. All style numbers (band count, ramps, outline width, palette hexes) are **`# style:` dials on the dial board** (`design/feel-tuning.md` pattern) — human-tunable, agent-untouchable.

### D. 2D icons / portraits / illustrations — icons 2–5 min, portraits 10–15 min (after ~1 hr anchor per class)

1. One locked **style anchor** per class (icon, portrait, tech card); all generation via style-reference (Recraft custom style; Gemini multi-ref for portraits).
2. Batch post-process locally, fully agent-scriptable: **rembg** (`rembg p in/ out/`, model `isnet-general-use`) → **ImageMagick** (`magick in.png -trim +repage -resize 256x256 -gravity center -background none -extent 256x256 out.png`).
3. **PNG, not SVG** (AI output is raster; Godot's SVG import is limited). Import: UI textures **Mipmaps OFF, Filter Linear**, lossless; portraits-on-3D-quads get mipmaps. Commit `.import` sidecars (existing policy). No hand-built atlases at our scale.

### E. VFX — first 5-effect kit ~1 day, then 30–60 min/effect

1. Primary: **GPUParticles + shaders** adapted from haowg/GODOT-VFX-LIBRARY (35+ action effects, Godot 4) + Kenney Particle Pack + MrMinimal flipbooks (all CC0).
2. Slash arcs: textured quad/trail + scrolling alpha gradient over ~0.15s (Gabriel Aguiar's Godot method); the swoosh texture is one grayscale image — trivially AI-generatable.
3. AI's role: one-off flipbook sheets + static particle textures (smoke wisp, rune glyph). Quality for combat-critical readability **unverified — trial one before depending on it**. EmberGen = overkill for v1.
4. Particle colours from the project palette + additive blending → matches the toon world automatically.

## Project organization + agent conventions

```
assets_src/            # .gdignore'd (empty .gdignore file inside) — Godot never imports it
  anchors/             # style-bible reference images (the externalized imagination)
  prompts/             # per-asset generation prompt .txt, named like the asset
  raw/                 # raw generator downloads pre-cleanup
assets/
  models/{characters,props,buildings}/   # id matches the data/ def key
  anims/               # ual_library.res, bonemaps/*.tres
  images/{icons,portraits,cards}/
  vfx/                 # flipbooks + particle scenes
  materials/           # tycho_toon.gdshader, ramps/, palette.tres
```

- **Never edit imported glb scenes — inherit them** (`prop_crate_a.tscn` inherits the glb, adds collision + toon material); regenerating the glb over the old file keeps all wiring intact.
- **Naming = the data key** (`enemy_skitterer` def ⇔ `enemy_skitterer.glb` ⇔ `enemy_skitterer.tscn`) so agents wire assets mechanically; **build a lint** listing missing/orphaned assets vs defs into the test suite when the first real assets land.
- **Post-import automation:** an `EditorScenePostImport` script in the preset auto-applies the toon material, strips generator junk, adds AABB collision — the glue that makes per-asset cost near-zero.
- Keep `assets_src/` in git (prompt→asset provenance enables regeneration); binaries + `.import` committed; LFS past ~1 GB (existing policy).

## Validation loop (screenshots replace the mind's eye)

1. **Lineup scenes** generalizing the gate: `prop_lineup.tscn` / character lineup instancing every asset in a grid under the REAL camera + toon shader. Judging 20 in context beats one in a turntable.
2. Agents auto-screenshot (`get_viewport().get_texture().get_image().save_png()`; windowed run or `--write-movie` — real rendering, not `--headless`) into contact sheets; human picks against the style bible.
3. Per asset: 3–4 candidates → lineup → screenshot → pick/reject vs bible → losers deleted, winner's prompt saved beside it.

## Licensing (for the eventual commercial ship)

- **Steam AI disclosure (rules of 2026-01-16):** shipped AI-generated content must be disclosed in the Content Survey (store-page section; disclosure, not prohibition). AI code assistants explicitly exempt. Tripo models = disclose; Claude-written GDScript = exempt.
- Raw AI output isn't copyrightable (USCO 2025 guidance); our human selection/rigging/kitbash passes are. Paid-tier "ownership" = contractual + privacy, still worth paying for.
- **Non-commercial traps:** Tripo free (public + no commercial), Recraft free, Scenario free, Cascadeur free (no FBX export anyway), FLUX.2-dev outputs, DeepMotion/Rokoko free. **EU trap:** Hunyuan3D. **Attribution:** Meshy free, Anything World, any CC-BY (credits screen suffices).
- The all-CC0 stock stack (Quaternius/Kenney/KayKit/PolyHaven/ambientCG) carries zero obligations.
- Sketchfab free downloads are terminal — archive any CC0/CC-BY finds now with a license screenshot.

## Time estimates (steady state, after pipeline setup)

Character 30–60 min · prop 10–20 min · building 20–40 min · icon 2–5 min · portrait 10–15 min · VFX effect 30–60 min · unification layer 1–2 days once.

## Open / unverified (re-check before relying)

- **Tripo-rig ↔ UAL retarget in Godot specifically** — all components individually verified, the exact combo has no published write-up; **the gate run IS the experiment**. (Tripo also ships preset animations at rig time — could shortcut the gate if UAL fights back; quality unverified.)
- Recraft Basic's inclusion of custom styles + SVG (vs a higher tier) — confirm in-app first.
- AI flipbooks for combat-readable VFX; Polycam texture-tool license; Tripo per-operation credit costs; Gemini/GPT image API prices (secondhand sources).
