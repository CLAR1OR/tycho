extends CharacterBody3D
class_name EnemyDummy
## Phase 0 combat-feel prototype enemy: chase → telegraph → strike → recover.
## A real opponent (not a punching bag) so the feel gate measures real combat:
## reading the tell, dashing through the strike, punishing the recovery.
##
## Stats are @export so VARIANTS are just scenes with different values + mesh/colour
## (see enemy_dummy.tscn = Brute, enemy_skirmisher.tscn = Skirmisher). Numbers marked
## `# FEEL:` are human-tuning territory — see player.gd header.

# --- Per-variant stats (FEEL; overridden per scene) ---
@export var max_hp: int = 60
@export var move_speed: float = 4.5         # FEEL: chase speed (m/s)
@export var stop_range: float = 1.9         # FEEL: how close it gets before it commits
@export var attack_range: float = 2.6       # FEEL: max reach of a strike
@export var telegraph_time: float = 0.45    # FEEL: tell duration — the reaction window
@export var strike_time: float = 0.12       # FEEL: active hit window
@export var recover_time: float = 0.55      # FEEL: punish window after a strike
@export var attack_damage: int = 15         # FEEL: damage per strike
@export var knockback: float = 6.0          # FEEL: how far a player hit shoves it
@export var base_color: Color = Color(0.75, 0.25, 0.25)

# Shared so the TELL reads the same on every variant (yellow wind-up, red strike).
const COLOR_TELEGRAPH := Color(1.0, 0.85, 0.2)
const COLOR_STRIKE := Color(1.0, 0.2, 0.1)

# Crowd separation so enemies don't stack on each other (FEEL).
const SEPARATION_RADIUS := 2.2   # FEEL: start pushing apart within this distance (m)
const SEPARATION_FORCE := 7.0    # FEEL: how hard they spread

enum State { CHASE, TELEGRAPH, STRIKE, RECOVER }

signal died

var target: Node3D = null

var _hp: int = 0
var _state: int = State.CHASE
var _timer: float = 0.0
var _struck: bool = false
var _knockback_vel: Vector3 = Vector3.ZERO

@onready var _mesh: MeshInstance3D = $Body


func _ready() -> void:
	_hp = max_hp
	add_to_group("enemies")
	_set_color(base_color)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 30.0 * delta)

	match _state:
		State.CHASE:
			_do_chase(delta)
		State.TELEGRAPH:
			_do_telegraph(delta)
		State.STRIKE:
			_do_strike(delta)
		State.RECOVER:
			_do_recover(delta)

	velocity += _knockback_vel
	velocity += _separation()
	_face_target()
	move_and_slide()


func _do_chase(_delta: float) -> void:
	var to_target := _flat(target.global_position - global_position)
	var dist := to_target.length()
	if dist <= stop_range:
		_enter(State.TELEGRAPH, telegraph_time)
		velocity = Vector3.ZERO
		return
	velocity = to_target.normalized() * move_speed


func _do_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_enter(State.STRIKE, strike_time)
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
			CombatFX.damage_number(get_parent(), target.global_position + Vector3.UP * 1.4, attack_damage, Color(1.0, 0.5, 0.5))
			_struck = true
	if _timer <= 0.0:
		_enter(State.RECOVER, recover_time)
		_set_color(base_color)


func _do_recover(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.CHASE


func _enter(state: int, time: float) -> void:
	_state = state
	_timer = time
	if state == State.TELEGRAPH:
		_set_color(COLOR_TELEGRAPH)


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


# --- Helpers ----------------------------------------------------------------

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
