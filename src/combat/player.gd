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
@export var move_speed: float = 9.0       # FEEL: top movement speed (m/s)
@export var accel: float = 70.0           # FEEL: how fast we reach move_speed
@export var friction: float = 80.0        # FEEL: how fast we stop when no input

# --- Dash (FEEL) ---
@export var dash_speed: float = 30.0      # FEEL: burst speed during a dash
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

## External push accumulator (design/dungeon-strata.md drift fields). A DriftField adds
## into this each physics tick; it is folded into velocity and reset every frame just
## before move_and_slide, so it never persists past the field. Additive only — carries
## no feel value of its own (the push_strength in the hazard data is the placeholder dial).
var external_drift: Vector3 = Vector3.ZERO

# --- Weapon (configured per room by WeaponCore from the save's loadout) ---
## "melee" = the combo/lunge kit below; "ranged" = draw → loose an arrow → recover.
var weapon_kind: String = "melee"
var arrow_speed: float = 22.0  # ranged only; weapon data (projectile.speed)

const ARROW_SCENE := preload("res://scenes/combat/arrow.tscn")
const SNARE_FIELD := preload("res://src/combat/snare_field.gd")

# --- Etchings (design/etchings.md) — the RMB/Q/R ability kit, loaded from the save ---
# Data lives in data/etchings/; per-ability numbers are in each def's `behavior` dict
# (the dial board — feel-tuning.md), NOT here, so they tune like economy numbers. Five
# abilities are implemented (Push/Bolt/Snare/Shockwave/Surge); the rest are dormant.
var _etch_defs: Dictionary = {}
var _etch_state: Dictionary = {}                 # the save's combat.etchings, at spawn
var _equipped := {"rmb": "", "q": "", "r": ""}   # slot -> etching id
var _cast_cd := {"rmb": 0.0, "q": 0.0, "r": 0.0} # per-slot cooldown remaining (s)
var _surge_t: float = 0.0                        # Surge remaining (s); 0 = inactive
var _surge_prev: Dictionary = {}                 # stats to restore when Surge ends

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
	_load_etchings()


func _physics_process(delta: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_tick_abilities(delta)

	_face_mouse()

	# Cast an equipped ability toward the cursor (respects cooldown; never mid-dash —
	# a committed dash shouldn't be cancelled). try_cast is the shared entry point.
	if _state != State.DASHING:
		if Input.is_action_just_pressed("ability_rmb"):
			try_cast("rmb")
		elif Input.is_action_just_pressed("ability_q"):
			try_cast("q")
		elif Input.is_action_just_pressed("ability_r"):
			try_cast("r")

	match _state:
		State.NORMAL:
			_handle_normal(delta)
		State.DASHING:
			_handle_dashing(delta)
		State.ATTACKING:
			_handle_attacking(delta)

	# Drift field push (design/dungeon-strata.md): folded in + reset each tick.
	velocity += external_drift
	external_drift = Vector3.ZERO

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


# --- Etchings — the RMB/Q/R ability kit (design/etchings.md) ------------------

## Read the equipped loadout off the save at spawn. ensure_baseline grants Push once B2
## is set (Thomas's meditation scene). No-op outside a real save (the feel_room sandbox
## has no loaded slot) — the sandbox player simply has no abilities.
func _load_etchings() -> void:
	_etch_defs = EtchingsCore.defs()
	var state: Dictionary = SaveManager.state
	if not (state is Dictionary) or not state.has("combat"):
		return
	var etchings: Dictionary = (state["combat"] as Dictionary).get("etchings", {})
	var flags: Dictionary = (state.get("story", {}) as Dictionary).get("flags", {})
	etchings = EtchingsCore.ensure_baseline(etchings, _etch_defs, flags)
	state["combat"]["etchings"] = etchings
	_etch_state = etchings
	var slots: Dictionary = etchings.get("slots", {})
	for slot: String in _equipped:
		_equipped[slot] = str(slots.get(slot, ""))


## The etching id equipped in `slot` ("" if empty). Public for the smoke driver.
func equipped_id(slot: String) -> String:
	return str(_equipped.get(slot, ""))


func _tick_abilities(delta: float) -> void:
	for slot: String in _cast_cd:
		_cast_cd[slot] = maxf(0.0, float(_cast_cd[slot]) - delta)
	if _surge_t > 0.0:
		_surge_t -= delta
		if _surge_t <= 0.0:
			_end_surge()


## Cast the ability equipped in `slot` toward the cursor. Returns true if it fired.
## Shared by input and the headless smoke. No-op on an empty slot, an unimplemented
## (dormant) ability, or while on cooldown.
func try_cast(slot: String) -> bool:
	var id := str(_equipped.get(slot, ""))
	if id.is_empty() or float(_cast_cd.get(slot, 0.0)) > 0.0:
		return false
	if not EtchingsCore.is_implemented(id) or not _etch_defs.has(id):
		return false
	var def: Dictionary = _etch_defs[id]
	var b := EtchingsCore.effective_behavior(def, EtchingsCore.level_of(_etch_state, id))
	_cast_cd[slot] = float(def.get("cooldown_s", 5.0))
	match id:
		"push": _cast_push(b)
		"bolt": _cast_bolt(b)
		"snare": _cast_snare(b)
		"shockwave": _cast_shockwave(b)
		"surge": _cast_surge(b)
	Sfx.play("dash", global_position)  # placeholder cast whoosh (audio.md: add per-ability later)
	return true


func _cast_push(b: Dictionary) -> void:
	var facing := _flat(-global_transform.basis.z).normalized()
	var half := deg_to_rad(float(b.get("cone_deg", 100.0))) * 0.5
	var reach := float(b.get("range", 5.0))
	var dmg := int(round(float(attack_damage) * float(b.get("damage_scale", 0.6))))
	var knock := float(b.get("knockback", 16.0))
	var wall_bonus := int(round(float(attack_damage) * float(b.get("wall_bonus_scale", 1.5))))
	var wall_stag := float(b.get("wall_stagger", 0.5))
	CombatFX.shockwave_ring(get_parent(), global_position + facing * reach * 0.5, reach * 0.6, Color(0.7, 0.9, 1.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to_e := _flat((e as Node3D).global_position - global_position)
		var d := to_e.length()
		if d < 0.01 or d > reach or facing.angle_to(to_e) > half:
			continue
		e.take_damage(dmg)
		if is_instance_valid(e) and e.has_method("apply_knockback"):
			e.apply_knockback(to_e / d, knock, wall_bonus, wall_stag)


func _cast_bolt(b: Dictionary) -> void:
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.collision_mask = 6  # enemies + walls — the player's own bolt never bites back
	get_parent().add_child(arrow)
	var dir := _flat(-global_transform.basis.z).normalized()
	arrow.global_position = global_position + Vector3.UP * 0.9 + dir * 0.8
	var dmg := int(round(float(attack_damage) * float(b.get("damage_scale", 0.8))))
	arrow.setup(dir, dmg, float(b.get("projectile_speed", 26.0)), Color(0.6, 0.85, 1.0))


func _cast_snare(b: Dictionary) -> void:
	var field: SnareField = SNARE_FIELD.new()
	get_parent().add_child(field)
	field.global_position = global_position
	field.setup(float(b.get("radius", 3.0)), float(b.get("slow_factor", 0.3)),
		float(b.get("duration", 4.0)), float(b.get("stagger_on_cast", 0.25)))


func _cast_shockwave(b: Dictionary) -> void:
	var radius := float(b.get("radius", 6.0))
	var base_dmg := float(attack_damage) * float(b.get("damage_scale", 1.4))
	var edge := float(b.get("falloff", 0.4))
	var knock := float(b.get("knockback", 22.0))
	var stag := float(b.get("stagger_duration", 0.6))
	CombatFX.shockwave_ring(get_parent(), global_position, radius, Color(1.0, 0.9, 0.5))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to_e := _flat((e as Node3D).global_position - global_position)
		var d := to_e.length()
		if d > radius:
			continue
		var dmg := int(round(base_dmg * lerpf(1.0, edge, clampf(d / radius, 0.0, 1.0))))
		e.take_damage(maxi(1, dmg))
		# The panic button briefly staggers EVEN ARMORED enemies (the only thing that does).
		if is_instance_valid(e):
			if e.has_method("force_stagger"):
				e.force_stagger(stag)
			if e.has_method("apply_knockback") and d > 0.01:
				e.apply_knockback(to_e / d, knock)


func _cast_surge(b: Dictionary) -> void:
	# Refresh if already up; otherwise snapshot the CURRENT (possibly echo-modified) stats
	# so the end restores to what they were at cast, never the raw exports.
	if _surge_t <= 0.0:
		_surge_prev = {
			"move_speed": move_speed,
			"attack_windup": attack_windup, "attack_active": attack_active,
			"attack_recover": attack_recover, "attack_recover_finisher": attack_recover_finisher,
			"dash_cooldown": dash_cooldown,
		}
		move_speed *= float(b.get("move_mult", 1.35))
		var atm := float(b.get("attack_time_mult", 0.6))
		attack_windup *= atm
		attack_active *= atm
		attack_recover *= atm
		attack_recover_finisher *= atm
		dash_cooldown *= float(b.get("dash_cd_mult", 0.5))
	_surge_t = float(b.get("duration", 5.0))


func _end_surge() -> void:
	_surge_t = 0.0
	for stat: String in _surge_prev:
		set(stat, _surge_prev[stat])
	_surge_prev = {}


## Per-slot ability info for the run HUD (RunHud polls this): {rmb,q,r} each ->
## {id, name, cd_left, cd_total}, plus a "dash" entry {cd_left, cd_total}. Clean
## read-only view over _equipped/_cast_cd/_etch_defs so the HUD never pokes privates.
## Dash has no separate cooldown accessor otherwise; it is ready whenever cd_left <= 0.
func ability_slot_info() -> Dictionary:
	var out := {}
	for slot: String in ["rmb", "q", "r"]:
		var id := str(_equipped.get(slot, ""))
		var nm := ""
		var cd_total := 0.0
		if not id.is_empty() and _etch_defs.has(id):
			var def: Dictionary = _etch_defs[id]
			nm = str(def.get("name", id))
			cd_total = float(def.get("cooldown_s", 0.0))
		out[slot] = {
			"id": id, "name": nm,
			"cd_left": float(_cast_cd.get(slot, 0.0)), "cd_total": cd_total,
		}
	out["dash"] = {"cd_left": _dash_cd, "cd_total": dash_cooldown}
	return out


## Minimal run-HUD readout of the three ability slots (combat_room polls this).
func ability_hud_text() -> String:
	var glyph := {"rmb": "RMB", "q": "Q", "r": "R"}
	var parts := PackedStringArray(["Abilities:"])
	for slot: String in ["rmb", "q", "r"]:
		var id := str(_equipped.get(slot, ""))
		if id.is_empty():
			parts.append("%s: -" % glyph[slot])
		else:
			var cd := float(_cast_cd.get(slot, 0.0))
			var disp := str((_etch_defs.get(id, {}) as Dictionary).get("name", id))
			parts.append("%s: %s %s" % [glyph[slot], disp, "ready" if cd <= 0.0 else "%.1fs" % cd])
	return "\n".join(parts)


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
