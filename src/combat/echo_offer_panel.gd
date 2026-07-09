extends Control
class_name EchoOfferPanel
## In-run Echo offer UI — "The etchings answer" (O1, human-picked 2026-07-09 via
## claude.ai/design, "Echo Offer" group). No panel, no cards: when the offer fires (the
## game is already paused) the whole screen dims hard and three resonance marks bloom over
## the dimmed battlefield — the same ring-and-glow language as the etchings screen's marks
## (E1). Each mark carries the echo's Cinzel monogram (the exact glyph it will wear on the
## RunHud echo shelf — HudCore.monogram, reused), a key badge, the name in Cinzel, and the
## effect lines in mono. Hover wakes the ring (full cyan + halo); click or number key picks.
##
## Drawn entirely in `_draw` (the panel IS the screen); hover/click hit-test in `_gui_input`.
## The pure display rules live in EchoOfferCore; this owns only pixels + hit-testing.
##
## FROZEN: the panel unpauses BEFORE reporting the pick, so whatever the callback does
## (apply stats, open the exit) runs in a live tree. present()/pick() are public so the
## headless smoke driver can choose programmatically. The mock's gold pick-flash and
## fly-to-shelf animation are DEFERRED to a later juice pass — pick() stays synchronous.
##
## HUMAN: everything under "Style / copy" is a PLACEHOLDER — dial like FEEL numbers (no
## combat feel, so no `# FEEL:` tag). The shared palette + fonts live in SlateHud.

# =====================================================================================
# Style / copy — placeholders. (Palette + fonts are shared — see SlateHud.)
# =====================================================================================
const DIMMER := Color(8.0/255, 7.0/255, 12.0/255, 0.62)          # hard screen dim over the field
const COL_SUB := Color(87.0/255, 83.0/255, 106.0/255)            # #57536a faint caps sub
const COL_DRAWBACK := Color(201.0/255, 129.0/255, 129.0/255)     # #c98181 soft red (softer than COL_PERIL)
const COL_MONO_HOVER := Color(191.0/255, 242.0/255, 255.0/255)   # #bff2ff woken monogram
const COL_HELD_BORDER := Color(138.0/255, 124.0/255, 70.0/255)   # #8a7c46 gold held-badge border
const TITLE := "Your etchings glow."          # placeholder copy (was "…— choose an Echo")
const SUB := "CHOOSE AN ECHO"                 # placeholder copy (caps mono sub)
const WOVEN_FMT := "woven from %s"            # placeholder copy — wraps the resolved parents
# Header
const HEADER_TOP_FRAC := 0.13
const FS_TITLE := 21    # title (body / Garamond)
const FS_SUB := 11      # caps sub (num / mono, letter-spaced)
const SUB_SPACING := 3
const SUB_DY := 6.0
# Marks (a shallow arc; ring radius, the middle lifted when the count is odd)
const RING_R := 75.0
const ARC_BASE_FRAC := 0.52   # ring-centre y as a fraction of size.y
const ARC_LIFT := 38.0        # the middle mark rides higher (odd counts, >= 3)
const RING_W := 2.0
const RING_SEGMENTS := 48
const RING_IDLE_ALPHA := 0.45
const MONO_IDLE_ALPHA := 0.85
const FS_MONO := 46     # monogram (display / Cinzel)
const FS_NAME := 21     # echo name (display / Cinzel)
const FS_FX := 12       # effect lines (num / mono)
const FS_PARENTS := 10  # synergy parents line (num / mono)
const FS_KEY := 11      # key badge digit (num)
const FS_HELD := 10     # held ×n badge (num)
const NAME_DY := 14.0   # name top, below the ring
const LINE_GAP := 4.0
const FX_GAP := 3.0
# Glow / halo (layered fills + arcs, like the S2 title glow / E1 mark halo)
const GLOW_A_IDLE := 0.10
const GLOW_A_HOVER := 0.16
const GLOW_LAYERS := 5
const HALO_A := 0.14
const HALO_W := 6.0
const HALO_STEP := 5.0
const HALO_RINGS := 3
# Synergy weave (a faint outer second ring)
const WEAVE_GAP := 5.0
const WEAVE_W := 3.0
const WEAVE_ALPHA := 0.30
# Hit-test box around a mark (ring + the name/effects below it)
const HIT_W := 220.0
const HIT_TOP := 18.0
const HIT_BOT := 104.0

var _ids: Array[String] = []
var _on_pick: Callable
var _defs: Dictionary = {}
var _hovered: int = -1

var _font_display: FontVariation
var _font_body: FontVariation
var _font_num: FontVariation
var _font_sub: FontVariation
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the tree is paused
	add_to_group("echo_offer")
	mouse_filter = Control.MOUSE_FILTER_STOP  # the whole screen catches hover + clicks
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_display = SlateHud._with_fallback(SlateHud.FONT_DISPLAY_FILE)
	_font_body = SlateHud._with_fallback(SlateHud.FONT_BODY_FILE)
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)
	_font_sub = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)
	_font_sub.set_spacing(TextServer.SPACING_GLYPH, SUB_SPACING)


## Show the offer and pause the game. `on_pick` is called with the chosen echo id.
func present(offer_ids: Array[String], on_pick: Callable) -> void:
	_ids = offer_ids
	_on_pick = on_pick
	_defs = EchoCore.defs()
	_sync_size()  # the marks draw off size — set it now (no more await-a-frame recenter hack)
	get_tree().paused = true
	Sfx.play("echo-open")
	queue_redraw()


## Choose mark `index` (0-based). Public: the mouse, number keys, and the smoke driver all
## land here. FROZEN semantics: unpause BEFORE reporting the pick, synchronously.
func pick(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	var id := _ids[index]
	var cb := _on_pick
	Sfx.play("echo-pick")
	get_tree().paused = false
	queue_free()
	if cb.is_valid():
		cb.call(id)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_3:
			get_viewport().set_input_as_handled()
			pick(int(key - KEY_1))  # keys map 1..n; pick() guards a key past the count


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _mark_at((event as InputEventMouseMotion).position)
		if hit != _hovered:
			_hovered = hit
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _mark_at((event as InputEventMouseButton).position)
		if i >= 0:
			pick(i)


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under a CanvasLayer get no layout pass (size stays
	# 0,0) — sync to the viewport, like every other rebuilt Slate screen.
	if _sync_size():
		queue_redraw()


# --- Debug (the headless smoke reads this) -------------------------------------------

func mark_count() -> int:
	return _ids.size()


# --- Layout / hit-test ---------------------------------------------------------------

func _sync_size() -> bool:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
		return true
	return false


## The ring centre of mark `i` — a shallow arc: outer marks lower, the exact-middle mark
## lifted when the count is odd (and >= 3). 1-2-mark offers centre gracefully.
func _center(i: int) -> Vector2:
	var n := _ids.size()
	var cy := size.y * ARC_BASE_FRAC
	if n >= 3 and n % 2 == 1 and i == n / 2:
		cy -= ARC_LIFT
	return Vector2(size.x * float(i + 1) / float(n + 1), cy)


func _mark_at(pos: Vector2) -> int:
	for i in _ids.size():
		var c := _center(i)
		var rect := Rect2(c.x - HIT_W * 0.5, c.y - RING_R - HIT_TOP, HIT_W, RING_R + HIT_TOP + HIT_BOT)
		if rect.has_point(pos):
			return i
	return -1


# --- Draw ----------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), DIMMER)  # the hard dim over the battlefield
	_draw_header()
	for i in _ids.size():
		_draw_mark(i)


func _draw_header() -> void:
	var cx := size.x * 0.5
	var top := size.y * HEADER_TOP_FRAC
	_line(_font_body, Vector2(cx, top), TITLE, FS_TITLE, SlateHud.COL_KEY_TEXT)
	_line(_font_sub, Vector2(cx, top + FS_TITLE + SUB_DY), SUB, FS_SUB, COL_SUB)


func _draw_mark(i: int) -> void:
	var id := _ids[i]
	var def: Dictionary = _defs.get(id, {"name": id, "desc": ""})
	var c := _center(i)
	var hovered := i == _hovered
	var synergy := EchoOfferCore.is_synergy(def)
	# Radial inner glow, then the ring (a faint outer weave first when it's a synergy).
	_inner_glow(c, hovered)
	if synergy:
		draw_arc(c, RING_R + WEAVE_GAP, 0.0, TAU, RING_SEGMENTS,
			Color(SlateHud.COL_DUST, WEAVE_ALPHA), WEAVE_W, true)
	var border := SlateHud.COL_DUST if hovered else Color(SlateHud.COL_DUST, RING_IDLE_ALPHA)
	draw_arc(c, RING_R, 0.0, TAU, RING_SEGMENTS, border, RING_W, true)
	if hovered:
		_halo(c)
	# Monogram — the exact glyph the pick will wear on the shelf.
	var mono := HudCore.monogram(str(def.get("name", id)))
	var mcol := COL_MONO_HOVER if hovered else Color(SlateHud.COL_DUST, MONO_IDLE_ALPHA)
	_glyph(_font_display, c, mono, FS_MONO, mcol)
	# Key badge (top-centre of the ring) + held ×n badge (upper-right, stackables only).
	_chip(c + Vector2(0, -RING_R), str(i + 1), _font_num, FS_KEY,
		SlateHud.COL_CHIP_BG, SlateHud.COL_CHIP_BORDER, SlateHud.COL_KEY_TEXT)
	var held := EchoOfferCore.held_count(id, RunState.echoes)
	if held > 0:
		_chip(c + Vector2(RING_R * 0.62, -RING_R * 0.62), "×%d" % held, _font_num, FS_HELD,
			SlateHud.COL_CHIP_BG, COL_HELD_BORDER, SlateHud.COL_READY)
	# Name, then (synergy) the parents line, then the effect lines.
	var y := c.y + RING_R + NAME_DY
	_line(_font_display, Vector2(c.x, y), str(def.get("name", id)), FS_NAME, SlateHud.COL_TEXT)
	y += _font_display.get_height(FS_NAME) + LINE_GAP
	if synergy:
		_line(_font_num, Vector2(c.x, y), WOVEN_FMT % EchoOfferCore.parents_line(def, _defs),
			FS_PARENTS, SlateHud.COL_KEY_TEXT)
		y += _font_num.get_height(FS_PARENTS) + LINE_GAP
	for fx: Dictionary in EchoOfferCore.effect_lines(str(def.get("desc", ""))):
		var col := COL_DRAWBACK if bool(fx["drawback"]) else SlateHud.COL_KEY_TEXT
		_line(_font_num, Vector2(c.x, y), str(fx["text"]), FS_FX, col)
		y += _font_num.get_height(FS_FX) + FX_GAP


# --- draw helpers --------------------------------------------------------------------

## A horizontally-centred line; `pos.y` is the line top (baseline = top + ascent).
func _line(font: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(pos.x - w * 0.5, pos.y + font.get_ascent(fs)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A glyph centred (both axes) on `center` — for the monogram inside the ring.
func _glyph(font: Font, center: Vector2, text: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _inner_glow(center: Vector2, hovered: bool) -> void:
	var a := GLOW_A_HOVER if hovered else GLOW_A_IDLE
	for i in GLOW_LAYERS:
		var t := float(i) / float(GLOW_LAYERS)
		draw_circle(center, RING_R * (1.0 - t * 0.35), Color(SlateHud.COL_DUST, a * (1.0 - t)))


func _halo(center: Vector2) -> void:
	for i in HALO_RINGS:
		var r := RING_R + HALO_STEP * float(i + 1)
		draw_arc(center, r, 0.0, TAU, RING_SEGMENTS, Color(SlateHud.COL_DUST, HALO_A / float(i + 1)),
			HALO_W, true)


## A small chip centred on `center` — the key digit / held-count badge.
func _chip(center: Vector2, text: String, font: Font, fs: int, bg: Color, border: Color, fg: Color) -> void:
	var pad := Vector2(7, 2)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := font.get_height(fs) + pad.y * 2.0
	var w := tw + pad.x * 2.0
	var rect := Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h)
	_sb.bg_color = bg
	_sb.border_color = border
	_sb.set_border_width_all(1)
	_sb.set_corner_radius_all(4)
	draw_style_box(_sb, rect)
	var y := rect.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(rect.position.x + pad.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
