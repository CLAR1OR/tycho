extends EmberHud
class_name TechChart
## The research constellation (R1 — Star chart, human-picked 2026-07-08 via
## claude.ai/design). Draws the tech tree as stars + prereq edges in `_draw` and turns a
## click near a star into a select callback. Pure state → the state grammar lives in
## TechChartCore; this node owns only pixels + hit-testing. The header, detail dock, and
## solve flow live in the panel (src/learning/tech_panel.gd). Non-interactive chrome
## (title/subtitle/carry/turn-in/dock) sits on top of this Control as siblings; only stars
## are clickable.
##
## MIGRATED TO EMBER 2026-08-14 (Tier C). The star chart was always the closest Slate
## screen to Ember — panel-less, gold-for-state, drawn on a dark field — so the migration
## is mostly a palette swap plus two deletions: the bottom **hint chip** is gone (the
## no-on-screen-instructions directive), taking the last bordered box on the screen with
## it, and `_centered` gave way to the shared `_text_centred`. The star geometry, the
## states and the Age-II fade are untouched.
##
## HUMAN: everything under "Style" is a PLACEHOLDER — dial like FEEL numbers (they carry
## no combat feel, so no `# FEEL:` tag). The shared palette + fonts live in EmberHud.

# =====================================================================================
# Style — placeholders. (Palette + fonts are shared — see EmberHud.)
# =====================================================================================
const R_MAIN := 8.0          # done / ready / active / available core radius
const R_LOCKED := 4.5        # a dim locked dot
const R_UNKNOWN := 2.5       # the Age-II tease dots
const GLOW_R := 16.0         # soft glow behind gold/cyan stars
const GLOW_ALPHA := 0.16
const RING_W := 2.0          # star outline width
const ARC_W := 2.5           # active-node progress arc
const ARC_R := 15.0          # progress-arc radius
const SEL_SEGMENTS := 22     # dashed selection ring
const SEL_R := 26.0
const HIT_R := 42.0          # click hit radius around a star centre
const NAME_DY := 20.0        # name baseline below the core
const META_DY := 34.0        # meta baseline below the core
const DUST_R := 1.0
const DUST_ALPHA := 0.12
const FADE_W := 270.0        # right-edge Age-II darkening
const FADE_STEPS := 40
const FADE_ALPHA := 0.9
const FS_NAME := 13          # star name (display)
const FS_META := 10          # star meta (num)
const FS_AGE := 11           # the Age-II caps label (display)
const COL_TEASE := Color(44.0/255, 42.0/255, 53.0/255)            # #2c2a35 unnamed dots
const COL_EDGE_DIM := Color(44.0/255, 42.0/255, 53.0/255)         # #2c2a35 dashed
const COL_LOCKED_CORE := Color(44.0/255, 42.0/255, 53.0/255)      # #2c2a35
const COL_LOCKED_NAME := Color(87.0/255, 83.0/255, 106.0/255)     # #57536a
const COL_ACTIVE_NAME := Color(240.0/255, 238.0/255, 246.0/255)   # #f0eef6 bright
const COL_AGE_LABEL := Color(87.0/255, 83.0/255, 106.0/255)       # #57536a
const AGE_LABEL := "AGE II — THE SKY GOES DEEPER"
const QUIZ_LOCK_META := "ask again after a run"  # the only red on the screen

## Deterministic starfield dust (normalized positions) — a fixed const array so it never
## shuffles per frame/open.
const DUST: Array[Vector2] = [
	Vector2(0.14, 0.22), Vector2(0.31, 0.66), Vector2(0.52, 0.14), Vector2(0.08, 0.48),
	Vector2(0.44, 0.82), Vector2(0.23, 0.36), Vector2(0.60, 0.52), Vector2(0.37, 0.28),
]
## Unnamed Age-II tease stars (normalized), toward the right edge behind the fade.
const TEASE: Array[Vector2] = [
	Vector2(0.617, 0.25), Vector2(0.641, 0.50), Vector2(0.594, 0.78),
]

var defs: Dictionary = {}
var on_select: Callable = Callable()

var _selected: String = ""


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	# EmberHud defaults to MOUSE_FILTER_IGNORE; the chart hit-tests its stars.
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(defs_in: Dictionary, on_select_cb: Callable) -> void:
	defs = defs_in
	on_select = on_select_cb
	queue_redraw()


func set_selected(id: String) -> void:
	_selected = id
	queue_redraw()


func refresh() -> void:
	queue_redraw()


# --- Input ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = (event as InputEventMouseButton).position
	var tech: Dictionary = SaveManager.state["tech"]
	var best := ""
	var best_d := HIT_R
	for id: String in defs:
		# Only the researchable stars respond — selecting sets the ACTIVE node (as the old
		# list did, offering only available nodes). Locked / researched stars are inert.
		var st := TechChartCore.node_state(defs[id], tech, id)
		if st == &"locked" or st == &"researched":
			continue
		var d := pos.distance_to(_px(id))
		if d < best_d:
			best_d = d
			best = id
	if not best.is_empty() and on_select.is_valid():
		on_select.call(best)


# --- Draw ----------------------------------------------------------------------------

func _px(id: String) -> Vector2:
	return TechChartCore.chart_pos(defs[id], id) * size


func _draw() -> void:
	if defs.is_empty() or size.x < 1.0:
		return
	var tech: Dictionary = SaveManager.state["tech"]
	for d: Vector2 in DUST:
		draw_circle(d * size, DUST_R, Color(COL_INK, DUST_ALPHA))
	for t: Vector2 in TEASE:
		draw_circle(t * size, R_UNKNOWN, COL_TEASE)
	_draw_fade()
	# Edges under the stars.
	for id: String in defs:
		var dep_state := TechChartCore.node_state(defs[id], tech, id)
		for req: String in defs[id].get("prereqs", []):
			if not defs.has(req):
				continue
			var req_state := TechChartCore.node_state(defs[req], tech, req)
			_draw_edge(_px(req), _px(id), TechChartCore.edge_kind(req_state, dep_state))
	# Stars.
	for id: String in defs:
		_draw_star(id, TechChartCore.node_state(defs[id], tech, id), tech)
	_draw_age_label()


func _draw_fade() -> void:
	# The right-edge Age-II darkening: transparent → frame bg over FADE_W, drawn as strips.
	var x0 := size.x - FADE_W
	var strip := FADE_W / float(FADE_STEPS)
	for i in FADE_STEPS:
		var a := FADE_ALPHA * (float(i) / float(FADE_STEPS - 1))
		draw_rect(Rect2(x0 + strip * i, 0.0, strip + 1.0, size.y),
			Color(COL_SCRIM, a))


func _draw_edge(a: Vector2, b: Vector2, kind: StringName) -> void:
	match kind:
		&"lit":
			draw_line(a, b, Color(COL_ACCENT, 0.55), 1.5)
		&"open":
			draw_line(a, b, COL_RING, 1.2)
		_:
			draw_dashed_line(a, b, COL_EDGE_DIM, 1.2, 5.0)


func _draw_star(id: String, state: StringName, tech: Dictionary) -> void:
	var c := _px(id)
	var def: Dictionary = defs[id]
	if id == _selected:
		_dashed_ring(c, SEL_R, Color(COL_ACCENT, 0.5))
	var name_col := COL_INK
	var meta := ""
	var meta_col := COL_INK_DIM
	# A star's core is punched out of the field, so an unfilled one needs a ground to sit
	# on: COL_SCRIM is the same ground the panel's backdrop paints, which is what makes a
	# hollow star read as a hole rather than a dark disc.
	match state:
		&"researched":
			draw_circle(c, GLOW_R, Color(COL_ACCENT, GLOW_ALPHA))
			draw_circle(c, R_MAIN, COL_ACCENT)
			name_col = COL_ACCENT
			meta = "✓ researched" + ("  ·  🧠" if bool(def.get("thinking_tool", false)) else "")
		&"ready":
			draw_circle(c, GLOW_R, Color(COL_ACCENT, GLOW_ALPHA))
			draw_circle(c, R_MAIN, COL_SCRIM)
			_ring(c, R_MAIN, RING_W, COL_ACCENT)
			name_col = COL_ACCENT
			if TechCore.is_quiz_locked(tech, id) and _is_quiz(def):
				meta = QUIZ_LOCK_META
				meta_col = COL_DANGER  # the one red on the screen
			else:
				meta = "READY — read & solve"
				meta_col = COL_ACCENT
		&"active":
			draw_circle(c, GLOW_R, Color(COL_KNOWLEDGE, GLOW_ALPHA))
			draw_circle(c, R_MAIN, COL_SCRIM)
			_ring(c, R_MAIN, RING_W, COL_KNOWLEDGE)
			var cost := float(def.get("cost_knowledge", 0.0))
			var prog := TechCore.progress(tech, id)
			var frac := clampf(prog / cost, 0.0, 1.0) if cost > 0.0 else 0.0
			if frac > 0.0:
				_arc_sweep(c, ARC_R, ARC_W, frac, COL_KNOWLEDGE)
			name_col = COL_ACTIVE_NAME
			meta = "%d/%d · Sophia's focus" % [int(prog), int(cost)]
			meta_col = COL_KNOWLEDGE
		&"available":
			draw_circle(c, R_MAIN, COL_SCRIM)
			_ring(c, R_MAIN, RING_W, COL_RING)
			meta = "%d knowledge" % int(def.get("cost_knowledge", 0.0))
		_:  # locked
			draw_circle(c, R_LOCKED, COL_LOCKED_CORE)
			_ring(c, R_LOCKED, 1.0, COL_RING)
			name_col = COL_LOCKED_NAME
			meta_col = COL_LOCKED_NAME
			meta = "needs %s" % _first_unmet_prereq_name(def, tech)
	_text_centred(c.x, c.y + NAME_DY, str(def["name"]), name_col, FS_NAME, _font_display)
	if not meta.is_empty():
		_text_centred(c.x, c.y + META_DY, meta, meta_col, FS_META, _font_ui)


func _is_quiz(def: Dictionary) -> bool:
	return str((def.get("puzzle", {}) as Dictionary).get("kind", "quiz")) == "quiz"


func _first_unmet_prereq_name(def: Dictionary, tech: Dictionary) -> String:
	var researched: Array = tech.get("researched", [])
	for req: String in def.get("prereqs", []):
		if req not in researched:
			return str(defs[req]["name"]) if defs.has(req) else req
	return "?"


func _dashed_ring(c: Vector2, r: float, col: Color) -> void:
	var step := TAU / float(SEL_SEGMENTS)
	for i in SEL_SEGMENTS:
		if i % 2 == 0:
			var a := i * step
			draw_arc(c, r, a, a + step * 0.55, 4, col, 1.0)


func _draw_age_label() -> void:
	_text_centred(size.x - FADE_W * 0.5, size.y - 70.0, AGE_LABEL, COL_AGE_LABEL,
		FS_AGE, _font_display)
