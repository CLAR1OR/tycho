extends CharacterBody3D
class_name EnemyDummy
## Phase 0 combat-feel prototype enemy.
##
## Behaviour: start DORMANT (idle). Only wake when the player is within sight_range
## AND in clear line of sight (a raycast against the obstacle layer — cover blocks it).
## Once awake: orbit the player at a stand-off distance (strafing, not beelining);
## when a COMMIT TOKEN is free, close in → telegraph → strike → recover → rest,
## then back to orbiting. Only max_attackers enemies may be committed at once, so
## crowds stay readable (the "token" is just being in a committed state — counted
## across the "enemies" group, so it can never leak). Walk far enough away and they
## lose interest and settle back to idle.
##
## Squishy variants (stagger_time > 0) get INTERRUPTED by player hits: any hit knocks
## them into a brief STAGGER that cancels a wind-up — so attacking them is also
## defence. Brutes have stagger_time 0 and power through (armored).
##
## Stats are @export so VARIANTS are just scenes with different values + mesh/colour
## (enemy_dummy.tscn = Brute, enemy_skirmisher.tscn = Skirmisher). Numbers marked
## `# FEEL:` are human-tuning territory — see player.gd header.

# --- Per-variant stats (FEEL; overridden per scene) ---
@export var max_hp: int = 60
@export var move_speed: float = 4.5         # FEEL: chase/close speed (m/s)
@export var engage_dist: float = 4.5        # FEEL: orbit stand-off radius (m)
@export var stop_range: float = 1.9         # FEEL: close to here, then it strikes
@export var attack_range: float = 2.6       # FEEL: max reach of a strike
@export var telegraph_time: float = 0.45    # FEEL: tell duration — the reaction window
@export var strike_time: float = 0.12       # FEEL: active hit window
@export var recover_time: float = 0.4       # FEEL: punish window right after a strike
@export var rest_time: float = 0.9          # FEEL: orbit-and-breathe before re-engaging
@export var attack_damage: int = 15         # FEEL: damage per strike
@export var knockback: float = 6.0          # FEEL: how far a player hit shoves it
@export var stagger_time: float = 0.0       # FEEL: hit-interrupt duration; 0 = armored (Brute)
@export var sight_range: float = 12.0       # FEEL: how close the player must be to be noticed (m)
@export var base_color: Color = Color(0.75, 0.25, 0.25)

# Shared so the TELL reads the same on every variant (yellow wind-up, red strike).
const COLOR_TELEGRAPH := Color(1.0, 0.85, 0.2)
const COLOR_STRIKE := Color(1.0, 0.2, 0.1)

# Crowd control (shared across all variants; `static var` so the F1 tuning panel
# can dial them live for the whole class — treat like consts otherwise).
static var max_attackers: int = 2            # FEEL: how many enemies may commit at once
static var circle_speed_mult: float = 0.7    # FEEL: orbit speed vs. charge speed
static var close_timeout: float = 1.5        # FEEL: give up closing if the player kites this long (s)
static var separation_radius: float = 2.2    # FEEL: start pushing apart within this distance (m)
static var separation_force: float = 7.0     # FEEL: how hard they spread

# Idle wander (shared across all variants).
const WANDER_SPEED_MULT := 0.35   # FEEL: idle stroll speed vs. move_speed
const WANDER_RADIUS := 6.0        # FEEL: how far each idle stroll point is (m)
const WANDER_BOUND := 24.0        # keep stroll points inside the room (m from centre)

# Perception (shared across all variants).
const OBSTACLE_MASK := 4          # collision layer of walls + cover (blocks sight)
const SIGHT_HEIGHT := 0.7         # eye height for the line-of-sight ray (m)
const SIGHT_LOSE_MARGIN := 7.0    # FEEL: lose interest past sight_range + this (m)
const IDLE_DARKEN := 0.4          # how much dimmer a dormant enemy looks

const DEATH_FX_HEIGHT := 0.9      # where the death burst spawns (body-centre height, m)

enum State { IDLE, ENGAGE, CLOSING, TELEGRAPH, STRIKE, RECOVER, REST, STAGGER }

signal died

var target: Node3D = null

## Movement multiplier applied to planar velocity (1.0 = normal). The Snare etching's
## field sets this < 1 while an enemy is inside and restores 1.0 on exit/expiry — it must
## NEVER persist past the field (design/etchings.md Q). Runtime-only, not a FEEL export.
var slow_factor: float = 1.0

var _hp: int = 0
var _state: int = State.IDLE
var _timer: float = 0.0
var _struck: bool = false
var _knockback_vel: Vector3 = Vector3.ZERO
# Push etching (design/etchings.md RMB): a heavy knockback that deals bonus damage +
# a brief forced stagger if the enemy is slammed into a wall/obstacle (reuses the
# Charger's _hit_wall idea). Active only for the duration of the shove.
var _slam_active: bool = false
var _slam_bonus_dmg: int = 0
var _slam_stagger: float = 0.0
var _circle_dir: float = 1.0
var _flip_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0

@onready var _mesh: MeshInstance3D = $Body


func _ready() -> void:
	_hp = max_hp
	add_to_group("enemies")
	_set_color(_idle_color())   # dormant until it notices the player
	_circle_dir = 1.0 if randf() < 0.5 else -1.0
	_flip_timer = randf_range(1.0, 3.0)
	_pick_wander()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 30.0 * delta)

	match _state:
		State.IDLE:
			_do_idle(delta)
		State.ENGAGE:
			_do_engage(delta)
		State.CLOSING:
			_do_closing(delta)
		State.TELEGRAPH:
			_do_telegraph(delta)
		State.STRIKE:
			_do_strike(delta)
		State.RECOVER:
			_do_recover(delta)
		State.REST:
			_do_rest(delta)
		State.STAGGER:
			_do_stagger(delta)

	velocity += _knockback_vel
	velocity += _separation()
	# Snare field: heavily slow the whole planar motion while inside (restored on exit).
	velocity.x *= slow_factor
	velocity.z *= slow_factor
	if _state == State.IDLE:
		_face_move()   # a strolling enemy looks where it walks, not at an unseen player
	else:
		_face_target()
	move_and_slide()
	_check_slam_wall()


# --- States -----------------------------------------------------------------

func _do_idle(delta: float) -> void:
	# Dormant but alive: stroll slowly between random nearby points until the player
	# is seen (in range + clear line of sight). Pauses briefly at each point.
	if _can_see_target():
		_wake()
		return
	_wander_timer -= delta
	var to_point := _flat(_wander_target - global_position)
	if to_point.length() < 0.5 or _wander_timer <= 0.0:
		_pick_wander()  # arrived, or timed out (e.g. blocked by cover) → new point
		velocity = Vector3.ZERO
	else:
		velocity = to_point.normalized() * move_speed * WANDER_SPEED_MULT


func _do_engage(delta: float) -> void:
	# Lose interest if the player gets far enough away.
	if _dist_to_target() > sight_range + SIGHT_LOSE_MARGIN:
		_to_idle()
		return
	_update_flip(delta)
	velocity = _orbit_velocity()
	# Commit to an attack when in range and a token is free.
	if _dist_to_target() <= engage_dist + 0.5 and _committed_count() < max_attackers:
		_state = State.CLOSING
		_timer = close_timeout


func _do_closing(delta: float) -> void:
	_timer -= delta
	var to_target := _flat(target.global_position - global_position)
	var dist := to_target.length()
	if dist <= stop_range:
		_state = State.TELEGRAPH
		_timer = telegraph_time
		velocity = Vector3.ZERO
		_set_color(COLOR_TELEGRAPH)
		return
	if _timer <= 0.0:
		_start_rest()  # couldn't reach a kiting player — drop the token and breathe
		return
	velocity = to_target.normalized() * move_speed


func _do_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.STRIKE
		_timer = strike_time
		_struck = false
		_set_color(COLOR_STRIKE)


func _do_strike(delta: float) -> void:
	# Lunge forward during the strike.
	var to_target := _flat(target.global_position - global_position).normalized()
	velocity = to_target * move_speed * 1.5
	_timer -= delta
	if not _struck:
		var dist := _flat(target.global_position - global_position).length()
		if dist <= attack_range and target.has_method("take_damage"):
			target.take_damage(attack_damage, global_position)
			CombatFX.damage_number(get_parent(), target.global_position + Vector3.UP * 1.6, attack_damage, Color(1.0, 0.5, 0.5))
			_struck = true
	if _timer <= 0.0:
		_state = State.RECOVER
		_timer = recover_time
		_set_color(base_color)


func _do_recover(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_start_rest()


func _do_rest(delta: float) -> void:
	# Orbit and breathe — NOT committed, so the token is free for others.
	if _dist_to_target() > sight_range + SIGHT_LOSE_MARGIN:
		_to_idle()
		return
	_update_flip(delta)
	velocity = _orbit_velocity()
	_timer -= delta
	if _timer <= 0.0:
		_state = State.ENGAGE


func _do_stagger(delta: float) -> void:
	# Hit-interrupted: rooted (knockback still shoves via _knockback_vel), any
	# wind-up cancelled, commit token released. Back to ENGAGE when it wears off.
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.ENGAGE
		_set_color(base_color)


func _start_rest() -> void:
	_state = State.REST
	_timer = rest_time
	_set_color(base_color)


# --- Movement helpers -------------------------------------------------------

## Strafe around the player, correcting toward the stand-off radius. This is what
## makes them orbit instead of beelining.
func _orbit_velocity() -> Vector3:
	var to_target := _flat(target.global_position - global_position)
	var dist := to_target.length()
	if dist < 0.001:
		return Vector3.ZERO
	var radial := to_target / dist
	var tangent := Vector3.UP.cross(radial) * _circle_dir
	var radius_error := clampf(dist - engage_dist, -1.0, 1.0)  # +far → move in, −close → move out
	var dir := tangent + radial * radius_error * 0.9
	if dir.length() < 0.001:
		return Vector3.ZERO
	return dir.normalized() * move_speed * circle_speed_mult


## Choose a fresh idle stroll point near the current position, clamped to the room.
func _pick_wander() -> void:
	var ang := randf() * TAU
	var r := randf_range(2.0, WANDER_RADIUS)
	var t := global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	t.x = clampf(t.x, -WANDER_BOUND, WANDER_BOUND)
	t.z = clampf(t.z, -WANDER_BOUND, WANDER_BOUND)
	_wander_target = t
	_wander_timer = randf_range(1.5, 3.5)  # also a stuck-against-cover backstop


func _update_flip(delta: float) -> void:
	_flip_timer -= delta
	if _flip_timer <= 0.0:
		_circle_dir = -_circle_dir
		_flip_timer = randf_range(1.5, 3.5)


## Push away from nearby enemies so a wave spreads instead of stacking.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var diff := _flat(global_position - (other as Node3D).global_position)
		var d := diff.length()
		if d > 0.001 and d < separation_radius:
			push += diff.normalized() * (1.0 - d / separation_radius)
	return push * separation_force


# --- Perception -------------------------------------------------------------

## Wake from idle: the player is close enough AND in clear line of sight.
func _wake() -> void:
	_state = State.ENGAGE
	_set_color(base_color)


## Lose interest and go dormant again.
func _to_idle() -> void:
	_state = State.IDLE
	velocity = Vector3.ZERO
	_set_color(_idle_color())


func _can_see_target() -> bool:
	if _dist_to_target() > sight_range:
		return false
	return _has_line_of_sight()


## Raycast enemy → player against the obstacle layer; cover/walls block it.
func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * SIGHT_HEIGHT
	var to := target.global_position + Vector3.UP * SIGHT_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, OBSTACLE_MASK)
	return space.intersect_ray(query).is_empty()


func _idle_color() -> Color:
	return base_color.darkened(IDLE_DARKEN)


# --- Crowd-control token ----------------------------------------------------

## A committed enemy is mid-attack-commitment; only max_attackers may be at once.
func is_committed() -> bool:
	return _state == State.CLOSING or _state == State.TELEGRAPH or _state == State.STRIKE


func _committed_count() -> int:
	var n := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(other) and (other as EnemyDummy).is_committed():
			n += 1
	return n


# --- Damage -----------------------------------------------------------------

## Returns true if this hit killed the enemy (the player uses it to size hitstop).
func take_damage(amount: int, from: Vector3 = Vector3.ZERO) -> bool:
	_hp = maxi(0, _hp - amount)
	if _state == State.IDLE:
		_wake()   # getting hit always rouses a dormant enemy
	if from != Vector3.ZERO:
		var dir := _flat(global_position - from).normalized()
		_knockback_vel = dir * knockback
	if _hp == 0:
		CombatFX.death_burst(get_parent(), global_position + Vector3.UP * DEATH_FX_HEIGHT, base_color)
		died.emit()
		queue_free()
		return true
	_flash()
	# Squishy variants get interrupted: cancels a wind-up and drops the token.
	if stagger_time > 0.0:
		_enter_stagger()
	return false


func _enter_stagger() -> void:
	_state = State.STAGGER
	_timer = stagger_time
	_set_color(base_color)  # a cancelled telegraph must stop reading as a threat


# --- Etching hooks (design/etchings.md) --------------------------------------

## Heavy shove from the Push etching. Knocks the enemy back (armored or not — knockback
## is not a stagger); if it hits a wall/obstacle mid-shove it takes `wall_bonus_dmg` and a
## brief forced stagger. Overrides the light take_damage knockback.
func apply_knockback(dir: Vector3, strength: float, wall_bonus_dmg: int = 0, wall_stagger: float = 0.0) -> void:
	_knockback_vel = _flat(dir).normalized() * strength
	_slam_bonus_dmg = wall_bonus_dmg
	_slam_stagger = wall_stagger
	_slam_active = wall_bonus_dmg > 0


## While being shoved by Push, a wall/obstacle collision spends the shove for bonus damage
## + a brief stagger (design's "slammed into walls take bonus damage + brief stagger").
func _check_slam_wall() -> void:
	if not _slam_active:
		return
	if _knockback_vel.length() < 1.0:
		_slam_active = false
		return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody3D:
			_slam_active = false
			_knockback_vel = Vector3.ZERO
			if _slam_stagger > 0.0:
				force_stagger(_slam_stagger)
			take_damage(_slam_bonus_dmg)  # no `from` → no extra knockback
			return


## Brief hit-interrupt for SQUISHIES only (stagger_time > 0) — used by the Snare field's
## on-cast root. Armored enemies are never staggered by this (design: armored never rooted).
func stagger(duration: float) -> void:
	if stagger_time <= 0.0:
		return
	_state = State.STAGGER
	_timer = duration
	_set_color(base_color)


## Force a stagger even on ARMORED enemies — the Shockwave etching is the ONLY thing that
## bypasses stagger_time == 0 (design/etchings.md R: "briefly staggers even armored").
func force_stagger(duration: float) -> void:
	_state = State.STAGGER
	_timer = duration
	_set_color(base_color)


## True while hit-interrupted (STAGGER). Exposed for the headless smoke's shockwave assert.
func is_staggered() -> bool:
	return _state == State.STAGGER


## Current hit points (max is the `max_hp` export). Read-only view for the run HUD's
## boss bar, which polls the boss node each frame (design/ui-hud.md).
func current_hp() -> int:
	return _hp


# --- Misc helpers -----------------------------------------------------------

func _dist_to_target() -> float:
	return _flat(target.global_position - global_position).length()


func _face_target() -> void:
	if target == null:
		return
	var look := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)


## Face the current movement direction (used while strolling in idle).
func _face_move() -> void:
	var v := _flat(velocity)
	if v.length() > 0.1:
		look_at(global_position + v, Vector3.UP)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _set_color(c: Color) -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = c


func _flash() -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color.WHITE
		await get_tree().create_timer(0.06).timeout
		if is_instance_valid(self) and mat is StandardMaterial3D:
			# Restore whatever colour the CURRENT state wants (it may have changed
			# during the flash — e.g. the hit caused a stagger or a wake).
			match _state:
				State.IDLE:
					mat.albedo_color = _idle_color()
				State.TELEGRAPH:
					mat.albedo_color = COLOR_TELEGRAPH
				State.STRIKE:
					mat.albedo_color = COLOR_STRIKE
				_:
					mat.albedo_color = base_color
