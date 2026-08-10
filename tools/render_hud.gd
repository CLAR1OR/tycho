extends Node
## Renders the in-run HUD (RunHud, the "Ember" design) to PNGs so its LAYOUT can be
## judged without playing to the right room state — the 2D companion to render_prop.gd
## (which does the same job for 3D props at the game camera angle).
##
## It is a layout probe, not a screenshot of the game: the world behind the HUD is a flat
## dark field with a few bright patches, so you can check that the shadowed prose stays
## legible over a light background and that nothing collides or falls off-screen. Judge
## the real thing in F5 — this only catches the gross errors before you spend a run on them.
##
## Needs a real GPU context (it reads the viewport texture back), so NOT --headless:
##   godot --path . tools/render_hud.tscn
## Output: user://hud_render_<state>.png (paths echoed to stdout, with the OS path).

## The fake world behind the HUD: a dark field plus bright patches under the places where
## Ember draws unbacked prose (hint line, objective rows, resource numbers).
const BG := Color(0.055, 0.06, 0.065)
const PATCHES: Array[Rect2] = [
	Rect2(430, 600, 420, 60),    # under the hint + HP bar
	Rect2(940, 30, 320, 210),    # under the resource row + room block
	Rect2(60, 380, 150, 300),    # under the echo rail
]
const PATCH_COL := Color(0.42, 0.45, 0.38)

## Render at the project's BASE viewport, never at whatever size the window manager hands
## the probe window — the HUD constants are judged against these numbers.
const SHOT_SIZE := Vector2i(1280, 720)

var _hud: RunHud
var _player: Node = null
var _sv: SubViewport


func _ready() -> void:
	_sv = SubViewport.new()
	_sv.size = SHOT_SIZE
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(SHOT_SIZE)
	_sv.add_child(bg)
	for r: Rect2 in PATCHES:
		var p := ColorRect.new()
		p.color = PATCH_COL
		p.position = r.position
		p.size = r.size
		_sv.add_child(p)
	# A real Player so the ability dial shows real glyphs + cooldown arcs. If the scene
	# refuses to stand up outside a combat room, fall back to an empty dial (the rings and
	# key badges still draw, which is most of what the layout probe is checking). It lives
	# outside the SubViewport — the HUD only polls it for data, never renders it.
	_player = _make_player()
	var layer := CanvasLayer.new()
	_sv.add_child(layer)
	_hud = RunHud.new()
	layer.add_child(_hud)
	if _player != null:
		_hud.setup(_player)
	_run()


func _make_player() -> Node:
	var scene: PackedScene = load("res://scenes/combat/player.tscn")
	if scene == null:
		return null
	var p: Node = scene.instantiate()
	add_child(p)
	# Equip three etchings and put two of them mid-cooldown, so the probe shows a ready
	# ring, two sweeping arcs, and the dash pip together.
	p.set("_etch_defs", EtchingsCore.defs())
	p.set("_equipped", {"rmb": "push", "q": "snare", "r": "shockwave"})
	p.set("_cast_cd", {"rmb": 0.0, "q": 3.1, "r": 6.4})
	p.set("_dash_cd", 0.35)
	return p


func _run() -> void:
	await _shot("combat", func() -> void:
		_hud.configure_room(2, 3, 5, HudCore.KIND_COMBAT, true)
		_hud.set_wave(1, 3)
		_hud.set_wave_progress(2, 5)
		_hud.set_hp(72, 100)
		_hud.set_hint("Clear the room")
		_hud.set("_res_amounts", {
			"gold": 128.0, "resonance-ore": 35.0, "resonance-dust": 12.0,
			"knowledge-shards": 4.0,
		})
		_hud.set("_echoes", _fake_echoes(6))
	)
	await _shot("low-hp-cleared", func() -> void:
		_hud.configure_room(4, 5, 5, HudCore.KIND_COMBAT, false)
		_hud.set_wave(2, 3)
		_hud.mark_cleared()
		_hud.set_hp(14, 100)
		_hud.set_hint("Choose a door — the sigil is what the next room pays")
		_hud.set("_echoes", _fake_echoes(11))
	)
	print("render_hud: done")
	get_tree().quit()


## Fake folded-echo tiles, including a couple of stacks so the gold count badge shows.
func _fake_echoes(n: int) -> Array:
	var names := ["Tempest Stride", "Vital Core", "Quick Dash", "Swift Step", "Mender's Rhythm",
		"Iron Skin", "Keen Edge", "Long Reach", "Cinder Mark", "Deep Well", "Sure Footing"]
	var out: Array = []
	for i in mini(n, names.size()):
		out.append({
			"id": "e%d" % i, "name": names[i],
			"monogram": HudCore.monogram(names[i]),
			"count": 3 if i == 1 else (2 if i == 4 else 1),
		})
	return out


func _shot(label: String, setup: Callable) -> void:
	setup.call()
	_hud.queue_redraw()
	# Two frames: one to lay out and redraw, one to be sure it reached the framebuffer.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	var path := "user://hud_render_%s.png" % label
	img.save_png(path)
	print("render_hud: wrote %s -> %s" % [path, ProjectSettings.globalize_path(path)])
