extends SlateHud
class_name TownHud
## The town HUD ("Slate" T1 design — human-picked 2026-07-07 via claude.ai/design, the
## "Town HUD" group: the T1 slate strip + the overnight production toast + a per-resource
## projection under each column). Replaces the old plain DayInfo / FoodStatus / Hint
## Labels AND game.gd's stacked $HUD/Resources readout. Spec: design/ui-hud.md.
##
## Code-built by town.gd onto the town's $HUD CanvasLayer; a screen-filling Control
## (mouse_filter IGNORE, from SlateHud) that draws everything itself in _draw and polls
## the Ledger each frame (town is cheap). Pure string/delta/toast logic lives in
## TownHudCore (src/town/town_hud_core.gd); this node owns only pixels.
##
## Extends SlateHud (src/core/slate_hud.gd) for the SHARED Slate style — palette, the
## three fonts, FS_CHIP/BODY/HINT/SMALL, MARGIN, and the draw plumbing. Dial shared style
## there; the town-specific placeholders below (the three new resource colours, the toast
## timings, the hint copy) are dialled here.
##
## The strip is TWO panels (human decision 2026-07-07): the town economy (resources a
## building can generate — derived from the building defs) and the run pickups (only
## ever brought home from runs), the run panel holding the corner like the in-run strip.
##
## HUMAN: HINT_TEXT, the toast copy/timings, the FS_*/PROJECTION_ALPHA, the three new
## resource colours, and the TOWN/RUN group headers are all PLACEHOLDERS — dial like
## FEEL numbers (design/ui-hud.md).

# =====================================================================================
# Town-specific style — placeholders. (Shared palette + fonts + sizes live in SlateHud.)
# =====================================================================================
# The stone/food/knowledge resource colours were lifted UP to SlateHud (2026-07-08, the
# research star chart reads the knowledge colour off the ONE dial source) — they resolve
# here by inheritance, alongside COL_GOLD/COL_ORE/COL_DUST/COL_SHARDS.
# Resource strip layout
const COL_GAP := 16.0            # gap between columns
const VALUE_LABEL_GAP := 4.0     # gap between a column's value and its dim label
const PROJECTION_ALPHA := 0.55   # the "+n/d" projection below each column
# The town/run group split (human decision 2026-07-07): building-producible resources
# in one panel, run-collected pickups in another, run panel at the corner (mirrors the
# in-run pickup strip's position). Headers are placeholder copy.
const GROUP_GAP := 12.0          # gap between the two panels
const FS_GROUP := 10             # the tiny group headers (display font)
const GROUP_HEADER_ALPHA := 0.65
const GROUP_TOWN_LABEL := "TOWN"
const GROUP_RUN_LABEL := "RUN"
# Toast (overnight production)
const FS_TOAST_HEAD := 11        # the "OVERNIGHT" header (display)
const TOAST_HOLD_S := 4.0
const TOAST_FADE_S := 1.0
# Contextual hint (bottom-center). PLACEHOLDER copy — dial freely.
const HINT_TEXT := "WASD move · E interact · the portal starts a run"

## The strip's seven columns, in order (Ledger ids). Colours via _strip_color.
const STRIP_IDS: Array[String] = [
	"gold", "stone", "food", "knowledge", "knowledge-shards", "resonance-ore", "resonance-dust",
]
## Short dim label beside each column's value.
const STRIP_LABEL := {
	"gold": "gold", "stone": "stone", "food": "food", "knowledge": "know",
	"knowledge-shards": "shards", "resonance-ore": "ore", "resonance-dust": "dust",
}

# =====================================================================================
# State (pushed in by town.gd, or polled/computed)
# =====================================================================================
var _day: int = 1
var _well_fed: bool = false
var _has_ticked: bool = false

var _building_defs: Dictionary = {}
var _deltas: Dictionary = {}   # TownHudCore.day_deltas — recomputed on resource_changed
var _town_ids: Array[String] = []   # STRIP_IDS partitioned by TownHudCore.producible_resources:
var _run_ids: Array[String] = []    # building-producible = town, the rest = run pickups

var _toast_segs: Array = []
var _toast_alpha: float = 0.0
var _toast_hold_t: float = 0.0


func _ready() -> void:
	super._ready()  # SlateHud: anchors + mouse_filter + the three fonts
	add_to_group("town_hud")
	# Process even while paused: a town-entry cutscene can pause the tree before the first
	# idle frame, and a PAUSABLE _process would then never sync `size` off (0,0) (the
	# CanvasLayer-under-_ready quirk). ALWAYS also lets the overnight toast keep fading
	# behind a dialogue. (The town has no player input here, so ALWAYS is harmless.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_building_defs = DataLoader.load_domain("buildings")
	# Partition the strip: town economy (a building can generate it) vs run pickups
	# (only ever brought home). Data-driven — see TownHudCore.producible_resources.
	var producible := TownHudCore.producible_resources(_building_defs)
	for id: String in STRIP_IDS:
		if producible.has(id):
			_town_ids.append(id)
		else:
			_run_ids.append(id)
	# The projections mirror the day tick, which depends on the town's buildings + the
	# food stock — recompute on any Ledger change AND after a build (its resource-spend
	# fires BEFORE the building lands in state, so the spend alone would leave a stale
	# delta). Cheap (the tick just walks buildings); NOT per frame.
	EventBus.resource_changed.connect(func(_id: String, _o: float, _n: float, _r: String) -> void:
		_recompute_deltas())
	EventBus.building_built.connect(func(_id: String, _lvl: int) -> void: _recompute_deltas())
	_recompute_deltas()


# --- Setters / API (town.gd + game.gd push state in) ---------------------------------

## Day number + last-tick Food status. `has_ticked` is false on day 1 (no tick yet) — the
## chip then shows just "Day 1" with no food span.
func configure(day: int, well_fed: bool, has_ticked: bool) -> void:
	_day = day
	_well_fed = well_fed
	_has_ticked = has_ticked
	queue_redraw()


## Fire the overnight production toast from a TownCore.tick(...) result (game.gd passes the
## day tick on the run-end town return). A no-op for an empty tick (e.g. a Forfeit return,
## which ticks no day).
func show_day_toast(tick: Dictionary) -> void:
	if tick.is_empty():
		return
	_toast_segs = TownHudCore.toast_segments(tick)
	_toast_alpha = 1.0
	_toast_hold_t = TOAST_HOLD_S
	queue_redraw()


func _recompute_deltas() -> void:
	var tick := TownCore.tick(
		SaveManager.state["town"], _building_defs, Ledger.get_amount("food"))
	_deltas = TownHudCore.day_deltas(tick)
	queue_redraw()


# --- Smoke/test getters --------------------------------------------------------------

func day_chip() -> String:
	return TownHudCore.day_chip_text(_day, _well_fed, _has_ticked)


func projection(id: String) -> float:
	return float(_deltas.get(id, 0.0))


func toast_visible() -> bool:
	return _toast_alpha > 0.0


func town_group() -> Array:
	return _town_ids.duplicate()


func run_group() -> Array:
	return _run_ids.duplicate()


# --- Process -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_sync_viewport_size()  # SlateHud: the CanvasLayer-under-_ready layout quirk
	if _toast_alpha > 0.0:
		if _toast_hold_t > 0.0:
			_toast_hold_t -= delta
		else:
			_toast_alpha = maxf(0.0, _toast_alpha - delta / TOAST_FADE_S)
	queue_redraw()  # strip values poll the Ledger each frame (town is cheap)


# =====================================================================================
# Draw
# =====================================================================================

func _draw() -> void:
	_draw_day_chip()
	_draw_resource_strip()  # + the per-column projections below it
	_draw_hint()
	_draw_toast()


func _strip_color(id: String) -> Color:
	match id:
		"gold": return COL_GOLD
		"stone": return COL_STONE
		"food": return COL_FOOD
		"knowledge": return COL_KNOWLEDGE
		"knowledge-shards": return COL_SHARDS
		"resonance-ore": return COL_ORE
		"resonance-dust": return COL_DUST
	return COL_TEXT


# --- Day chip (top-left) -------------------------------------------------------------

func _draw_day_chip() -> void:
	var prefix := "Day %d" % _day
	var sep := ""
	var status := ""
	var status_col := COL_TEXT
	if _has_ticked:
		sep = " · "  # dim separator
		if _well_fed:
			status = "Well-Fed +%s%%" % str(int(TownCore.WELL_FED_BONUS * 100))
			status_col = COL_READY  # gold — a good thing
		else:
			status = "Short on food"
			status_col = COL_KEY_TEXT  # dim, NEVER red (red is reserved for player danger)
	var pad := Vector2(10, 5)
	var full := prefix + sep + status
	var w := _text_w(full, FS_CHIP, _font_num) + pad.x * 2.0
	var h := _font_num.get_height(FS_CHIP) + pad.y * 2.0
	var rect := Rect2(MARGIN, MARGIN, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	# Two/three coloured spans on one line: prefix, dim separator, coloured status.
	var x := rect.position.x + pad.x
	x = _span(x, rect.position.y, h, prefix, COL_TEXT)
	if _has_ticked:
		x = _span(x, rect.position.y, h, sep, COL_KEY_TEXT)
		_span(x, rect.position.y, h, status, status_col)


## Draw one left-aligned FS_CHIP span at x; return the x just past it.
func _span(x: float, y: float, h: float, s: String, col: Color) -> float:
	var sw := _text_w(s, FS_CHIP, _font_num)
	_text_in(Rect2(x, y, sw, h), s, col, FS_CHIP, _font_num, HORIZONTAL_ALIGNMENT_LEFT)
	return x + sw


# --- Resource strip (top-right) + projections (below) --------------------------------

func _draw_resource_strip() -> void:
	# Two panels under tiny headers: the town economy (building-producible) left, the
	# run pickups right — the run group holds the corner, mirroring where the in-run
	# pickup strip lives so the same resources sit in the same place in both scenes.
	var head_h := _font_display.get_height(FS_GROUP)
	var y := MARGIN + head_h + 3.0
	var run_left := _draw_group(_run_ids, GROUP_RUN_LABEL, size.x - MARGIN, y)
	_draw_group(_town_ids, GROUP_TOWN_LABEL, run_left - GROUP_GAP, y)


## Draw one resource-group panel with its columns + projections, right edge at right_x,
## panel top at y, and a tiny centred header above it. Returns the panel's left edge.
func _draw_group(ids: Array[String], header: String, right_x: float, y: float) -> float:
	var pad := Vector2(12, 6)
	# Measure every column first (value + dim label), so we can right-anchor the panel.
	var cols: Array = []  # [{id, val, label, val_w, label_w, w}]
	for id: String in ids:
		var val := "%d" % int(Ledger.get_amount(id))
		var label := str(STRIP_LABEL.get(id, id))
		var vw := _text_w(val, FS_BODY, _font_num)
		var lw := _text_w(label, FS_SMALL, _font_num)
		cols.append({
			"id": id, "val": val, "label": label,
			"val_w": vw, "label_w": lw, "w": vw + VALUE_LABEL_GAP + lw,
		})
	var content_w := 0.0
	for c: Dictionary in cols:
		content_w += float(c["w"]) + COL_GAP
	content_w -= COL_GAP
	var w := content_w + pad.x * 2.0
	var h := _font_num.get_height(FS_BODY) + pad.y * 2.0
	var rect := Rect2(right_x - w, y, w, h)
	_panel(rect, COL_SLATE_BG, COL_SLATE_BORDER, 2, 8)
	var head_h := _font_display.get_height(FS_GROUP)
	_text_in(Rect2(rect.position.x, y - head_h - 3.0, w, head_h), header,
		Color(COL_KEY_TEXT, GROUP_HEADER_ALPHA), FS_GROUP, _font_display)
	var x := rect.position.x + pad.x
	for c: Dictionary in cols:
		var id := str(c["id"])
		var vw: float = float(c["val_w"])
		_text_in(Rect2(x, rect.position.y, vw, h), str(c["val"]),
			_strip_color(id), FS_BODY, _font_num, HORIZONTAL_ALIGNMENT_LEFT)
		_text_in(Rect2(x + vw + VALUE_LABEL_GAP, rect.position.y, float(c["label_w"]), h),
			str(c["label"]), COL_KEY_TEXT, FS_SMALL, _font_num, HORIZONTAL_ALIGNMENT_LEFT)
		# Projection under the column (outside the panel), centred on the column width.
		var proj := TownHudCore.projection_text(projection(id))
		if not proj.is_empty():
			var pw := _text_w(proj, FS_SMALL, _font_num)
			var center := x + float(c["w"]) * 0.5
			_text_in(Rect2(center - pw * 0.5, rect.position.y + h + 3.0, pw,
				_font_num.get_height(FS_SMALL)), proj, Color(COL_KEY_TEXT, PROJECTION_ALPHA),
				FS_SMALL, _font_num, HORIZONTAL_ALIGNMENT_LEFT)
		x += float(c["w"]) + COL_GAP
	return rect.position.x


# --- Contextual hint (bottom-center) -------------------------------------------------

func _draw_hint() -> void:
	var pad := Vector2(14, 6)
	var w := _text_w(HINT_TEXT, FS_HINT, _font_body) + pad.x * 2.0
	var h := _font_body.get_height(FS_HINT) + pad.y * 2.0
	var rect := Rect2((size.x - w) * 0.5, size.y - MARGIN - h, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	_text_in(Rect2(rect.position.x + pad.x, rect.position.y, w - pad.x * 2.0, h),
		HINT_TEXT, COL_TEXT, FS_HINT, _font_body, HORIZONTAL_ALIGNMENT_LEFT)


# --- Overnight toast (top-center, fading) --------------------------------------------

func _draw_toast() -> void:
	if _toast_alpha <= 0.0 or _toast_segs.is_empty():
		return
	var a := _toast_alpha
	var pad := Vector2(14, 8)
	var seg_gap := 14.0
	var head := "OVERNIGHT"
	var head_h := _font_display.get_height(FS_TOAST_HEAD)
	var row_h := _font_num.get_height(FS_BODY)
	# Measure the segment row (the "Well-Fed" word rides Garamond a touch larger).
	var segs: Array = []  # [{text, color, font, fs, w}]
	for s: Dictionary in _toast_segs:
		var id := str(s["id"])
		var font := _font_body if id == "fed" else _font_num
		var fs := FS_BODY + 2 if id == "fed" else FS_BODY
		segs.append({
			"text": str(s["text"]), "color": _toast_color(id), "font": font, "fs": fs,
			"w": _text_w(str(s["text"]), fs, font),
		})
	var row_w := 0.0
	for s: Dictionary in segs:
		row_w += float(s["w"]) + seg_gap
	row_w -= seg_gap
	var content_w := maxf(row_w, _text_w(head, FS_TOAST_HEAD, _font_display))
	var w := content_w + pad.x * 2.0
	var h := head_h + 4.0 + row_h + pad.y * 2.0
	var rect := Rect2((size.x - w) * 0.5, MARGIN, w, h)
	_panel(rect, Color(COL_SLATE_BG, COL_SLATE_BG.a * a),
		Color(COL_SLATE_BORDER, COL_SLATE_BORDER.a * a), 2, 8)
	_text_in(Rect2(rect.position.x, rect.position.y + pad.y, w, head_h), head,
		Color(COL_KEY_TEXT, COL_KEY_TEXT.a * a), FS_TOAST_HEAD, _font_display)
	var x := rect.position.x + (w - row_w) * 0.5
	var ry := rect.position.y + pad.y + head_h + 4.0
	for s: Dictionary in segs:
		var col: Color = s["color"]
		_text_in(Rect2(x, ry, float(s["w"]), row_h), str(s["text"]),
			Color(col, col.a * a), int(s["fs"]), s["font"], HORIZONTAL_ALIGNMENT_LEFT)
		x += float(s["w"]) + seg_gap


func _toast_color(id: String) -> Color:
	match id:
		"eaten": return COL_FOOD  # the mock's choice: eaten reads in the food colour
		"fed": return COL_READY   # gold — a good status
	return _strip_color(id)
