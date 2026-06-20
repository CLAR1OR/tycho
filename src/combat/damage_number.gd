extends Label3D
class_name DamageNumber
## A floating damage number that rises and fades at a hit location. Billboards to the
## camera (set in the scene). Cosmetic only. Spawned via CombatFX.damage_number().

# FEEL: human-tuned, do not optimize — hit-feedback readability.
const LIFETIME := 0.7      # FEEL: seconds before it fades + frees
const RISE_SPEED := 1.6    # FEEL: how fast it floats up (m/s)

var _t: float = 0.0


func setup(amount: int, color: Color) -> void:
	text = str(amount)
	modulate = color
	# Small scatter so stacked hits don't print exactly on top of each other.
	global_position += Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.15, 0.15))


func _process(delta: float) -> void:
	_t += delta
	position.y += RISE_SPEED * delta
	var k := clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	modulate.a = k
	if _t >= LIFETIME:
		queue_free()
