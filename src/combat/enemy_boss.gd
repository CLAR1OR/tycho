extends EnemyDummy
class_name EnemyBoss
## A floor boss (design/bosses/floor-1-boss.md; boss #1 = the Den-Warden, built
## 2026-07-10). Data-driven: combat_room picks the floor's def from data/bosses/
## and calls setup(def) BEFORE add_child — the def owns hp/damage/phases/moves,
## the pure BossCore owns every sequencing decision, and this scene only EXECUTES
## moves by composing the proven telegraph vocabulary (grammar rule 1): the
## Charger's line telegraph (lunge), the dummy's strike grammar (swipe), the
## Slammer's growing ground circle (burrow/erupt), and the arena's real vent-plate
## hazards (vent_call). Same fixed telegraph colours as every enemy and hazard —
## the readability guard; boss tells run LONGER than trash tells, which lives in
## the DEF's telegraph numbers (placeholders the human dials, feel-tuning.md).
##
## WITHOUT a def (floors with no data/bosses/ file yet) this falls straight
## through to the EnemyDummy state machine — today's stats-pumped placeholder
## boss, behaviour unchanged.
##
## Invulnerability (the reconfiguration beat + burrow) always resolves on its own
## in bounded time, and take_damage during it is cleanly IGNORED (returns false,
## nothing queued) — the headless smoke depends on both. A one-shot kill from full
## HP skips every phase and dies normally (legal; nothing wedges).

enum BossState { BEAT, TELEGRAPH, EXECUTE, RECONFIGURE }

## The Slammer's slam-circle hot orange (== Hazard.COL_HOT) — the fixed "impact
## here" tell colour, reused for the burrow circles and the erupt ring.
const COLOR_BURROW := Color(1.0, 0.35, 0.15)

# Boss-frame dials — NEW placeholders, human-tuned. Per-move numbers (telegraphs,
# ranges, damage, chain counts) live in the boss def, not here.
@export var move_beat_s: float = 0.7        # FEEL: vulnerable breather between moves when a move has no recover_s (s)
@export var reconfigure_pulse: float = 1.35 # FEEL: mesh scale-pulse peak during the reconfiguration beat

## The arena's dormant vent plates (spawned by combat_room from the def's
## arena_vents). Only the vent_call move ever fires them.
var arena_vents: Array[Hazard] = []

var _def: Dictionary = {}
var _phase_index: int = 0
var _pending_phase: int = 0
var _loop_pos: int = 0
var _move: Dictionary = {}
var _move_id: String = ""
var _bstate: int = BossState.BEAT
var _btimer: float = 0.0
var _bstruck: bool = false
var _lunge_dir: Vector3 = Vector3.ZERO
var _submerged: bool = false
var _burrow_spot: Vector3 = Vector3.ZERO
var _circles_left: int = 0
var _vent_index: int = 0
var _active_tell: MeshInstance3D = null  # the live lunge line / burrow circle (withdrawn on reconfigure)

@onready var _shape: CollisionShape3D = $CollisionShape3D


## Configure from a boss def (data/bosses/<id>.json) — call BEFORE add_child (like
## the peril mults), so the parent _ready reads the def's hp into _hp.
func setup(def: Dictionary) -> void:
	_def = def
	max_hp = int(def.get("hp", max_hp))
	attack_damage = int(def.get("contact_damage", attack_damage))


func set_arena_vents(vents: Array[Hazard]) -> void:
	arena_vents = vents


func _ready() -> void:
	super()
	if not _def.is_empty():
		# A boss never sleeps: skip the dormant/idle layer entirely. _state mirrors
		# the parent enum so inherited take_damage/_flash colour logic stays honest.
		_state = State.ENGAGE
		_set_color(base_color)
		_bstate = BossState.BEAT
		_btimer = move_beat_s


func _physics_process(delta: float) -> void:
	if _def.is_empty():
		super(delta)  # placeholder floors: the plain stats-pumped brute, unchanged
		return
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 30.0 * delta)
	match _bstate:
		BossState.BEAT:
			_b_beat(delta)
		BossState.TELEGRAPH:
			_b_telegraph(delta)
		BossState.EXECUTE:
			_b_execute(delta)
		BossState.RECONFIGURE:
			_b_reconfigure(delta)
	# Same velocity composition as the base enemy: knockback + snare slow + drift.
	velocity += _knockback_vel
	velocity.x *= slow_factor
	velocity.z *= slow_factor
	velocity += external_drift
	external_drift = Vector3.ZERO
	_face_boss()
	move_and_slide()
	_check_slam_wall()


# --- Damage / phases ----------------------------------------------------------------

## Cleanly IGNORE hits while invulnerable (reconfiguration beat / burrowed): return
## false, nothing queued. Otherwise the normal EnemyDummy flow, then the phase
## check — crossing a threshold starts the reconfiguration beat (BossCore decides).
func take_damage(amount: int, from: Vector3 = Vector3.ZERO) -> bool:
	if _def.is_empty():
		return super(amount, from)
	if is_invulnerable():
		return false
	var killed := super(amount, from)
	if killed:
		return true
	var new_phase := BossCore.phase_for(_def, float(current_hp()) / float(maxi(1, max_hp)))
	if BossCore.should_reconfigure(_phase_index, new_phase):
		_begin_reconfigure(new_phase)
	return false


## True while hits are ignored: the reconfiguration beat or burrowed underground.
## Both resolve on their own in bounded time (reconfigure_s / circles x chain_s).
func is_invulnerable() -> bool:
	return _bstate == BossState.RECONFIGURE or _submerged


## 0-based phase index (0 = phase 1). Exposed for the smoke's reconfigure assert.
func phase_index() -> int:
	return _phase_index


## True when a data def drives this boss (false = the placeholder-brute fallback).
func has_def() -> bool:
	return not _def.is_empty()


# --- Boss states ----------------------------------------------------------------------

## The between-move breather: vulnerable, walking the fight back to the player.
func _b_beat(delta: float) -> void:
	var to_t := _flat(target.global_position - global_position)
	velocity = to_t.normalized() * move_speed if to_t.length() > stop_range else Vector3.ZERO
	_btimer -= delta
	if _btimer <= 0.0:
		_start_next_move()


func _b_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO  # rooted through the windup — the tell is painted, it commits
	_btimer -= delta
	if _btimer <= 0.0:
		_begin_execute()


func _b_execute(delta: float) -> void:
	match str(_move.get("kind", "")):
		"lunge":
			_exec_lunge(delta)
		"swipe":
			_exec_swipe(delta)
		"circle":
			_exec_circle(delta)
		"burrow":
			_exec_burrow(delta)
		"vent_call":
			_exec_vent_call(delta)
		_:
			_end_move()  # erupt resolves at begin; unknown kinds were rejected at load


func _b_reconfigure(delta: float) -> void:
	velocity = Vector3.ZERO
	_btimer -= delta
	if _btimer <= 0.0:
		_phase_index = _pending_phase
		_loop_pos = 0  # the new phase's loop starts at its top
		_to_beat(move_beat_s)


# --- Move sequencing --------------------------------------------------------------------

func _start_next_move() -> void:
	var step := BossCore.next_move(_def, _phase_index, _loop_pos)
	if step.is_empty():
		_to_beat(move_beat_s)  # defensive: broken data already push_errored at spawn
		return
	_loop_pos = int(step["next_position"])
	_move_id = str(step["id"])
	_move = step["move"]
	_bstruck = false
	match str(_move.get("kind", "")):
		"lunge":
			_begin_lunge()
		"swipe":
			_begin_swipe()
		"circle":
			_begin_circle()
		"burrow":
			_begin_burrow()
		"erupt":
			_begin_erupt()
		"vent_call":
			_begin_vent_call()
		_:
			_to_beat(move_beat_s)


func _end_move() -> void:
	if _submerged:
		_start_next_move()  # no visible beat underground — burrow chains straight into erupt
		return
	_to_beat(float(_move.get("recover_s", move_beat_s)))


## The recover/punish beat after a move (its recover_s, else move_beat_s).
func _to_beat(duration: float) -> void:
	_bstate = BossState.BEAT
	_state = State.ENGAGE
	_btimer = maxf(0.05, duration)
	_set_color(base_color)


func _begin_execute() -> void:
	_bstate = BossState.EXECUTE
	_state = State.STRIKE  # parent mirror: a hit-flash mid-strike restores to red
	_set_color(COLOR_STRIKE)
	match str(_move.get("kind", "")):
		"lunge":
			_btimer = float(_move.get("range", 14.0)) / maxf(1.0, float(_move.get("speed", 22.0)))
		"swipe":
			_btimer = float(_move.get("strike_s", 0.2))


# --- Moves ------------------------------------------------------------------------------

## Lunge: the Charger's grammar at boss length — lock a lane, paint the line, dash it.
func _begin_lunge() -> void:
	_lunge_dir = _flat(target.global_position - global_position).normalized()
	if _lunge_dir.length() < 0.001:
		_lunge_dir = Vector3.FORWARD
	_bstate = BossState.TELEGRAPH
	_state = State.TELEGRAPH
	_btimer = float(_move.get("telegraph_s", 0.8))
	velocity = Vector3.ZERO
	_set_color(COLOR_TELEGRAPH)
	_active_tell = CombatFX.line_telegraph(get_parent(), global_position, _lunge_dir,
		float(_move.get("range", 14.0)), _btimer, COLOR_TELEGRAPH)


func _exec_lunge(delta: float) -> void:
	velocity = _lunge_dir * float(_move.get("speed", 22.0))
	_btimer -= delta
	if not _bstruck and _dist_to_target() <= float(_move.get("contact_radius", 2.4)) \
			and target.has_method("take_damage"):
		_bstruck = true
		_hit_player()
	if _btimer <= 0.0 or _hit_static():
		_end_move()


## Swipe: the dummy's strike grammar, wider — a short forward surge; damage lands
## only inside the frontal arc, so stepping around it (or the dash) is the dodge.
func _begin_swipe() -> void:
	_bstate = BossState.TELEGRAPH
	_state = State.TELEGRAPH
	_btimer = float(_move.get("telegraph_s", 0.7))
	velocity = Vector3.ZERO
	_set_color(COLOR_TELEGRAPH)


func _exec_swipe(delta: float) -> void:
	var to_t := _flat(target.global_position - global_position)
	velocity = to_t.normalized() * move_speed * 1.5 if to_t.length() > 0.001 else Vector3.ZERO
	_btimer -= delta
	if not _bstruck and to_t.length() <= float(_move.get("radius", 4.5)) \
			and _in_front_arc(to_t) and target.has_method("take_damage"):
		_bstruck = true
		_hit_player()
	if _btimer <= 0.0:
		_end_move()


## Circle: the repositioning retreat — THE punish window. No attack, just orbiting.
func _begin_circle() -> void:
	_bstate = BossState.EXECUTE
	_state = State.ENGAGE
	_btimer = float(_move.get("duration_s", 2.0))
	_set_color(base_color)


func _exec_circle(delta: float) -> void:
	velocity = _orbit_velocity() * float(_move.get("speed_mult", 1.2))
	_btimer -= delta
	if _btimer <= 0.0:
		_end_move()


## Burrow: submerge (untargetable + invulnerable); chained Slammer-grammar ground
## circles track the player, each LOCKED at its start — the last one is where erupt
## surfaces. Watch the ground, dash on the beat: the whole floor's lesson.
func _begin_burrow() -> void:
	_submerged = true
	_bstate = BossState.EXECUTE
	_state = State.ENGAGE
	velocity = Vector3.ZERO
	_mesh.visible = false
	_shape.set_deferred("disabled", true)
	CombatFX.shockwave_ring(get_parent(), global_position, 2.0, base_color)  # the dive plume
	_circles_left = maxi(1, int(_move.get("circles", 3)))
	_next_burrow_circle()


func _next_burrow_circle() -> void:
	_burrow_spot = _flat(target.global_position)
	_btimer = float(_move.get("chain_s", 0.9))
	_active_tell = CombatFX.ground_telegraph(get_parent(), _burrow_spot, _btimer,
		float(_move.get("circle_radius", 3.4)), COLOR_BURROW)


func _exec_burrow(delta: float) -> void:
	velocity = Vector3.ZERO
	_btimer -= delta
	if _btimer > 0.0:
		return
	_circles_left -= 1
	if _circles_left > 0:
		_next_burrow_circle()
	else:
		_end_move()  # still submerged — chains straight into the next move (erupt)


## Erupt: surface under the final burrow circle with the AoE — that circle WAS the
## telegraph. Resolves instantly at begin, then the recover beat (vulnerable).
func _begin_erupt() -> void:
	var radius := float(_move.get("radius", 3.4))
	if _submerged:
		global_position = Vector3(_burrow_spot.x, global_position.y, _burrow_spot.z)
		_submerged = false
		_mesh.visible = true
		_shape.set_deferred("disabled", false)
	CombatFX.shockwave_ring(get_parent(), global_position, radius, COLOR_BURROW)
	if _flat(target.global_position - global_position).length() <= radius \
			and target.has_method("take_damage"):
		_hit_player()
	_to_beat(float(_move.get("recover_s", move_beat_s)))


## Vent call: command the arena — the dormant vent plates fire in sequence (grammar
## rule 4: the floor's signature hazard is the boss's phase-2 weapon). Each vent
## runs its own standard telegraph -> eruption; the boss stands exposed while calling.
func _begin_vent_call() -> void:
	if arena_vents.is_empty():
		_to_beat(move_beat_s)
		return
	_vent_index = 0
	_bstate = BossState.EXECUTE
	_state = State.ENGAGE
	velocity = Vector3.ZERO
	_set_color(COLOR_TELEGRAPH)  # the "commanding" read — it is NOT a wind-up; still punishable


func _exec_vent_call(delta: float) -> void:
	velocity = Vector3.ZERO
	_btimer -= delta
	if _btimer > 0.0:
		return
	if _vent_index < arena_vents.size():
		var vent := arena_vents[_vent_index]
		if is_instance_valid(vent):
			vent.fire_once()
		_vent_index += 1
		_btimer = float(_move.get("stagger_s", 0.45))
	else:
		_end_move()


# --- Reconfiguration beat ---------------------------------------------------------------

## The invulnerable phase-transition beat (grammar rule 3) — diegetically the
## examiner adjusting the test; reads as the beast molting. SHORT, resolves on its
## own, and any live tell is withdrawn (the cancelled move never comes).
func _begin_reconfigure(new_phase: int) -> void:
	_pending_phase = new_phase
	_bstate = BossState.RECONFIGURE
	_state = State.ENGAGE
	_btimer = float(_def.get("reconfigure_s", 1.0))
	velocity = Vector3.ZERO
	if is_instance_valid(_active_tell):
		_active_tell.queue_free()
	CombatFX.shockwave_ring(get_parent(), global_position, 3.0, base_color)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ONE * reconfigure_pulse, _btimer * 0.5)
	tw.tween_property(_mesh, "scale", Vector3.ONE, _btimer * 0.5)


# --- Helpers ------------------------------------------------------------------------------

func _hit_player() -> void:
	var dmg := int(_move.get("damage", attack_damage))
	target.take_damage(dmg, global_position)
	CombatFX.damage_number(get_parent(), target.global_position + Vector3.UP * 1.6,
		dmg, Color(1.0, 0.5, 0.5))


func _in_front_arc(to_target: Vector3) -> bool:
	var facing := _flat(-global_transform.basis.z)
	if facing.length() < 0.001 or to_target.length() < 0.001:
		return true
	var half := deg_to_rad(float(_move.get("arc_deg", 150.0)) * 0.5)
	return facing.normalized().angle_to(to_target.normalized()) <= half


## Face the locked lane mid-lunge (committed, no longer tracking); hidden while
## submerged; otherwise track the player like the base enemy.
func _face_boss() -> void:
	if _submerged:
		return
	if _bstate == BossState.EXECUTE and str(_move.get("kind", "")) == "lunge" \
			and _lunge_dir.length() > 0.001:
		look_at(global_position + _lunge_dir, Vector3.UP)
		return
	_face_target()


## True if this frame's slide collisions hit a static wall/cover (Charger pattern).
func _hit_static() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody3D:
			return true
	return false
