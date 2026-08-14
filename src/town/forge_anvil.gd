extends EmberHud
class_name ForgeAnvil
## Mara's Forge, centre stage — "The anvil" (F2, human-picked 2026-07-08 via claude.ai/design,
## with the "no stat bars" amendment). Draws the ember glow, the three weapon tabs (left
## column), the anvil, the SELECTED weapon lying large on it, its name bar, and the top-right
## Resonance-Ore readout in `_draw`, and turns hover/click on a tab into a redraw / select
## callback. Pure state → the weapon geometry lives in WeaponSilhouette; this node owns only
## pixels + hit-testing. The header (title/subtitle), the bottom strip, and Close sit on top
## as panel siblings (ForgePanel).
##
## MIGRATED TO EMBER 2026-08-14 (Tier B). What changed: this node now extends `EmberHud`, so
## it draws the SCRIM itself (ForgePanel's backdrop ColorRect is gone — one scrim dial for
## every Ember screen); the three tabs became `_row_box` list rows, the same mark the anchor's
## weapon list uses and the same one every migrated catalogue now wears; and the hand-rolled
## ore crystal + big number gave way to the shared `_resource_readout`. The tab column and the
## readout sit against `EmberMenuCore`'s bands, so the forge's margins agree with every other
## screen. The anvil, the ember glow and the weapon-on-the-anvil staging are UNTOUCHED — that
## picture was the human's F2 pick, and Ember is a language for drawing it, not a different
## composition.
##
## HUMAN: everything under "Style" is a PLACEHOLDER — dial like FEEL numbers (no combat feel,
## so no `# FEEL:` tag). The anvil / weapon / tab geometry, the ember glow, and the name-bar
## meta-line format are all placeholder. Shared palette + fonts live in EmberHud.

# =====================================================================================
# Style — placeholders. (Palette + fonts are shared — see EmberHud.)
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
# Tabs (left column) — the anchor's weapon LIST, drawn with the shared row-box mark. Sized
# in px against EmberMenuCore's content band, so the column starts where every other Ember
# screen's content starts.
const TAB_ORDER: Array[String] = ["sword", "daggers", "bow"]
const TAB_W := 168.0
const TAB_H := 92.0
const TAB_GAP := 14.0
const TAB_TOP_DROP := 34.0      # first tab, below the content band's top
const TAB_LINE_W := 1.6
const TAB_SIL_SCALE := 0.22
const FS_TAB := 11              # tab caps label (ui med, tracked)
const TAB_TRACKING := 1.2
# Name bar (over the anvil).
const NAME_TITLE_Y := 0.185     # 132/720 baseline-ish top
const NAME_META_Y := 0.235      # 168/720
const FS_NAME := 30             # weapon name (display)
const FS_META := 11             # meta line (ui med, tracked caps)
const META_TRACKING := 1.4
# The shared resource readout's row (top-right), level with the title band.
const RES_Y := 40.0

var defs: Dictionary = {}
var on_select: Callable = Callable()

var _tab_ids: Array[String] = []
var _selected: String = ""
var _hovered: String = ""


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	# EmberHud defaults to MOUSE_FILTER_IGNORE (the run HUD is not interactive). This stage
	# hit-tests its tabs, so it takes the mouse — and swallows it from the town behind.
	mouse_filter = Control.MOUSE_FILTER_STOP
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


## Tab `i`'s bounds. Laid down the content band via EmberMenuCore.stack, so the column's
## left edge and first row line up with the list column of every other Ember screen.
func _tab_rect(i: int) -> Rect2:
	var content: Rect2 = EmberMenuCore.catalogue(size)["content"]
	var col := Rect2(content.position.x, content.position.y + TAB_TOP_DROP, TAB_W,
		maxf(0.0, content.size.y - TAB_TOP_DROP))
	return EmberMenuCore.stack(col, maxi(1, i + 1), TAB_H, TAB_GAP)[i]


# --- Draw ----------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim()  # the ground every Ember menu sits on — ForgePanel no longer carries its own
	_draw_ember()
	_draw_anvil()
	_draw_weapon()
	_draw_name_bar()
	for i in _tab_ids.size():
		_draw_tab(i)
	_resource_readout(size.x - EmberMenuCore.PAD_PX, RES_Y, ["resonance-ore"])


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
	# Title (Cinzel, centred over the anvil).
	var cx := size.x * 0.5
	_text_centred(cx, NAME_TITLE_Y * size.y, wname, COL_INK, FS_NAME, _font_display)
	# Meta line (tracked caps): KIND · [EQUIPPED ·] FLAT Ln · +N% DAMAGE. EQUIPPED is the one
	# gold word — Ember spends gold on state, and "this is the weapon you carry" is the only
	# state on the line.
	var kind := str(def.get("kind", "melee")).to_upper()
	var lead := "%s · " % kind
	var eq_txt := "EQUIPPED · " if equipped else ""
	var tail := "FLAT L%d · +%d%% DAMAGE" % [level, int(round(pct))]
	var my := NAME_META_Y * size.y
	var mw := _text_tracked_w(lead + eq_txt + tail, FS_META, _font_ui_med, META_TRACKING)
	var mx := cx - mw * 0.5
	mx += _text_tracked(Vector2(mx, my), lead, COL_INK_DIM, FS_META, _font_ui_med,
		META_TRACKING) + META_TRACKING
	if not eq_txt.is_empty():
		mx += _text_tracked(Vector2(mx, my), eq_txt, COL_ACCENT, FS_META, _font_ui_med,
			META_TRACKING) + META_TRACKING
	_text_tracked(Vector2(mx, my), tail, COL_INK_DIM, FS_META, _font_ui_med, META_TRACKING)


func _draw_tab(i: int) -> void:
	var id := _tab_ids[i]
	var rect := _tab_rect(i)
	var selected := id == _selected
	var hovered := id == _hovered
	# The row box: a barely-there wash inside a hairline, and a dashed GOLD frame on the
	# selected one. Under Slate this was a filled chip with a coloured border, which made
	# three weapons read as three buttons; the row-box mark says "a list of things, one of
	# them is current" — and it is the same mark the build and market lists now wear.
	var state := "idle"
	if selected:
		state = "selected"
	elif hovered:
		state = "hover"
	_row_box(rect, state)
	# Silhouette (dim, brightens on hover/select via a modulate on the metal fill).
	var alpha := 1.0 if (selected or hovered) else 0.75
	var fill := Color(WeaponSilhouette.COL_METAL_FILL, alpha)
	var stroke := Color(WeaponSilhouette.COL_METAL_STROKE, alpha)
	var sil_c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.42)
	WeaponSilhouette.paint(self, id, sil_c, TAB_SIL_SCALE, fill, stroke, TAB_LINE_W,
		_font_ui_med, FS_TAB)
	# Label (tracked caps): NAME, or NAME · EQUIPPED when equipped (gold when selected).
	var def: Dictionary = defs.get(id, {})
	var wname := str(def.get("name", id)).to_upper()
	var equipped := str(SaveManager.state["combat"].get("current_weapon", "sword")) == id
	var label := wname + " · EQUIPPED" if equipped else wname
	var col := COL_ACCENT if selected else COL_INK_DIM
	var lw := _text_tracked_w(label, FS_TAB, _font_ui_med, TAB_TRACKING)
	var ly := rect.position.y + rect.size.y - 14.0
	_text_tracked(Vector2(rect.get_center().x - lw * 0.5, ly), label, col, FS_TAB,
		_font_ui_med, TAB_TRACKING)

