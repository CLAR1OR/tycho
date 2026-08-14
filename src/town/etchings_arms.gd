extends EmberHud
class_name EtchingsArms
## Tycho's two arms, palms up, with the four etched sites (E1 — "The arms", human-picked
## 2026-07-08 via claude.ai/design). Draws the stylized arm silhouettes + the four marks +
## the top-right Resonance Dust readout in `_draw`, and turns hover/click near a mark into a
## redraw / select callback. Pure state → the display rules live in EtchingsArmsCore and the
## sigil geometry in SigilIcon; this node owns only pixels + hit-testing. The header
## (title/subtitle), the skill menu, and Close sit on top as panel siblings.
##
## MIGRATED TO EMBER 2026-08-14 (Tier B). This node extends `EmberHud` and now draws the
## SCRIM itself (EtchingsPanel's backdrop ColorRect is gone). Two Slate leftovers went: the
## key badge was a bordered chip and is now bare tracked caps with a shadow — the badge had
## a box only because Slate had no other way to keep small text legible over the arms — and
## the hand-rolled mote cluster + big number became the shared `_resource_readout`, so Dust
## here wears exactly the mark it wears in the run HUD and the town strip. The arms, the four
## site positions and the hover/select glow are UNTOUCHED (the human's E1 pick).
##
## HUMAN: everything under "Style" is a PLACEHOLDER — dial like FEEL numbers (no combat feel,
## so no `# FEEL:` tag). The arm silhouettes are placeholder primitives for the painterly
## pass. The shared palette + fonts live in EmberHud.

# =====================================================================================
# Style — placeholders. (Palette + fonts are shared — see EmberHud.)
# =====================================================================================
const HIT_R := 44.0             # click / hover radius around a site centre
const SIGIL_W := 2.4            # sigil stroke width
const SITE_HALO_R := 30.0       # hover/select glow radius
const SEL_RING_R := 30.0        # dashed selection ring radius
const SEL_SEGMENTS := 22
const BADGE_DY := 40.0          # key badge baseline below a site centre
const FS_BADGE := 11            # key badge (ui med, tracked caps)
const BADGE_TRACKING := 1.2
const RES_Y := 40.0             # the shared Dust readout's row, level with the title band
# Arm silhouette (placeholder primitives).
const ARM_FORE_HALF_ELBOW := 30.0
const ARM_FORE_HALF_WRIST := 20.0
const ARM_ELBOW_DIST := 66.0    # elbow below the forearm site, along the arm axis
const ARM_PALM_R := 26.0
const ARM_FINGER_W := 10.0
const COL_ARM_FILL := Color(26.0/255, 25.0/255, 34.0/255)      # #1a1922
const COL_ARM_PALM := Color(29.0/255, 28.0/255, 37.0/255)      # #1d1c25
const COL_ARM_STROKE := Color(52.0/255, 50.0/255, 63.0/255)    # #34323f

## The four sites, in draw order. Normalized to the control size (from the mock's 1280x720
## frame). Left arm carries Q (palm) + SPC/dash (forearm); right arm RMB (palm) + R (forearm).
const SITES: Array[Dictionary] = [
	{"slot": "q", "key": "Q", "pos": Vector2(0.2625, 0.400), "dash": false},
	{"slot": "spc", "key": "SPC", "pos": Vector2(0.2383, 0.692), "dash": true},
	{"slot": "rmb", "key": "RMB", "pos": Vector2(0.4563, 0.400), "dash": false},
	{"slot": "r", "key": "R", "pos": Vector2(0.4800, 0.692), "dash": false},
]

var defs: Dictionary = {}
var starters: Dictionary = {}
var on_select: Callable = Callable()

var _selected: String = ""
var _hovered: String = ""


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	# EmberHud defaults to MOUSE_FILTER_IGNORE; this stage hit-tests its four sites.
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(defs_in: Dictionary, starters_in: Dictionary, on_select_cb: Callable) -> void:
	defs = defs_in
	starters = starters_in
	on_select = on_select_cb
	queue_redraw()


func set_selected(slot: String) -> void:
	_selected = slot
	queue_redraw()


func refresh() -> void:
	queue_redraw()


# --- Input ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _site_at((event as InputEventMouseMotion).position)
		if hit != _hovered:
			_hovered = hit
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var slot := _site_at((event as InputEventMouseButton).position)
		if not slot.is_empty() and on_select.is_valid():
			on_select.call(slot)


func _site_at(pos: Vector2) -> String:
	var best := ""
	var best_d := HIT_R
	for site: Dictionary in SITES:
		var d := pos.distance_to(Vector2(site["pos"]) * size)
		if d < best_d:
			best_d = d
			best = str(site["slot"])
	return best


# --- Draw ----------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim()  # the ground every Ember menu sits on — EtchingsPanel no longer carries its own
	# The two arms (palm site + forearm site define each arm's axis).
	_draw_arm(_pos("rmb"), _pos("r"), 1.0)
	_draw_arm(_pos("q"), _pos("spc"), -1.0)
	# The four marks on top.
	for site: Dictionary in SITES:
		_draw_site(site)
	_resource_readout(size.x - EmberMenuCore.PAD_PX, RES_Y, ["resonance-dust"])


func _pos(slot: String) -> Vector2:
	for site: Dictionary in SITES:
		if str(site["slot"]) == slot:
			return Vector2(site["pos"]) * size
	return Vector2.ZERO


## A placeholder arm silhouette: a tapered forearm trapezoid from the elbow up to the wrist,
## a palm disc, four fingers, and a thumb. `palm`/`fore` are the two site centres; `sign`
## flips the thumb outward per side.
func _draw_arm(palm: Vector2, fore: Vector2, flip: float) -> void:
	var axis := (palm - fore).normalized()            # up the arm (toward fingers)
	if axis == Vector2.ZERO:
		axis = Vector2.UP
	var perp := Vector2(-axis.y, axis.x)
	var elbow := fore - axis * ARM_ELBOW_DIST
	var top := palm - axis * (ARM_PALM_R * 0.7)        # wrist, just below the palm disc
	var fore_poly := PackedVector2Array([
		elbow + perp * ARM_FORE_HALF_ELBOW, top + perp * ARM_FORE_HALF_WRIST,
		top - perp * ARM_FORE_HALF_WRIST, elbow - perp * ARM_FORE_HALF_ELBOW])
	draw_colored_polygon(fore_poly, COL_ARM_FILL)
	draw_polyline(fore_poly + PackedVector2Array([fore_poly[0]]), COL_ARM_STROKE, 2.0, true)
	# Fingers, fanned above the palm.
	var spread: Array[float] = [-16.0, -5.0, 6.0, 16.0]
	var length: Array[float] = [70.0, 84.0, 80.0, 62.0]
	for i in 4:
		var base: Vector2 = palm + perp * spread[i] + axis * (ARM_PALM_R * 0.4)
		var tip: Vector2 = base + axis * length[i]
		draw_line(base, tip, COL_ARM_PALM, ARM_FINGER_W, true)
		draw_circle(tip, ARM_FINGER_W * 0.5, COL_ARM_PALM)
	# Thumb, angled outward.
	var thumb_base := palm + perp * (ARM_PALM_R * 0.85 * flip)
	var thumb_tip := thumb_base + (perp * flip + axis).normalized() * 46.0
	draw_line(thumb_base, thumb_tip, COL_ARM_PALM, ARM_FINGER_W, true)
	draw_circle(thumb_tip, ARM_FINGER_W * 0.5, COL_ARM_PALM)
	# Palm disc on top of the finger roots + wrist.
	draw_circle(palm, ARM_PALM_R, COL_ARM_PALM)
	draw_arc(palm, ARM_PALM_R, 0.0, TAU, 32, COL_ARM_STROKE, 2.0, true)


func _draw_site(site: Dictionary) -> void:
	var slot := str(site["slot"])
	var is_dash := bool(site["dash"])
	var center := Vector2(site["pos"]) * size
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var selected := slot == _selected
	var hovered := slot == _hovered
	# Which ability + level this site shows.
	var ability_id := "dash"
	var level := 1                                     # the dash is always awake
	if not is_dash:
		ability_id = EtchingsArmsCore.displayed_ability(slot, etchings, starters)
		level = EtchingsCore.level_of(etchings, ability_id)
	var awake := is_dash or level >= 1
	# Colour + alpha by state. Dust cyan is the mark's own colour; gold means SELECTED, and
	# nothing else on this screen is allowed to be gold.
	var col := COL_DUST
	if selected:
		col = COL_ACCENT
	elif hovered:
		col = Color(COL_DUST, 1.0)
	elif awake:
		col = Color(COL_DUST, 0.62)
	else:
		col = Color(COL_DUST, 0.22)
	# Glow / ring behind the mark. The dashed selection ring is the round cousin of the
	# `_row_box` dashed frame — one dashed gold outline means "this is the current thing".
	if selected:
		_glow(center, SITE_HALO_R, COL_ACCENT)
		_dashed_ring(center, SEL_RING_R, Color(COL_ACCENT, 0.55))
	elif hovered:
		_glow(center, SITE_HALO_R, COL_DUST)
	# The sigil.
	SigilIcon.paint(self, ability_id, center, 1.0, col, SIGIL_W, awake, _font_ui_med, 14)
	# Key badge on hover / select.
	if hovered or selected:
		var disp_name := "Dash" if is_dash else str((defs.get(ability_id, {}) as Dictionary).get("name", ability_id))
		_badge(center + Vector2(0, BADGE_DY), "%s · %s" % [str(site["key"]), disp_name.to_upper()],
			COL_ACCENT if selected else COL_INK_DIM)


# --- draw helpers --------------------------------------------------------------------

func _glow(center: Vector2, r: float, base: Color) -> void:
	for i in 4:
		var t := float(i) / 4.0
		draw_circle(center, r * (1.0 - t * 0.6), Color(base, 0.10 * (1.0 - t)))


func _dashed_ring(c: Vector2, r: float, col: Color) -> void:
	var step := TAU / float(SEL_SEGMENTS)
	for i in SEL_SEGMENTS:
		if i % 2 == 0:
			var a := i * step
			draw_arc(c, r, a, a + step * 0.55, 4, col, 1.0)


## The hovered site's name, under the mark. No box: Slate gave this a bordered chip because
## a chip was the only way it knew to keep 10px text readable over the arms; Ember uses
## tracked caps and the shadow, which is what every other floating label in the game does.
func _badge(center: Vector2, text: String, text_col: Color) -> void:
	var w := _text_tracked_w(text, FS_BADGE, _font_ui_med, BADGE_TRACKING)
	var pos := Vector2(center.x - w * 0.5, center.y)
	_text_tracked(pos + Vector2(1.0, 1.0), text, Color(COL_SHADOW, COL_SHADOW.a * text_col.a),
		FS_BADGE, _font_ui_med, BADGE_TRACKING)
	_text_tracked(pos, text, text_col, FS_BADGE, _font_ui_med, BADGE_TRACKING)
