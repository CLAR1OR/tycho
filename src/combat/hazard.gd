extends Node3D
class_name Hazard
## A dungeon-strata hazard (design/dungeon-strata.md) — scripted geometry + a timer +
## a damage volume + a telegraph. Never simulated, always telegraphed, always
## learnable. DUAL-USE by default: it damages enemies too (`hurts_enemies`), so baiting
## a Brute into the beam is the intended play. One class dispatches all six kinds off
## the def's `kind` (a code-built node like the doors/wellspring in combat_room.gd; the
## kinds share the telegraph + damage plumbing, so splitting into subclasses is a later
## polish, not needed for the slice). Group "hazards"; spawned at room setup, persists
## across waves, dies with the room.
##
## Peril door mults do NOT apply to hazards. Every damage/cycle/telegraph number lives
## in data/hazards/*.json — a HUMAN placeholder (feel-tuning.md), read here, never a
## `# FEEL:` const of this file. Telegraph colours are FIXED across strata (the
## readability guard) — they reuse the enemy telegraph yellow / strike red conventions.

# Telegraph colours (fixed across all strata — the readability guard). Reused from the
# enemy tell language so a hazard warning reads the same everywhere.
const COL_WARN := Color(1.0, 0.85, 0.2)      # charge-up / danger zone (enemy telegraph yellow)
const COL_HOT := Color(1.0, 0.35, 0.15)      # live / hot (enemy strike red-orange)
const COL_DRIFT := Color(0.5, 0.75, 1.0)     # drift current (cool, no damage)
const COL_MIST := Color(0.6, 0.55, 0.75)     # denial mist (violet no-stand)

const OBSTACLE_MASK := 4      # cover/wall layer — blocks the watcher's line of sight
const BEAM_HALF_WIDTH := 0.6  # placeholder: how wide the sweep beam's kill line is (m)
const ROOM_BOUND := 24.0      # mist bounces off the room bounds (m from centre)
const ARROW_SCENE := preload("res://scenes/combat/arrow.tscn")

# --- Config (from the hazard def; all placeholders) ---
var kind: String = ""
var telegraph_s: float = 0.6
var cycle_s: float = 0.0
var damage: int = 15
var radius: float = 2.5
var hurts_enemies: bool = true
var _length: float = 14.0          # beam
var _rotate_deg_s: float = 45.0    # beam
var _range: float = 22.0           # watcher LoS/fire range
var _projectile_speed: float = 20.0
var _push_strength: float = 6.0    # drift
var _drift_speed: float = 1.5      # mist wander speed
var _tick_s: float = 1.0           # mist damage cadence

## The player this hazard aims at / tests line of sight to (watcher). Set by the room
## after configure(). Vent/burst/beam/drift/mist damage everyone in radius regardless.
var target: Node3D = null

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _phase: int = 0                # small per-kind state machine
var _armed: bool = false
var _drift_dir := Vector3.ZERO     # drift push / mist wander direction
var _beam: MeshInstance3D = null
var _beam_cooldowns: Dictionary = {}  # per-target re-hit cooldown for the sweep beam


## Read the def and build the placeholder body. `rng_seed` desyncs periodic instances
## (a per-hazard phase offset) and fixes the drift/mist direction — deterministic.
func configure(def: Dictionary, rng_seed: int) -> void:
	kind = str(def.get("kind", ""))
	telegraph_s = float(def.get("telegraph_s", 0.6))
	cycle_s = float(def.get("cycle_s", 0.0))
	damage = int(def.get("damage", 15))
	radius = float(def.get("radius", 2.5))
	hurts_enemies = bool(def.get("hurts_enemies", true))
	_length = float(def.get("length", 14.0))
	_rotate_deg_s = float(def.get("rotate_deg_s", 45.0))
	_range = float(def.get("range", 22.0))
	_projectile_speed = float(def.get("projectile_speed", 20.0))
	_push_strength = float(def.get("push_strength", 6.0))
	_drift_speed = float(def.get("drift_speed", 1.5))
	_tick_s = float(def.get("tick_s", 1.0))
	_rng.seed = hash([rng_seed, "hazard", kind])
	add_to_group("hazards")
	var ang := _rng.randf() * TAU
	_drift_dir = Vector3(cos(ang), 0.0, sin(ang))
	# Periodic kinds start at a random point in their cycle so instances don't fire in
	# lockstep; triggered kinds (burst) idle until proximity, timed kinds arm after a beat.
	if kind == "vent":
		_timer = _rng.randf() * maxf(0.1, cycle_s)
	elif kind == "node":
		_timer = _rng.randf() * maxf(0.1, cycle_s)
	elif kind == "mist":
		_timer = _tick_s
	elif kind == "beam":
		_timer = telegraph_s  # a brief pre-hot telegraph before it goes live
	_build_body()


func _physics_process(delta: float) -> void:
	match kind:
		"vent": _tick_vent(delta)
		"node": _tick_node(delta)
		"burst": _tick_burst(delta)
		"beam": _tick_beam(delta)
		"drift": _tick_drift(delta)
		"mist": _tick_mist(delta)


# --- Vent plate: idle -> telegraph -> erupt, on a cycle ---------------------------

func _tick_vent(delta: float) -> void:
	_timer -= delta
	if _phase == 0 and _timer <= 0.0:            # idle -> telegraph
		_phase = 1
		_timer = telegraph_s
		CombatFX.ground_telegraph(get_parent(), global_position, telegraph_s, radius, COL_WARN)
	elif _phase == 1 and _timer <= 0.0:          # telegraph -> erupt -> idle
		_phase = 0
		_timer = maxf(0.1, cycle_s)
		_erupt()


func _erupt() -> void:
	CombatFX.shockwave_ring(get_parent(), global_position, radius, COL_HOT)
	damage_area(global_position, radius)


# --- Watcher node: on a cycle, if LoS is clear, flare then fire a projectile -------

func _tick_node(delta: float) -> void:
	if _phase == 1:                              # brief flare telegraph, then fire
		_timer -= delta
		if _timer <= 0.0:
			_phase = 0
			_timer = maxf(0.1, cycle_s)
			_fire_projectile()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = maxf(0.1, cycle_s)
		if _has_line_of_sight():
			_phase = 1
			_timer = telegraph_s
			CombatFX.shockwave_ring(get_parent(), global_position + Vector3.UP * 1.2, 0.8, COL_WARN)


func _fire_projectile() -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir := _flat(target.global_position - global_position)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.collision_mask = 7  # player + enemies + walls — the murder-hole hits everyone
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector3.UP * 1.2 + dir * 0.8
	arrow.setup(dir, damage, _projectile_speed, COL_HOT)
	Sfx.play("arrow-loose", global_position)


func _has_line_of_sight() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if _flat(target.global_position - global_position).length() > _range:
		return false
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.2
	var to := target.global_position + Vector3.UP * 0.7
	var query := PhysicsRayQueryParameters3D.create(from, to, OBSTACLE_MASK)
	return space.intersect_ray(query).is_empty()


# --- Burst crystal: proximity-triggered one-shot detonation -----------------------

func _tick_burst(delta: float) -> void:
	if _phase == 2:                              # already spent (freeing)
		return
	if _phase == 1:                              # telegraph -> detonate once -> free
		_timer -= delta
		if _timer <= 0.0:
			_phase = 2
			CombatFX.shockwave_ring(get_parent(), global_position, radius, COL_HOT)
			damage_area(global_position, radius)
			queue_free()
		return
	# Proximity trigger: player OR an enemy within ~0.6 x radius arms it. (Damage-
	# triggered detonation is DEFERRED — player attack scans only touch the enemies
	# group; see dungeon-strata.md.)
	if _anyone_within(radius * 0.6):
		_phase = 1
		_timer = telegraph_s
		CombatFX.ground_telegraph(get_parent(), global_position, telegraph_s, radius, COL_WARN)


# --- Sweep beam: a rotating hot line, per-target re-hit cooldown -------------------

func _tick_beam(delta: float) -> void:
	rotation.y += deg_to_rad(_rotate_deg_s) * delta
	if not _armed:
		_timer -= delta
		if _timer <= 0.0:
			_armed = true
			if _beam != null:
				_set_emission(_beam, COL_HOT)
		return
	for id: Variant in _beam_cooldowns.keys():
		_beam_cooldowns[id] = maxf(0.0, float(_beam_cooldowns[id]) - delta)
	var dir := _flat(-global_transform.basis.z).normalized()
	for body in _candidate_bodies():
		var to_b := _flat((body as Node3D).global_position - global_position)
		var along := to_b.dot(dir)
		if along < 0.0 or along > _length:
			continue
		if (to_b - dir * along).length() > BEAM_HALF_WIDTH:
			continue
		var key := (body as Object).get_instance_id()
		if float(_beam_cooldowns.get(key, 0.0)) > 0.0:
			continue
		_beam_cooldowns[key] = 0.5  # placeholder per-target re-hit gap (s)
		_hit_body(body)


# --- Drift field: push bodies inside along a fixed direction (no damage) -----------

func _tick_drift(_delta: float) -> void:
	for body in _candidate_bodies():
		if _flat((body as Node3D).global_position - global_position).length() > radius:
			continue
		if "external_drift" in body:
			body.external_drift += _drift_dir * _push_strength


# --- Denial mist: wanders, ticks damage to anyone inside --------------------------

func _tick_mist(delta: float) -> void:
	global_position += _drift_dir * _drift_speed * delta
	# Bounce off the room bounds.
	if absf(global_position.x) > ROOM_BOUND:
		_drift_dir.x = -_drift_dir.x
		global_position.x = clampf(global_position.x, -ROOM_BOUND, ROOM_BOUND)
	if absf(global_position.z) > ROOM_BOUND:
		_drift_dir.z = -_drift_dir.z
		global_position.z = clampf(global_position.z, -ROOM_BOUND, ROOM_BOUND)
	_timer -= delta
	if _timer <= 0.0:
		_timer = maxf(0.1, _tick_s)
		damage_area(global_position, radius)


# --- Shared damage ----------------------------------------------------------------

## Apply `damage` to the player (always) and — when hurts_enemies — to every enemy in
## the radius. Public so the headless smoke can drive a dual-use hit by direct call.
func damage_area(center: Vector3, r: float) -> void:
	for body in _candidate_bodies():
		if _flat((body as Node3D).global_position - center).length() <= r:
			_hit_body(body)


func _hit_body(body: Node) -> void:
	if not body.has_method("take_damage"):
		return
	if body is EnemyDummy and not hurts_enemies:
		return
	body.take_damage(damage, global_position)


## Player (via target) + everything in the enemies group — the hazard's damage/push set.
func _candidate_bodies() -> Array:
	var out: Array = []
	if target != null and is_instance_valid(target):
		out.append(target)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			out.append(e)
	return out


func _anyone_within(r: float) -> bool:
	for body in _candidate_bodies():
		if _flat((body as Node3D).global_position - global_position).length() <= r:
			return true
	return false


# --- Placeholder bodies -----------------------------------------------------------

func _build_body() -> void:
	match kind:
		"vent":
			var m := _flat_disc(radius, COL_WARN, 0.18)
			add_child(m)
		"node":
			var box := BoxMesh.new()
			box.size = Vector3(0.9, 2.4, 0.9)
			var mi := MeshInstance3D.new()
			mi.mesh = box
			mi.position = Vector3(0, 1.2, 0)
			mi.set_surface_override_material(0, _emissive_mat(COL_HOT, 0.35))
			add_child(mi)
		"burst":
			var pm := PrismMesh.new()
			pm.size = Vector3(1.2, 1.8, 1.2)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.position = Vector3(0, 0.9, 0)
			mi.set_surface_override_material(0, _emissive_mat(Color(0.9, 0.5, 0.3), 0.5))
			add_child(mi)
		"beam":
			var bx := BoxMesh.new()
			bx.size = Vector3(BEAM_HALF_WIDTH * 2.0, 0.2, _length)
			_beam = MeshInstance3D.new()
			_beam.mesh = bx
			_beam.position = Vector3(0, 0.4, -_length * 0.5)  # runs down local -Z
			_beam.set_surface_override_material(0, _emissive_mat(COL_WARN, 0.6))
			add_child(_beam)
		"drift":
			var cm := CylinderMesh.new()
			cm.top_radius = radius
			cm.bottom_radius = radius
			cm.height = 2.4
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.position = Vector3(0, 1.2, 0)
			mi.set_surface_override_material(0, _translucent_mat(COL_DRIFT, 0.12))
			add_child(mi)
		"mist":
			var sm := SphereMesh.new()
			sm.radius = radius
			sm.height = radius * 2.0
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.position = Vector3(0, 1.2, 0)
			mi.set_surface_override_material(0, _translucent_mat(COL_MIST, 0.16))
			add_child(mi)


func _flat_disc(r: float, col: Color, alpha: float) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position = Vector3(0, 0.06, 0)
	mi.set_surface_override_material(0, _translucent_mat(col, alpha))
	return mi


func _emissive_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _translucent_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = col
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	return mat


func _set_emission(mi: MeshInstance3D, col: Color) -> void:
	var mat := mi.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission = col
		mat.albedo_color = Color(col.r, col.g, col.b, mat.albedo_color.a)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
