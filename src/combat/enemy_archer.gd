extends EnemyDummy
class_name EnemyArcher
## Ranged variant of EnemyDummy: keeps its distance and looses arrows instead of meleeing.
##
## Reuses all of EnemyDummy's machinery (perception, idle-wander, separation, health,
## death, knockback) and overrides ONLY the engage + strike behaviour:
##   ENGAGE → orbit at a stand-off, KITE outward if the player gets too close; when in
##   shoot range with a clear line of sight → TELEGRAPH (aim) → STRIKE (fire one arrow)
##   → RECOVER → REST. No melee close-in.
##
## Archers sit OUTSIDE the melee commit-token pool (is_committed() == false): a ranged
## attacker at distance doesn't hurt crowd readability the way a melee pile-in does, so
## they fire independently of how many melee enemies are committed.
## Numbers marked `# FEEL:` are human-tuning territory — see player.gd header.

const ARROW := preload("res://scenes/combat/arrow.tscn")

@export var shoot_range: float = 11.0   # FEEL: max distance it will loose an arrow (m)
@export var min_range: float = 6.0      # FEEL: backs away (kites) if the player is closer


func _do_engage(delta: float) -> void:
	# Lose interest if the player gets far enough away.
	if _dist_to_target() > sight_range + SIGHT_LOSE_MARGIN:
		_to_idle()
		return
	_update_flip(delta)
	var dist := _dist_to_target()
	if dist < min_range:
		velocity = _retreat_velocity()  # too close — kite outward
	else:
		velocity = _orbit_velocity()
	# Commit to a shot when in range with a clear line of sight.
	if dist <= shoot_range and dist >= min_range * 0.75 and _has_line_of_sight():
		_state = State.TELEGRAPH
		_timer = telegraph_time
		velocity = Vector3.ZERO
		_set_color(COLOR_TELEGRAPH)


## Plant and loose a single arrow at the player; no melee lunge.
func _do_strike(delta: float) -> void:
	velocity = Vector3.ZERO
	_timer -= delta
	if not _struck:
		_fire_arrow()
		_struck = true
	if _timer <= 0.0:
		_state = State.RECOVER
		_timer = recover_time
		_set_color(base_color)


## Ranged attackers don't hold a melee crowd-control token.
func is_committed() -> bool:
	return false


func _fire_arrow() -> void:
	var arrow := ARROW.instantiate()
	var spawn := global_position + Vector3.UP * 1.0
	get_parent().add_child(arrow)
	arrow.global_position = spawn
	var aim := target.global_position + Vector3.UP * 0.8 - spawn
	arrow.setup(aim, attack_damage)


## Move directly away from the player (with a little tangential drift) to keep distance.
func _retreat_velocity() -> Vector3:
	var away := _flat(global_position - target.global_position)
	if away.length() < 0.001:
		return Vector3.ZERO
	var radial := away.normalized()
	var tangent := Vector3.UP.cross(radial) * _circle_dir
	return (radial + tangent * 0.5).normalized() * move_speed
