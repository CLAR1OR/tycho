extends EmberHud
class_name TownHud
## The town HUD. **Migrated to Ember 2026-08-13** (Tier A of design/ui-hud.md §
## "Migrating to Ember") from the Slate T1 design that shipped 2026-07-07.
##
## Code-built by town.gd onto the town's $HUD CanvasLayer; a screen-filling Control
## (mouse_filter IGNORE, from EmberHud) that draws everything itself in _draw and polls
## the Ledger each frame (town is cheap). Pure string/delta/toast logic lives in
## TownHudCore (src/town/town_hud_core.gd); this node owns only pixels.
##
## WHAT THE MIGRATION CHANGED — four Slate panels became no panels:
##   day chip    -> tracked text on a hairline, top-left (the run HUD's room-header grammar)
##   two strips  -> bare glyph + number readouts, top-right (the run HUD's resource grammar)
##   toast panel -> a tracked caps head over its row, on a hairline, top-centre
## The point is not that panels are ugly — it is that **the town and the run now speak the
## same language in the same corners**, so a resource sits in the same place with the same
## mark whichever scene you are in. Under Slate they merely looked similar.
##
## The strip stays TWO groups (human decision 2026-07-07): the town economy (resources a
## building can generate — DERIVED from the building defs, so it self-maintains) and the
## run pickups (only ever brought home), the run group holding the corner.
##
## RESTYLE ONLY — configure / show_day_toast / day_chip / projection / toast_visible /
## town_group / run_group, the EventBus wiring, and the derivation are byte-identical.
##
## HUMAN: HINT_TEXT, the toast copy/timings, every size, and the TOWN/RUN group headers
## are PLACEHOLDERS — dial like FEEL numbers (design/feel-tuning.md § Ember menus).

# =====================================================================================
# Town-specific style — placeholders. (Palette + fonts + primitives live in EmberHud.)
# =====================================================================================
# Day chip (top-left)
const DAY_TOP := 12.0            # text centre, below MARGIN
const DAY_RULE_DROP := 13.0      # the hairline under it
const DAY_RULE_PAD := 8.0        # how far the rule runs past the text
const DAY_TRACKING := 1.4
# Resource strip (top-right) — the run HUD's readout grammar, extended to seven ids.
const RES_TOP := 26.0            # readout row centre, below MARGIN
const RES_GLYPH := 18.0
const RES_GAP := 11.0            # glyph -> its number
const RES_SPACING := 26.0        # between resources inside a group
const GROUP_GAP := 40.0          # between the two groups (reads as the group boundary)
const HEAD_LIFT := 20.0          # group header centre, above the readout row
const FS_GROUP := 10             # the tiny group headers (ui med, tracked)
const PROJ_DROP := 20.0          # the "+n/d" projection, below the readout row
const PROJECTION_ALPHA := 0.55
const GROUP_TOWN_LABEL := "TOWN"  # HUMAN: placeholder copy
const GROUP_RUN_LABEL := "RUN"    # HUMAN: placeholder copy
# Toast (overnight production) — TOP-LEFT, under the day chip, fading.
#
# It was top-centre under Slate, where it was a panel and the resource strip was another
# panel, so they never met. Ember's strip has no panel padding and spans seven resources,
# so it now reaches well past the middle — the first probe render had the toast drawn
# straight through it. Moving the toast under the day chip fixes the collision AND reads
# better: "Day 4 · Well-Fed +25%" and "+5 stone +3 food -5 eaten" are the same thought,
# so they belong in the same column. Top-centre is left free for the achievement toast.
# HUMAN: placeholder placement — the collision is fixed, the composition is yours.
const TOAST_TOP := 62.0          # the segment row's centre, below MARGIN
const TOAST_HEAD_LIFT := 20.0    # the "OVERNIGHT" head, above the row
const TOAST_RULE_DROP := 17.0
const TOAST_RULE_PAD := 8.0
const TOAST_SEG_GAP := 16.0
const FS_TOAST_HEAD := 11        # the "OVERNIGHT" header (ui med, tracked)
const TOAST_HOLD_S := 4.0
const TOAST_FADE_S := 1.0

## The strip's seven columns, in order (Ledger ids). Marks + colours come from EmberHud's
## RESOURCE_GLYPH / RESOURCE_COLOR, so a resource cannot wear two different marks on two
## screens.
const STRIP_IDS: Array[String] = [
	"gold", "stone", "food", "knowledge", "knowledge-shards", "resonance-ore", "resonance-dust",
]

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
	super._ready()  # EmberHud: anchors + mouse_filter + the four fonts
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
	_sync_viewport_size()  # EmberHud: the CanvasLayer-under-_ready layout quirk
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
	if size.x < 1.0:
		return
	_draw_day_chip()
	_draw_resource_strip()  # + the per-resource projections below it
	_draw_toast()


# --- Day chip (top-left) -------------------------------------------------------------

func _draw_day_chip() -> void:
	# Three coloured spans on one tracked line — the run HUD's room-header grammar, with
	# the food status taking the place of the peril mark. NEVER red: red is reserved for
	# player danger, and being short on food is a problem, not a threat.
	var y := MARGIN + DAY_TOP
	var x := MARGIN
	var prefix := "Day %d" % _day
	x += _text_tracked(Vector2(x, y), prefix, COL_INK, FS_HEAD, _font_ui_med, DAY_TRACKING)
	if _has_ticked:
		x += _text_tracked(Vector2(x, y), " · ", COL_INK_DIM, FS_HEAD, _font_ui_med, DAY_TRACKING)
		var status := "Short on food"
		var status_col := COL_INK_DIM
		if _well_fed:
			status = "Well-Fed +%s%%" % str(int(TownCore.WELL_FED_BONUS * 100))
			status_col = COL_ACCENT  # gold — a good thing, and the only gold up here
		x += _text_tracked(Vector2(x, y), status, status_col, FS_HEAD, _font_ui_med, DAY_TRACKING)
	_hairline(MARGIN, x + DAY_RULE_PAD, y + DAY_RULE_DROP)


# --- Resource strip (top-right) + projections (below) --------------------------------

func _draw_resource_strip() -> void:
	# Two groups laid right-to-left: the run pickups hold the corner (mirroring where the
	# in-run readout lives, so the same resources sit in the same place in both scenes),
	# the town economy to their left. No panels — the gap IS the group boundary.
	var y := MARGIN + RES_TOP
	var right := size.x - MARGIN
	right = _draw_group(_run_ids, GROUP_RUN_LABEL, right, y) - GROUP_GAP
	_draw_group(_town_ids, GROUP_TOWN_LABEL, right, y)


## Draw one resource group right-anchored at `right_x`: a tiny tracked header above a row
## of `glyph + number` readouts, each with its projection underneath. Returns the group's
## left edge, so the caller can lay the next group beside it.
func _draw_group(ids: Array[String], header: String, right_x: float, y: float) -> float:
	if ids.is_empty():
		return right_x
	# Measure every readout first — there is no panel to anchor to, so the total width has
	# to be known before anything is drawn.
	var widths: Array[float] = []
	var total := 0.0
	for id: String in ids:
		var w := RES_GLYPH + RES_GAP + _text_w(_amount_text(id), FS_BIG, _font_num)
		widths.append(w)
		total += w + RES_SPACING
	total -= RES_SPACING
	var left := right_x - total
	_text_tracked(Vector2(left, y - HEAD_LIFT), header, COL_INK_DIM, FS_GROUP, _font_ui_med)
	var x := left
	for i in ids.size():
		var id := ids[i]
		_glyph(Vector2(x + RES_GLYPH * 0.5, y), RES_GLYPH, EmberHud.resource_glyph(id),
			EmberHud.resource_color(id))
		_text_at(Vector2(x + RES_GLYPH + RES_GAP, y), _amount_text(id), COL_INK,
			FS_BIG, _font_num)
		# Projection under the readout, centred on it.
		var proj := TownHudCore.projection_text(projection(id))
		if not proj.is_empty():
			_text_centred(x + widths[i] * 0.5, y + PROJ_DROP, proj,
				Color(COL_INK_DIM, PROJECTION_ALPHA), FS_KEY, _font_num)
		x += widths[i] + RES_SPACING
	return left


func _amount_text(id: String) -> String:
	return "%d" % int(Ledger.get_amount(id))


# --- Overnight toast (top-centre, fading) --------------------------------------------

func _draw_toast() -> void:
	if _toast_alpha <= 0.0 or _toast_segs.is_empty():
		return
	var a := _toast_alpha
	var head := "OVERNIGHT"  # HUMAN: placeholder copy
	# Measure the segment row (the "Well-Fed" word rides Garamond a touch larger).
	var segs: Array = []  # [{text, color, font, fs, w}]
	for s: Dictionary in _toast_segs:
		var id := str(s["id"])
		var font := _font_body if id == "fed" else _font_num
		var fs := FS_VALUE + 2 if id == "fed" else FS_VALUE
		segs.append({
			"text": str(s["text"]), "color": _toast_color(id), "font": font, "fs": fs,
			"w": _text_w(str(s["text"]), fs, font),
		})
	var row_w := 0.0
	for s: Dictionary in segs:
		row_w += float(s["w"]) + TOAST_SEG_GAP
	row_w -= TOAST_SEG_GAP
	var y := MARGIN + TOAST_TOP
	var head_w := _text_tracked_w(head, FS_TOAST_HEAD, _font_ui_med)
	_text_tracked(Vector2(MARGIN, y - TOAST_HEAD_LIFT), head,
		Color(COL_INK_DIM, a), FS_TOAST_HEAD, _font_ui_med)
	var x := MARGIN
	for s: Dictionary in segs:
		var col: Color = s["color"]
		# Shadowed: there is nothing behind it, and the town is bright where it lands.
		x += _text_shadowed(Vector2(x, y), str(s["text"]), Color(col, col.a * a),
			int(s["fs"]), s["font"]) + TOAST_SEG_GAP
	_hairline(MARGIN, MARGIN + maxf(row_w, head_w) + TOAST_RULE_PAD, y + TOAST_RULE_DROP,
		Color(COL_HAIR, COL_HAIR.a * a))


func _toast_color(id: String) -> Color:
	match id:
		"eaten": return COL_FOOD  # eaten reads in the food colour (the T1 mock's choice)
		"fed": return COL_ACCENT  # gold — a good status
	return EmberHud.resource_color(id)
