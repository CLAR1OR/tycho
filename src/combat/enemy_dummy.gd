extends CharacterBody3D
class_name EnemyDummy
## Phase 0 combat-feel prototype enemy: chase → telegraph → strike → recover.
## A real opponent (not a punching bag) so the feel gate measures real combat:
## reading the tell, dashing through the strike, punishing the recovery.
##
## Numbers marked `# FEEL:` are human-tuning territory — see player.gd header.

const MAX_HP := 60

# FEEL: behaviour timing/spacing — the readability of the fight lives here.
const MOVE_SPEED := 4.5        # FEEL: chase speed (m/s)
const STOP_RANGE := 1.9        # FEEL: how close it gets before it commits
const ATTACK_RANGE := 2.6      # FEEL: max reach of a strike
const TELEGRAPH_TIME := 0.45   # FEEL: tell duration — the player's reaction window
const STRIKE_TIME := 0.12      # FEEL: active hit window
const RECOVER_TIME := 0.55     # FEEL: punish window after a whiff/hit
const ATTACK_DAMAGE := 15      # FEEL: damage per strike
const KNOCKBACK := 6.0         # FEEL: how far a player hit shoves it

enum State { CHASE, TELEGRAPH, STRIKE, RECOVER }

signal died

var target: Node3D = null

var _hp: int = MAX_HP
var _state: int = State.CHASE
var _timer: float = 0.0
var _struck: bool = false
var _knockback_vel: Vector3 = Vector3.ZERO

@onready var _mesh: MeshInstance3D = $Body
var _color_chase: Color = Color(0.75, 0.25, 0.25)
var _color_telegraph: Color = Color(1.0, 0.85, 0.2)
var _color_strike: Color = Color(1.0, 0.2, 0.1)


func _ready() -> void:
	_set_color(_color_chase)


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
	_face_target()
	move_and_slide()


func _do_chase(delta: float) -> void:
	var to_target := _flat(target.global_position - global_position)
	var dist := to_target.length()
	if dist <= STOP_RANGE:
		_enter(State.TELEGRAPH, TELEGRAPH_TIME)
		velocity = Vector3.ZERO
		return
	velocity = to_target.normalized() * MOVE_SPEED


func _do_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	# Wind-up "lean": a small lurch toward the player sells the tell.
	if _timer <= 0.0:
		_enter(State.STRIKE, STRIKE_TIME)
		_struck = false
		_set_color(_color_strike)


func _do_strike(delta: float) -> void:
	# Lunge forward during the strike.
	var to_target := _flat(target.global_position - global_position).normalized()
	velocity = to_target * MOVE_SPEED * 1.5
	_timer -= delta
	if not _struck:
		var dist := _flat(target.global_position - global_position).length()
		if dist <= ATTACK_RANGE and target.has_method("take_damage"):
			target.take_damage(ATTACK_DAMAGE, global_position)
			_struck = true
	if _timer <= 0.0:
		_enter(State.RECOVER, RECOVER_TIME)
		_set_color(_color_chase)


func _do_recover(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.CHASE


func _enter(state: int, time: float) -> void:
	_state = state
	_timer = time
	if state == State.TELEGRAPH:
		_set_color(_color_telegraph)


# --- Damage -----------------------------------------------------------------

func take_damage(amount: int, from: Vector3 = Vector3.ZERO) -> void:
	_hp = maxi(0, _hp - amount)
	_flash()
	if from != Vector3.ZERO:
		var dir := _flat(global_position - from).normalized()
		_knockback_vel = dir * KNOCKBACK
	if _hp == 0:
		died.emit()
		queue_free()


# --- Helpers ----------------------------------------------------------------

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
