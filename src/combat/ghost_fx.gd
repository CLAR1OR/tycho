extends MeshInstance3D
class_name GhostFX
## A translucent after-image of a mesh, left behind during a dash so the dash
## (and its i-frames) reads as a whoosh. Fades out and frees itself.
## Spawned via CombatFX.dash_ghost — built in code, no scene needed.

# FEEL: human-tuned, do not optimize — dash-feedback look.
const LIFETIME := 0.22     # FEEL: seconds before a ghost fully fades + frees
const START_ALPHA := 0.4   # FEEL: how solid a fresh ghost looks

var _t: float = 0.0
var _mat: StandardMaterial3D = null


## Call right after add_child (needs to be in-tree for global_transform).
func setup(ghost_mesh: Mesh, color: Color) -> void:
	mesh = ghost_mesh
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(color.r, color.g, color.b, START_ALPHA)
	material_override = _mat


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	if _mat != null:
		_mat.albedo_color.a = START_ALPHA * k
	if _t >= LIFETIME:
		queue_free()
