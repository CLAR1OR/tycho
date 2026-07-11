extends RefCounted
class_name StyleMaterials
## Material factory for the STYLE-UNIFICATION LAYER (design/asset-pipeline.md §C).
## Everything that touches engine resources (Shader/ShaderMaterial/GradientTexture1D)
## lives HERE; the pure palette/ramp maths lives in StyleCore. All style numbers are
## StyleCore `# style:` dials — this file only assembles.
##
## What gets converted: opaque, SHADED StandardMaterial3Ds. SKIP rules (critical):
##  - transparency != DISABLED or shading_mode == UNSHADED → untouched. That protects
##    every FX/telegraph/portal/ghost material automatically (they are all
##    unshaded+translucent — verified survey 2026-07-11).
##  - a node with metadata `style_skip` → untouched (per-mesh opt-out).
##  - anything already a ShaderMaterial (e.g. converted once) → untouched.
## Emission carries over (glowing props/forge keep their glow). Materials are built
## FRESH per call — set_tint mutates them, so sharing would repaint siblings; only the
## immutable ramp textures and the one outline pass are cached.

const TOON_SHADER: Shader = preload("res://assets/materials/tycho_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/materials/tycho_outline.gdshader")
const META_SKIP := "style_skip"    # set this metadata on a MeshInstance3D to opt out
const RAMP_TEX_WIDTH := 64         # gradient bake resolution (bands sample discretely)

static var _ramps: Dictionary = {}          # html-key -> GradientTexture1D (immutable, shared)
static var _outline: ShaderMaterial = null  # ONE shared outline pass (uniform everywhere)


## A toon ShaderMaterial: `albedo` tint over the `ramp_stops` gradient; optional
## emission; `outlined` chains the shared inverted-hull pass via next_pass (characters
## only — never environment geometry or props).
static func toon_material(albedo: Color, ramp_stops: Array[Color], outlined: bool,
		emission := Color.BLACK, emission_energy := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", albedo)
	mat.set_shader_parameter("band_count", StyleCore.BAND_COUNT)
	mat.set_shader_parameter("ramp", _ramp_texture(ramp_stops))
	mat.set_shader_parameter("emission_color", emission)
	mat.set_shader_parameter("emission_energy", emission_energy)
	if outlined:
		mat.next_pass = outline_material()
	return mat


## The one shared outline pass (uniforms are project-wide StyleCore dials).
static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter("outline_width", StyleCore.OUTLINE_WIDTH)
		_outline.set_shader_parameter("outline_color", StyleCore.OUTLINE_COLOR)
	return _outline


## Chain the outline pass onto an ALREADY-CONVERTED mesh (e.g. after an apply_to_tree
## sweep, promote NPC capsules to "character" rendering). No-op on anything else.
static func add_outline(mesh: MeshInstance3D) -> void:
	var mat := mesh.get_active_material(0)
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == TOON_SHADER \
			and (mat as ShaderMaterial).next_pass == null:
		(mat as ShaderMaterial).next_pass = outline_material()


## Walk every MeshInstance3D under `root` (inclusive) and replace each ELIGIBLE
## StandardMaterial3D with the equivalent toon material on `ramp_stops` (albedo +
## emission carried over; skip rules above). Handles material_override, surface
## override materials, and mesh-surface materials (via get_active_material; converted
## surfaces are set as surface overrides — the safe per-instance path).
static func apply_to_tree(root: Node, ramp_stops: Array[Color], outlined := false) -> void:
	if root is MeshInstance3D:
		_convert_mesh(root as MeshInstance3D, ramp_stops, outlined)
	for child in root.get_children():
		apply_to_tree(child, ramp_stops, outlined)


## Tint whatever material a mesh currently carries — the ONE abstraction every
## flash/tint call site uses, so call sites never care whether the mesh has been
## converted to toon yet (ShaderMaterial "albedo" param) or not (albedo_color).
static func set_tint(mesh: MeshInstance3D, color: Color) -> void:
	var mat := mesh.get_active_material(0)
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("albedo", color)
	elif mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = color


# --- Internals --------------------------------------------------------------------------

static func _convert_mesh(mesh: MeshInstance3D, ramp_stops: Array[Color], outlined: bool) -> void:
	if mesh.has_meta(META_SKIP):
		return
	# material_override wins over all surfaces — convert it in place if eligible.
	if mesh.material_override is StandardMaterial3D:
		var conv := _convert_standard(mesh.material_override as StandardMaterial3D,
			ramp_stops, outlined)
		if conv != null:
			mesh.material_override = conv
		return
	for i in mesh.get_surface_override_material_count():
		var mat := mesh.get_active_material(i)
		if mat is StandardMaterial3D:
			var conv := _convert_standard(mat as StandardMaterial3D, ramp_stops, outlined)
			if conv != null:
				mesh.set_surface_override_material(i, conv)


## The toon equivalent of a StandardMaterial3D, or null when the SKIP rules say
## "leave it alone" (translucent/unshaded = FX/telegraph territory).
static func _convert_standard(mat: StandardMaterial3D, ramp_stops: Array[Color],
		outlined: bool) -> ShaderMaterial:
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	var emission := Color.BLACK
	var energy := 0.0
	if mat.emission_enabled:
		emission = mat.emission
		energy = mat.emission_energy_multiplier
	var conv := toon_material(mat.albedo_color, ramp_stops, outlined, emission, energy)
	if mat.albedo_texture != null:
		conv.set_shader_parameter("albedo_texture", mat.albedo_texture)
	return conv


## GradientTexture1D from ramp stops (dark -> light, evenly spaced), cached by colour
## key — ramps are immutable, so rooms/enemies on the same stratum share one texture.
static func _ramp_texture(stops: Array[Color]) -> GradientTexture1D:
	var key := ""
	for c in stops:
		key += c.to_html() + "|"
	if _ramps.has(key):
		return _ramps[key]
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	if stops.is_empty():
		offsets.append(0.0)
		colors.append(Color.WHITE)
	else:
		for i in stops.size():
			offsets.append(float(i) / maxf(1.0, float(stops.size() - 1)))
			colors.append(stops[i])
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = RAMP_TEX_WIDTH
	_ramps[key] = tex
	return tex
