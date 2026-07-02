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
| `move_speed` | 7.0 | Top run speed (m/s). |
| `accel` | 70.0 | How fast you reach top speed (higher = snappier start). |
| `friction` | 80.0 | How fast you stop when you release the keys (higher = less slide). |

### Dash
| Var | Default | What it does |
|-----|---------|--------------|
| `dash_speed` | 24.0 | Burst speed during a dash. |
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
| `cam_offset` | (0, 15, 9) | Height + pull-back of the fixed camera (the framing). Panel exposes `.y` and `.z`. |
| `cam_pitch` | -58.0 | Downward tilt in degrees — **the 2.5D angle**. |
| `shake_decay` | 6.0 | How fast a screen-shake settles (higher = snappier). |

> The shake **amount** on getting hit is `shake_on_hit` in `feel_room.gd` (below).

---

## Enemies — base behaviour `src/combat/enemy_dummy.gd`
This script is shared by **all three variants**. It has two layers:

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

## Per-variant stat sheet (current `@export` values)
What each variant scene currently sets. Edit these in the Inspector (open the scene → root node).

| Stat | **Brute** `enemy_dummy.tscn` | **Skirmisher** `enemy_skirmisher.tscn` | **Archer** `enemy_archer.tscn` |
|------|------|------|------|
| `max_hp` | 60 | 28 | 22 |
| `move_speed` | 4.5 | 7.5 | 5.5 |
| `engage_dist` | 4.5 | 5.5 | 9.0 |
| `stop_range` | 1.9 | 1.6 | — (ranged) |
| `attack_range` | 2.6 | 2.2 | — (ranged) |
| `telegraph_time` | 0.45 | 0.3 | 0.6 |
| `strike_time` | 0.12 | 0.1 | 0.15 |
| `recover_time` | 0.4 | 0.35 | 0.5 |
| `rest_time` | 0.9 | 0.6 | 1.0 |
| `attack_damage` | 15 | 8 | 12 |
| `knockback` | 6.0 | 5.0 | 4.0 |
| `stagger_time` | 0 (armored) | 0.25 | 0.3 |
| `sight_range` | 12.0 | 12.0 | 14.0 |
| `shoot_range` | — | — | 11.0 |
| `min_range` | — | — | 6.0 |
| `base_color` | red | orange | green |

---

## The room & the wave — `src/combat/feel_room.gd`  (`@export` → F1 panel / Inspector)
The sandbox director. Tune the encounter, not a character.

| Var | Default | What it does |
|-----|---------|--------------|
| `enemy_count` | 4 | Enemies per wave (applies from the next wave). |
| `respawn_delay` | 1.0 | Beat between clearing a wave and the next (s). |
| `shake_on_hit` | 0.35 | Camera kick when **you** take a hit (pairs with `shake_decay`). |
| `spawn_radius` | 18.0 | How far out around the room the wave scatters (m). |
| `spawn_jitter` | 3.0 | Random wobble on each spawn point (m). |

> The **mix** of variants per wave is `_scene_for()` (currently rotates Brute / Skirmisher
> / Archer by `i % 3`). The **room size, walls, and cover layout** are nodes in
> `scenes/combat/feel_room.tscn` (`Floor`, `WallN/S/E/W`, the `Obstacles` group) — move or
> resize them in the editor; obstacles are on collision layer 4 so they block movement **and**
> line-of-sight.

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
- **Camera floaty / harsh:** `follow_lerp`, `shake_on_hit`, `shake_decay`, `cam_pitch`.
