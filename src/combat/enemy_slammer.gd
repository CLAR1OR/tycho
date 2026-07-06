extends EnemyDummy
class_name EnemySlammer
## Heavy AoE variant of EnemyDummy (the requested "windup then ground slam", 2026-07-06).
##
## Behaviour: lumbers straight at the player (no orbit); when it gets within slam_range
## and a commit token is free, it LOCKS an impact point at the player's current spot and
## paints a growing ground-circle telegraph over a long windup — then slams. Anyone
## still inside slam_radius when it lands takes meaningful damage; the impact is locked
## at telegraph start, so DASHING OUT of the circle (dash i-frames also cover it) dodges
## it cleanly. A recovery pause follows the slam.
##
## Armored: stagger_time is 0 (like the Brute), so player hits do NOT interrupt the
## windup — you dodge the slam, you don't cancel it.
##
## Commit token: the Slammer DOES participate in the melee commit-token cap (base
## is_committed() is true during TELEGRAPH + STRIKE) — it is a melee committer, so it
## must count against max_attackers to keep crowds readable.
## Numbers marked `# FEEL:` are human-tuning placeholders — see player.gd header.

@export var slam_range: float = 3.5    # FEEL: distance at which it commits to a slam (m)
@export var slam_radius: float = 3.2   # FEEL: AoE radius of the slam (m)

var _impact: Vector3 = Vector3.ZERO    # flat impact centre, locked at telegraph start


func _do_engage(delta: float) -> void:
	# Lose interest if the player gets far enough away.
	if _dist_to_target() > sight_range + SIGHT_LOSE_MARGIN:
		_to_idle()
		return
	# Lumber straight at the player — no strafing (it is slow and heavy).
	var to_target := _flat(target.global_position - global_position)
	velocity = to_target.normalized() * move_speed
	# Commit to a slam when close and a token is free.
	if _dist_to_target() <= slam_range and _committed_count() < max_attackers:
		_begin_slam()


func _begin_slam() -> void:
	_impact = _flat(target.global_position)  # LOCKED here — moving out of the circle dodges it
	_state = State.TELEGRAPH
	_timer = telegraph_time
	velocity = Vector3.ZERO
	_set_color(COLOR_TELEGRAPH)
	CombatFX.ground_telegraph(get_parent(), _impact, telegraph_time, slam_radius,
		Color(1.0, 0.35, 0.15))


func _do_telegraph(delta: float) -> void:
	velocity = Vector3.ZERO  # rooted through the windup (committed, telegraphed)
	_timer -= delta
	if _timer <= 0.0:
		_state = State.STRIKE
		_timer = strike_time
		_struck = false
		_set_color(COLOR_STRIKE)


func _do_strike(delta: float) -> void:
	velocity = Vector3.ZERO  # it slams in place — no lunge
	_timer -= delta
	if not _struck:
		_struck = true
		# AoE: the player takes it only if still inside the locked circle (dash i-frames
		# also make take_damage a no-op — so a dash out is doubly safe).
		if _flat(target.global_position - _impact).length() <= slam_radius \
				and target.has_method("take_damage"):
			target.take_damage(attack_damage, _impact)
			CombatFX.damage_number(get_parent(),
				target.global_position + Vector3.UP * 1.6, attack_damage, Color(1.0, 0.5, 0.5))
	if _timer <= 0.0:
		_state = State.RECOVER
		_timer = recover_time
		_set_color(base_color)
