# Feel-Tuning Knobs — the combat-feel gate

> **Purpose:** one place that lists every number you can turn to tune how the Phase 0
> combat-feel gate *feels*, what each one does, and exactly where to change it. This is
> the dial board for the go/no-go playtest (CLAUDE.md → Build order, Phase 0; pass bar:
> *after the 20th clear, you still want one more*).
>
> **Game feel cannot be vibecoded** — these are meant for hands-on human iteration. Tweak,
> run, feel, repeat. Don't let an agent "optimize" or round them away.

---

## Two kinds of knob — and where each one lives

There are **two** ways a value is exposed, and they're edited in different places:

| Kind | Edited where | Shows in Godot editor? | Live per-instance? |
|------|--------------|------------------------|--------------------|
| **`@export` var** | Godot **Inspector**, *or* the `.gd` file's default | ✅ Yes — select the node, see the **Inspector** | ✅ Each scene/instance can override it |
| **`const`** | Only by editing the `.gd` script file | ❌ No — code-only | ❌ Same value for every instance |

### How to edit an `@export` in the Godot editor
1. Open the scene in the editor (e.g. `scenes/combat/enemy_dummy.tscn`).
2. Click the **root node** in the Scene panel (e.g. `EnemyDummy`).
3. Look at the **Inspector** (right side). The exported vars appear under a
   **"Script Variables"** heading (`Max Hp`, `Move Speed`, `Engage Dist`, …).
4. Change a value → **Ctrl+S**. It's saved into that `.tscn`, so it only affects that variant.

> Godot prettifies names in the Inspector: `move_speed` shows as **"Move Speed"**,
> `engage_dist` as **"Engage Dist"**, etc.

### How to edit a `const`
Open the listed `.gd` file in any editor (or Godot's Script tab), change the number after
`:=`, save. It changes the value for **all** instances. Consts are used for things that
should be uniform across the whole prototype (player feel, camera, crowd rules).

> **Quick way to find any of these:** search the codebase for `# FEEL:` — every tunable
> is tagged with that comment.

---

## Player — `src/combat/player.gd`  (all `const`, code-only)
The player is one instance, so its feel lives in consts. Edit the file directly.

### Movement
| Const | Default | What it does |
|-------|---------|--------------|
| `MOVE_SPEED` | 7.0 | Top run speed (m/s). |
| `ACCEL` | 70.0 | How fast you reach top speed (higher = snappier start). |
| `FRICTION` | 80.0 | How fast you stop when you release the keys (higher = less slide). |

### Dash
| Const | Default | What it does |
|-------|---------|--------------|
| `DASH_SPEED` | 24.0 | Burst speed during a dash. |
| `DASH_TIME` | 0.15 | How long the burst lasts (s). |
| `DASH_COOLDOWN` | 0.90 | Time before dash is ready again (s). |
| `DASH_IFRAMES` | 0.18 | Invulnerability window from dash start (s). Raise to make dashing more forgiving. |

### Light attack — 3-hit combo
| Const | Default | What it does |
|-------|---------|--------------|
| `ATTACK_WINDUP` | 0.05 | Delay before the hitbox goes live (s) — the wind-up. |
| `ATTACK_ACTIVE` | 0.10 | How long the hitbox stays live (s). |
| `ATTACK_RECOVER` | 0.10 | Lockout after hits 1 & 2 (s). |
| `ATTACK_RECOVER_FINISHER` | 0.45 | Longer lockout after the 3rd hit (s) — the finisher's commitment. |
| `ATTACK_DAMAGE` | 25 | Damage of hits 1 & 2. |
| `ATTACK_DAMAGE_FINISHER` | 50 | Damage of the 3rd hit. |
| `ATTACK_MOVE_MULT` | 0.35 | How much you can still move while swinging (0 = rooted, 1 = full speed). |
| `COMBO_CONTINUE_WINDOW` | 0.35 | Max gap between hits before the combo resets to hit 1 (s). |
| `SWING_ARC_DEG` | 120.0 | Blade sweep for hits 1 & 2 (degrees) — also the hit cone width. |
| `SWING_ARC_FINISHER` | 210.0 | Wider sweep for the 3rd hit (degrees). |
| `BLADE_ALPHA` | 0.85 | Blade visual brightness during the swing (cosmetic). |

> `MAX_HEALTH` (100) lives here too — not a `# FEEL:` knob but easy to change.
> The literal hitbox **size** is the `Hitbox`/`HitboxViz` node in `scenes/combat/player.tscn`
> (a `BoxShape3D` you can resize in the editor), not a number in the script.

---

## Camera — `src/core/camera_rig.gd`  (all `const`, code-only)
| Const | Default | What it does |
|-------|---------|--------------|
| `FOLLOW_LERP` | 9.0 | How tightly the camera tracks you (higher = snappier, lower = floatier). |
| `CAM_OFFSET` | (0, 15, 9) | Height + pull-back of the fixed camera (the framing). |
| `CAM_PITCH` | -58.0 | Downward tilt in degrees — **the 2.5D angle**. |
| `SHAKE_DECAY` | 6.0 | How fast a screen-shake settles (higher = snappier). |

> The shake **amount** on getting hit is `SHAKE_ON_HIT` in `feel_room.gd` (below).

---

## Enemies — base behaviour `src/combat/enemy_dummy.gd`
This script is shared by **all three variants**. It has two layers:

### A) Per-variant stats — `@export` (✏️ edit in the Inspector, per variant)
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
| `sight_range` (Sight Range) | How close you must be for it to notice you (m). Needs line of sight too. |
| `base_color` (Base Color) | Body colour (also dimmed when dormant). Cosmetic / readability. |

### B) Shared behaviour rules — `const` (code-only, affect all enemies)
| Const | Default | What it does |
|-------|---------|--------------|
| `MAX_ATTACKERS` | 2 | How many **melee** enemies may commit to attacking at once (crowd readability). Archers are exempt. |
| `CIRCLE_SPEED_MULT` | 0.7 | Orbit speed vs. charge speed (lower = they circle more lazily). |
| `CLOSE_TIMEOUT` | 1.5 | Melee gives up a charge if it can't reach a kiting player in this long (s). |
| `SEPARATION_RADIUS` | 2.2 | Enemies start pushing apart within this distance (m) — anti-stacking. |
| `SEPARATION_FORCE` | 7.0 | How hard they spread. |
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
| `sight_range` | 12.0 | 12.0 | 14.0 |
| `shoot_range` | — | — | 11.0 |
| `min_range` | — | — | 6.0 |
| `base_color` | red | orange | green |

---

## The room & the wave — `src/combat/feel_room.gd`  (`const`, code-only)
The sandbox director. Tune the encounter, not a character.

| Const | Default | What it does |
|-------|---------|--------------|
| `ENEMY_COUNT` | 4 | Enemies per wave. |
| `RESPAWN_DELAY` | 1.0 | Beat between clearing a wave and the next (s). |
| `SHAKE_ON_HIT` | 0.35 | Camera kick when **you** take a hit (pairs with `SHAKE_DECAY`). |
| `SPAWN_RADIUS` | 18.0 | How far out around the room the wave scatters (m). |
| `SPAWN_JITTER` | 3.0 | Random wobble on each spawn point (m). |

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

> Damage-number **size** is on the `DamageNumber` node in `scenes/combat/damage_number.tscn`
> (`pixel_size` 0.008, `font_size` 40) — editor, not script.

---

## First dials to try (suggested starting points)
- **Too easy / too hard:** enemy `attack_damage`, `telegraph_time` (longer = fairer),
  `ENEMY_COUNT`, `MAX_ATTACKERS`.
- **Combat feels mushy:** player `ATTACK_RECOVER*`, `ATTACK_WINDUP`, `DASH_COOLDOWN`.
- **Crowds unreadable:** `MAX_ATTACKERS` (down), `SEPARATION_FORCE` (up), enemy `engage_dist`.
- **Archers oppressive:** arrow `SPEED` (down), Archer `telegraph_time` (up), `shoot_range` (down).
- **Camera floaty / harsh:** `FOLLOW_LERP`, `SHAKE_ON_HIT`, `SHAKE_DECAY`, `CAM_PITCH`.
