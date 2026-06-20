extends CharacterBody3D
class_name Player
## Phase 0 combat-feel prototype: Tycho with move + dash + light attack.
## This is the GO/NO-GO sandbox character. Its only job is to feel good.
##
## ALL numbers marked `# FEEL:` are human-tuning territory. Agents: do not "optimize",
## round, or DRY these away — they carry the combat feel (CLAUDE.md working agreement).
## Movement is on the XZ plane; the camera has no yaw, so WASD maps straight to world XZ.
## Forward = local -Z (Godot look_at convention); the player faces the mouse cursor.

# --- Movement (FEEL) ---
const MOVE_SPEED := 7.0       # FEEL: top movement speed (m/s)
const ACCEL := 70.0           # FEEL: how fast we reach MOVE_SPEED
const FRICTION := 80.0        # FEEL: how fast we stop when no input

# --- Dash (FEEL) ---
const DASH_SPEED := 24.0      # FEEL: burst speed during a dash
const DASH_TIME := 0.15       # FEEL: how long the burst lasts (s)
const DASH_COOLDOWN := 0.90   # FEEL: time before dash is ready again (s)
const DASH_IFRAMES := 0.18    # FEEL: invulnerability window from dash start (s)

# --- Light attack — 3-hit combo (FEEL) ---
# Hits 1 & 2 are quick; hit 3 is a finisher: more damage, wider arc, longer recovery.
# Wait longer than COMBO_CONTINUE_WINDOW between hits and the sequence resets to hit 1.
const ATTACK_WINDUP := 0.05            # FEEL: delay before the hitbox goes live (s)
const ATTACK_ACTIVE := 0.10           # FEEL: how long the hitbox stays live (s)
const ATTACK_RECOVER := 0.10          # FEEL: lockout after hits 1 & 2 (s)
const ATTACK_RECOVER_FINISHER := 0.45 # FEEL: longer lockout after the 3rd hit (s)
const ATTACK_DAMAGE := 25             # FEEL: damage of hits 1 & 2
const ATTACK_DAMAGE_FINISHER := 50    # FEEL: damage of the 3rd hit
const ATTACK_MOVE_MULT := 0.35        # FEEL: movement allowed while swinging (0 = rooted)
const COMBO_CONTINUE_WINDOW := 0.35   # FEEL: max gap between hits before the combo resets (s)
const SWING_ARC_DEG := 120.0          # FEEL: blade sweep for hits 1 & 2 (degrees)
const SWING_ARC_FINISHER := 210.0     # FEEL: wider sweep for the 3rd hit (degrees)
const BLADE_ALPHA := 0.85             # FEEL: blade brightness during the swing

const MAX_HEALTH := 100

signal health_changed(hp: int, max_hp: int)
signal died

enum State { NORMAL, DASHING, ATTACKING }

var health: int = MAX_HEALTH
var _state: int = State.NORMAL
var _dash_cd: float = 0.0
var _dash_t: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _iframe_t: float = 0.0
var _attack_t: float = 0.0
var _hit_this_swing: Array = []
var _buffered_attack: bool = false
var _swing_sign: float = 1.0
var _combo_index: int = 0          # which hit the NEXT swing performs (0,1,2)
var _combo_window_t: float = 0.0   # time left (in NORMAL) to chain before the combo resets
var _cur_damage: int = ATTACK_DAMAGE
var _cur_recover: float = ATTACK_RECOVER
var _cur_arc: float = SWING_ARC_DEG

@onready var _hitbox: Area3D = $Hitbox
@onready var _mesh: MeshInstance3D = $Body
@onready var _swing_pivot: Node3D = $SwingPivot
@onready var _blade: MeshInstance3D = $SwingPivot/Blade
@onready var _hitbox_viz: MeshInstance3D = $HitboxViz
var _base_mesh_color: Color = Color(0.85, 0.85, 0.9)


func _ready() -> void:
	health_changed.emit(health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_iframe_t = maxf(0.0, _iframe_t - delta)

	_face_mouse()

	match _state:
		State.NORMAL:
			_handle_normal(delta)
		State.DASHING:
			_handle_dashing(delta)
		State.ATTACKING:
			_handle_attacking(delta)

	move_and_slide()


# --- States -----------------------------------------------------------------

func _handle_normal(delta: float) -> void:
	# Tick the combo-continue window; let it lapse and the sequence resets to hit 1.
	if _combo_window_t > 0.0:
		_combo_window_t -= delta
		if _combo_window_t <= 0.0:
			_combo_index = 0
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_start_dash()
		return
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return
	_apply_ground_movement(delta, 1.0)


func _handle_dashing(delta: float) -> void:
	_dash_t -= delta
	velocity = _dash_dir * DASH_SPEED
	if _dash_t <= 0.0:
		_state = State.NORMAL


func _handle_attacking(delta: float) -> void:
	_attack_t += delta

	# Buffer a follow-up swing if the player clicks during the swing.
	if Input.is_action_just_pressed("attack") and _attack_t >= ATTACK_WINDUP:
		_buffered_attack = true
	# Dash cancels the recovery — feels responsive — but breaks the combo.
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_reset_combo()
		_end_attack()
		_start_dash()
		return

	# Hitbox active window.
	var active_start := ATTACK_WINDUP
	var active_end := ATTACK_WINDUP + ATTACK_ACTIVE
	if _attack_t >= active_start and _attack_t < active_end:
		_apply_attack_hits()

	_update_swing_visual()
	_apply_ground_movement(delta, ATTACK_MOVE_MULT)

	if _attack_t >= active_end + _cur_recover:
		_advance_combo()


# --- Actions ----------------------------------------------------------------

func _start_dash() -> void:
	var dir := _input_dir()
	if dir == Vector3.ZERO:
		dir = -global_transform.basis.z  # dash toward facing if no movement input
	_dash_dir = dir.normalized()
	_state = State.DASHING
	_dash_t = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_iframe_t = DASH_IFRAMES


func _start_attack() -> void:
	_state = State.ATTACKING
	_attack_t = 0.0
	_buffered_attack = false
	_combo_window_t = 0.0
	_hit_this_swing.clear()
	_swing_sign = -_swing_sign  # alternate sweep direction each swing
	_swing_pivot.visible = true
	# Per-hit params for the current combo step (index 2 = finisher).
	var finisher := _combo_index == 2
	_cur_damage = ATTACK_DAMAGE_FINISHER if finisher else ATTACK_DAMAGE
	_cur_recover = ATTACK_RECOVER_FINISHER if finisher else ATTACK_RECOVER
	_cur_arc = SWING_ARC_FINISHER if finisher else SWING_ARC_DEG


## Called when a swing's recovery ends: advance/chain/reset the 3-hit sequence.
func _advance_combo() -> void:
	if _combo_index >= 2:
		# Finisher done → full reset, eat the longer recovery already applied.
		_reset_combo()
		_end_attack()
		return
	_combo_index += 1  # move to the next hit in the sequence
	if _buffered_attack:
		_start_attack()  # chain straight into the next hit
	else:
		_end_attack()
		_combo_window_t = COMBO_CONTINUE_WINDOW  # allow continuing from NORMAL


func _reset_combo() -> void:
	_combo_index = 0
	_combo_window_t = 0.0


func _end_attack() -> void:
	_state = State.NORMAL
	_buffered_attack = false
	_swing_pivot.visible = false
	_hitbox_viz.visible = false


func _apply_attack_hits() -> void:
	for body in _hitbox.get_overlapping_bodies():
		if body in _hit_this_swing:
			continue
		if body.has_method("take_damage"):
			_hit_this_swing.append(body)
			body.take_damage(_cur_damage, global_position)
			CombatFX.slash(get_parent(), body.global_position + Vector3.UP * 0.6)
			var col := Color(1.0, 0.85, 0.3) if _combo_index == 2 else Color(1.0, 1.0, 1.0)
			CombatFX.damage_number(get_parent(), body.global_position + Vector3.UP * 1.4, _cur_damage, col)


## A swept blade visual + the literal hitbox volume shown during the active window,
## so you can see exactly what a swing covers and what it hit.
func _update_swing_visual() -> void:
	var total_swing := ATTACK_WINDUP + ATTACK_ACTIVE
	var half := deg_to_rad(_cur_arc) * 0.5
	var alpha := BLADE_ALPHA
	if _attack_t <= total_swing:
		var p := ease(_attack_t / total_swing, 0.4)  # ease-out sweep
		_swing_pivot.rotation.y = lerpf(half, -half, p) * _swing_sign
	else:
		_swing_pivot.rotation.y = -half * _swing_sign
		var rp := clampf((_attack_t - total_swing) / _cur_recover, 0.0, 1.0)
		alpha = lerpf(BLADE_ALPHA, 0.0, rp)
	var mat := _blade.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color.a = alpha
	var active_end := ATTACK_WINDUP + ATTACK_ACTIVE
	_hitbox_viz.visible = _attack_t >= ATTACK_WINDUP and _attack_t < active_end


# --- Movement helpers -------------------------------------------------------

func _apply_ground_movement(delta: float, speed_mult: float) -> void:
	var dir := _input_dir()
	var target := dir * MOVE_SPEED * speed_mult
	var rate := ACCEL if dir != Vector3.ZERO else FRICTION
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	velocity.y = 0.0


func _input_dir() -> Vector3:
	var v := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if v.length() > 1.0:
		v = v.normalized()
	# Screen "up" (move_up) is -Z because the camera has no yaw.
	return Vector3(v.x, 0.0, v.y)


func _face_mouse() -> void:
	var ground := _mouse_ground_pos()
	var look := Vector3(ground.x, global_position.y, ground.z)
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)


func _mouse_ground_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position - global_transform.basis.z
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, global_position.y)
	var hit = plane.intersects_ray(from, dir)
	return hit if hit != null else global_position - global_transform.basis.z


# --- Damage / life ----------------------------------------------------------

func take_damage(amount: int, _from: Vector3 = Vector3.ZERO) -> void:
	if _iframe_t > 0.0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	_flash(Color(1.0, 0.3, 0.3))
	if health == 0:
		died.emit()


func revive() -> void:
	health = MAX_HEALTH
	_state = State.NORMAL
	velocity = Vector3.ZERO
	global_position = Vector3(0.0, global_position.y, 0.0)
	_reset_combo()
	_swing_pivot.visible = false
	_hitbox_viz.visible = false
	health_changed.emit(health, MAX_HEALTH)


func _flash(color: Color) -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = color
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self):
			mat.albedo_color = _base_mesh_color
