# Feel-Tuning Knobs — the combat-feel gate

> **Purpose:** one place that lists every number you can turn to tune how the Phase 0
> combat-feel gate *feels*, what each one does, and exactly where to change it. This is
> the dial board for the go/no-go playtest (CLAUDE.md → Build order, Phase 0; pass bar:
> *after the 20th clear, you still want one more*).
>
> **Game feel cannot be vibecoded** — these are meant for hands-on human iteration. Tweak,
> run, feel, repeat. Don't let an agent "optimize" or round them away.

---

## ⚡ The fast way: the runtime tuning panel (press **F1** in game)

Since 2026-07-01 the sandbox has a **live tuning panel**: run the game, press **F1**.
The game **pauses**, a slider board opens on the right with the ~35 most important dials
(player, aim assist, hitstop, camera, wave, crowd). Drag sliders, press **F1** again to
resume and *feel* the change — mid-fight, no restart.

- **Changes are live-only** — they do NOT persist. When something feels right, click
  **Copy changed**: the changed values land in your clipboard (and the console), then
  paste them into the file/scene this doc points at.
- **Reset all** puts every slider back to the session's starting values.
- The panel is debug tooling (`src/core/tuning_panel.gd`); both the sandbox
  (`feel_room.gd`) and real dungeon rooms (`combat_room.gd`) spawn it, so F1 works
  mid-run too. In a run, per-instance dials (player/room `@export`s) reset with each
  new room — the shared `static var` dials (hitstop, crowd) stick for the session;
  for uninterrupted tuning use the endless sandbox.
- **Since 2026-07-02 the main scene (F5) is the real game loop** (`game.tscn`: town →
  portal → run). The endless-wave sandbox is still there for pure feel work: open
  `scenes/combat/feel_room.tscn` in the editor and press **F6** (run current scene), or
  `godot --path . res://scenes/combat/feel_room.tscn`.

Everything below is the *persistent* home of each knob — where a value lives once you
commit to it.

> **Weapons vs. these knobs (2026-07-02):** weapon definitions (`data/weapons/`) apply
> as **relative multipliers over these tuned numbers** — the Sword is the baseline with
> no mods at all. Tuning the knobs below tunes the whole arsenal proportionally; the
> F1 panel and "Copy changed" workflow are unaffected. (In a run, the room re-applies
> weapon+echo mods to each fresh player, so panel edits to modded stats last one room —
> use the F6 sandbox for uninterrupted dialing.)

---

## Three kinds of knob — and where each one lives

| Kind | Edited where | Shows in Godot editor? | Live per-instance? |
|------|--------------|------------------------|--------------------|
| **`@export` var** | **F1 panel** (live), Godot **Inspector**, *or* the `.gd` file's default | ✅ Yes — select the node, see the **Inspector** | ✅ Each scene/instance can override it |
| **`static var`** | **F1 panel** (live) *or* the `.gd` file's default | ❌ No — code-only | ❌ One value for the whole class (that's the point — shared rules) |
| **`const`** | Only by editing the `.gd` script file | ❌ No — code-only | ❌ Same value for every instance |

### How to edit an `@export` in the Godot editor
1. Open the scene in the editor (e.g. `scenes/combat/enemy_dummy.tscn`).
2. Click the **root node** in the Scene panel (e.g. `EnemyDummy`).
3. Look at the **Inspector** (right side). The exported vars appear under a
   **"Script Variables"** heading (`Max Hp`, `Move Speed`, `Engage Dist`, …).
4. Change a value → **Ctrl+S**. It's saved into that `.tscn`, so it only affects that variant.

> Godot prettifies names in the Inspector: `move_speed` shows as **"Move Speed"**,
> `engage_dist` as **"Engage Dist"**, etc.
>
> ⚠️ The **player and camera** exports live on instanced scenes. To make a change stick,
> edit the **default in the `.gd` file** (simplest, affects everything), or edit the node
> inside `feel_room.tscn` (sticks to this room only). Pasting the F1 panel's "Copy
> changed" values into the `.gd` defaults is the intended loop.

### How to edit a `const` / a `static var` default
Open the listed `.gd` file in any editor (or Godot's Script tab), change the number after
`:=` / `=`, save. It changes the value for **all** instances.

> **Quick way to find any of these:** search the codebase for `# FEEL:` — every tunable
> is tagged with that comment.

---

## Player — `src/combat/player.gd`  (all `@export` → F1 panel / Inspector / file default)

### Movement
| Var | Default | What it does |
|-----|---------|--------------|
| `move_speed` | 9.0 | Top run speed (m/s). |
| `accel` | 70.0 | How fast you reach top speed (higher = snappier start). |
| `friction` | 80.0 | How fast you stop when you release the keys (higher = less slide). |

### Dash
| Var | Default | What it does |
|-----|---------|--------------|
| `dash_speed` | 30.0 | Burst speed during a dash. |
| `dash_time` | 0.15 | How long the burst lasts (s). |
| `dash_cooldown` | 0.90 | Time before dash is ready again (s). |
| `dash_iframes` | 0.18 | Invulnerability window from dash start (s). Raise to make dashing more forgiving. |
| `ghost_interval` | 0.035 | Seconds between dash after-images (cosmetic trail density). |
| `ghost_color` | pale cyan | After-image tint (cosmetic). Ghost fade/solidity: `src/combat/ghost_fx.gd` (`LIFETIME`, `START_ALPHA`). |

### Light attack — 3-hit combo
| Var | Default | What it does |
|-----|---------|--------------|
| `attack_windup` | 0.05 | Delay before the hitbox goes live (s) — the wind-up. |
| `attack_active` | 0.10 | How long the hitbox stays live (s). |
| `attack_recover` | 0.10 | Lockout after hits 1 & 2 (s). |
| `attack_recover_finisher` | 0.45 | Longer lockout after the 3rd hit (s) — the finisher's commitment. |
| `attack_damage` | 25 | Damage of hits 1 & 2. |
| `attack_damage_finisher` | 50 | Damage of the 3rd hit. |
| `attack_move_mult` | 0.35 | How much you can still move while swinging (0 = rooted, 1 = full speed). |
| `combo_continue_window` | 0.35 | Max gap between hits before the combo resets to hit 1 (s). |
| `swing_arc_deg` | 120.0 | Blade sweep for hits 1 & 2 (degrees) — also the hit cone width. |
| `swing_arc_finisher` | 210.0 | Wider sweep for the 3rd hit (degrees). |
| `blade_alpha` | 0.85 | Blade visual brightness during the swing (cosmetic). |

### Soft aim assist — the attack lunge *(added 2026-07-01)*
Each swing magnetizes a short step toward the nearest enemy in a forward cone, so attacks
connect instead of whiffing by half a metre. Mouse aim is untouched — only the feet cheat.

| Var | Default | What it does |
|-----|---------|--------------|
| `lunge_speed` | 9.0 | Burst speed of the attack step (m/s). **0 switches aim assist off entirely.** |
| `lunge_range` | 4.5 | Max distance to magnet onto an enemy (m). |
| `lunge_cone_deg` | 80.0 | Full width of the "in front of you" cone (degrees). |
| `lunge_stop` | 1.7 | Don't lunge if the target is already this close (m) — prevents overshooting through enemies. |
| `lunge_whiff_mult` | 0.35 | Forward-step strength when no target is found (commitment on a whiff). |
| `lunge_decel` | 45.0 | How fast the lunge bleeds off (m/s²). |

### Getting hit
| Var | Default | What it does |
|-----|---------|--------------|
| `hit_grace` | 0.45 | Post-hit invulnerability (s) so two enemies can't double-tap you on the same beat. |

> `MAX_HEALTH` (100) is still a `const` — not a `# FEEL:` knob but easy to change.
> The literal hitbox **size** is the `Hitbox`/`HitboxViz` node in `scenes/combat/player.tscn`
> (a `BoxShape3D` you can resize in the editor), not a number in the script.

---

## Hitstop — `src/combat/fx.gd`  (`static var` → F1 panel / file default) *(added 2026-07-01)*
The whole-game freeze-frame when a hit lands — where the *weight* comes from.

| Var | Default | What it does |
|-----|---------|--------------|
| `hitstop_scale` | 0.05 | How frozen the freeze is (`Engine.time_scale` during the stop). |
| `hitstop_light` | 0.04 | Freeze on combo hits 1 & 2 (real seconds). |
| `hitstop_finisher` | 0.10 | Freeze on the 3rd-hit finisher. |
| `hitstop_kill` | 0.13 | Freeze on a killing blow (the biggest beat). |

---

## Camera — `src/core/camera_rig.gd`  (all `@export` → F1 panel / Inspector / file default)
| Var | Default | What it does |
|-----|---------|--------------|
| `follow_lerp` | 9.0 | How tightly the camera tracks you (higher = snappier, lower = floatier). |
| `cam_offset` | (0, 25.3, 15.8) *(painted fork, was (0, 12, 7.5))* | Height + pull-back of the fixed camera (the framing). Panel exposes `.y` and `.z`. |
| `cam_pitch` | -58.0 | Downward tilt in degrees — **the 2.5D angle**. |
| `cam_yaw` | 45.0 *(new, painted fork — was structurally 0)* | Rig rotation. 45 = the anchor's corner-on read (two faces of every building visible); 0 = the old axis-aligned framing. **Try 45 / 30 / 0.** |
| `cam_fov` | 40.0 *(painted fork, was Godot's default 75)* | Lower = flatter/more telephoto, which is how the anchor reads. |
| `shake_decay` | 6.0 | How fast a screen-shake settles (higher = snappier). |

> The shake **amount** on getting hit is `shake_on_hit` in `feel_room.gd` (below).

> **`cam_offset` invariant:** `atan(12/7.5) = 58°` — the offset direction IS `cam_pitch`. Scale
> the offset **uniformly**; changing one axis alone aims the camera off the rig and the follow
> silently stops centring. The painted-fork value is the old vector × 2.11, compensating the
> narrower FOV so the framed ground area is roughly unchanged.
>
> **`cam_yaw` ≠ 0 makes WASD camera-relative** (`player.gd::_input_dir`, derived from the live
> camera basis) — dial it freely, including back to 0, without the controls desyncing.
> Square rooms read as **diamonds** at 45°; more varied room shapes are a wanted future change.

---

## Enemies — base behaviour `src/combat/enemy_dummy.gd`
This script is shared by **all five variants** (the Archer, Slammer, and Charger each
`extend` it and override only their engage/strike). It has two layers:

### A) Per-variant stats — `@export` (✏️ Inspector, per variant scene)
Open the variant scene, select its root node, edit in the Inspector. Current values per
variant are in the table further down ("Per-variant stat sheet").

| Export (Inspector name) | What it does |
|-------------------------|--------------|
| `max_hp` (Max Hp) | Hit points. |
| `move_speed` (Move Speed) | Chase / close / kite speed (m/s). |
| `engage_dist` (Engage Dist) | Orbit stand-off radius — how far out it circles you (m). |
| `stop_range` (Stop Range) | Melee: closes to here, then strikes (m). *(unused by Archer)* |
| `attack_range` (Attack Range) | Melee: max reach of a strike (m). *(unused by Archer)* |
| `telegraph_time` (Telegraph Time) | Tell duration before a strike — **the player's reaction window** (s). |
| `strike_time` (Strike Time) | Active hit window (s). |
| `recover_time` (Recover Time) | Punish window right after a strike (s). |
| `rest_time` (Rest Time) | Orbit-and-breathe pause before re-engaging (s). |
| `attack_damage` (Attack Damage) | Damage per strike (Archer: per arrow). |
| `knockback` (Knockback) | How far a *player* hit shoves it. |
| `stagger_time` (Stagger Time) | **Hit-interrupt** (s): a player hit cancels whatever it was doing (incl. a telegraph!) for this long. **0 = armored** — powers through. *(added 2026-07-01)* |
| `sight_range` (Sight Range) | How close you must be for it to notice you (m). Needs line of sight too. |
| `base_color` (Base Color) | Body colour (also dimmed when dormant). Cosmetic / readability. |

### B) Shared crowd rules — `static var` (F1 panel / file default; one value for ALL enemies)
| Var | Default | What it does |
|-----|---------|--------------|
| `max_attackers` | 2 | How many **melee** enemies may commit to attacking at once (crowd readability). Archers are exempt. |
| `circle_speed_mult` | 0.7 | Orbit speed vs. charge speed (lower = they circle more lazily). |
| `close_timeout` | 1.5 | Melee gives up a charge if it can't reach a kiting player in this long (s). |
| `separation_radius` | 2.2 | Enemies start pushing apart within this distance (m) — anti-stacking. |
| `separation_force` | 7.0 | How hard they spread. |

### C) Shared behaviour — `const` (code-only)
| Const | Default | What it does |
|-------|---------|--------------|
| `WANDER_SPEED_MULT` | 0.35 | Idle stroll speed vs. `move_speed` (how briskly dormant enemies wander). |
| `WANDER_RADIUS` | 6.0 | How far each idle stroll point is (m). |
| `WANDER_BOUND` | 24.0 | Keeps stroll points inside the room (m from centre). Leave unless you resize the room. |
| `SIGHT_LOSE_MARGIN` | 7.0 | They lose interest and go dormant past `sight_range + this` (m). Higher = stickier aggro. |
| `SIGHT_HEIGHT` | 0.7 | Eye height for the line-of-sight ray (m). Structural; rarely touched. |
| `IDLE_DARKEN` | 0.4 | How much dimmer a dormant enemy looks (readability). |

---

## Archer extras — `src/combat/enemy_archer.gd`
Adds two more `@export`s (✏️ Inspector, on `enemy_archer.tscn`):

| Export (Inspector name) | Default | What it does |
|-------------------------|---------|--------------|
| `shoot_range` (Shoot Range) | 11.0 | Max distance it will loose an arrow (m). |
| `min_range` (Min Range) | 6.0 | Backs away (kites) if you get closer than this (m). |

### Arrow projectile — `src/combat/arrow.gd` (`const`, code-only)
| Const | Default | What it does |
|-------|---------|--------------|
| `SPEED` | 17.0 | Arrow travel speed (m/s). Lower = more dodgeable. |
| `LIFETIME` | 3.0 | Seconds before an arrow that hit nothing despawns. |

> Arrow **size/look** is the mesh + `SphereShape3D` in `scenes/combat/arrow.tscn` (editor).

---

## Slammer extras — `src/combat/enemy_slammer.gd` *(added 2026-07-06)*
The AoE-after-windup enemy: lumbers in, paints a growing **ground circle**, then slams;
armored (stagger 0), so you *dodge* the slam (dash out — dash i-frames cover it), you don't
cancel it. Adds two `@export`s (✏️ Inspector, on `enemy_slammer.tscn`) on top of the base stats.

| Export (Inspector name) | Default | What it does |
|-------------------------|---------|--------------|
| `slam_range` (Slam Range) | 3.5 | Distance at which it commits to a slam (m). |
| `slam_radius` (Slam Radius) | 3.2 | AoE radius of the slam — and of the ground-circle telegraph (m). |

> The **windup length** (your reaction/dodge window) is the base `telegraph_time` (0.9 — long
> on purpose). Slam **damage** is the base `attack_damage` (28). All placeholders.

## Charger extras — `src/combat/enemy_charger.gd` *(added 2026-07-06)*
Locks on, paints a brief **line telegraph**, then dash-charges down it; hits you on contact,
overshoots, and is left briefly stunned + vulnerable (longer if it slams a wall). Squishy;
staggerable except mid-charge. Adds five `@export`s (✏️ Inspector, on `enemy_charger.tscn`).

| Export (Inspector name) | Default | What it does |
|-------------------------|---------|--------------|
| `charge_range` (Charge Range) | 10.0 | Distance at which it locks on and charges (m). |
| `charge_speed` (Charge Speed) | 22.0 | Dash-charge speed (m/s). |
| `charge_time` (Charge Time) | 0.55 | How long the charge runs (m ~ range/speed). |
| `contact_radius` (Contact Radius) | 1.7 | Charge hitbox radius vs the player (m). |
| `wall_stun_bonus` (Wall Stun Bonus) | 0.8 | Extra RECOVER stun after slamming a wall (s). |

> The **aim/lock window** is the base `telegraph_time` (0.4 — brief); the post-charge stun is
> the base `recover_time` (0.9), plus `wall_stun_bonus` on a wall hit. All placeholders.

---

## Per-variant stat sheet (current `@export` values)
What each variant scene currently sets. Edit these in the Inspector (open the scene → root node).

| Stat | **Brute** `enemy_dummy.tscn` | **Skirmisher** `enemy_skirmisher.tscn` | **Archer** `enemy_archer.tscn` | **Slammer** `enemy_slammer.tscn` | **Charger** `enemy_charger.tscn` |
|------|------|------|------|------|------|
| `max_hp` | 60 | 28 | 22 | 90 | 24 |
| `move_speed` | 4.5 | 7.5 | 5.5 | 3.2 | 5.0 |
| `engage_dist` | 4.5 | 5.5 | 9.0 | 3.5 | 8.0 |
| `stop_range` | 1.9 | 1.6 | — (ranged) | 2.0 | 1.8 |
| `attack_range` | 2.6 | 2.2 | — (ranged) | 3.2 | 2.2 |
| `telegraph_time` | 0.45 | 0.3 | 0.6 | 0.9 | 0.4 |
| `strike_time` | 0.12 | 0.1 | 0.15 | 0.15 | 0.12 |
| `recover_time` | 0.4 | 0.35 | 0.5 | 0.8 | 0.9 |
| `rest_time` | 0.9 | 0.6 | 1.0 | 1.2 | 0.8 |
| `attack_damage` | 15 | 8 | 12 | 28 | 18 |
| `knockback` | 6.0 | 5.0 | 4.0 | 3.0 | 4.0 |
| `stagger_time` | 0 (armored) | 0.25 | 0.3 | 0 (armored) | 0.28 |
| `sight_range` | 12.0 | 12.0 | 14.0 | 12.0 | 13.0 |
| `shoot_range` | — | — | 11.0 | — | — |
| `min_range` | — | — | 6.0 | — | — |
| `base_color` | red | orange | green | steel-blue | teal |

> Slammer/Charger also carry their own extras — see the sections above.

---

## The room & the wave — combat rooms & the sandbox
### Live run — `src/combat/combat_room.gd`  (`@export` → F1 panel / Inspector)
A live combat room runs **2–3 sequential waves** *(multi-wave added 2026-07-06)*; it only
counts as cleared after the last wave falls. All placeholders — dial like feel numbers.

| Var | Default | What it does |
|-----|---------|--------------|
| `enemy_count` | 3 | Base wave size (wave 0); later waves + floor/room add bodies on top. |
| `wave_beat` | 1.0 | Pause between a cleared wave and the next (s). |
| `wave_spawn_telegraph` | 0.6 | Warn time — a growing ground marker flashes at each spawn before the enemy appears (s). |
| `respawn_delay` | 0.9 | Beat between the **final** clear and the doors/exit opening (s). |
| `spawn_radius` | 16.0 | How far out around the room each wave scatters (m). |
| `spawn_jitter` | 3.0 | Random wobble on each spawn point (m). |

> **Wave count / sizes / type mix** are the pure `WaveCore` (`src/combat/wave_core.gd`),
> code-only placeholders: `MIN_WAVES` (2) / `MAX_WAVES` (3) / `THIRD_WAVE_AT` (4 = when a
> room earns its 3rd wave), the `wave_size()` growth curve, and `TYPE_WEIGHTS` (per-type
> draw weight: Brute 3 / Skirmisher 3 / Archer 2 / Slammer 1 / Charger 1 — Slammer & Charger
> are lightly weighted so they season the mix from floor 1). Peril mults apply to every wave.

### Sandbox — `src/combat/feel_room.gd`  (`@export` → F1 panel / Inspector)
The endless-wave director (F6 room). Tune the encounter, not a character.

| Var | Default | What it does |
|-----|---------|--------------|
| `enemy_count` | 4 | Enemies per wave (applies from the next wave). |
| `respawn_delay` | 1.0 | Beat between clearing a wave and the next (s). |
| `shake_on_hit` | 0.35 | Camera kick when **you** take a hit (pairs with `shake_decay`). |
| `spawn_radius` | 18.0 | How far out around the room the wave scatters (m). |
| `spawn_jitter` | 3.0 | Random wobble on each spawn point (m). |

> The sandbox **mix** of variants per wave is `_scene_for()` (rotates all five variants —
> Brute / Skirmisher / Archer / Slammer / Charger — by `i % 5`). The **room size, walls, and
> cover layout** are nodes in `scenes/combat/feel_room.tscn` (`Floor`, `WallN/S/E/W`, the
> `Obstacles` group) — move or resize them in the editor; obstacles are on collision layer 4
> so they block movement **and** line-of-sight.

---

## Cosmetic FX (tweak only if a hit reads poorly)
**Slash streak — `src/combat/slash_fx.gd`** (`const`)
| Const | Default | What it does |
|-------|---------|--------------|
| `LIFETIME` | 0.9 | Seconds before the slash streak fully fades. |
| `START_ALPHA` | 0.9 | Peak brightness. |
| `START_EMISSION` | 2.0 | Peak glow. |

**Floating damage numbers — `src/combat/damage_number.gd`** (`const`)
| Const | Default | What it does |
|-------|---------|--------------|
| `LIFETIME` | 0.7 | Seconds before a number fades + frees. |
| `RISE_SPEED` | 1.6 | How fast it floats up (m/s). |

**Death burst — `src/combat/death_fx.gd`** (`const`) *(added 2026-07-01)*
| Const | Default | What it does |
|-------|---------|--------------|
| `LIFETIME` | 0.7 | Seconds before the whole effect frees. |
| `POP_TIME` | 0.22 | How long the pop sphere lasts (s). |
| `POP_SCALE` | 2.4 | How big the pop swells. |
| `POP_ALPHA` | 0.65 | Pop starting brightness. |

> Shard count/speed/gravity are on the `Shards` CPUParticles3D node in
> `scenes/combat/death_fx.tscn` (editor).

**Dash after-images — `src/combat/ghost_fx.gd`** (`const`) *(added 2026-07-01)*
| Const | Default | What it does |
|-------|---------|--------------|
| `LIFETIME` | 0.22 | Seconds before a ghost fully fades + frees. |
| `START_ALPHA` | 0.4 | How solid a fresh ghost looks. |

> Ghost spawn **rate** and **tint** are on the player (`ghost_interval`, `ghost_color`).

---

## Etching abilities — `data/etchings/*.json` (data files, dial like economy numbers) *(added 2026-07-07)*
Every ability number is a **data field**, not a `# FEEL:` export — edit the JSON and reload
(no code, no scene). Two places per ability:
- **`behavior` dict** — the base cast numbers (below). Damage fields are a *scale of the
  player's `attack_damage`* (so tuning the baseline tunes the abilities, like weapon mods).
- **`levels[1]` / `levels[2]`** — L2/L3 scaling: any `"<field>_mult"` multiplies that base
  `behavior` field (e.g. `"cone_deg_mult": 1.3`). `levels[2]` also names the L3 `rider`
  (unimplemented in v1 — the string is inert). `cooldown_s` and the dust costs
  (`cost_unlock_dust`, `cost_levels_dust: [L2, L3]`) are top-level.

| Ability | Slot | `cooldown_s` | Key `behavior` fields (placeholder values) |
|---------|------|--------------|--------------------------------------------|
| **Push** | rmb | 5 | `damage_scale` 0.6, `cone_deg` 100, `range` 5, `knockback` 16, `wall_bonus_scale` 1.5, `wall_stagger` 0.5 |
| **Bolt** | rmb | 5 | `damage_scale` 0.8, `range` 16, `projectile_speed` 26 |
| **Snare** | q | 12 | `radius` 3, `slow_factor` 0.3, `duration` 4, `stagger_on_cast` 0.25 |
| **Shockwave** | r | 40 | `damage_scale` 1.4, `radius` 6, `knockback` 22, `falloff` 0.4 (edge dmg fraction), `stagger_duration` 0.6 |
| **Surge** | r | 35 | `duration` 5, `move_mult` 1.35, `attack_time_mult` 0.6 (lower = faster), `dash_cd_mult` 0.5 |

> The four dormant abilities (Afterstrike/Ward/Lodestone/Sentinel) carry placeholder
> `behavior` too, but nothing reads it yet (they aren't in `EtchingsCore.IMPLEMENTED`).
> No dedicated cast SFX yet — casting reuses the `dash` sound as a placeholder whoosh
> (add per-ability rows to `data/audio/sfx-map.json` + a hook when desired).

---

## Passive Attunements — `data/attunements/*.json` (data dials, `design/etchings.md`, built 2026-07-10)

The seven persistent passives (the Dust two-sink baseline UNDER echoes). All numbers are placeholders — dial like economy numbers, no code edit. Each file has `costs_dust: [L1, L2, L3]` (Resonance Dust) and a `levels` array of 3 **absolute** effect entries (level N = the TOTAL effect at that level, not a delta).

| Attunement | Dial (per level) |
| --- | --- |
| **vitality** | `levels[i].mods[0].add` — flat `max_health` (20 / 40 / 60) |
| **recovery** | `levels[i].pct` — fraction of MISSING HP healed on room clear (0.04 / 0.07 / 0.10) |
| **quickening** | `levels[i].mods[0].mult` — `dash_cooldown` multiplier (0.9 / 0.82 / 0.75) |
| **resonance-flow** | `levels[i].mult` — ability cast-cooldown multiplier (0.9 / 0.82 / 0.75) |
| **focus** | `levels[i].mods[*].mult` — `attack_damage`/`_finisher` multiplier (1.08 / 1.16 / 1.25) |
| **resilience** | `levels[i].amount` — flat HP off each hit, floored at 1 (1 / 2 / 3) |
| **attunement** | `levels[i].mult` — Dust/Ore find multiplier; keep tame, bounded at 3 levels (1.1 / 1.2 / 1.3) |

> `costs_dust` [8,12,16]/attunement (rebalanced 2026-07-10 against `tools/economy_sim.gd`) → 252 Dust to max all 7 (near the full ability kit's ≈270 — the shared-Dust tension is the point; move both together, and re-run the sim after). The `stat`-kind mods reuse EchoCore's exact handles; changing a `stat` name is a code concern (must match a `player.gd` `@export`), the numbers are free. Page copy/layout consts live atop `src/town/attunements_page.gd`.

---

## Dungeon strata + hazards (data dials, `design/dungeon-strata.md`, built 2026-07-10)

Floor identity is DATA, not code — dial these like FEEL numbers (no code edit):

- **`data/floors/<n>.json` → `environment`**: per-floor palette — `background_color` / `ambient_color` / `light_color` / `ground_color` / `wall_color` / `obstacle_color` (`#hex`), `ambient_energy` / `light_energy` / `fog_density` (floats), `fog_enabled` (bool). Keep floors 1–4 subtle (the deniability rule); enemy/telegraph colours are FIXED and must stay readable against every palette (the legibility passes).
- **`data/floors/<n>.json` → `hazards.density`**: `{early_rooms, late_rooms}` = the expected hazard count in the floor's first vs last room (interpolated; fractional → seeded probability). Floor 1 is low (0.15 → 0.4).
- **`data/floors/<n>.json` → `hazards.signature` / `pool` / `props`**: which hazards + dressing a floor uses.
- **`data/hazards/<id>.json`**: every hazard's `telegraph_s` (reaction window — longer = fairer), `cycle_s` (period), `damage`, `radius`, and the kind extras (`length`/`rotate_deg_s` for the beam, `range`/`projectile_speed` for the watcher, `push_strength` for drift, `drift_speed`/`tick_s` for mist).
- **Placement/keep-outs** (`StrataCore` consts `HALF_EXTENT`/`KEEP_OUT_SPAWN`/`MIN_SPACING`) and the **beam kill-line width** / **mist bounce bound** (`Hazard` consts) are placeholder code constants, not data — dial only if the play field itself changes.

> **No dedicated hazard SFX yet** — the watcher reuses the arrow sounds; vent/beam/burst/mist are silent (add rows to `data/audio/sfx-map.json` + a hook when desired).

---

## Style unification — `src/core/style_core.gd` / `assets/materials/*.gdshader` *(built 2026-07-11, design/asset-pipeline.md §C)*

Every 3D mesh renders through ONE shader (`tycho_toon.gdshader`). Everything below is a **`# style:` dial** — the SAME untouchable contract as `# FEEL:` (human-tuned, agents never optimize). `StyleCore` consts are the source of truth; the shaders' uniform defaults mirror them — when dialing a default, change BOTH.

> **PAINTED-LITE FORK, 2026-08-13.** The look target moved from the flat/banded town anchor to **`assets_src/anchors/art-style.png`** (human pick): soft painterly shading, no outlines, dusk lighting, desaturated world. The shader now samples the ramp **continuously** instead of quantizing it into bands — the ramp's meaning (dark→light) is unchanged, so `ramp_stops()`, the per-stratum derivation and the readability guard all carried over. `BAND_COUNT` retired. **Every value here is a placeholder awaiting the human's F5 verdict** — judge with `tools/render_compare.tscn` (§ Tools) and re-dial freely.

| Var | Default | What it does |
|-----|---------|--------------|
| `SHADOW_WRAP` | 0.35 *(new)* | Diffuse wrap: 0 = plain lambert (hard terminator), 1 = full half-lambert (soft painted falloff). |
| `PRACTICAL_GAIN` | 1.0 *(new)* | How much omni/spot **practicals** (lanterns, forge, windows) contribute. Before the fork the shader ignored every non-directional light outright, so practicals glowed but lit nothing. |
| `RIM_STRENGTH` | 0.15 *(new; was a shader-only uniform at 0.0)* | Soft fresnel rim on the lit side. `smoothstep`, not `step` — a hard rim reads as an outline. |
| `OUTLINES_ENABLED` | **false** *(new)* | Master switch for the inverted-hull pass. The painted anchor has no outlines; the pass is KEPT so it can be A/B'd from this one dial without touching a call site. |
| `OUTLINE_WIDTH` | 0.01 (human-dialed from 0.03) | Inverted-hull push distance (m). Characters only, never environment/props. Inert while `OUTLINES_ENABLED` is false. |
| `OUTLINE_COLOR` | near-black `(0.07, 0.06, 0.10)` | Outline colour. (The town anchor's outlines read dark-WARM — a candidate re-dial, see style-bible.) |
| `NEUTRAL_RAMP` | cool-dark grey → white (3 stops) | The CHARACTER ramp — never stratum-tinted, so enemy identity hues + telegraph colours read identically on every floor (the readability guard). |
| `TOWN_RAMP` | dusk: indigo shadow → khaki mid → glow-cream (anchor pass 2026-07-12) | The town's ramp (the town has no floor profile). First pass from the anchor's extracted palette — judge in F5 vs the anchor, re-dial freely. |
| `RAMP_TINT_SATURATION` | 0.5 | Fraction of an env colour's saturation kept when deriving a stratum ramp. |
| `RAMP_SATURATION_CAP` | 0.4 | Max saturation any derived ramp stop may reach (subtle tint, never a hue takeover). |
| `PALETTE_*` | parchment / stone / wood / verdigris / iron / ember + roof-slate / roof-rust / window-glow (anchor-derived, 2026-07-12) | Starter medieval palette consts for props/buildings. `PALETTE_WINDOW_GLOW` is the planned emissive-window convention (style-bible carrier #3). |
| `data/floors/<n>.json` → `environment.ramp` | absent | OPTIONAL per-floor explicit ramp — `["#hex", "#hex", "#hex"]` dark→light, used VERBATIM; absent/empty = derived from the floor's fog/background + ambient + light colours (brightness always from `NEUTRAL_RAMP`, so the dark→light order is structural). |

### Environment + vignette — `src/core/style_environment.gd` *(new with the painted fork, 2026-08-13)*

Before the fork every scene carried a hand-inlined `Environment` with nothing but a background colour and an ambient light — no tonemap, glow, fog or AO. **That gap, not the geometry, was the largest single distance between the build and the anchor.** One factory now defines the look for `town` + `combat_room` + both render tools; callers pass only their per-scene background/ambient identity. `feel_room` is EXEMPT and must never call it.

| Var | Default | What it does |
|-----|---------|--------------|
| `TONEMAP_EXPOSURE` | 1.8 | AgX is a filmic curve that rolls the image down hard vs. the old linear tonemap; exposure carries that back so existing light energies stay meaningful. |
| `TONEMAP_WHITE` | 6.0 | AgX white point. |
| `GLOW_INTENSITY` / `GLOW_BLOOM` / `GLOW_HDR_THRESHOLD` | 0.5 / 0.15 / 0.95 | The practicals' halo (the anchor's forge/lantern read). Threshold just under 1.0 so warm sources catch and ordinary lit surfaces don't turn to soup. Blend = additive. |
| `FOG_*` (density / albedo / anisotropy / length / ambient_inject) | 0.015 / cool blue-grey / 0.2 / 64 / 0.1 | Volumetric haze: depth, plus the light shafts around practicals. Rides *alongside* each stratum's own distance fog, which stays a per-floor identity dial. |
| `SSAO_*` (radius / intensity / power / detail) | 1.0 / 2.0 / 1.5 / 0.5 | Contact shadows in the clutter. |
| `ADJ_BRIGHTNESS` / `ADJ_CONTRAST` | 1.0 / 1.05 | Grade. |
| **`ADJ_SATURATION`** | **0.85** | **Double duty — do not "clean up" toward 1.0.** Desaturating the world is (a) most of what reads as *painted* rather than *3D render*, and (b) the combat-readability guard: it leaves telegraph red / hazard amber / pickup cyan as the only saturated pixels on screen, so they pop on hue alone without being brightened out of the palette. |
| `VIGNETTE_STRENGTH` / `_RADIUS` / `_SOFTNESS` / `_COLOR` | 0.55 / 0.75 / 0.45 / near-black | `Environment` has no vignette and the anchor's corners are near-black — a full-rect `ColorRect` on `tycho_vignette.gdshader`. Deliberately **not** aspect-corrected: an elliptical vignette that follows the frame beats a circular one that clips the sides. |
| `VIGNETTE_LAYER` | 0 | Under every gameplay CanvasLayer (the HUDs sit on the default layer 1) — it darkens the WORLD, never the UI. A dimmed HUD would undo Ember's whole contrast story. |

### Town practicals — `src/town/town.gd` *(the look-gate scene)*

| Var | Default | What it does |
|-----|---------|--------------|
| `PRACTICALS` | 5 warm omnis (fountain, market face, tree line, 2 corners), energy 3.5–5.0, range 10–12, shadowless | The anchor's light story: many small warm sources at **edges and on props**, so the play area keeps an ambient fill and nothing important happens inside the vignette. |
| `KEY_ENERGY` / `KEY_COLOR` | 1.5 / cool blue-white | The DirectionalLight is the dusk key now, not the whole lighting story. |
| **`AMBIENT_ENERGY` / `AMBIENT_COLOR`** | **0.3 / cool dusk blue** *(was 0.8, near-white)* | **The least obvious dial, and the one the anchor's drama hangs on.** The old ambient lit every surface evenly, so the practicals had nothing to read against and the ramp's dark stop was never reached. The anchor's power is a **ratio** — dark cool ambient, bright warm local pools — not brighter lights. |

**Opt-outs (how a mesh stays raw):** translucent or unshaded materials are never converted (all FX/telegraph/portal/ghost materials, automatically); set metadata `style_skip` on a `MeshInstance3D` for an explicit opt-out. `scenes/combat/feel_room.tscn` is untouched — the sandbox keeps the raw look. Known gotcha: hard-edged primitives (boxes) can gap at outline corners (split normals) — acceptable on placeholders; smooth-normal models won't. (Moot while `OUTLINES_ENABLED` is false; faceted primitives DO show their facets under the fork's soft light — expected, and the answer is smooth normals on real models, not a dial.)

### Water — `src/core/water_plane.gd` (@export → Inspector) + `assets/materials/water_absorption.gdshader` uniforms *(built 2026-07-11; the town's south border)*

Water LOOK dials are the shader's uniform defaults (grouped in the shader: color / displacement / edge / player / caustics / normal_map — absorption_color, fresnel_color, depth_distance 6, beers_law 4.5, edge_thickness/foam, influence_size 2.5 walk-ripples, displacement_strength 0.08 wave height…). SSR ships DISABLED (`//#define SSR` — re-enable in the shader if wanted; costly, near-invisible at our camera). Node dials:

| Var | Default | What it does |
|-----|---------|--------------|
| `size` / `subdivisions` | 34×11 m / 48 | Plane footprint and wave vertex resolution. |
| `make_bed` / `bed_shallow_y` / `bed_deep_y` / `bed_color` | on / −0.5 / −4.0 / silt | The generated sloped floor the absorption gradient reads against (shallow at the town edge, deep out). |
| `wind_intensity` / `wind_direction` | 0.35 / (1, 0, 0.35) | Fed into the PROJECT-WIDE shader globals at ready (never zero the direction). |

### Shore — `src/core/shore_terrain.gd` (@export → Inspector) *(built 2026-07-11; the curvy waterline)*

The shoreline is never drawn — it emerges where this terrain's height crosses the water surface (the water shader foams at depth≈0). Node origin sits ON the mean waterline.

| Var | Default | What it does |
|-----|---------|--------------|
| `width` / `land_depth` / `water_depth` | 80 / 4 / 14 | Strip footprint: beach toward town, bed toward the lake. |
| `curve_amplitude` / `curve_frequency` / `curve_seed` | 2.0 / 0.08 / 7 | THE shoreline dials: meander size (± m), feature wiggliness, reroll the shape. |
| `drop_slope` / `land_y` | 0.35 / 0.02 | Bed steepness (absorption gradient) and beach height over the town floor. |
| `resolution` / `sand_color` | 0.75 m / sand | Grid density and the beach colour (toon-swept at runtime). |

### Grass — `src/core/grass_patch.gd` (@export → Inspector) + `assets/materials/grass_blade.gdshader` uniforms *(built 2026-07-11; judge in `scenes/core/grass_demo.tscn`)*

| Var | Default | What it does |
|-----|---------|--------------|
| `patch_size` / `blade_count` | 12×12 m / 4000 | Patch footprint and density. |
| `blade_width` / `blade_height` / `height_jitter` | 0.08 / 0.55 / ±0.35 | Blade quad size + per-blade height variance. |
| `top_color` / `bottom_color` (shader) | green pair | Tip→root gradient; roots also darken by `ambient_occlusion_factor` (0.3). |
| `wind_direction` / `wind_strength` / `wind_noise_size` / `wind_noise_speed` (shader) | (1, 0, 0.35) / 0.3 / 0.05 / 0.1 | Gust direction, sway amount, gust patch size, gust travel speed. |
| `player_displacement_strength` / `player_displacement_size` (shader) | 0.4 / 1.0 | How hard and how wide a walker bends the grass (`follow_target` on the patch node). |

### Town fountain — `src/core/town_fountain.gd` (@export → Inspector) *(built 2026-08-10; the town square's centrepiece)*

Generated geometry, not a model — the anchor's plaza well minus its posts and canopy. Four generated children (Paving / Stone / Submerged / Water) + its own collision; the stone parts are plain StandardMaterial3Ds, so town.gd's toon sweep converts them on `TOWN_RAMP` like any other town mesh, while the water (a `WaterPlane.build_material()` ShaderMaterial, shared with the lake) is skipped by the sweep's existing FX rule.

**Three findings from the render pass (`tools/render_prop.gd`) — the reasons the defaults are what they are.** At the fixed −58° pitch: (1) tiers whose radii are close read as a mushy swirl, so it is ONE chunky step, not a stack; (2) the shader alone over a 0.44 m basin is nearly clear, so the pool only reads as water because everything under `water_y` is its own dark teal material; (3) the apron only reads as paving when `paving_color` sits well below `stone_color`.

| Var | Default | What it does |
|-----|---------|--------------|
| `segments` / `pedestal_segments` | 20 / 8 | Radial facets. Low = chunkier (flat normals; the column reads octagonal). |
| `apron_radius` / `apron_height` / `show_apron` | 3.4 m (town instance overrides to 3.0) / 0.05 / on | The paving circle. Flat and OUTSIDE the collider on purpose — the player walks over it. |
| `step_radius` / `step_top` | 2.45 / 0.30 | The single step. `step_radius` is also the collision radius. |
| `rim_outer` / `rim_inner` / `rim_top` | 2.05 / 1.68 / 0.95 | Basin wall: outside face, inside face (difference = rim thickness), sit-on height. |
| `basin_floor_y` / `water_y` | 0.36 / 0.80 | Bed and surface. Water must stay between them and below `rim_top`. |
| `pedestal_radius` / `pedestal_top` | 0.34 / 1.45 | The column — the only thing that breaks the flat circular silhouette from above. |
| `bowl_outer` / `bowl_inner` / `bowl_floor_y` / `bowl_top` | 0.80 / 0.58 / 1.50 / 1.78 | The upper spill bowl. Keep it well inside `rim_inner` or it merges with the rim ring. |
| `finial_base_radius` / `finial_top_radius` / `finial_top_y` | 0.22 / 0.10 / 2.10 | The spout stub; `finial_top_y` is the total height (NPC capsules are 1.7 m). |
| `stone_color` / `paving_color` / `submerged_color` | stone grey / dark cobble / deep teal | See finding (3) and (2) above. |
| `water_depth_distance` / `water_beers_law` / `water_displacement` | 0.55 / 9.0 / 0.02 | Per-instance overrides of the shared water shader — the lake's defaults (6 / 4.5 / 0.08) are tuned for a 34 m body. |
| `water_uv_metres` | 10.0 | Metres per UV unit, matched to the lake's texel density so the same noise reads at the same physical size. |

---

## Ember HUD — `src/core/ember_hud.gd` + `src/combat/run_hud.gd` (`const`, code-only) *(built 2026-08-10; the in-run HUD's reference-anchor redesign, `design/ui-hud.md`)*

Not `# FEEL:`-tagged (no combat feel rides on them) but the same contract: **the human owns every value.** Judge with `tools/render_hud.tscn` for layout, then in F5 over real combat for the last 10%.

**Shared language — `EmberHud`** (both the palette and the glyph table are placeholders):

| Const | Now | What it does |
| --- | --- | --- |
| `COL_INK` / `COL_INK_DIM` / `COL_INK_FAINT` | `#e5e4e0` / `#9a9691` / dim @ 0.55 | primary text / labels+keys / completed rows + empty slots |
| `COL_HAIR` / `COL_RING` | white @ 0.14 / 0.22 | section rules / idle medallion + slot rings |
| `COL_ACCENT` | `#e0a83c` | **THE gold — state only.** Ready slots, bullets, badges, the HP diamond |
| `COL_TRACK` | white @ 0.16 | the unfilled part of any bar |
| `COL_SHADOW` | black @ 0.7 | the 1 px drop under unbacked prose |
| `COL_GOLD/ORE/DUST/SHARDS` | as Slate | **deliberately shared with `SlateHud`** — a resource means one colour game-wide |
| `FS_HEAD/LABEL/VALUE/BIG/KEY/MONO` | 12 / 17 / 15 / 22 / 10 / 13 | section heads · objective labels + list rows · counters+HP · resource numbers · key badges · monograms |
| `TRACKING` / `MARGIN` | 1.6 / 22 | letter-spacing on tracked caps / screen-edge margin |
| `GLYPH_FILL` / `GLYPH_STROKE` / `GLYPH_ARCS` | unit-square point lists | **every glyph silhouette** — now **22** marks (4 resource crystals + 6 ability + 12 menu). Adding one is a `match` arm. `GLYPH_ARCS` entries take an optional 4th/5th element = the arc's centre offset |
| **Fonts** | Cinzel / EB Garamond / JetBrains Mono / **Alegreya Sans** | display · prose · numbers · **the interface voice (added 2026-08-13)**. Swapping a role = swapping its `FONT_*_FILE` preload |

**Run-specific — `RunHud`:**

| Const | Now | What it does |
| --- | --- | --- |
| `ECHO_D` / `ECHO_GAP` / `ECHO_BADGE_R` | 38 / 11 / 8 | echo medallion size, spacing, stack-count disc (rail grows **up** from bottom-left) |
| `HP_W` / `HP_H` / `HP_BOTTOM` | 460 / 5 / 52 | HP bar width, thickness, distance from the bottom edge |
| `HP_DIAMOND` / `HP_FILL_INSET` | 6.5 / 5 | centre diamond size, where the outward fill starts clear of it |
| `HP_NUM_HOLD_S` / `HP_NUM_FADE_S` / `HP_NUM_DROP` | 1.5 / 0.6 / 18 | the number fades in on any HP change. **0 hold = follow the anchor exactly (no number); a huge hold = always on** |
| `COL_HP` / `COL_HP_LOW` | `#c83028` / `#ec4c3e` | bar fill, and its low-HP brightening |
| `SLOT_D` / `DASH_D` / `SLOT_GAP` | 56 / 40 / 26 | cast-ring and dash-ring diameters; the gap must clear **both** the key label and the neighbour's cooldown arc |
| `SLOT_RING_W` / `SLOT_ARC_W` / `SLOT_ARC_PAD` | 2 / 3 / 5 | ring thickness, cooldown-arc thickness, arc radius beyond the ring |
| `GLYPH_SCALE` / `KEY_DROP` / `ABIL_BOTTOM` | 0.52 / 9 / 58 | glyph size as a fraction of its ring, key label drop, dash ring's height off the bottom |
| `BLOCK_W` / `HEAD_GAP` / `ROW_GAP` / `ROW_VALUE_DROP` | 300 / 36 / 28 / 21 | room block width, resources→header gap, row spacing, label→counter drop |
| `RES_GLYPH` / `RES_GAP` / `RES_SPACING` / `RES_TOP` | 19 / 12 / 30 / 14 | resource glyph size, glyph→number, between resources, row height below `MARGIN` |
| `BULLET_HALF` / `BULLET_GAP` / `HEAD_TRACKING` | 4.5 / 13 / 1.8 | objective diamond size, bullet→label, header letter-spacing |
| `BOSS_W` / `BOSS_H` / `BOSS_DIAMOND` / `BOSS_TRACKING` | 420 / 7 / 7 / 2.6 | boss bar geometry + its name's letter-spacing |
| `HINT_LIFT` | 30 | hint prose's height above the HP bar |
| `VIGNETTE_DEPTH/STEPS/ALPHA` | 90 / 24 / 0.30 | low-HP screen edge. **Known dial:** nested `draw_rect` outlines read as faint banding, not a smooth glow (inherited from Slate) |

## Ember menus — `src/core/ember_hud.gd` + `ember_menu_core.gd` + `ember_theme.gd` *(built 2026-08-13; the base the fifteen Slate screens migrate onto, `design/ui-hud.md` § "Ember menu vocabulary")*

Same contract as above: **the human owns every value.** Judge with `tools/render_menu.tscn` (renders a specimen screen exercising every primitive at once, side-by-side-able with `assets_src/anchors/weapon-menu-reference.png`), then in F5 once real screens migrate.

**Menu palette + sizes — `EmberHud`** (beside the HUD block, same file, one dial source):

| Const | Now | What it does |
| --- | --- | --- |
| `COL_SCRIM` | `#0a090d` **opaque** | the ground every screen sits on. **Human call 2026-08-14: fully opaque** — it shipped at 0.90 and the town showing faintly through the forge read as distraction, not depth. Lowering it below 1.0 brings that back; the two surfaces that DO want the world visible (`EchoOfferPanel.DIMMER`, the dialogue box) carry their own values |
| `COL_ROW` / `COL_ROW_HOVER` | white @ 0.035 / 0.075 | the resting + hovered row wash. Deliberately near-invisible — a row is bounded by its hairline, not by a fill |
| `COL_ROW_SELECTED` | gold @ 0.10 | the selected row's wash (it also gets the dashed gold frame) |
| `COL_DISABLED` | dim ink @ 0.38 | unaffordable actions, locked rows. **Never red** — the house rule holds |
| `FS_TITLE` / `FS_SUB` | 34 / 16 | the screen's name (display) and the line under it (prose) |
| `FS_ROW` / `FS_ROW_SM` | 17 / 13 | list-row names + dock labels / meta lines, level captions, costs |
| `FS_HERO` / `FS_PROMPT` | 26 / 14 | the centre stage's big name / footer prompt labels |

**Primitive defaults** (each also takes an argument, so a screen can override locally without touching the shared value): `_flourish` diamond half **4.0** · `_dashed_rect` width **1.5**, dash **7.0**, gap **5.0** · `_pips` half **4.5**, gap **13.0** · `_prompt` radius **9.0**, gap **9.0** · `_section` rule drop **13.0**, first-row drop **24.0**.

**Layout — `EmberMenuCore`** (the grammar all fifteen screens share; changing one number here moves every migrated screen at once, which is the point):

| Const | Now | What it does |
| --- | --- | --- |
| `PAD_PX` | 46 | screen-edge margin. **Deliberately larger than the HUD's `MARGIN` 22** — a menu's negative space does the work a panel border used to |
| `TITLE_TOP_PX` / `SUBTITLE_DROP_PX` | 30 / 30 | title centre below the top edge / subtitle below the title |
| `CONTENT_TOP_PX` / `CONTENT_BOTTOM_PX` | 96 / 66 | where the content band starts and stops |
| `FOOTER_BOTTOM_PX` | 34 | the prompt row's centre, above the bottom edge |
| `RAIL_W_PX` / `COL_GAP_PX` | 74 / 26 | the icon rail's width / the gap between all four columns |
| `LIST_WEIGHT` / `HERO_WEIGHT` / `DOCK_WEIGHT` | 0.34 / 0.32 / 0.34 | how the three real columns split what the rail left. **Relative, not absolute** — they need not sum to 1 |
| `COLUMN_W_PX` | 700 | the centred single-column width (settings / achievements shape) |
| `RAIL_MIN_W_PX` | 900 | below this viewport width the rail is **dropped, not squeezed** |

**Theme sizes — `EmberTheme`:** `FS_PROSE` 18 · `BTN_RADIUS` **3** (Ember frames are near-square by design — a big radius reads as Slate) · `BTN_MARGIN` (16, 9) · `ACTION_MARGIN` (26, 13) · `PANEL_MARGIN` 18. **The Panel/PanelContainer stylebox is `StyleBoxEmpty` and should stay that way** — that transparency IS the language.

**Glyphs:** all 12 new marks (`leaf`, `stone`, `sword`, `shield`, `heart`, `boot`, `star`, `anvil`, `book`, `house`, `lock`, `check`) are placeholder silhouettes, unit-square point lists in `EmberHud`. Re-shaping one is editing a point list; adding one is a dictionary entry. **`RESOURCE_GLYPH` / `RESOURCE_COLOR`** map all seven Ledger ids to one mark and one colour game-wide — change a resource's identity there, once, not per screen.

## Ember Tier A — the migrated overlays *(built 2026-08-13, `design/ui-hud.md` § "Migrating to Ember")*

Judge with `tools/render_hud.tscn` (states `town`, `echo-offer`) and `tools/render_menu.tscn` (state `pause`), then F5.

| Surface | Const | Now | What it does |
| --- | --- | --- | --- |
| **TownHud** | `DAY_TOP` / `DAY_RULE_DROP` / `DAY_TRACKING` | 12 / 13 / 1.4 | day chip's line, its hairline, its letter-spacing |
| | `RES_TOP` / `RES_GLYPH` / `RES_GAP` / `RES_SPACING` | 26 / 18 / 11 / 26 | readout row height, mark size, mark→number, between readouts |
| | `GROUP_GAP` / `HEAD_LIFT` / `FS_GROUP` | 40 / 20 / 10 | **the gap IS the group boundary** (no panel) · header height · header size |
| | `PROJ_DROP` / `PROJECTION_ALPHA` | 20 / 0.55 | the `+n/d` under each readout |
| | `TOAST_TOP` | 62 | overnight toast, **top-LEFT under the day chip** — it moved out of top-centre because the panel-less strip now reaches past the middle. Moving it back needs the strip to shrink first |
| **AchievementToast** | `TOP_MARGIN` | 96 | **a clearance constraint, not taste** — must clear the run HUD's boss bar AND the town strip, since this is the one toast that plays in every scene |
| | `MEDAL_R` / `TEXT_GAP` / `RULE_DROP` | 21 / 15 / 22 | the monogram ring, ring→text, the hairline under it |
| | `SLIDE_S` / `HOLD_S` / `FADE_S` | 0.25 / 3.0 / 0.6 | lifecycle (unchanged from Slate) |
| **EchoOfferPanel** | `DIMMER` | `#08070c` @ 0.62 | **the dial that decides whether the offer feels like a pause or a screen.** Deliberately lighter than `COL_SCRIM` — you are still reading the battlefield you drop back into |
| | `KEY_R` / `HELD_R` | 11 / 9 | the key badge ring and the gold held-count disc |
| | `NAME_DY` / `LINE_GAP` / `FX_GAP` | 26 / 22 / 18 | name below the ring, then the parents line, then the effect lines |
| **PauseMenu** | `TITLE_GAP` / `PANEL_WIDTH` | 18 / 320 | title block → buttons; the column's width |
| | *(everything else)* | — | comes from `EmberTheme`. Only **Resume** takes `EmberAction` (gold); the rest are plain hairline Buttons |

## Ember Tier B — the six town screens *(built 2026-08-14, `design/ui-hud.md` § "Migrating to Ember")*

Judge with `tools/render_menu.tscn` (states `forge`, `etchings`, `attunements`, `build`, `build-locked`, `survey`, `market`), then F5 and walk the town.

**Dial the shared numbers first.** These six screens borrow their margins, title band and footer from `EmberMenuCore` (§ Ember menus above), so moving `PAD_PX` or `TITLE_TOP_PX` moves all of them at once — that is the point, and it is also why the per-screen table below is short. Everything here is a placeholder.

| Surface | Const | Now | What it does |
| --- | --- | --- | --- |
| **shared** | `EmberPips.PIP_HALF` / `PIP_GAP` / `PAD` | 4.5 / 13 / (2, 6) | **every level track in the game**: forge refine, building levels, attunement depth, etchings rungs. One node, one look |
| | `EmberHud._resource_readout` defaults | `fs` 22 · glyph 17 · gap 9 · spacing 24 | the top-right carry readout on all six screens. It grows **leftward** from the right margin, so a long readout never walks into the title |
| | `EmberTheme` scrollbar | track `COL_HAIR`, grabber `COL_INK_DIM` (hover `COL_INK`) | **do not dial these back toward invisible** — a page that scrolls with no visible bar reads as a page that was cut off |
| **ForgeAnvil** | `TAB_W` / `TAB_H` / `TAB_GAP` / `TAB_TOP_DROP` | 168 / 92 / 14 / 34 | the weapon list rows, laid down `EmberMenuCore`'s content band |
| | `FS_TAB` / `TAB_TRACKING` | 11 / 1.2 | the tab's caps label |
| | `FS_NAME` / `FS_META` / `META_TRACKING` | 30 / 11 / 1.4 | the weapon name over the anvil and its `KIND · EQUIPPED · FLAT Ln` line |
| | `EMBER_*` / `ANVIL_*` / `WEAPON_*` | *(unchanged)* | the forge's warm glow and its staging — the human's F2 pick, untouched by the migration |
| **EtchingsArms** | `FS_BADGE` / `BADGE_TRACKING` / `BADGE_DY` | 11 / 1.2 / 40 | the hovered site's name, now bare tracked caps (the chip is gone) |
| | `SITE_HALO_R` / `SEL_RING_R` | 30 / 30 | **equal, so the dashed selection ring hides inside its own glow.** Pull the halo in if you want the dash to read |
| **EtchingsPanel** | `DOCK_W` | 382 | +26 over Slate's 356 — the dock's new inner hairline and its gap cost that much |
| | `FS_DOCK_NAME` | `FS_HERO` (26) | the dock's ability name. Full `EmberTitle` size wraps every two-word name at this width |
| | `TAB_TOP` / `TAB_GAP` | 70 / 18 | the `THE MARKS` / `THE BODY` row |
| **BuildPanel** | `DOCK_W` | 410 | +26 over Slate's 384, same reason. **Below ~390 the yield text wraps into the price column** |
| | `STAGE_CENTER` / `STAGE_SCALE` / `NAME_Y` / `META_Y` | (0.34, 0.60) / 1.6 / 0.185 / 0.238 | the building's stage — unchanged from B2 |
| **SurveyPanel** | `SHEET_W` / `SHEET_TOP` | 800 / 116 | the whole-town sheet. It **scrolls**; its height is the content band's floor |
| **AttunementsPage** | `SHEET_W` / `SHEET_TOP` | 700 / 150 | seven ledger rows, also scrolling |
| **MarketPanel** | `SHEET_W` / `SHEET_TOP` | 560 / 120 | exchange + caravan |

**Where the gold went, per screen** (the language's one hard rule — gold is state, at most one gold control per screen): forge → **Refine** · etchings → **Awaken/Deepen** · build → **Build/Raise** · market → **Accept** (the caravan is once a day; the exchange buttons are plain) · survey → **nothing** (it is read-only, so there is no action to spend gold on) · attunements → **nothing** (seven rows; seven gold buttons would mark nothing).

## Ember Tier C — the last five screens *(built 2026-08-14, `design/ui-hud.md` § "Migrating to Ember")*

Judge with `tools/render_menu.tscn` (states `tech`, `tech-read`, `settings`, `achievements`, `slot-select`, `dialogue`), then F5 from the title screen.

| Surface | Const | Now | What it does |
| --- | --- | --- | --- |
| **shared** | `EmberFrame.WIDTH` / `RING_WIDTH` | 1.0 / 1.6 | every packable frame + ring in the game (empty plaques, achievement medallions) |
| **TechChart** | `R_MAIN` / `R_LOCKED` / `GLOW_R` / `GLOW_ALPHA` | 8 / 4.5 / 16 / 0.16 | the star sizes and their soft glow — unchanged from R1 |
| | `SEL_R` / `SEL_SEGMENTS` | 26 / 22 | the dashed selection ring around the chosen star |
| | `FADE_W` / `FADE_ALPHA` | 270 / 0.9 | the Age-II darkening at the right edge; it dissolves toward `COL_SCRIM` now, so it follows the scrim dial |
| **TechPanel** | `DOCK_W` / `DOCK_TOP` / `DOCK_BAR_H` | 348 / 96 / 12 | the detail dock. It gained the inner hairline in Tier C but **did not need the +26 px the build/etchings docks did** — its rows are short |
| | `GUTTER_X` / `GUTTER_Y` | 240 / 24 | the reading page's margins. **This is the dial that decides whether an explanation reads like a page or a wall** — the line length is `1280 - 2×GUTTER_X` |
| **SettingsPanel** | `COLUMN_W` / `TOP_FRAC` / `ROW_H` | 700 / 0.13 / 56 | the page's column |
| | `NOTCH_COUNT` / `NOTCH_GAP` / `TRACK_H` | 12 / 6 / 26 | the volume tracks. **The lit notches are the loudest thing on the screen** — full `COL_DUST` on 12 fat blocks. Thinner notches or a dimmer lit colour is the first thing to try |
| | `COL_HOVER_BRIGHT` / `COL_NOTCH_UNLIT` | `#bff2ff` / white @ 0.16 | hovered-lit, and the unlit remainder (the shared unfilled-bar wash) |
| **SlotSelect** | `PLAQUE_W` / `PLAQUE_H` / `PLAQUE_GAP` | 620 / 74 / 22 | the three saga plaques |
| | `FS_NAME_ROW` / `FS_RN` / `FS_META` | 20 / 15 / 12 | the saga name, its roman numeral, the meta line |
| | *(frame states)* | `_style_frame` | idle hairline · hover ink · armed danger-red · **empty = a real dashed frame**. Four states of one mark |
| **SlotSelectSky** | the whole Style block | — | gradient stops, star scatter, constellation, ridge, `TITLE_FS` 72 / `TITLE_SPACING` 16 / `TITLE_GLOW_R` 150. Untouched by the migration; it is an illustration, dial it as art |
| **AchievementsPanel** | `COLUMN_W` / `ICON_BOX` / `LOCKED_ALPHA` | 700 / 44 / 0.45 | the column, the medallion box, how far a locked row greys out |
| **DialoguePanel** | `BOX_HEIGHT` / `MARGIN_X` / `BOX_LIFT` | 150 / 180 / 16 | the talk box's band |
| | `CUTSCENE_DIM` / `COL_WHO` | black @ 0.55 / `#ffd980` | the cutscene dim over the world, and the speaker name's warm gold |
| | `FS_WHO` / `FS_LINE` | 16 / 19 | speaker (display) and the spoken line (prose) |

**Where the gold went:** tech → **Invest / Read & solve** (never both — the dock shows one) · settings → the **selected window chip** · slot-select → nothing until a plaque is hovered or armed (the title screen's only gold is a mid-run or ACT I badge, which is state) · achievements → an **unlocked medallion's ring** · dialogue → the speaker's name.

## Boss — Den-Warden (floor 1; data dials + 2 exports, `design/bosses/floor-1-boss.md`, built 2026-07-10)

ALL placeholder numbers. Grammar rule 2 applies: boss tells stay LONGER than trash tells (trash baselines: dummy 0.45 s, Slammer/Charger ~0.5–0.6 s).

**A) The def — `data/bosses/den-warden.json`** (dial like the hazard numbers; loop/phase SHAPE is design, not a dial):
- `hp` 350, `contact_damage` 20 (the default move damage — a move's own `damage` overrides).
- `reconfigure_s` 1.2 — the invulnerable phase-transition beat at the 50% crossing.
- `phases[1].threshold` 0.5 — where phase 2 starts (fraction of max HP, entered AT the value).
- **lunge** `telegraph_s` 0.8 / `range` 14 / `speed` 22 / `damage` 20 / `contact_radius` 2.4 / `recover_s` 0.8 — Charger line grammar at boss length; `recover_s` is the punish beat after each move.
- **swipe** `telegraph_s` 0.7 / `radius` 4.5 / `arc_deg` 150 / `strike_s` 0.2 / `damage` 24 / `recover_s` 0.6 — dummy strike grammar, wider; damage only inside the frontal arc.
- **circle** `duration_s` 2.0 / `speed_mult` 1.2 — THE phase-1 punish window (no attack; orbits at `move_speed` × mult × the shared `circle_speed_mult`).
- **burrow** `circles` 3 / `chain_s` 0.9 / `circle_radius` 3.4 — chained Slammer circles tracking the player (each LOCKED at its start); boss untargetable/invulnerable throughout.
- **erupt** `radius` 3.4 / `damage` 28 / `recover_s` 1.0 — surfaces under the LAST burrow circle.
- **vent_call** `stagger_s` 0.45 / `recover_s` 0.8 — the gap between vent firings; the boss stands exposed while calling.
- `arena_vents` — five `[x, z]` vent-plate spots; the vents' own telegraph/damage numbers are `data/hazards/vent-plate.json` (shared with the floor's trash rooms — dialing one dials both).

**B) Scene `# FEEL` exports — `src/combat/enemy_boss.gd`** (✏️ Inspector on `enemy_boss.tscn`):
- `move_beat_s` (0.7) — the between-move breather when a move has no `recover_s`.
- `reconfigure_pulse` (1.35) — the placeholder molt visual's mesh-scale peak.
- The tscn's inherited dummy exports still shape the walk/orbit (`move_speed` 3.6, `engage_dist` 5.0, `stop_range` 2.4); its `max_hp`/`attack_damage`/`telegraph_time` values only matter on the def-less placeholder floors (2–5).

---

## Town economy (data dials, `design/town-economy.md`, built 2026-07-10)

ALL placeholder economy numbers — dial like the etching/attunement data (no code edit unless noted; rerun `tools/economy_sim.tscn` after changes):

- **Building costs + yields** — `data/buildings/*.json` (9 files): every level's `cost` (Gold + Stone in Age I), `produce`/`knowledge` per_day, and the `multiplier` mults (Library 1.10/1.15/1.25/1.5 on knowledge; Mill 1.10/1.15/1.25 on food AND stone).
- **Market rates** — `data/buildings/market.json`, the per-level `capability` effect: `sell_food_rate` (1.0/1.5/2.0), `buy_stone_gold` (5/4/3), `buy_food_gold` (2/2/1), `deal_slots` (1/1/2). Exchange is meant to be WORSE than producing (the soft gold sink).
- **Auto-sell keep-buffer** — `TownCore.MARKET_KEEP_BUFFER_DAYS` (2.0 × nominal upkeep; code const, commented placeholder).
- **Caravan deals** — `data/town/caravan-deals.json`: the whole table (5 deals) is a dial — shapes, amounts, and the placeholder Herzog pitch lines.
- **Cathedral stage costs** — `data/buildings/cathedral.json`: 400g+60s → 900g+150s → 2000g+300s; the completion bonus is L3's `shard_value_add` (1).
- **Per-level tech gates** — each level's `unlocked_by` (Farm L3, Quarry L2, Mill L3, Observatory L3, Library L4) is data; moving a gate re-paces an age.
- **UI copy** — the placeholder lines in `BuildPanelCore` (`YIELD_MULT`, `CAP_MARKET`, `CAP_GREAT_WORK`, `LOCKED_FMT`, `LOCKED_UNKNOWN_TECH`), `MarketPanel` (title through deal rows), `BuildPanel.TRADE_LABEL`, and the toast's "+N gold in trade" (`TownHudCore`).

---

## First dials to try (suggested starting points)
- **Too easy / too hard:** enemy `attack_damage`, `telegraph_time` (longer = fairer),
  `enemy_count`, `max_attackers`, player `hit_grace`.
- **Combat feels mushy:** player `attack_recover*`, `attack_windup`, `dash_cooldown`,
  and the **hitstop** quartet (more stop = more weight).
- **Attacks whiff annoyingly / magnet too hard:** `lunge_speed`, `lunge_range`,
  `lunge_stop` (0 lunge_speed = off).
- **Squishies feel armored / stunlocked:** variant `stagger_time` (0 = never interrupted).
- **Crowds unreadable:** `max_attackers` (down), `separation_force` (up), enemy `engage_dist`.
- **Archers oppressive:** arrow `SPEED` (down), Archer `telegraph_time` (up), `shoot_range` (down).
- **Slammer AoE unfair / trivial:** Slammer `telegraph_time` (longer = more dodge time),
  `slam_radius`, `attack_damage`; it's meant to be dodged with a dash.
- **Charger too swingy:** Charger `charge_speed`, `telegraph_time` (the lock/aim window),
  `contact_radius`, `recover_time` + `wall_stun_bonus` (its punish window).
- **Rooms too short / too long:** `WaveCore` `MIN_WAVES`/`MAX_WAVES`/`THIRD_WAVE_AT`, the
  `wave_size()` curve, combat-room `enemy_count`, `wave_beat` (pause between waves).
- **New types too rare / too common:** `WaveCore.TYPE_WEIGHTS` (Slammer/Charger start at 1).
- **Camera floaty / harsh:** `follow_lerp`, `shake_on_hit`, `shake_decay`, `cam_pitch`.
