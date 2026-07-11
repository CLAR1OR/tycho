@tool
extends MeshInstance3D
class_name ShoreTerrain
## A generated shore strip: flat beach on the -Z (town) side, sloping underwater on
## the +Z (lake) side, with the drop-off line MEANDERING by 1D noise per-x — where
## that contour crosses the water surface, the water shader's depth-based edge foam
## draws a curvy shoreline for free (a shoreline is never drawn; it emerges from
## height vs water level). Pairs with WaterPlane (make_bed OFF — this IS the bed).
##
## @tool + save hygiene: the GrassPatch/WaterPlane contract — visible while designing,
## dials rebuild live, generated mesh/material cleared on EDITOR_PRE_SAVE + rebuilt
## POST_SAVE. Plain StandardMaterial3D; the town toon sweep converts it at runtime.
##
## Placement convention: put the node's origin ON the intended mean waterline (the
## beach extends land_depth toward -Z, the bed water_depth toward +Z). The beach sits
## a hair ABOVE the town floor at the shoreline (land_y) and dips just BELOW it at
## the landward edge, so it overlays the floor without z-fighting or a visible lip.

const LAND_EDGE_DROP := 0.04  ## landward edge sits land_y - this (under the floor)

@export var width := 80.0:                  # style: human-tuned, do not optimize — stretch left/right
	set(v):
		width = v
		_request_rebuild()
@export var land_depth := 4.0:              # style: human-tuned, do not optimize — beach strip (m)
	set(v):
		land_depth = maxf(v, 0.5)
		_request_rebuild()
@export var water_depth := 14.0:            # style: human-tuned, do not optimize — underwater run (m)
	set(v):
		water_depth = maxf(v, 1.0)
		_request_rebuild()
@export var curve_amplitude := 2.0:         # style: human-tuned, do not optimize — shoreline meander (± m)
	set(v):
		curve_amplitude = v
		_request_rebuild()
@export var curve_frequency := 0.08:        # style: human-tuned, do not optimize — meander feature size (higher = wigglier)
	set(v):
		curve_frequency = v
		_request_rebuild()
@export var curve_seed := 7:                ## deterministic shoreline shape
	set(v):
		curve_seed = v
		_request_rebuild()
@export var drop_slope := 0.35:             # style: human-tuned, do not optimize — how fast the bed deepens
	set(v):
		drop_slope = v
		_request_rebuild()
@export var land_y := 0.02:                 # style: human-tuned, do not optimize — beach height at the waterline
	set(v):
		land_y = v
		_request_rebuild()
@export var resolution := 0.75:             # style: human-tuned, do not optimize — grid step (m)
	set(v):
		resolution = maxf(v, 0.25)
		_request_rebuild()
@export var sand_color := Color(0.62, 0.55, 0.42):  # style: human-tuned, do not optimize
	set(v):
		sand_color = v
		_request_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	_build_all()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			mesh = null
			material_override = null
		NOTIFICATION_EDITOR_POST_SAVE:
			_build_all()


func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_rebuild_queued = false
	_build_all()


func _build_all() -> void:
	mesh = _build_terrain()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = sand_color
	material_override = mat


## Height at a local (x, z): z = 0 is the MEAN waterline; the actual drop-off starts
## at z = shoreline(x), a per-x noise offset — the whole curvy-shore trick lives here.
func _height(x: float, z: float, noise: FastNoiseLite) -> float:
	var shoreline := curve_amplitude * noise.get_noise_1d(x)
	var d := z - shoreline
	if d < 0.0:
		# Beach: land_y at the waterline, easing under the town floor at the far edge.
		return land_y + (d / land_depth) * LAND_EDGE_DROP
	return land_y - d * drop_slope


func _build_terrain() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = curve_seed
	noise.frequency = curve_frequency
	var cols := maxi(int(ceil(width / resolution)), 2)
	var rows := maxi(int(ceil((land_depth + water_depth) / resolution)), 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows + 1:
		for c in cols + 1:
			var x := -width * 0.5 + width * float(c) / float(cols)
			var z := -land_depth + (land_depth + water_depth) * float(r) / float(rows)
			st.set_uv(Vector2(float(c) / float(cols), float(r) / float(rows)))
			st.add_vertex(Vector3(x, _height(x, z, noise), z))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			st.add_index(i)
			st.add_index(i + cols + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols + 1)
			st.add_index(i + cols + 2)
	st.generate_normals()
	return st.commit()
