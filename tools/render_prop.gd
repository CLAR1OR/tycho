extends Node
## Renders a prop offscreen AT THE GAME'S CAMERA ANGLE and writes PNGs — the missing
## half of the style-bible judging protocol (design/style-bible.md: "open the anchor and
## the candidate side by side"; design/asset-list.md: "every 3D asset is judged at the
## game's camera angle, never in a free-orbit turntable").
##
## It reproduces the town's actual look: the town's DirectionalLight + Environment, the
## town ground colour, and the SAME toon sweep town.gd runs (StyleMaterials.apply_to_tree
## on TOWN_RAMP) — so what lands in the PNG is what F5 shows, not an approximation.
## Needs a real GPU context (the water shader is Forward+), so NOT --headless:
##   godot --path . tools/render_prop.tscn --quit-after 240
## Output: user://prop_render_*.png (path echoed to stdout).

# Mirrors scenes/town/town.tscn exactly — change these only if the town changes.
## GOTCHA: a .tscn Transform3D's 9 basis floats are stored ROW-major, while
## Basis(a, b, c) takes COLUMN vectors. Transcribing the rows straight into Basis()
## gives a different (here: upside-down) light. These are town.tscn's rows transposed:
## rows (0.866, -0.35, 0.354) / (0, 0.707, 0.707) / (-0.5, -0.612, 0.612).
const TOWN_LIGHT_BASIS := Basis(Vector3(0.866, 0, -0.5), Vector3(-0.35, 0.707, -0.612),
	Vector3(0.354, 0.707, 0.612))
const TOWN_BG := Color(0.12, 0.13, 0.1)
const TOWN_AMBIENT := Color(0.55, 0.55, 0.5)
const TOWN_AMBIENT_ENERGY := 0.8
const TOWN_GROUND := Color(0.3, 0.32, 0.24)
# Mirrors src/core/camera_rig.gd's FEEL dials — the fixed 2.5D framing.
const CAM_OFFSET := Vector3(0, 12, 7.5)
const CAM_PITCH := -58.0

## Framings to render: label -> how much to scale the rig offset in (a closer shot is
## the SAME angle, just nearer — never a different angle).
const SHOTS := {"game": 1.0, "close": 0.42}
const VIEW_SIZE := Vector2i(1100, 800)

var _shots: Array[Dictionary] = []
var _frames := 0


func _ready() -> void:
	# Keep the harness out of the user's face: tiny window, parked in a corner.
	DisplayServer.window_set_size(Vector2i(96, 96))
	DisplayServer.window_set_position(Vector2i(0, 0))
	# The water shader's project-wide globals (WaterPlane normally sets these).
	RenderingServer.global_shader_parameter_set("wind_intensity", 0.35)
	RenderingServer.global_shader_parameter_set("wind_direction", Vector3(1.0, 0.0, 0.35))
	RenderingServer.global_shader_parameter_set("player_position", Vector3(1.0e6, 0.0, 0.0))

	for label: String in SHOTS:
		_shots.append(_make_shot(label, SHOTS[label]))


## One SubViewport holding a full town-lit stage with the prop at the origin.
func _make_shot(label: String, distance_scale: float) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEW_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TOWN_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = TOWN_AMBIENT
	env.ambient_light_energy = TOWN_AMBIENT_ENERGY
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var light := DirectionalLight3D.new()
	light.transform = Transform3D(TOWN_LIGHT_BASIS, Vector3(0, 12, 0))
	light.shadow_enabled = true
	vp.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = TOWN_GROUND
	ground.material_override = gmat
	vp.add_child(ground)

	var prop := TownFountain.new()
	vp.add_child(prop)

	var cam := Camera3D.new()
	cam.position = CAM_OFFSET * distance_scale
	cam.rotation_degrees = Vector3(CAM_PITCH, 0.0, 0.0)
	cam.current = true
	vp.add_child(cam)

	# The one line that matters for fidelity: the town's own toon sweep.
	StyleMaterials.apply_to_tree(ground, StyleCore.TOWN_RAMP)
	StyleMaterials.apply_to_tree(prop, StyleCore.TOWN_RAMP)
	return {"label": label, "vp": vp}


func _process(_delta: float) -> void:
	# Let the water shader's scroll settle and shadows populate before grabbing.
	_frames += 1
	if _frames < 30:
		return
	for shot in _shots:
		var vp: SubViewport = shot["vp"]
		var path := "user://prop_render_%s.png" % shot["label"]
		var err := vp.get_texture().get_image().save_png(path)
		print("%s -> %s (%s)" % [shot["label"], ProjectSettings.globalize_path(path),
			"ok" if err == OK else "ERR %d" % err])
	get_tree().quit()
