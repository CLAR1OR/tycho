extends Node
## Renders the town AT THE GAME'S CAMERA and composites it side by side with the style
## anchor into ONE png — the style-bible judging protocol (design/style-bible.md: "open
## the anchor and the candidate side by side, never against memory") with the manual
## image-editing step removed. Built for the LOOK GATE (the art-style.png fork).
##
## Needs a real GPU context (Forward+: volumetric fog, the water shader), so NOT headless:
##   godot --path . tools/render_compare.tscn --quit-after 300
## Output: user://look_compare.png (path echoed to stdout), anchor LEFT, render RIGHT.
##
## Unlike tools/render_prop.gd this does NOT restage the town by hand — it instances the
## real scenes/town/town.tscn, so what lands in the png cannot drift from what F5 shows.

const ANCHOR_PATH := "res://assets_src/anchors/art-style.png"
const TOWN_SCENE := "res://scenes/town/town.tscn"
const VIEW_SIZE := Vector2i(1280, 853)   # ~3:2, the anchor's aspect
const SETTLE_FRAMES := 45                # water scroll + volumetric fog + shadows settle

var _vp: SubViewport = null
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(96, 96))
	DisplayServer.window_set_position(Vector2i(0, 0))

	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The town runs Forward+ effects; the default subviewport scaling would soften them.
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)

	# The town reads live save state (plots, story flags, day). Hand it a default slot
	# IN MEMORY ONLY — never create_slot(), which writes to disk; profile.json and the
	# save slots are the human's real files (design/godot-conventions.md § Testing).
	SaveManager.state = SaveData.default_slot("look-gate", "")
	var town: Node = load(TOWN_SCENE).instantiate()
	_vp.add_child(town)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return
	set_process(false)
	var render := _vp.get_texture().get_image()
	var anchor := _load_anchor()
	var out := _side_by_side(anchor, render) if anchor != null else render
	var path := "user://look_compare.png"
	var err := out.save_png(path)
	print("look compare -> %s (%s)" % [ProjectSettings.globalize_path(path),
		"ok" if err == OK else "ERR %d" % err])
	if anchor == null:
		push_warning("anchor not loaded — wrote the bare render instead of a comparison")
	get_tree().quit()


## assets_src/ is .gdignore'd (Godot never imports it), so the anchor CANNOT be load()ed
## as a resource — it has no .import. Read it off disk as a raw file instead.
func _load_anchor() -> Image:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(ANCHOR_PATH)) != OK:
		return null
	return img


## Anchor left, render right, scaled to a common height, on a dark seam.
func _side_by_side(anchor: Image, render: Image) -> Image:
	var h := maxi(anchor.get_height(), render.get_height())
	var a := _scaled_to_height(anchor, h)
	var b := _scaled_to_height(render, h)
	const GAP := 16
	var out := Image.create(a.get_width() + GAP + b.get_width(), h, false, render.get_format())
	out.fill(Color(0.06, 0.06, 0.07))
	a.convert(out.get_format())
	b.convert(out.get_format())
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + GAP, 0))
	return out


func _scaled_to_height(img: Image, h: int) -> Image:
	if img.get_height() == h:
		return img
	var copy := img.duplicate() as Image
	copy.resize(int(round(float(img.get_width()) * float(h) / float(img.get_height()))), h,
		Image.INTERPOLATE_LANCZOS)
	return copy
