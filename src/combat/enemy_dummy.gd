extends CharacterBody3D
class_name EnemyDummy
## Phase 0 combat-feel prototype enemy.
##
## Behaviour: orbit the player at a stand-off distance (strafing, not beelining);
## when a COMMIT TOKEN is free, close in → telegraph → strike → recover → rest,
## then back to orbiting. Only MAX_ATTACKERS enemies may be committed at once, so
## crowds stay readable (the "token" is just being in a committed state — counted
## across the "enemies" group, so it can never leak).
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
@export var base_color: Color = Color(0.75, 0.25, 0.25)

# Shared so the TELL reads the same on every variant (yellow wind-up, red strike).
const COLOR_TELEGRAPH := Color(1.0, 0.85, 0.2)
const COLOR_STRIKE := Color(1.0, 0.2, 0.1)

# Crowd control (shared across all variants).
const MAX_ATTACKERS := 2          # FEEL: how many enemies may commit at once
const CIRCLE_SPEED_MULT := 0.7    # FEEL: orbit speed vs. charge speed
const CLOSE_TIMEOUT := 1.5        # FEEL: give up closing if the player kites this long (s)
const SEPARATION_RADIUS := 2.2    # FEEL: start pushing apart within this distance (m)
const SEPARATION_FORCE := 7.0     # FEEL: how hard they spread

enum State { ENGAGE, CLOSING, TELEGRAPH, STRIKE, RECOVER, REST }

signal died

var target: Node3D = null

var _hp: int = 0
var _state: int = State.ENGAGE
var _timer: float = 0.0
var _struck: bool = false
var _knockback_vel: Vector3 = Vector3.ZERO
var _circle_dir: float = 1.0
var _flip_timer: float = 0.0

@onready var _mesh: MeshInstance3D = $Body


func _ready() -> void:
	_hp = max_hp
	add_to_group("enemies")
	_set_color(base_color)
	_circle_dir = 1.0 if randf() < 0.5 else -1.0
	_flip_timer = randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 30.0 * delta)

	match _state:
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

	velocity += _knockback_vel
	velocity += _separation()
	_face_target()
	move_and_slide()


# --- States -----------------------------------------------------------------

func _do_engage(delta: float) -> void:
	_update_flip(delta)
	velocity = _orbit_velocity()
	# Commit to an attack when in range and a token is free.
	if _dist_to_target() <= engage_dist + 0.5 and _committed_count() < MAX_ATTACKERS:
		_state = State.CLOSING
		_timer = CLOSE_TIMEOUT


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
	_update_flip(delta)
	velocity = _orbit_velocity()
	_timer -= delta
	if _timer <= 0.0:
		_state = State.ENGAGE


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
	return dir.normalized() * move_speed * CIRCLE_SPEED_MULT


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
		if d > 0.001 and d < SEPARATION_RADIUS:
			push += diff.normalized() * (1.0 - d / SEPARATION_RADIUS)
	return push * SEPARATION_FORCE


# --- Crowd-control token ----------------------------------------------------

## A committed enemy is mid-attack-commitment; only MAX_ATTACKERS may be at once.
func is_committed() -> bool:
	return _state == State.CLOSING or _state == State.TELEGRAPH or _state == State.STRIKE


func _committed_count() -> int:
	var n := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(other) and (other as EnemyDummy).is_committed():
			n += 1
	return n


# --- Damage -----------------------------------------------------------------

func take_damage(amount: int, from: Vector3 = Vector3.ZERO) -> void:
	_hp = maxi(0, _hp - amount)
	_flash()
	if from != Vector3.ZERO:
		var dir := _flat(global_position - from).normalized()
		_knockback_vel = dir * knockback
	if _hp == 0:
		died.emit()
		queue_free()


# --- Misc helpers -----------------------------------------------------------

func _dist_to_target() -> float:
	return _flat(target.global_position - global_position).length()


func _face_target() -> void:
	if target == null:
		return
	var look := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _set_color(c: Color) -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = c


func _flash() -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		var prev: Color = mat.albedo_color
		mat.albedo_color = Color.WHITE
		await get_tree().create_timer(0.06).timeout
		if is_instance_valid(self) and mat is StandardMaterial3D:
			mat.albedo_color = prev
