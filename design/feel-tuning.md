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
| `cam_offset` | (0, 12, 7.5) | Height + pull-back of the fixed camera (the framing). Panel exposes `.y` and `.z`. |
| `cam_pitch` | -58.0 | Downward tilt in degrees — **the 2.5D angle**. |
| `shake_decay` | 6.0 | How fast a screen-shake settles (higher = snappier). |

> The shake **amount** on getting hit is `shake_on_hit` in `feel_room.gd` (below).

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

Every 3D mesh renders through ONE toon shader (`tycho_toon.gdshader`); characters (player/enemies/bosses/NPCs/gate models) add the inverted-hull outline pass (`tycho_outline.gdshader`, chained via `next_pass`). Everything below is a **`# style:` dial** — the SAME untouchable contract as `# FEEL:` (human-tuned, agents never optimize), and every current value is a first-guess placeholder. `StyleCore` consts are the source of truth; the two shaders' uniform defaults mirror them — when dialing a default, change BOTH.

| Var | Default | What it does |
|-----|---------|--------------|
| `BAND_COUNT` | 3 | Toon light bands (2 = harshest cel, higher = softer). |
| `OUTLINE_WIDTH` | 0.03 | Inverted-hull push distance (m). Characters only, never environment/props. |
| `OUTLINE_COLOR` | near-black `(0.07, 0.06, 0.10)` | Outline colour. |
| `NEUTRAL_RAMP` | cool-dark grey → white (3 stops) | The CHARACTER ramp — never stratum-tinted, so enemy identity hues + telegraph colours read identically on every floor (the readability guard). |
| `TOWN_RAMP` | warm daylight (3 stops) | The town's ramp (the town has no floor profile). |
| `RAMP_TINT_SATURATION` | 0.5 | Fraction of an env colour's saturation kept when deriving a stratum ramp. |
| `RAMP_SATURATION_CAP` | 0.4 | Max saturation any derived ramp stop may reach (subtle tint, never a hue takeover). |
| `PALETTE_*` | parchment / stone / wood / verdigris / iron / ember | Starter medieval palette consts for future props/buildings. |
| `rim_strength` (shader uniform) | 0.0 (off) | Minimal banded rim light on the lit side of characters. |
| `data/floors/<n>.json` → `environment.ramp` | absent | OPTIONAL per-floor explicit ramp — `["#hex", "#hex", "#hex"]` dark→light, used VERBATIM; absent/empty = derived from the floor's fog/background + ambient + light colours (brightness always from `NEUTRAL_RAMP`, so the dark→light order is structural). |

**Opt-outs (how a mesh stays raw):** translucent or unshaded materials are never converted (all FX/telegraph/portal/ghost materials, automatically); set metadata `style_skip` on a `MeshInstance3D` for an explicit opt-out. `scenes/combat/feel_room.tscn` is untouched — the sandbox keeps the raw look. Known gotcha: hard-edged primitives (boxes) can gap at outline corners (split normals) — acceptable on placeholders; smooth-normal models won't.

### Grass — `src/core/grass_patch.gd` (@export → Inspector) + `assets/materials/grass_blade.gdshader` uniforms *(built 2026-07-11; judge in `scenes/core/grass_demo.tscn`)*

| Var | Default | What it does |
|-----|---------|--------------|
| `patch_size` / `blade_count` | 12×12 m / 4000 | Patch footprint and density. |
| `blade_width` / `blade_height` / `height_jitter` | 0.08 / 0.55 / ±0.35 | Blade quad size + per-blade height variance. |
| `top_color` / `bottom_color` (shader) | green pair | Tip→root gradient; roots also darken by `ambient_occlusion_factor` (0.3). |
| `wind_direction` / `wind_strength` / `wind_noise_size` / `wind_noise_speed` (shader) | (1, 0, 0.35) / 0.3 / 0.05 / 0.1 | Gust direction, sway amount, gust patch size, gust travel speed. |
| `player_displacement_strength` / `player_displacement_size` (shader) | 0.4 / 1.0 | How hard and how wide a walker bends the grass (`follow_target` on the patch node). |

---

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
