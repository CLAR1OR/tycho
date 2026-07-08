extends Control
class_name ForgeAnvil
## Mara's Forge, centre stage — "The anvil" (F2, human-picked 2026-07-08 via claude.ai/design,
## with the "no stat bars" amendment). Draws the ember glow, the three weapon tabs (left
## column), the anvil, the SELECTED weapon lying large on it, its name bar, and the top-right
## Resonance-Ore readout in `_draw`, and turns hover/click on a tab into a redraw / select
## callback. Pure state → the weapon geometry lives in WeaponSilhouette; this node owns only
## pixels + hit-testing. The header (title/subtitle), the bottom strip, and Close sit on top
## as panel siblings (ForgePanel).
##
## HUMAN: everything under "Style" is a PLACEHOLDER — dial like FEEL numbers (no combat feel,
## so no `# FEEL:` tag). The anvil / weapon / tab geometry, the ember glow, the ore glyph, and
## the name-bar meta-line format are all placeholder. Shared palette + fonts live in SlateHud.

# =====================================================================================
# Style — placeholders. (Palette + fonts are shared — see SlateHud.)
# =====================================================================================
# The ember glow — the ONE warm note on the screen (a soft warm radial around the anvil).
const COL_EMBER := Color(150.0/255, 75.0/255, 25.0/255)   # warm forge orange
const EMBER_CENTER := Vector2(0.5, 0.66)                  # normalized to the control size
const EMBER_R := 300.0                                    # outer radius (px)
const EMBER_ALPHA := 0.16                                 # peak alpha at the core
const EMBER_LAYERS := 8
# The anvil silhouette (placeholder primitives lifted from the mock's SVG).
const COL_ANVIL_FILL := Color(32.0/255, 30.0/255, 39.0/255)     # #201e27
const COL_ANVIL_STROKE := Color(52.0/255, 50.0/255, 63.0/255)   # #34323f
const ANVIL_CENTER := Vector2(0.5, 0.635)
const ANVIL_LINE_W := 2.5
# The weapon lying on the anvil (large) + its drop shadow.
const WEAPON_CENTER := Vector2(0.5, 0.50)
const WEAPON_ANGLE := -0.052                              # ~-3°, "slightly rotated"
const WEAPON_LINE_W := 2.0
const WEAPON_SHADOW := Color(0, 0, 0, 0.5)
const WEAPON_SHADOW_OFF := Vector2(0, 12)
# Tabs (left column) — normalized rects.
const TAB_ORDER: Array[String] = ["sword", "daggers", "bow"]
const TAB_X := 0.03125          # 40/1280
const TAB_W := 0.1172           # 150/1280
const TAB_H := 0.1194           # 86/720
const TAB_TOPS: Array[float] = [0.1806, 0.3278, 0.475]   # 130 / 236 / 342
const TAB_LINE_W := 2.0
const TAB_RADIUS := 10
const TAB_SIL_SCALE := 0.22
const FS_TAB := 10              # tab caps label (num)
# Name bar (over the anvil).
const NAME_TITLE_Y := 0.185     # 132/720 baseline-ish top
const NAME_META_Y := 0.235      # 168/720
const FS_NAME := 30             # weapon name (display)
const FS_META := 11             # meta line (num, caps)
# Ore readout (top-right — bare glyph + big number + dim label, NO box; mirrors the Dust one).
const FS_ORE := 30              # the big ore number (num)
const FS_ORE_LABEL := 11        # "resonance ore" (num, dim)
const ORE_SUBTITLE := "resonance ore"

var defs: Dictionary = {}
var on_select: Callable = Callable()

var _tab_ids: Array[String] = []
var _selected: String = ""
var _hovered: String = ""
var _font_display: FontVariation
var _font_num: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_display = SlateHud._with_fallback(SlateHud.FONT_DISPLAY_FILE)
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)
	resized.connect(queue_redraw)


func setup(defs_in: Dictionary, on_select_cb: Callable) -> void:
	defs = defs_in
	on_select = on_select_cb
	# Tab order: the known three first, then any future weapon that ships in data.
	_tab_ids = []
	for id in TAB_ORDER:
		if defs.has(id):
			_tab_ids.append(id)
	for id: String in defs:
		if not _tab_ids.has(id):
			_tab_ids.append(id)
	queue_redraw()


func set_selected(id: String) -> void:
	_selected = id
	queue_redraw()


func refresh() -> void:
	queue_redraw()


# --- Input ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _tab_at((event as InputEventMouseMotion).position)
		if hit != _hovered:
			_hovered = hit
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id := _tab_at((event as InputEventMouseButton).position)
		if not id.is_empty() and on_select.is_valid():
			on_select.call(id)


func _tab_at(pos: Vector2) -> String:
	for i in _tab_ids.size():
		if _tab_rect(i).has_point(pos):
			return _tab_ids[i]
	return ""


func _tab_rect(i: int) -> Rect2:
	var top: float = TAB_TOPS[i] if i < TAB_TOPS.size() else TAB_TOPS[TAB_TOPS.size() - 1] \
		+ (i - TAB_TOPS.size() + 1) * TAB_H * 1.2
	return Rect2(TAB_X * size.x, top * size.y, TAB_W * size.x, TAB_H * size.y)


# --- Draw ----------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_draw_ember()
	_draw_anvil()
	_draw_weapon()
	_draw_name_bar()
	for i in _tab_ids.size():
		_draw_tab(i)
	_draw_ore()


func _draw_ember() -> void:
	var c := EMBER_CENTER * size
	for i in EMBER_LAYERS:
		var t := float(i) / float(EMBER_LAYERS)
		draw_circle(c, EMBER_R * (1.0 - t * 0.85), Color(COL_EMBER, EMBER_ALPHA * (1.0 - t)))


func _draw_anvil() -> void:
	var c := ANVIL_CENTER * size
	# Face + horn (top), waist (middle), base (bottom) — placeholder primitives.
	_anvil_poly([Vector2(-170, -55), Vector2(130, -55), Vector2(170, -25), Vector2(90, -17),
		Vector2(90, 13), Vector2(-90, 13), Vector2(-90, -17), Vector2(-150, -23),
		Vector2(-195, -40)], c)
	_anvil_poly([Vector2(-70, 13), Vector2(70, 13), Vector2(70, 47), Vector2(-70, 47)], c)
	_anvil_poly([Vector2(-100, 47), Vector2(100, 47), Vector2(120, 83), Vector2(-120, 83)], c)


func _anvil_poly(local: Array, c: Vector2) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in local:
		pts.append(c + p)
	draw_colored_polygon(pts, COL_ANVIL_FILL)
	pts.append(pts[0])
	draw_polyline(pts, COL_ANVIL_STROKE, ANVIL_LINE_W, true)


func _draw_weapon() -> void:
	if _selected.is_empty():
		return
	var c := WEAPON_CENTER * size
	# Drop shadow, then the weapon in metal colours.
	WeaponSilhouette.paint(self, _selected, c + WEAPON_SHADOW_OFF, 1.0,
		WEAPON_SHADOW, WEAPON_SHADOW, WEAPON_LINE_W, _font_display, FS_NAME, WEAPON_ANGLE)
	WeaponSilhouette.paint(self, _selected, c, 1.0,
		WeaponSilhouette.COL_METAL_FILL, WeaponSilhouette.COL_METAL_STROKE, WEAPON_LINE_W,
		_font_display, FS_NAME, WEAPON_ANGLE)


func _draw_name_bar() -> void:
	if _selected.is_empty():
		return
	var def: Dictionary = defs.get(_selected, {})
	var wname := str(def.get("name", _selected.capitalize()))
	var equipped := str(SaveManager.state["combat"].get("current_weapon", "sword")) == _selected
	var level := WeaponCore.flat_level(SaveManager.state["combat"], _selected)
	var pct := ForgePanelCore.damage_bonus_pct(def, level)
	# Title (Cinzel, centred).
	var tw := _font_display.get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_NAME).x
	var ty := NAME_TITLE_Y * size.y + _font_display.get_ascent(FS_NAME)
	draw_string(_font_display, Vector2((size.x - tw) * 0.5, ty), wname,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_NAME, SlateHud.COL_TEXT)
	# Meta line (mono caps): KIND · [EQUIPPED ·] FLAT Ln · +N% DAMAGE. EQUIPPED gold.
	var kind := str(def.get("kind", "melee")).to_upper()
	var lead := "%s · " % kind
	var eq_txt := "EQUIPPED · " if equipped else ""
	var tail := "FLAT L%d · +%d%% DAMAGE" % [level, int(round(pct))]
	var my := NAME_META_Y * size.y + _font_num.get_ascent(FS_META)
	var full := lead + eq_txt + tail
	var mw := _font_num.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_META).x
	var mx := (size.x - mw) * 0.5
	mx = _seg(lead, mx, my, SlateHud.COL_KEY_TEXT)
	if not eq_txt.is_empty():
		mx = _seg(eq_txt, mx, my, SlateHud.COL_READY)
	_seg(tail, mx, my, SlateHud.COL_KEY_TEXT)


func _seg(s: String, x: float, y: float, col: Color) -> float:
	draw_string(_font_num, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_META, col)
	return x + _font_num.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_META).x


func _draw_tab(i: int) -> void:
	var id := _tab_ids[i]
	var rect := _tab_rect(i)
	var selected := id == _selected
	var hovered := id == _hovered
	# Box.
	var border := SlateHud.COL_CHIP_BORDER
	if selected:
		border = SlateHud.COL_READY
	elif hovered:
		border = SlateHud.COL_ORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SlateHud.COL_CHIP_BG
	sb.border_color = border
	sb.set_border_width_all(int(TAB_LINE_W))
	sb.set_corner_radius_all(TAB_RADIUS)
	draw_style_box(sb, rect)
	# Silhouette (dim, brightens on hover/select via a modulate on the metal fill).
	var alpha := 1.0 if (selected or hovered) else 0.75
	var fill := Color(WeaponSilhouette.COL_METAL_FILL, alpha)
	var stroke := Color(WeaponSilhouette.COL_METAL_STROKE, alpha)
	var sil_c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.42)
	WeaponSilhouette.paint(self, id, sil_c, TAB_SIL_SCALE, fill, stroke, TAB_LINE_W,
		_font_num, FS_TAB)
	# Label (mono caps): NAME, or NAME · EQUIPPED when equipped (gold when selected).
	var def: Dictionary = defs.get(id, {})
	var wname := str(def.get("name", id)).to_upper()
	var equipped := str(SaveManager.state["combat"].get("current_weapon", "sword")) == id
	var label := wname + " · EQUIPPED" if equipped else wname
	var col := SlateHud.COL_READY if selected else SlateHud.COL_KEY_TEXT
	var lw := _font_num.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TAB).x
	var ly := rect.position.y + rect.size.y - 8.0
	draw_string(_font_num, Vector2(rect.get_center().x - lw * 0.5, ly), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TAB, col)


func _draw_ore() -> void:
	var n := int(Ledger.get_amount("resonance-ore"))
	var num := str(n)
	var right := size.x - SlateHud.MARGIN - 6.0
	var top := SlateHud.MARGIN + 6.0
	# Big number, right-aligned.
	var nw := _font_num.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ORE).x
	var ny := top + _font_num.get_ascent(FS_ORE)
	draw_string(_font_num, Vector2(right - nw, ny), num, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FS_ORE, SlateHud.COL_ORE)
	# Placeholder ore glyph — a small faceted crystal outline to the left of the number.
	_ore_crystal(Vector2(right - nw - 20.0, top + FS_ORE * 0.5), 11.0)
	# Small dim label under the number.
	var lw := _font_num.get_string_size(ORE_SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ORE_LABEL).x
	draw_string(_font_num, Vector2(right - lw, ny + FS_ORE_LABEL + 4.0), ORE_SUBTITLE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ORE_LABEL, SlateHud.COL_KEY_TEXT)


func _ore_crystal(p: Vector2, s: float) -> void:
	# A faceted gem: a hexagon outline + two inner facet lines, in the ore violet.
	var hex := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s * 0.85, -s * 0.4), p + Vector2(s * 0.85, s * 0.4),
		p + Vector2(0, s), p + Vector2(-s * 0.85, s * 0.4), p + Vector2(-s * 0.85, -s * 0.4)])
	draw_colored_polygon(hex, Color(SlateHud.COL_ORE, 0.18))
	hex.append(hex[0])
	draw_polyline(hex, SlateHud.COL_ORE, 1.6, true)
	draw_line(p + Vector2(-s * 0.85, -s * 0.4), p + Vector2(s * 0.85, -s * 0.4),
		Color(SlateHud.COL_ORE, 0.7), 1.2, true)
	draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color(SlateHud.COL_ORE, 0.7), 1.2, true)
