extends MeshInstance3D
class_name SlashFX
## A short bright streak left at the point of a landed hit; fades out and frees.
## Spawned by player.gd when a light attack connects. Orients to face the fixed
## camera so it reads from the 2.5D angle. Cosmetic only — no gameplay effect.

# FEEL: human-tuned, do not optimize — hit-feedback timing/look.
const LIFETIME := 0.9          # FEEL: seconds before it fully fades + frees
const START_ALPHA := 0.9       # FEEL: peak brightness
const START_EMISSION := 2.0    # FEEL: peak glow

var _t: float = 0.0
var _mat: StandardMaterial3D = null
var _oriented: bool = false
var _roll: float = 0.0
var _grow_scale: float = 1.0


func _ready() -> void:
	_mat = get_active_material(0) as StandardMaterial3D
	_roll = randf_range(-PI, PI)
	_grow_scale = randf_range(0.85, 1.2)
	if _mat != null:
		_mat.albedo_color.a = START_ALPHA
		_mat.emission_energy_multiplier = START_EMISSION


func _process(delta: float) -> void:
	# Orient on the first frame, once global_position is valid and the camera exists.
	if not _oriented:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			look_at(cam.global_position, Vector3.UP)
			rotate_object_local(Vector3.FORWARD, _roll)  # roll in the view plane for variety
		_oriented = true

	_t += delta
	var k := clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	if _mat != null:
		_mat.albedo_color.a = START_ALPHA * k
		_mat.emission_energy_multiplier = START_EMISSION * k
	# Grow slightly as it fades for a "pop".
	var g := _grow_scale * (1.0 + (1.0 - k) * 0.4)
	scale = Vector3(g, g, g)
	if _t >= LIFETIME:
		queue_free()
