@tool
extends StaticBody3D
class_name TownFountain
## The town-square fountain: a GENERATED stone basin — paving apron, one chunky step,
## a block rim you could sit on, a pool, and a slim column carrying a spill bowl.
## Derived from the town style anchor's plaza well
## (assets_src/anchors/town-style-anchor.png, design/style-bible.md) MINUS its four
## posts and slate canopy — this is the roofless fountain reading of that silhouette.
##
## Why generated and not a model: the asset-pipeline gate has not run yet
## (design/asset-pipeline.md), so nothing 3D ships as a file. Chunky faceted geometry
## on flat normals is exactly the anchor's "chunky silhouette" carrier (style bible
## carrier #5), and it flows through the town's toon sweep for free.
##
## Style layer: the stone/paving meshes carry plain StandardMaterial3Ds, so
## `StyleMaterials.apply_to_tree` in town.gd converts them to the toon shader on
## `TOWN_RAMP` at runtime like every other town mesh. The water is a ShaderMaterial
## (water_absorption.gdshader, shared with WaterPlane) and is therefore SKIPPED by the
## sweep by construction — the same rule that protects every FX material.
##
## @tool + save hygiene: the GrassPatch/WaterPlane/ShoreTerrain contract — visible
## while designing, dials rebuild live, and every generated child is added WITHOUT an
## owner + torn down on EDITOR_PRE_SAVE, so no geometry ever serializes into a .tscn.
##
## Collision: this node IS the blocker (world layer 4, mask 0 — set in _ready so the
## node works dropped anywhere) with a cylinder out to the step. The paving apron is
## deliberately OUTSIDE it: it is flat ground the player walks over.
##
## Every number below is a `# style:` dial (design/feel-tuning.md § Style unification)
## — placeholders on the human's dial board, judged in F5 against the anchor.

const WORLD_LAYER := 4  ## the town's static-world collision layer (Floor/walls)

# --- Footprint ------------------------------------------------------------------------
@export var segments := 20:                  # style: human-tuned, do not optimize — radial facets (low = chunkier)
	set(v):
		segments = maxi(v, 3)
		_request_rebuild()
@export var pedestal_segments := 8:          # style: human-tuned, do not optimize — the column reads octagonal
	set(v):
		pedestal_segments = maxi(v, 3)
		_request_rebuild()
@export var apron_radius := 3.4:             # style: human-tuned, do not optimize — paving circle (m)
	set(v):
		apron_radius = v
		_request_rebuild()
@export var apron_height := 0.05:            # style: human-tuned, do not optimize — proud of the ground, still walkable
	set(v):
		apron_height = v
		_request_rebuild()
## ONE chunky step, not a stack of near-equal tiers: at the game's -58° pitch, tiers
## whose radii are close read as a mushy swirl rather than as steps (verified in
## tools/render_prop.gd). Big radius jumps, few of them.
@export var step_radius := 2.45:             # style: human-tuned, do not optimize — the step (also the collision radius)
	set(v):
		step_radius = v
		_request_rebuild()
@export var step_top := 0.30:                # style: human-tuned, do not optimize
	set(v):
		step_top = v
		_request_rebuild()

# --- Basin ----------------------------------------------------------------------------
@export var rim_outer := 2.05:               # style: human-tuned, do not optimize — basin wall, outside face
	set(v):
		rim_outer = v
		_request_rebuild()
@export var rim_inner := 1.68:               # style: human-tuned, do not optimize — basin wall, inside face (rim thickness = the difference)
	set(v):
		rim_inner = v
		_request_rebuild()
@export var rim_top := 0.95:                 # style: human-tuned, do not optimize — sit-on height
	set(v):
		rim_top = v
		_request_rebuild()
@export var basin_floor_y := 0.36:           # style: human-tuned, do not optimize — the bed the water absorption reads against
	set(v):
		basin_floor_y = v
		_request_rebuild()
@export var water_y := 0.80:                 # style: human-tuned, do not optimize — surface height (below rim_top = the rim contains it)
	set(v):
		water_y = v
		_request_rebuild()

# --- Centrepiece ----------------------------------------------------------------------
## Tall and slim on purpose: from the fixed camera the column is the only thing that
## breaks the fountain's flat circular silhouette, so it carries the whole read.
@export var pedestal_radius := 0.34:         # style: human-tuned, do not optimize
	set(v):
		pedestal_radius = v
		_request_rebuild()
@export var pedestal_top := 1.45:            # style: human-tuned, do not optimize
	set(v):
		pedestal_top = v
		_request_rebuild()
@export var bowl_outer := 0.80:              # style: human-tuned, do not optimize — upper spill bowl
	set(v):
		bowl_outer = v
		_request_rebuild()
@export var bowl_inner := 0.58:              # style: human-tuned, do not optimize
	set(v):
		bowl_inner = v
		_request_rebuild()
@export var bowl_floor_y := 1.50:            # style: human-tuned, do not optimize
	set(v):
		bowl_floor_y = v
		_request_rebuild()
@export var bowl_top := 1.78:                # style: human-tuned, do not optimize
	set(v):
		bowl_top = v
		_request_rebuild()
@export var finial_base_radius := 0.22:      # style: human-tuned, do not optimize — the spout stub
	set(v):
		finial_base_radius = v
		_request_rebuild()
@export var finial_top_radius := 0.10:       # style: human-tuned, do not optimize
	set(v):
		finial_top_radius = v
		_request_rebuild()
@export var finial_top_y := 2.10:            # style: human-tuned, do not optimize — total height of the piece
	set(v):
		finial_top_y = v
		_request_rebuild()

# --- Colours + water look ---------------------------------------------------------------
@export var stone_color := Color(0.55, 0.54, 0.52):    # style: human-tuned, do not optimize — ≈ StyleCore.PALETTE_STONE
	set(v):
		stone_color = v
		_request_rebuild()
@export var paving_color := Color(0.30, 0.29, 0.27):   # style: human-tuned, do not optimize — dark cobble ring; must sit well below stone_color or the apron merges into the fountain
	set(v):
		paving_color = v
		_request_rebuild()
## Everything BELOW the waterline is its own dark material. Two jobs: shallow water is
## nearly clear, so the pool only reads dark if the basin under it is dark; and the
## split at water_y draws a crisp wet/dry line up the rim and the column.
@export var submerged_color := Color(0.09, 0.22, 0.26): # style: human-tuned, do not optimize — deep teal pool body (reads as WATER, not a hole)
	set(v):
		submerged_color = v
		_request_rebuild()
@export var show_apron := true:              ## the paving circle under the fountain (off = fountain alone)
	set(v):
		show_apron = v
		_request_rebuild()
## The lake's water dials are tuned for a 34 m body; a 3 m basin needs its own. These
## three override the shader's uniform DEFAULTS on this instance only.
@export var water_depth_distance := 0.55:    # style: human-tuned, do not optimize — how fast depth darkens (basin is ~0.4 m deep)
	set(v):
		water_depth_distance = v
		_request_rebuild()
@export var water_beers_law := 9.0:          # style: human-tuned, do not optimize — absorption falloff (higher = reads deeper)
	set(v):
		water_beers_law = v
		_request_rebuild()
@export var water_displacement := 0.02:      # style: human-tuned, do not optimize — wave height (m); lake default 0.08 is huge here
	set(v):
		water_displacement = v
		_request_rebuild()
## Metres per UV unit for the water surface — matched to the town lake's texel density
## so the same shader noise reads at the same physical scale in both bodies.
@export var water_uv_metres := 10.0:         # style: human-tuned, do not optimize
	set(v):
		water_uv_metres = maxf(v, 0.01)
		_request_rebuild()

var _parts: Array[Node] = []
var _rebuild_queued := false


func _ready() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0
	_build_all()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_clear_parts()
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


func _clear_parts() -> void:
	for part in _parts:
		if is_instance_valid(part):
			part.queue_free()
	_parts.clear()


## Every child is added with NO owner -> never serialized into the scene file.
func _add_part(part: Node) -> void:
	add_child(part)
	_parts.append(part)


func _build_all() -> void:
	_clear_parts()
	if show_apron:
		_add_part(_mesh_part("Paving", _build_apron(), paving_color))
	_add_part(_mesh_part("Stone", _build_stone(), stone_color))
	_add_part(_mesh_part("Submerged", _build_submerged(), submerged_color))
	_add_part(_water_part())
	_add_part(_collision_part())


## A plain-StandardMaterial3D mesh child — the town's toon sweep converts it at runtime.
func _mesh_part(part_name: String, mesh: ArrayMesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi


# --- Geometry ---------------------------------------------------------------------------

## The flat paving circle. Separate mesh so it can carry its own colour and be
## switched off — it is ground dressing, not part of the fountain body.
func _build_apron() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall(st, apron_radius, apron_radius, 0.0, apron_height, segments, true)
	_cap(st, step_radius, apron_radius, apron_height, segments, true)
	st.generate_normals()
	return st.commit()


## The DRY stone: step -> basin rim -> the column out of the water, bottom up. Only
## surfaces that can be SEEN are emitted — the step's top is an annulus stopping at the
## rim, and undersides are omitted where one tier sits on another. Everything below
## water_y belongs to _build_submerged instead.
func _build_stone() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# One chunky step up to the basin.
	_wall(st, step_radius, step_radius, apron_height, step_top, segments, true)
	_cap(st, rim_outer, step_radius, step_top, segments, true)

	# The basin: outside face, the dry part of the inside face, and the sit-on rim.
	_wall(st, rim_outer, rim_outer, step_top, rim_top, segments, true)
	_wall(st, rim_inner, rim_inner, water_y, rim_top, segments, false)
	_cap(st, rim_inner, rim_outer, rim_top, segments, true)

	# The centrepiece rising out of the water.
	_wall(st, pedestal_radius, pedestal_radius, water_y, pedestal_top,
		pedestal_segments, true)
	_cap(st, pedestal_radius, bowl_outer, pedestal_top, segments, false)
	_wall(st, bowl_outer, bowl_outer, pedestal_top, bowl_top, segments, true)
	_wall(st, bowl_inner, bowl_inner, bowl_floor_y, bowl_top, segments, false)
	_cap(st, bowl_inner, bowl_outer, bowl_top, segments, true)
	_cap(st, finial_base_radius, bowl_inner, bowl_floor_y, segments, true)
	_wall(st, finial_base_radius, finial_top_radius, bowl_floor_y, finial_top_y,
		pedestal_segments, true)
	_cap(st, 0.0, finial_top_radius, finial_top_y, pedestal_segments, true)

	st.generate_normals()
	return st.commit()


## Everything under the waterline — the basin bed plus the drowned bands of the rim and
## the column. Its own (dark) material is what actually makes the pool read as water at
## the game's camera distance; a 0.4 m depth of the shader alone stays nearly clear.
func _build_submerged() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap(st, pedestal_radius, rim_inner, basin_floor_y, segments, true)
	if water_y > basin_floor_y:
		_wall(st, rim_inner, rim_inner, basin_floor_y, water_y, segments, false)
		_wall(st, pedestal_radius, pedestal_radius, basin_floor_y, water_y,
			pedestal_segments, true)
	st.generate_normals()
	return st.commit()


## One band of wall between two rings. `outward` = the surface faces AWAY from the Y
## axis (an outside face); false makes an inside face, e.g. the basin's inner wall.
func _wall(st: SurfaceTool, r_bottom: float, r_top: float, y_bottom: float,
		y_top: float, seg: int, outward: bool) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var b0 := Vector3(cos(a0) * r_bottom, y_bottom, sin(a0) * r_bottom)
		var b1 := Vector3(cos(a1) * r_bottom, y_bottom, sin(a1) * r_bottom)
		var t0 := Vector3(cos(a0) * r_top, y_top, sin(a0) * r_top)
		var t1 := Vector3(cos(a1) * r_top, y_top, sin(a1) * r_top)
		if outward:
			_tri(st, b0, t1, t0)
			_tri(st, b0, b1, t1)
		else:
			_tri(st, b0, t0, t1)
			_tri(st, b0, t1, b1)


## A horizontal annulus at height `y` (r_inner = 0 gives a full disc), facing up or down.
func _cap(st: SurfaceTool, r_inner: float, r_outer: float, y: float, seg: int,
		up: bool) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var o0 := Vector3(cos(a0) * r_outer, y, sin(a0) * r_outer)
		var o1 := Vector3(cos(a1) * r_outer, y, sin(a1) * r_outer)
		var i0 := Vector3(cos(a0) * r_inner, y, sin(a0) * r_inner)
		var i1 := Vector3(cos(a1) * r_inner, y, sin(a1) * r_inner)
		if up:
			_tri(st, i0, o0, o1)
			if r_inner > 0.0:
				_tri(st, i0, o1, i1)
		else:
			_tri(st, i0, o1, o0)
			if r_inner > 0.0:
				_tri(st, i0, i1, o1)


## One triangle with planar (top-down) UVs. Smooth group -1 makes generate_normals()
## emit FLAT per-face normals — that is the faceted chunky read we want (style-bible
## carrier #5), and it keeps the hard wall/cap corners hard instead of smearing the
## toon bands around them. Winding: verified against the rasterizer's own convention
## by tools/fountain_probe.gd, not assumed.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_smooth_group(-1)
	for v: Vector3 in [a, b, c]:
		st.set_uv(Vector2(v.x, v.z) / maxf(apron_radius * 2.0, 0.01) + Vector2(0.5, 0.5))
		st.add_vertex(v)


# --- Water --------------------------------------------------------------------------------

## The basin surface: a disc on the SHARED water shader (WaterPlane.build_material),
## so the fountain and the lake are the same water. The rim doubles as the shader's
## depth edge, so its foam line is drawn where the water meets the stone — the same
## "never draw a shoreline" trick ShoreTerrain uses.
func _water_part() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = _build_water_disc()
	var mat := WaterPlane.build_material()
	mat.set_shader_parameter("depth_distance", water_depth_distance)
	mat.set_shader_parameter("beers_law", water_beers_law)
	mat.set_shader_parameter("displacement_strength", water_displacement)
	mi.material_override = mat
	return mi


func _build_water_disc() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := rim_inner
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		_water_vertex(st, Vector3(0.0, water_y, 0.0))
		_water_vertex(st, Vector3(cos(a1) * r, water_y, sin(a1) * r))
		_water_vertex(st, Vector3(cos(a0) * r, water_y, sin(a0) * r))
	return st.commit()


## World-scaled UVs (metres / water_uv_metres) so the shader's scrolling noise reads at
## the same physical size here as on the town lake, despite the far smaller surface.
func _water_vertex(st: SurfaceTool, v: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(v.x, v.z) / water_uv_metres)
	st.add_vertex(v)


# --- Collision ------------------------------------------------------------------------------

## Blocks out to the step, so the player never stands inside raised geometry.
## The apron stays outside it on purpose (flat paving, walk right over it).
func _collision_part() -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = step_radius
	shape.height = maxf(finial_top_y, 0.1)
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.position = Vector3(0.0, shape.height * 0.5, 0.0)
	return cs
