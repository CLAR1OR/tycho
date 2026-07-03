extends CharacterBody3D
class_name Player
## Phase 0 combat-feel prototype: Tycho with move + dash + light attack.
## This is the GO/NO-GO sandbox character. Its only job is to feel good.
##
## ALL numbers marked `# FEEL:` are human-tuning territory. Agents: do not "optimize",
## round, or DRY these away — they carry the combat feel (CLAUDE.md working agreement).
## They are @export vars (not consts) so they can be tuned in the Inspector AND live
## via the F1 runtime tuning panel (src/core/tuning_panel.gd).
## Movement is on the XZ plane; the camera has no yaw, so WASD maps straight to world XZ.
## Forward = local -Z (Godot look_at convention); the player faces the mouse cursor.

# --- Movement (FEEL) ---
@export var move_speed: float = 7.0       # FEEL: top movement speed (m/s)
@export var accel: float = 70.0           # FEEL: how fast we reach move_speed
@export var friction: float = 80.0        # FEEL: how fast we stop when no input

# --- Dash (FEEL) ---
@export var dash_speed: float = 24.0      # FEEL: burst speed during a dash
@export var dash_time: float = 0.15       # FEEL: how long the burst lasts (s)
@export var dash_cooldown: float = 0.90   # FEEL: time before dash is ready again (s)
@export var dash_iframes: float = 0.18    # FEEL: invulnerability window from dash start (s)

# --- Light attack — 3-hit combo (FEEL) ---
# Hits 1 & 2 are quick; hit 3 is a finisher: more damage, wider arc, longer recovery.
# Wait longer than combo_continue_window between hits and the sequence resets to hit 1.
@export var attack_windup: float = 0.05             # FEEL: delay before the hitbox goes live (s)
@export var attack_active: float = 0.10             # FEEL: how long the hitbox stays live (s)
@export var attack_recover: float = 0.10            # FEEL: lockout after hits 1 & 2 (s)
@export var attack_recover_finisher: float = 0.45   # FEEL: longer lockout after the 3rd hit (s)
@export var attack_damage: int = 25                 # FEEL: damage of hits 1 & 2
@export var attack_damage_finisher: int = 50        # FEEL: damage of the 3rd hit
@export var attack_move_mult: float = 0.35          # FEEL: movement allowed while swinging (0 = rooted)
@export var combo_continue_window: float = 0.35     # FEEL: max gap between hits before the combo resets (s)
@export var swing_arc_deg: float = 120.0            # FEEL: blade sweep for hits 1 & 2 (degrees)
@export var swing_arc_finisher: float = 210.0       # FEEL: wider sweep for the 3rd hit (degrees)
@export var blade_alpha: float = 0.85               # FEEL: blade brightness during the swing

# --- Soft aim assist — attack lunge (FEEL) ---
# Each swing magnetizes a short step toward the nearest enemy in front of you, so
# attacks connect instead of whiffing by half a metre. Whiffed swings still step
# forward a little (commitment). Set lunge_speed to 0 to switch the whole thing off.
@export var lunge_speed: float = 9.0        # FEEL: burst speed of the attack step (m/s)
@export var lunge_range: float = 4.5        # FEEL: max distance to magnet onto an enemy (m)
@export var lunge_cone_deg: float = 80.0    # FEEL: full width of the "in front of you" cone (degrees)
@export var lunge_stop: float = 1.7         # FEEL: don't lunge if the target is already this close (m)
@export var lunge_whiff_mult: float = 0.35  # FEEL: forward-step strength when no target is found
@export var lunge_decel: float = 45.0       # FEEL: how fast the lunge bleeds off (m/s²)

# --- Getting hit (FEEL) ---
@export var hit_grace: float = 0.45   # FEEL: post-hit invulnerability so crowds can't double-tap you (s)

# --- Dash ghosts (FEEL, cosmetic) ---
@export var ghost_interval: float = 0.035                     # FEEL: seconds between dash after-images
@export var ghost_color: Color = Color(0.6, 0.85, 1.0)        # FEEL: after-image tint (matches the blade)

const MAX_HEALTH := 100  # base cap; echoes/attunements raise the live max_health

signal health_changed(hp: int, max_hp: int)
signal died

enum State { NORMAL, DASHING, ATTACKING }

## Live cap — starts at the base and gets buffed by Echoes (and later Attunements).
var max_health: int = MAX_HEALTH
var health: int = MAX_HEALTH

# --- Weapon (configured per room by WeaponCore from the save's loadout) ---
## "melee" = the combo/lunge kit below; "ranged" = draw → loose an arrow → recover.
var weapon_kind: String = "melee"
var arrow_speed: float = 22.0  # ranged only; weapon data (projectile.speed)

const ARROW_SCENE := preload("res://scenes/combat/arrow.tscn")
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
var _cur_damage: int = 0           # per-swing params, set in _start_attack
var _cur_recover: float = 0.0
var _cur_arc: float = 0.0
var _lunge_vel: Vector3 = Vector3.ZERO
var _ghost_t: float = 0.0
var _shot_fired: bool = false  # ranged: one arrow per attack

@onready var _hitbox: Area3D = $Hitbox
@onready var _mesh: MeshInstance3D = $Body
@onready var _swing_pivot: Node3D = $SwingPivot
@onready var _blade: MeshInstance3D = $SwingPivot/Blade
@onready var _hitbox_viz: MeshInstance3D = $HitboxViz
var _base_mesh_color: Color = Color(0.85, 0.85, 0.9)


func _ready() -> void:
	health_changed.emit(health, max_health)


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
	velocity = _dash_dir * dash_speed
	# Leave a trail of after-images so the dash (and its i-frames) reads as a whoosh.
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = ghost_interval
		CombatFX.dash_ghost(get_parent(), _mesh.mesh, _mesh.global_transform, ghost_color)
	if _dash_t <= 0.0:
		_state = State.NORMAL


func _handle_attacking(delta: float) -> void:
	if weapon_kind == "ranged":
		_handle_ranged_attacking(delta)
		return
	_attack_t += delta

	# Buffer a follow-up swing if the player clicks during the swing.
	if Input.is_action_just_pressed("attack") and _attack_t >= attack_windup:
		_buffered_attack = true
	# Dash cancels the recovery — feels responsive — but breaks the combo.
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_reset_combo()
		_end_attack()
		_start_dash()
		return

	# Hitbox active window.
	var active_start := attack_windup
	var active_end := attack_windup + attack_active
	if _attack_t >= active_start and _attack_t < active_end:
		_apply_attack_hits()

	_update_swing_visual()

	# Aim-assist lunge: while it has punch, it owns movement (plus a little input
	# drift); once spent, hand back to normal in-swing movement.
	_lunge_vel = _lunge_vel.move_toward(Vector3.ZERO, lunge_decel * delta)
	if _lunge_vel.length() > 0.5:
		velocity = _lunge_vel + _input_dir() * move_speed * attack_move_mult
	else:
		_apply_ground_movement(delta, attack_move_mult)

	if _attack_t >= active_end + _cur_recover:
		_advance_combo()


## Ranged attack: draw (windup) → loose one arrow toward facing → recover.
## No combo, no lunge, no blade sweep — the bow's rhythm is its recover time.
func _handle_ranged_attacking(delta: float) -> void:
	_attack_t += delta
	if Input.is_action_just_pressed("attack") and _attack_t >= attack_windup:
		_buffered_attack = true
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_end_attack()
		_start_dash()
		return
	if not _shot_fired and _attack_t >= attack_windup:
		_shot_fired = true
		_fire_arrow()
	_apply_ground_movement(delta, attack_move_mult)
	if _attack_t >= attack_windup + attack_active + _cur_recover:
		_end_attack()
		if _buffered_attack:
			_start_attack()


func _fire_arrow() -> void:
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.collision_mask = 6  # enemies + walls — the player's own arrows never bite back
	get_parent().add_child(arrow)
	var dir := _flat(-global_transform.basis.z).normalized()
	arrow.global_position = global_position + Vector3.UP * 0.9 + dir * 0.8
	arrow.setup(dir, _cur_damage, arrow_speed, Color.WHITE)
	Sfx.play("arrow-loose", global_position)


# --- Actions ----------------------------------------------------------------

func _start_dash() -> void:
	var dir := _input_dir()
	if dir == Vector3.ZERO:
		dir = -global_transform.basis.z  # dash toward facing if no movement input
	_dash_dir = dir.normalized()
	_state = State.DASHING
	_dash_t = dash_time
	_dash_cd = dash_cooldown
	_iframe_t = dash_iframes
	_ghost_t = 0.0  # first after-image immediately
	Sfx.play("dash", global_position)


func _start_attack() -> void:
	_state = State.ATTACKING
	_attack_t = 0.0
	_buffered_attack = false
	_combo_window_t = 0.0
	_hit_this_swing.clear()
	if weapon_kind == "ranged":
		_shot_fired = false
		_cur_damage = attack_damage
		_cur_recover = attack_recover
		_cur_arc = 0.0
		return
	_swing_sign = -_swing_sign  # alternate sweep direction each swing
	_swing_pivot.visible = true
	# Per-hit params for the current combo step (index 2 = finisher).
	var finisher := _combo_index == 2
	_cur_damage = attack_damage_finisher if finisher else attack_damage
	_cur_recover = attack_recover_finisher if finisher else attack_recover
	_cur_arc = swing_arc_finisher if finisher else swing_arc_deg
	_acquire_lunge()


## Soft aim assist: magnet the swing toward the nearest enemy inside a forward cone.
## No target → a small forward commitment step. Facing (= mouse aim) is untouched;
## only the feet cheat.
func _acquire_lunge() -> void:
	_lunge_vel = Vector3.ZERO
	if lunge_speed <= 0.0:
		return
	var facing := _flat(-global_transform.basis.z).normalized()
	var half_cone := deg_to_rad(lunge_cone_deg) * 0.5
	var best_dir := Vector3.ZERO
	var best_d := lunge_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to_e := _flat((e as Node3D).global_position - global_position)
		var d := to_e.length()
		if d < 0.001 or d > best_d:
			continue
		if facing.angle_to(to_e) > half_cone:
			continue
		best_d = d
		best_dir = to_e / d
	if best_dir != Vector3.ZERO:
		if best_d > lunge_stop:
			_lunge_vel = best_dir * lunge_speed
	else:
		_lunge_vel = facing * lunge_speed * lunge_whiff_mult


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
		_combo_window_t = combo_continue_window  # allow continuing from NORMAL


func _reset_combo() -> void:
	_combo_index = 0
	_combo_window_t = 0.0


func _end_attack() -> void:
	_state = State.NORMAL
	_buffered_attack = false
	_lunge_vel = Vector3.ZERO
	_swing_pivot.visible = false
	_hitbox_viz.visible = false


func _apply_attack_hits() -> void:
	var stop := 0.0
	var landed := false
	var any_kill := false
	var hit_pos := global_position
	for body in _hitbox.get_overlapping_bodies():
		if body in _hit_this_swing:
			continue
		if body.has_method("take_damage"):
			_hit_this_swing.append(body)
			var killed: bool = body.take_damage(_cur_damage, global_position)
			landed = true
			any_kill = any_kill or killed
			hit_pos = body.global_position
			CombatFX.slash(get_parent(), body.global_position + Vector3.UP * 0.6)
			var col := Color(1.0, 0.85, 0.3) if _combo_index == 2 else Color(1.0, 1.0, 1.0)
			CombatFX.damage_number(get_parent(), body.global_position + Vector3.UP * 1.4, _cur_damage, col)
			# Hitstop: kills freeze longest, then finishers, then normal hits.
			var dur := CombatFX.hitstop_finisher if _combo_index == 2 else CombatFX.hitstop_light
			stop = maxf(stop, CombatFX.hitstop_kill if killed else dur)
	if landed:
		# The sound IS part of the hit weight (audio.md) — one per swing-frame,
		# scaled with the combo like hitstop; kills add their own layer.
		Sfx.play(["hit-1", "hit-2", "hit-finisher"][_combo_index], hit_pos)
		if any_kill:
			Sfx.play("kill", hit_pos)
	if stop > 0.0:
		CombatFX.hitstop(self, stop)


## A swept blade visual + the literal hitbox volume shown during the active frames,
## so you can see exactly what a swing covers and what it hit.
func _update_swing_visual() -> void:
	var total_swing := attack_windup + attack_active
	var half := deg_to_rad(_cur_arc) * 0.5
	var alpha := blade_alpha
	if _attack_t <= total_swing:
		var p := ease(_attack_t / total_swing, 0.4)  # ease-out sweep
		_swing_pivot.rotation.y = lerpf(half, -half, p) * _swing_sign
	else:
		_swing_pivot.rotation.y = -half * _swing_sign
		var rp := clampf((_attack_t - total_swing) / _cur_recover, 0.0, 1.0)
		alpha = lerpf(blade_alpha, 0.0, rp)
	var mat := _blade.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color.a = alpha
	var active_end := attack_windup + attack_active
	_hitbox_viz.visible = _attack_t >= attack_windup and _attack_t < active_end


# --- Movement helpers -------------------------------------------------------

func _apply_ground_movement(delta: float, speed_mult: float) -> void:
	var dir := _input_dir()
	var target := dir * move_speed * speed_mult
	var rate := accel if dir != Vector3.ZERO else friction
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


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Damage / life ----------------------------------------------------------

func take_damage(amount: int, _from: Vector3 = Vector3.ZERO) -> void:
	if _iframe_t > 0.0:
		return
	health = maxi(0, health - amount)
	_iframe_t = maxf(_iframe_t, hit_grace)  # post-hit grace: crowds can't double-tap
	health_changed.emit(health, max_health)
	Sfx.play("player-hurt", global_position)
	_flash(Color(1.0, 0.3, 0.3))
	if health == 0:
		died.emit()


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


## Set HP outright (used to carry wounds between rooms of a run). Never kills.
func restore_health(hp: int) -> void:
	health = clampi(hp, 1, max_health)
	health_changed.emit(health, max_health)


func revive() -> void:
	health = max_health
	_state = State.NORMAL
	velocity = Vector3.ZERO
	global_position = Vector3(0.0, global_position.y, 0.0)
	_reset_combo()
	_swing_pivot.visible = false
	_hitbox_viz.visible = false
	health_changed.emit(health, max_health)


func _flash(color: Color) -> void:
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = color
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self):
			mat.albedo_color = _base_mesh_color
