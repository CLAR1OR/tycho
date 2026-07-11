@tool
extends MeshInstance3D
class_name WaterPlane
## A drop-anywhere stylized water body: a subdivided plane rendered through
## assets/materials/water_absorption.gdshader (CC0, Malido — depth-based absorption,
## edge foam, caustics, wind waves, walk-in ripples) over an optional SLOPED BED that
## gives the absorption its shallow→deep gradient. Requires Forward+ (depth texture)
## and the three project shader globals (project.godot [shader_globals]):
## wind_intensity, wind_direction, player_position.
##
## @tool + save hygiene: same contract as GrassPatch — visible while designing,
## generated mesh/material/bed cleared on EDITOR_PRE_SAVE and rebuilt POST_SAVE so
## nothing generated serializes into a .tscn. The bed child is never saved (no owner).
##
## `follow_target` feeds the GLOBAL player_position (RenderingServer) — one walker
## drives every WaterPlane at once; leave null for wind only. Water-look dials live as
## the shader's uniform DEFAULTS (the # style: dial contract); the node dials below
## are geometry (design/feel-tuning.md § Style unification).

const WATER_SHADER: Shader = preload("res://assets/materials/water_absorption.gdshader")
const NO_TARGET := Vector3(1.0e6, 0.0, 0.0)  ## parks the global ripple source far away

@export var follow_target: Node3D = null       ## drives the walk-in ripples (global)
@export var size := Vector2(34.0, 11.0):       # style: human-tuned, do not optimize
	set(v):
		size = v
		_request_rebuild()
@export var subdivisions := 48:                # style: human-tuned, do not optimize — wave vertex resolution
	set(v):
		subdivisions = maxi(v, 1)
		_request_rebuild()
@export var make_bed := true:                  ## sloped floor under the water (the depth gradient)
	set(v):
		make_bed = v
		_request_rebuild()
@export var bed_shallow_y := -0.5:             # style: human-tuned, do not optimize — bed depth at the near (-Z) edge
	set(v):
		bed_shallow_y = v
		_request_rebuild()
@export var bed_deep_y := -4.0:                # style: human-tuned, do not optimize — bed depth at the far (+Z) edge
	set(v):
		bed_deep_y = v
		_request_rebuild()
@export var bed_color := Color(0.42, 0.38, 0.30):  # style: human-tuned, do not optimize — silt/sand
	set(v):
		bed_color = v
		_request_rebuild()
## Wind fed into the shader globals at ready (shared by ALL water/wind shaders).
@export var wind_intensity := 0.35             # style: human-tuned, do not optimize
@export var wind_direction := Vector3(1.0, 0.0, 0.35)  # style: human-tuned, do not optimize — never zero

var _material: ShaderMaterial = null
var _bed: MeshInstance3D = null
var _rebuild_queued := false


func _ready() -> void:
	_build_all()
	RenderingServer.global_shader_parameter_set("wind_intensity", wind_intensity)
	RenderingServer.global_shader_parameter_set("wind_direction", wind_direction)
	if not Engine.is_editor_hint():
		RenderingServer.global_shader_parameter_set("player_position", NO_TARGET)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if follow_target != null:
		RenderingServer.global_shader_parameter_set(
			"player_position", follow_target.global_position)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			mesh = null
			material_override = null
			_clear_bed()
		NOTIFICATION_EDITOR_POST_SAVE:
			_build_all()


func _build_all() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = WATER_SHADER
		_material.set_shader_parameter("displacement_texture", _noise_texture(FastNoiseLite.TYPE_SIMPLEX))
		_material.set_shader_parameter("edge_noise", _noise_texture(FastNoiseLite.TYPE_CELLULAR))
		_material.set_shader_parameter("normal_map", _noise_texture(FastNoiseLite.TYPE_CELLULAR, true))
		_material.set_shader_parameter("edge_ramp", _edge_ramp_texture())
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	material_override = _material
	_clear_bed()
	if make_bed:
		_bed = _build_bed()
		add_child(_bed)  # no owner set -> never serialized into the scene


func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_rebuild_queued = false
	_build_all()


func _clear_bed() -> void:
	if _bed != null and is_instance_valid(_bed):
		_bed.queue_free()
	_bed = null


## The sloped floor the absorption reads against: shallow at the town-facing (-Z)
## edge, deep at the far (+Z) edge. Plain StandardMaterial3D — the town's toon sweep
## converts it at runtime like any other opaque mesh.
func _build_bed() -> MeshInstance3D:
	var drop := bed_deep_y - bed_shallow_y
	var slope_len := sqrt(size.y * size.y + drop * drop)
	var bed_plane := PlaneMesh.new()
	bed_plane.size = Vector2(size.x, slope_len)
	var bed := MeshInstance3D.new()
	bed.mesh = bed_plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bed_color
	bed.set_surface_override_material(0, mat)
	bed.rotation.x = atan2(-drop, size.y)
	bed.position = Vector3(0.0, (bed_shallow_y + bed_deep_y) * 0.5, 0.0)
	return bed


func _noise_texture(noise_type: FastNoiseLite.NoiseType, as_normal := false) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = noise_type
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.as_normal_map = as_normal
	return tex


## The author's edge ramp: a STEEP 1D gradient — white at 0.0, black by 0.08 — that
## turns the soft depth/noise masks into crisp foam lines.
func _edge_ramp_texture() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.08])
	grad.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex
