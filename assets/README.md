# Assets & the 2.5D pipeline

How art gets into Tycho. **Placeholder-first everywhere** — never block a system on final art (`design/godot-conventions.md`). The working default is 2.5D: 3D models on the fixed camera.

> **WHAT to make:** `design/asset-list.md` (the living master inventory — content chunks append to it). **HOW to make it** (tool stack, per-type workflows, style unification, licensing): `design/asset-pipeline.md`. This file keeps the folder layout + the pipeline gate.

```
assets/
  models/   # 3D models (.glb) — Tripo / Quaternius imports
  anims/    # animation libraries (Quaternius / Universal Animation Library)
  images/   # painterly 2D (portraits, cutscene stills, tech cards)
  audio/    # music, SFX
```

Commit the imported binaries + their `.import` sidecars for now (revisit Git LFS past ~1 GB).

---

## The asset-pipeline gate (Phase 0 gate 3)

**Goal:** prove ONE character can go end-to-end — Tripo model → rig → Quaternius/UAL animation retarget → **animated in Godot under the fixed camera** — before committing to any 3D art line item. Failure is **not** a project no-go; the fallbacks are stock Quaternius models or learning Blender.

**Gate scene:** `scenes/core/asset_pipeline_gate.tscn` (script `src/core/character_stage.gd`). It uses the same `camera_rig.tscn` the real game uses, finds the model's `AnimationPlayer`, force-loops each clip, and plays them so you can judge how the rig + retarget read at the game's camera angle. **A/D** cycle clips, **Space** toggles a turntable. With no model present it runs a bobbing placeholder capsule and tells you the gate isn't validated yet.

### Steps to validate the gate

1. **Model** — generate a character in [Tripo](https://www.tripo3d.ai/) (or grab a stock [Quaternius](https://quaternius.com/) model as the fallback path). Export/obtain a `.glb`.
2. **Rig** — ensure it has a humanoid skeleton. Tripo can auto-rig; otherwise rig in Blender. Aim for a Mixamo/standard-humanoid bone layout so retargeting is clean.
3. **Animate / retarget** — pull idle + walk + an attack clip from the [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) (or Mixamo) and retarget onto the rig (Blender, or Godot 4's retargeting on import).
4. **Export** — a single `.glb` containing the mesh, skeleton, and the animation clips.
5. **Drop it in** — save as `res://assets/models/gate_character.glb` (the default drop-point), or assign your imported scene to the `model_scene` field on the gate node in the inspector.
6. **Run the gate scene** and judge: does it read well at the fixed camera angle? Do the clips retarget without obvious deformation? Cycle the clips (A/D), watch the turntable (Space).

### Pass / fail

- **Pass** → the 2.5D pipeline assumption holds; 3D character/enemy art lines can proceed (still placeholder-first, gated per `design/content-budget.md`).
- **Fail** (rigging/retarget too painful or it looks wrong at the camera) → fall back to stock Quaternius models, or budget time to learn Blender. Record the outcome in `CLAUDE.md` status either way.

> The combat-feel gate (`scenes/combat/feel_room.tscn`) deliberately uses primitive placeholders and does **not** depend on this gate — feel is validated independently. A passing asset gate can later feed nicer placeholder-plus models into the feel room.
