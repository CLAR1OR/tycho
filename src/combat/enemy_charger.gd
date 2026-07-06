extends EnemyDummy
class_name EnemyCharger
## Dash-charge variant of EnemyDummy (2026-07-06).
##
## Behaviour: orbits at a stand-off; when the player sits in its charge band with a
## clear line of sight and a token is free, it LOCKS a direction and paints a brief LINE
## telegraph, then dash-charges along that line at high speed. It damages the player on
## contact during the charge, overshoots, and is left briefly stunned + vulnerable at the
## end — a LONGER stun if it slams into a wall/obstacle. Squishy, and staggerable by
## player hits whenever it is NOT mid-charge.
##
## Commit token: the charge IS its commitment — base is_committed() is true during
## TELEGRAPH (aim) + STRIKE (charge), so it holds a token across the whole move and
## counts against max_attackers. During RECOVER it releases the token (vulnerable window).
##
## Mid-charge armor: take_damage() is overridden to suppress the stagger-interrupt while
## charging (a committed dash shouldn't be cancelled by a chip hit); it stays fully
## staggerable in every other state.
## Numbers marked `# FEEL:` are human-tuning placeholders — see player.gd header.

@export var charge_range: float = 10.0    # FEEL: distance at which it locks on to charge (m)
@export var charge_speed: float = 22.0    # FEEL: dash-charge speed (m/s)
@export var charge_time: float = 0.55     # FEEL: how long the charge runs (m ~ range/speed)
@export var contact_radius: float = 1.7   # FEEL: charge hitbox radius vs the player (m)
@export var wall_stun_bonus: float = 0.8  # FEEL: extra RECOVER stun after hitting a wall (s)

var _charge_dir: Vector3 = Vector3.ZERO


func _do_engage(delta: float) -> void:
	# Lose interest if the player gets far enough away.
	if _dist_to_target() > sight_range + SIGHT_LOSE_MARGIN:
		_to_idle()
		return
	_update_flip(delta)
	velocity = _orbit_velocity()
	# Lock on and charge when in the band, with a clear lane and a free token.
	var dist := _dist_to_target()
	if dist <= charge_range and dist >= stop_range and _has_line_of_sight() \
			and _committed_count() < max_attackers:
		_charge_dir = _flat(target.global_position - global_position).normalized()
		_state = State.TELEGRAPH
		_timer = telegraph_time
		velocity = Vector3.ZERO
		_set_color(COLOR_TELEGRAPH)
		CombatFX.line_telegraph(get_parent(), global_position, _charge_dir, charge_range,
			telegraph_time, Color(1.0, 0.85, 0.2))


func _do_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.STRIKE
		_timer = charge_time
		_struck = false
		_set_color(COLOR_STRIKE)


func _do_strike(delta: float) -> void:
	# Barrel down the locked lane at charge speed.
	velocity = _charge_dir * charge_speed
	_timer -= delta
	if not _struck and _flat(target.global_position - global_position).length() <= contact_radius \
			and target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)
		CombatFX.damage_number(get_parent(),
			target.global_position + Vector3.UP * 1.6, attack_damage, Color(1.0, 0.5, 0.5))
		_struck = true
	# Slammed a wall/cover → stop short with the longer stun.
	if _hit_wall():
		_end_charge(true)
		return
	if _timer <= 0.0:
		_end_charge(false)


## Face the LOCKED charge direction while charging so the body reads as committed (it is
## no longer tracking the player). Otherwise defer to the base facing.
func _face_target() -> void:
	if _state == State.STRIKE and _charge_dir.length() > 0.001:
		look_at(global_position + _charge_dir, Vector3.UP)
		return
	super()


func _end_charge(hit_wall: bool) -> void:
	_state = State.RECOVER  # base _do_recover counts _timer down, then rests
	_timer = recover_time + (wall_stun_bonus if hit_wall else 0.0)
	velocity = Vector3.ZERO
	_set_color(base_color)  # back to base colour = vulnerable + staggerable again


## Suppress the stagger-interrupt mid-charge only; fully staggerable in every other state.
func take_damage(amount: int, from: Vector3 = Vector3.ZERO) -> bool:
	if _state == State.STRIKE:
		var saved := stagger_time
		stagger_time = 0.0
		var killed := super(amount, from)
		stagger_time = saved
		return killed
	return super(amount, from)


## True if this frame's slide collisions hit a static wall/cover (not the player/enemies).
func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col is StaticBody3D:
			return true
	return false
