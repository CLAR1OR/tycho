extends VBoxContainer
class_name ArchPuzzle
## The Masonry & the Arch interactive puzzle view (the CONTENT-GATE puzzle —
## design/tech-nodes/medieval-masonry-the-arch.md §5). Code-built, placeholder
## visuals: a clickable 2D diagram of the gateway drawn in _draw, driven entirely
## by the pure ArchPuzzleCore state machine. Click a slot to set a stone there
## (stands in for drag-and-drop — §9's UI note; upgrade with real art later).
##
## Contract with TechPanel: `setup(data)` with the node's puzzle.data
## ({intro, hints[]}), emits `solved` when the gateway holds. All player actions
## route through `act(action, arg) -> event` so the headless smoke can drive the
## REAL path, failures included.

signal solved

## Event → authored feedback. Failures teach: each says WHERE and WHY (§5).
const MESSAGES := {
	"lintel_placed": "The slab spans the gap. It looks right. Load it and see.",
	"lintel_cracked": "CRACK — along the UNDERSIDE. Bending stretched the bottom edge, and being pulled apart is the one thing stone cannot bear.",
	"arch_chosen": "No more flat spans. Curve the gap: wedge-shaped stones, each pressing on the next. Springers first — they rest on the piers.",
	"centering_up": "The wooden frame is up. It holds the wedges until the ring is closed.",
	"centering_down": "The frame comes away.",
	"ring_fell": "The half-ring falls the moment the frame goes! An open ring is no ring at all — keep the centering up until the keystone is in.",
	"voussoir_placed": "The wedge settles into place.",
	"voussoir_fell": "The wedge drops into the gap — nothing is under it. Only the springers rest on the piers; the rest need the centering.",
	"keystone_fell": "The keystone falls straight through — it needs the full ring to bear on. It goes in LAST.",
	"keystone_seated": "The keystone drops home. The ring locks, the frame comes away… and it stands.",
	"unkeyed_collapse": "It all comes down. A ring isn't a ring until the keystone closes it — never load an open arch.",
	"splayed": "It held — then the feet slid OUTWARD and the ring splayed. An arch doesn't just press down; it shoves sideways at its feet. Brace them.",
	"abutment_placed": "A heavy abutment, braced against the foot.",
	"holds": "The wall section settles onto the crown. The weight runs through the stones as pure squeeze, out through the abutments, into the earth. The gateway STANDS.",
	"profile_pointed": "Cut pointed: the thrust line runs steeper and the outward shove shrinks.",
	"profile_round": "Back to the round profile.",
	"load_nothing": "There is nothing over the gap to load.",
	"invalid": "",
}

# Diagram geometry (local px). FEEL-free — pure placeholder layout numbers.
const DIAGRAM_SIZE := Vector2(760, 340)
const HALF_GAP := 90.0     # inner radius / half the gateway span
const RING_T := 34.0       # ring (voussoir) thickness
const PIER_W := 60.0
const PIER_H := 140.0
const SLICES := 7          # 6 voussoirs + the keystone (middle slice)
const KEYSTONE_SLICE := 3

var _state: Dictionary = ArchPuzzleCore.initial_state()
var _data: Dictionary = {}
var _hint_index := -1
var _msg: Label
var _hint_label: Label
var _diagram: Control
var _buttons: HBoxContainer


## Inner drawing surface — delegates draw + clicks back to the puzzle.
class Diagram extends Control:
	var puzzle: ArchPuzzle

	func _draw() -> void:
		puzzle._draw_diagram(self)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			puzzle._diagram_click((event as InputEventMouseButton).position)


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(0, 44)
	add_child(_msg)
	_diagram = Diagram.new()
	(_diagram as Diagram).puzzle = self
	_diagram.custom_minimum_size = DIAGRAM_SIZE
	add_child(_diagram)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	add_child(_buttons)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.modulate = Color(0.8, 0.9, 1.0)
	add_child(_hint_label)
	_msg.text = str(_data.get("intro", "Raise a gateway that carries the new wall."))
	_refresh()


func setup(data: Dictionary) -> void:
	_data = data


# --- Actions (buttons, clicks, and the smoke all land here) ------------------------

func act(action: String, arg: Variant = null) -> String:
	var result: Dictionary
	match action:
		"lintel":
			result = ArchPuzzleCore.place_lintel(_state)
		"load":
			result = ArchPuzzleCore.load(_state)
		"arch":
			result = ArchPuzzleCore.choose_arch(_state)
		"centering":
			result = ArchPuzzleCore.toggle_centering(_state)
		"voussoir":
			result = ArchPuzzleCore.place_voussoir(_state, int(arg))
		"keystone":
			result = ArchPuzzleCore.place_keystone(_state)
		"abutment":
			result = ArchPuzzleCore.place_abutment(_state, str(arg))
		"pointed":
			result = ArchPuzzleCore.toggle_pointed(_state)
		"hint":
			_show_hint()
			return "hint"
		_:
			return "invalid"
	_state = result["state"]
	var event := str(result["event"])
	if MESSAGES.get(event, "") != "":
		_msg.text = str(MESSAGES[event])
	if event in ["lintel_cracked", "ring_fell", "voussoir_fell", "keystone_fell",
			"unkeyed_collapse", "splayed"]:
		_shake()
	_refresh()
	if event == "holds":
		solved.emit()
	return event


func _show_hint() -> void:
	var hints: Array = _data.get("hints", [])
	if hints.is_empty():
		return
	_hint_index = mini(_hint_index + 1, hints.size() - 1)
	_hint_label.text = "Sophia: “%s”" % str(hints[_hint_index])


func _shake() -> void:
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_diagram, "position:x", 6.0 if i % 2 == 0 else -6.0, 0.04).as_relative()
	tween.tween_property(_diagram, "position:x", 0.0, 0.04)


# --- Contextual buttons -------------------------------------------------------------

func _refresh() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	var beat := int(_state["beat"])
	if beat == 1:
		if not bool(_state["lintel"]) and not bool(_state["cracked"]):
			_add_button("Lay the flat lintel", "lintel")
		if bool(_state["cracked"]):
			_add_button("Clear the rubble — curve the span", "arch")
	if beat == 2:
		_add_button("Strike the centering" if bool(_state["centering"]) else "Raise the centering",
			"centering")
		if ArchPuzzleCore.placed_count(_state) == 0 and not bool(_state["keystone"]):
			_add_button("Cut round" if bool(_state["pointed"]) else "Cut pointed", "pointed")
		if ArchPuzzleCore.ring_complete(_state):
			_add_button("Set the keystone", "keystone")
	if beat in [2, 3]:
		var ab: Dictionary = _state["abutments"]
		if not bool(ab["left"]):
			_add_button("Brace the left foot", "abutment", "left")
		if not bool(ab["right"]):
			_add_button("Brace the right foot", "abutment", "right")
	if beat < 4:
		_add_button("⚒ Load it!", "load")
		_add_button("Ask Sophia", "hint")
	_diagram.queue_redraw()


func _add_button(text: String, action: String, arg: Variant = null) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: act(action, arg))
	_buttons.add_child(b)


# --- Clicks -------------------------------------------------------------------------

func _diagram_click(pos: Vector2) -> void:
	var beat := int(_state["beat"])
	if beat == 1 and _lintel_rect().has_point(pos):
		act("lintel")
		return
	if beat == 2:
		for k in SLICES:
			if Geometry2D.is_point_in_polygon(pos, _slice_poly(k)):
				if k == KEYSTONE_SLICE:
					act("keystone")
				else:
					act("voussoir", _voussoir_for_slice(k))
				return
	if beat in [2, 3]:
		for side in ["left", "right"]:
			if _abutment_rect(side).has_point(pos):
				act("abutment", side)
				return


# --- Geometry -----------------------------------------------------------------------

func _cx() -> float:
	return _diagram.size.x / 2.0


func _ground_y() -> float:
	return _diagram.size.y - 30.0


func _spring_y() -> float:
	return _ground_y() - PIER_H


## A point on the ring: t ∈ [0,1] runs left foot → right foot, off = radial offset
## from the inner face. Round = one semicircle; pointed = the equilateral two-arc
## profile (each face an arc of radius 2·HALF_GAP centered on the OPPOSITE springing).
func _ring_point(t: float, off: float) -> Vector2:
	var cx := _cx()
	var sy := _spring_y()
	if not bool(_state["pointed"]):
		var a := PI * (1.0 - t)
		var r := HALF_GAP + off
		return Vector2(cx + cos(a) * r, sy - sin(a) * r)
	var r2 := 2.0 * HALF_GAP + off
	if t <= 0.5:
		var a := PI - (t / 0.5) * (PI / 3.0)
		return Vector2(cx + HALF_GAP + cos(a) * r2, sy - sin(a) * r2)
	var a2 := ((1.0 - t) / 0.5) * (PI / 3.0)
	return Vector2(cx - HALF_GAP + cos(a2) * r2, sy - sin(a2) * r2)


func _slice_poly(k: int) -> PackedVector2Array:
	var t0 := float(k) / SLICES
	var t1 := float(k + 1) / SLICES
	var poly := PackedVector2Array([_ring_point(t0, 0.0), _ring_point(t1, 0.0),
		_ring_point(t1, RING_T), _ring_point(t0, RING_T)])
	# The keystone slice straddles the pointed apex — include the apex kink.
	if k == KEYSTONE_SLICE and bool(_state["pointed"]):
		poly = PackedVector2Array([_ring_point(t0, 0.0), _ring_point(0.5, 0.0),
			_ring_point(t1, 0.0), _ring_point(t1, RING_T), _ring_point(0.5, RING_T),
			_ring_point(t0, RING_T)])
	return poly


## Slice index → voussoir index (left: 0,1,2 from the foot up; right: 3 is the
## springer at slice 6, so idx = 9 - slice).
func _voussoir_for_slice(k: int) -> int:
	return k if k < KEYSTONE_SLICE else 9 - k


func _slice_placed(k: int) -> bool:
	if k == KEYSTONE_SLICE:
		return bool(_state["keystone"])
	return bool((_state["voussoirs"] as Array)[_voussoir_for_slice(k)])


func _lintel_rect() -> Rect2:
	return Rect2(_cx() - HALF_GAP - 24.0, _spring_y() - 30.0, 2.0 * (HALF_GAP + 24.0), 30.0)


func _abutment_rect(side: String) -> Rect2:
	var w := 64.0
	var h := 78.0
	var x := _cx() - HALF_GAP - PIER_W - w if side == "left" else _cx() + HALF_GAP + PIER_W
	return Rect2(x, _ground_y() - h, w, h)


# --- Drawing ------------------------------------------------------------------------

const COL_STONE := Color(0.62, 0.6, 0.56)
const COL_PIER := Color(0.45, 0.44, 0.42)
const COL_KEYSTONE := Color(0.8, 0.68, 0.42)
const COL_WOOD := Color(0.55, 0.38, 0.2)
const COL_GHOST := Color(1, 1, 1, 0.2)
const COL_CRACK := Color(0.9, 0.25, 0.2)
const COL_GROUND := Color(0.29, 0.24, 0.19)


func _draw_diagram(d: Control) -> void:
	var cx := _cx()
	var gy := _ground_y()
	var sy := _spring_y()
	var font := get_theme_default_font()
	d.draw_rect(Rect2(0, gy, d.size.x, d.size.y - gy), COL_GROUND)
	d.draw_rect(Rect2(cx - HALF_GAP - PIER_W, sy, PIER_W, PIER_H), COL_PIER)
	d.draw_rect(Rect2(cx + HALF_GAP, sy, PIER_W, PIER_H), COL_PIER)

	var beat := int(_state["beat"])
	if beat == 1:
		var lr := _lintel_rect()
		if bool(_state["lintel"]):
			d.draw_rect(lr, COL_STONE)
			d.draw_rect(lr, Color.BLACK, false, 1.5)
		elif bool(_state["cracked"]):
			# The failed lintel: two halves tipped into the gap, crack on the underside.
			var mid := Vector2(cx, sy + 26.0)
			d.draw_colored_polygon(PackedVector2Array([
				Vector2(lr.position.x, sy - 26.0), Vector2(cx - 6.0, sy - 4.0),
				mid, Vector2(lr.position.x, sy)]), COL_STONE)
			d.draw_colored_polygon(PackedVector2Array([
				Vector2(lr.end.x, sy - 26.0), Vector2(cx + 6.0, sy - 4.0),
				mid, Vector2(lr.end.x, sy)]), COL_STONE)
			d.draw_line(Vector2(cx - 6.0, sy - 4.0), mid, COL_CRACK, 3.0)
			d.draw_line(mid, Vector2(cx + 6.0, sy - 4.0), COL_CRACK, 3.0)
			d.draw_string(font, Vector2(cx - 96.0, sy + 48.0),
				"pulled apart here — tension", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_CRACK)
		else:
			d.draw_rect(lr, COL_GHOST, false, 2.0)
			d.draw_string(font, Vector2(lr.position.x + 10.0, lr.position.y + 20.0),
				"click: lay the slab", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_GHOST)
	else:
		# Centering: a wooden frame filling the opening under the ring.
		if bool(_state["centering"]):
			var frame := PackedVector2Array()
			for i in 25:
				frame.append(_ring_point(float(i) / 24.0, -3.0))
			frame.append(Vector2(cx + HALF_GAP, sy))
			frame.append(Vector2(cx - HALF_GAP, sy))
			d.draw_colored_polygon(frame, Color(COL_WOOD, 0.55))
			for t: float in [0.25, 0.5, 0.75]:
				d.draw_line(Vector2(cx, sy), _ring_point(t, -3.0), COL_WOOD, 3.0)
		# The ring, slice by slice: ghost slots to click, stone when placed.
		for k in SLICES:
			var poly := _slice_poly(k)
			if _slice_placed(k):
				d.draw_colored_polygon(poly, COL_KEYSTONE if k == KEYSTONE_SLICE else COL_STONE)
				var outline := poly.duplicate()
				outline.append(poly[0])
				d.draw_polyline(outline, Color.BLACK, 1.5)
			else:
				var ghost := poly.duplicate()
				ghost.append(poly[0])
				d.draw_polyline(ghost, COL_GHOST, 1.5)
		if beat >= 3 and not bool(_state["solved"]):
			# The outward shove at the feet — smaller when the profile is pointed.
			var shove := 26.0 if bool(_state["pointed"]) else 46.0
			for dir: float in [-1.0, 1.0]:
				var foot := Vector2(cx + dir * (HALF_GAP + RING_T), sy + 8.0)
				var tip := foot + Vector2(dir * shove, 0)
				d.draw_line(foot, tip, COL_CRACK, 3.0)
				d.draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 8.0, 0),
					tip + Vector2(0, -6.0), tip + Vector2(0, 6.0)]), COL_CRACK)
		if bool(_state["solved"]):
			# The wall section, resting on the crown. It holds.
			var crown_y := _ring_point(0.5, RING_T).y
			d.draw_rect(Rect2(cx - HALF_GAP - PIER_W, crown_y - 44.0,
				2.0 * (HALF_GAP + PIER_W), 40.0), Color(0.5, 0.52, 0.5))
			d.draw_rect(Rect2(cx - HALF_GAP - PIER_W, crown_y - 44.0,
				2.0 * (HALF_GAP + PIER_W), 40.0), Color(0.4, 0.9, 0.4), false, 2.0)

	# Abutment slots flank the piers from beat 2 on.
	if beat >= 2:
		var ab: Dictionary = _state["abutments"]
		for side: String in ["left", "right"]:
			var r := _abutment_rect(side)
			if bool(ab[side]):
				d.draw_rect(r, Color(0.36, 0.35, 0.34))
				d.draw_rect(r, Color.BLACK, false, 1.5)
			else:
				d.draw_rect(r, COL_GHOST, false, 2.0)
