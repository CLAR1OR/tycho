extends MultiMeshInstance3D
class_name GrassPatch
## A drop-anywhere stylized grass patch: builds a MultiMesh of blade quads scattered
## over a rectangle and renders them through assets/materials/grass_blade.gdshader
## (CC0, @_Malido — wind sway + walk-through displacement). Set `follow_target` to
## whatever should bend the grass (the player); leave it null for wind only.
##
## The blade is a vertical QuadMesh with its root at this node's origin (UV.y is 0 at
## the tip, 1 at the root — the shader's sway/colour convention). Scatter is SEEDED —
## the same patch looks the same every run. Every @export below is a style dial
## (placeholders; dial board: design/feel-tuning.md § Style unification).

const GRASS_SHADER: Shader = preload("res://assets/materials/grass_blade.gdshader")
## "No one nearby" — parked far away so the displacement never fires (the instance
## uniform defaults to the origin, which WOULD bend grass placed there).
const NO_TARGET := Vector3(1.0e6, 0.0, 0.0)

@export var follow_target: Node3D = null       ## bends the grass it walks through
@export var patch_size := Vector2(12.0, 12.0)  # style: human-tuned, do not optimize
@export var blade_count := 4000                # style: human-tuned, do not optimize
@export var blade_width := 0.08                # style: human-tuned, do not optimize
@export var blade_height := 0.55               # style: human-tuned, do not optimize
@export var height_jitter := 0.35              # style: human-tuned, do not optimize — ±fraction of blade_height
@export var scatter_seed := 1337               ## deterministic scatter

var _material: ShaderMaterial = null


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = GRASS_SHADER
	_material.set_shader_parameter("wind_noise", _wind_noise_texture())
	multimesh = _build_multimesh()
	material_override = _material
	# Blades displace in vertex() — grow the cull bounds so swaying tips at the patch
	# edge don't pop when the origin leaves the frustum.
	custom_aabb = AABB(
		Vector3(-patch_size.x * 0.5 - 1.0, 0.0, -patch_size.y * 0.5 - 1.0),
		Vector3(patch_size.x + 2.0, blade_height * 2.0 + 1.0, patch_size.y + 2.0))
	set_instance_shader_parameter("player_position", NO_TARGET)


func _physics_process(_delta: float) -> void:
	if follow_target != null:
		set_instance_shader_parameter("player_position", follow_target.global_position)


func _build_multimesh() -> MultiMesh:
	var blade := QuadMesh.new()
	blade.size = Vector2(blade_width, blade_height)
	blade.center_offset = Vector3(0.0, blade_height * 0.5, 0.0)  # root at y=0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = blade_count
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	for i in blade_count:
		var pos := Vector3(
			rng.randf_range(-patch_size.x * 0.5, patch_size.x * 0.5),
			0.0,
			rng.randf_range(-patch_size.y * 0.5, patch_size.y * 0.5))
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), pos)
		t = t.scaled_local(Vector3(1.0, 1.0 + rng.randf_range(-height_jitter, height_jitter), 1.0))
		mm.set_instance_transform(i, t)
	return mm


## The Perlin-FBM wind texture the shader author specifies (gain 0.5, lacunarity 1.5,
## octaves 3), built in code so the patch stays a single self-contained node.
func _wind_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 1.5
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	return tex
