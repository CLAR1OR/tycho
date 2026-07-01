extends Node3D
class_name DeathFX
## One-shot death celebration spawned where an enemy dies: a shard burst
## (CPUParticles3D, tinted to the variant's colour) + a bright pop sphere that
## swells and fades. Cosmetic only; frees itself. Spawned via CombatFX.death_burst.

# FEEL: human-tuned, do not optimize — death feedback timing/look.
const LIFETIME := 0.7      # FEEL: seconds before the whole effect frees (≥ shard lifetime)
const POP_TIME := 0.22     # FEEL: how long the pop sphere lasts (s)
const POP_SCALE := 2.4     # FEEL: how big the pop swells (× start size)
const POP_ALPHA := 0.65    # FEEL: pop starting brightness

var _t: float = 0.0

@onready var _shards: CPUParticles3D = $Shards
@onready var _pop: MeshInstance3D = $Pop


## Tint shards + pop to the dead enemy's colour and fire. Call right after add_child.
func setup(color: Color) -> void:
	_shards.color = color
	_shards.emitting = true
	var mat := _pop.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = Color(color.lightened(0.5), POP_ALPHA)
	_pop.scale = Vector3.ONE * 0.4


func _process(delta: float) -> void:
	_t += delta
	if _t < POP_TIME:
		var p := ease(_t / POP_TIME, 0.35)  # fast swell, slow tail
		var s := lerpf(0.4, POP_SCALE, p)
		_pop.scale = Vector3(s, s, s)
		var mat := _pop.get_active_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color.a = POP_ALPHA * (1.0 - p)
	else:
		_pop.visible = false
	if _t >= LIFETIME:
		queue_free()
