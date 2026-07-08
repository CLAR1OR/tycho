extends Control
class_name TechPanel
## Sophia's research screen (PRD §7.8) — the "Star chart" (R1, human-picked 2026-07-08
## via claude.ai/design): the tech tree drawn as a constellation. Fullscreen, code-built,
## Slate-themed; pauses the game while open.
##
## Two child roots, toggled by screen:
##   CHART  — the constellation (TechChart, custom-drawn stars + prereq edges) plus the
##            header (title/subtitle/carry chip/turn-in button), the right-side detail
##            DOCK for the selected node, a hint chip, and Close. Merges the old LIST +
##            NODE screens: clicking a star selects it (→ TechState.set_active, unchanged)
##            and fills the dock; the dock's action button invests or starts the solve.
##   PAGE   — the existing scrolling reading page for READ → QUIZ / PUZZLE → LOCKED / AHA.
##
## Flow (unchanged semantics): invest Knowledge into the active node → at cost it's READY
## → read the authored explanation → the node's puzzle, dispatched on `puzzle.kind`
## (architecture-schemas.md §4): "quiz" → the built-in QUIZ; "interactive" → PUZZLE embeds
## the bespoke scene from PUZZLES and waits for its `solved` signal → AHA (the reveal) →
## finish: TechState.complete (TechCore.complete + `tech_researched`) + save.
##
## Shard economy (2026-07-06): investing spends KNOWLEDGE ONLY. Knowledge Shards are turned
## in for Knowledge with the header's turn-in action (TechState). A wrong quiz answer LOCKS
## the quiz (LOCKED screen) until one run passes — the interactive arch puzzle is exempt.
##
## Logic stays in TechCore + TechChartCore (pure, tested); tech-section writes route through
## the TechState autoload (set_active / invest / turn_in_shards / lock_quiz / complete); this
## class is screens and wiring. The public flow methods (select_node / invest_all /
## turn_in_shards / begin_read / begin_quiz / answer / begin_puzzle / puzzle_node / finish /
## on_locked_screen) plus the star_state getter are FROZEN — the headless smoke drives them.

enum Screen { CHART, READ, QUIZ, LOCKED, PUZZLE, AHA }

## Bespoke interactive puzzles, keyed by the node's `puzzle.scene`. Contract:
## a Control with `setup(data: Dictionary)` and a `solved` signal.
const PUZZLES: Dictionary = {
	"puzzle_arch": preload("res://src/learning/puzzle_arch.gd"),
}

# =====================================================================================
# Style — placeholders. Dial like FEEL numbers (the shared palette/fonts live in SlateHud;
# the constellation's own placeholders live in TechChart; the reading page reuses the
# original gutter widths). New UI copy strings are placeholders too — dial freely.
# =====================================================================================
const MARGIN := 20.0
const DOCK_W := 348.0            # right-side detail dock width
const DOCK_TOP := 96.0           # dock top, below the header
const DOCK_BAR_H := 12.0         # dock progress bar height
# Reading page (READ/QUIZ/LOCKED/PUZZLE/AHA) — the original comfortable gutters.
const GUTTER_X := 240
const GUTTER_Y := 24
# New UI copy (the chart header + dock — NOT the shipped game-copy strings, which stay
# byte-identical). Placeholders.
const SUBTITLE := "She works at your focus between runs. Bring her what you find."
const CARRY_KNOWLEDGE_LABEL := "knowledge"
const CARRY_SHARDS_LABEL := "shards"
const DOCK_REQUIRES_PREFIX := "Requires: "
const DOCK_UNLOCKS_PREFIX := "Unlocks: "

var _defs: Dictionary = {}
var _building_defs: Dictionary = {}
var _screen: int = Screen.CHART
var _node_id: String = ""
var _quiz_index: int = 0

# Chart screen
var _chart_root: Control
var _chart: TechChart
var _topright: HBoxContainer
var _carry: HBoxContainer
var _turnin_btn: Button
var _dock: PanelContainer
var _close_btn: Button
# Reading page
var _page_root: Control
var _rows: VBoxContainer
var _puzzle: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tech_panel")
	theme = SlateTheme.get_theme()


func open() -> void:
	_defs = DataLoader.load_domain("tech")
	_building_defs = DataLoader.load_domain("buildings")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A near-opaque backdrop over the whole screen (the frame bg of the mock).
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = TechChart.COL_FRAME_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_page()
	_build_chart()
	_show_chart()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under game.gd's $HUD CanvasLayer get no layout
	# pass (size stays 0,0) — sync to the viewport, like the Slate HUDs do.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _chart_root != null and _chart_root.visible:
		_reposition()


# --- Flow (public — the dock buttons and the smoke driver both land here) -------------

func select_node(id: String) -> void:
	_node_id = id
	# Selecting makes it the ACTIVE node — the one Sophia auto-solves over runs.
	TechState.set_active(id)
	_show_chart()


## Pour the Ledger's Knowledge into the selected node, up to its remaining cost. The invest
## transaction (+ its Ledger spend) lives on TechState; the readout re-reads state below.
func invest_all() -> void:
	TechState.invest(_defs[_node_id], _node_id)
	_show_chart()


func begin_read() -> void:
	_show_read()


func begin_quiz() -> void:
	if TechCore.is_quiz_locked(SaveManager.state["tech"], _node_id):
		_show_locked()
		return
	_quiz_index = 0
	_show_quiz()


## Turn in ALL held Knowledge Shards for Knowledge at the desk (TechState owns the
## transaction). Public so the smoke can drive it; refreshes the current screen.
func turn_in_shards() -> void:
	TechState.turn_in_shards()
	SaveManager.save_current()
	if _screen == Screen.CHART:
		_show_chart()
	# (On a reading page the header isn't shown; nothing to refresh.)


## True while the quiz-locked screen is up (a wrong answer this run). Smoke/debug hook.
func on_locked_screen() -> bool:
	return _screen == Screen.LOCKED


## Embed the node's bespoke interactive puzzle and wait for it to be solved.
func begin_puzzle() -> void:
	_screen = Screen.PUZZLE
	_show_page()
	_clear()
	var def: Dictionary = _defs[_node_id]
	var puzzle: Dictionary = def["puzzle"]
	var scene_id := str(puzzle.get("scene", ""))
	if not PUZZLES.has(scene_id):
		push_error("TechPanel: unknown puzzle scene \"%s\" on %s" % [scene_id, _node_id])
		_show_read()
		return
	_title(str(def["name"]))
	_puzzle = (PUZZLES[scene_id] as GDScript).new()
	_puzzle.call("setup", puzzle.get("data", {}))
	_puzzle.connect("solved", _show_aha)
	_rows.add_child(_puzzle)
	_button("Step away (keeps progress)", close)


## The live puzzle Control (smoke driver + debugging).
func puzzle_node() -> Control:
	return _puzzle


## Answer the current quiz question with option `index` (in DATA order — the UI shuffles
## display order but binds original indices). A WRONG answer locks the quiz for one run
## (2026-07-06); Sophia still auto-solves eventually, so this delays, never hard-gates
## (IC-10). No-op while already locked.
func answer(index: int) -> void:
	if _screen == Screen.LOCKED:
		return
	var q := _current_question()
	if index == int(q.get("correct", 0)):
		_quiz_index += 1
		if _quiz_index >= _questions().size():
			_show_aha()
		else:
			_show_quiz()
	else:
		TechState.lock_quiz(_node_id)
		SaveManager.save_current()
		_show_locked()


## The aha has been read: the node completes for real, then back to the chart.
func finish() -> void:
	TechState.complete(_node_id)  # TechCore.complete + tech_researched, in one place
	SaveManager.save_current()
	_node_id = ""
	_show_chart()


## The chart state of a node as the panel sees it (TechChartCore). Smoke/debug hook.
func star_state(id: String) -> StringName:
	return TechChartCore.node_state(_defs[id], SaveManager.state["tech"], id)


# =====================================================================================
# Chart screen (constellation + header + dock)
# =====================================================================================

func _build_chart() -> void:
	_chart_root = Control.new()
	_chart_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chart_root)

	_chart = TechChart.new()
	_chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_root.add_child(_chart)
	_chart.setup(_defs, select_node)

	# Header: title + subtitle (top-left).
	var title := Label.new()
	title.text = "Sophia's Desk — Research"
	title.theme_type_variation = &"TitleLabel"
	title.position = Vector2(MARGIN + 8.0, MARGIN)
	_chart_root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.theme_type_variation = &"DimLabel"
	subtitle.position = Vector2(MARGIN + 9.0, MARGIN + 32.0)
	_chart_root.add_child(subtitle)

	# Header: carry chip + turn-in button (top-right).
	_topright = HBoxContainer.new()
	_topright.add_theme_constant_override("separation", 10)
	var carry_panel := PanelContainer.new()
	_carry = HBoxContainer.new()
	_carry.add_theme_constant_override("separation", 5)
	carry_panel.add_child(_carry)
	_topright.add_child(carry_panel)
	_turnin_btn = Button.new()
	_turnin_btn.pressed.connect(func() -> void: Sfx.play("ui-click"))
	_turnin_btn.pressed.connect(turn_in_shards)
	_topright.add_child(_turnin_btn)
	_chart_root.add_child(_topright)

	# Dock holder (rebuilt per selection) + Close.
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func() -> void: Sfx.play("ui-click"))
	_close_btn.pressed.connect(close)
	_chart_root.add_child(_close_btn)


## Position the header group, dock, and Close each frame while the chart is visible (their
## container sizes only settle after a layout pass, so absolute placement is simplest).
func _reposition() -> void:
	if _topright != null:
		_topright.position = Vector2(size.x - MARGIN - _topright.size.x, MARGIN - 4.0)
	if _dock != null:
		_dock.position = Vector2(size.x - MARGIN - DOCK_W, DOCK_TOP)
	if _close_btn != null:
		_close_btn.position = Vector2(MARGIN, size.y - MARGIN - _close_btn.size.y)


func _show_chart() -> void:
	_screen = Screen.CHART
	_chart_root.visible = true
	_page_root.visible = false
	_refresh_header()
	_build_dock()
	_chart.set_selected(_node_id)
	_chart.refresh()


func _refresh_header() -> void:
	for child in _carry.get_children():
		child.queue_free()
	_carry.add_child(_carry_span("%d" % int(Ledger.get_amount("knowledge")), SlateHud.COL_KNOWLEDGE, false))
	_carry.add_child(_carry_span(CARRY_KNOWLEDGE_LABEL, SlateHud.COL_KEY_TEXT, true))
	_carry.add_child(_carry_span("%d" % int(Ledger.get_amount("knowledge-shards")), SlateHud.COL_SHARDS, false))
	_carry.add_child(_carry_span(CARRY_SHARDS_LABEL, SlateHud.COL_KEY_TEXT, true))
	var shards := int(Ledger.get_amount("knowledge-shards"))
	_turnin_btn.text = "Turn in %d Knowledge Shards → %d Knowledge" % [
		shards, shards * int(TechCore.SHARD_KNOWLEDGE_VALUE)]
	_turnin_btn.disabled = shards <= 0


func _carry_span(text: String, col: Color, dim: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"NumLabel"
	l.add_theme_color_override("font_color", col)
	if dim:
		l.add_theme_font_size_override("font_size", SlateHud.FS_SMALL + 1)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Build (or clear) the detail dock for the selected node. No selection → no dock.
func _build_dock() -> void:
	if _dock != null:
		_dock.queue_free()
		_dock = null
	if _node_id.is_empty() or not _defs.has(_node_id):
		return
	var def: Dictionary = _defs[_node_id]
	var tech: Dictionary = SaveManager.state["tech"]
	_dock = PanelContainer.new()
	_dock.custom_minimum_size = Vector2(DOCK_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	_dock.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var name_l := Label.new()
	name_l.text = str(def["name"])
	name_l.theme_type_variation = &"TitleLabel"
	box.add_child(name_l)

	# Meta line: tier caps (gold for KEY) · AGE n · puzzle kind · 🧠.
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 0)
	var tier_l := Label.new()
	tier_l.text = str(def["tier"]).to_upper()
	tier_l.theme_type_variation = &"NumLabel"
	tier_l.add_theme_color_override("font_color",
		SlateHud.COL_READY if str(def["tier"]) == "key" else SlateHud.COL_KEY_TEXT)
	meta.add_child(tier_l)
	var kind := "gateway" if str((def["puzzle"] as Dictionary).get("kind", "quiz")) == "interactive" else "quiz"
	var rest_l := Label.new()
	rest_l.text = " · AGE %d · %s%s" % [int(def["age"]), kind,
		"  ·  🧠" if bool(def.get("thinking_tool", false)) else ""]
	rest_l.theme_type_variation = &"NumLabel"
	rest_l.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)
	meta.add_child(rest_l)
	box.add_child(meta)

	# Progress bar + n / cost.
	var cost := int(def["cost_knowledge"])
	var prog := TechCore.progress(tech, _node_id)
	var ready := TechCore.is_ready(def, tech)
	var frac := clampf(prog / float(cost), 0.0, 1.0) if cost > 0 else 0.0
	box.add_child(_dock_bar(frac, SlateHud.COL_READY if ready else SlateHud.COL_KNOWLEDGE))
	var bar_num := Label.new()
	bar_num.text = "%d / %d knowledge" % [int(prog), cost]
	bar_num.theme_type_variation = &"NumLabel"
	bar_num.add_theme_color_override("font_color", SlateHud.COL_KNOWLEDGE)
	box.add_child(bar_num)

	# Requires / Unlocks.
	var prereqs: Array = def.get("prereqs", [])
	if not prereqs.is_empty():
		var researched: Array = tech.get("researched", [])
		var reqs := PackedStringArray()
		for r: String in prereqs:
			var check := "✓ " if r in researched else ""
			reqs.append(check + (str(_defs[r]["name"]) if _defs.has(r) else r))
		var req_l := Label.new()
		req_l.text = DOCK_REQUIRES_PREFIX + ", ".join(reqs)
		req_l.theme_type_variation = &"DimLabel"
		req_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(req_l)
	var unlocks: Array = def.get("unlocks", [])
	if not unlocks.is_empty():
		var names := PackedStringArray()
		for u: Dictionary in unlocks:
			names.append(_display_unlock(u))
		var unl_l := Label.new()
		unl_l.text = DOCK_UNLOCKS_PREFIX + ", ".join(names)
		unl_l.theme_type_variation = &"DimLabel"
		unl_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(unl_l)

	# Action.
	if ready:
		var ready_l := Label.new()
		ready_l.text = "It's ready. Sophia lays out what the shards revealed —"
		ready_l.theme_type_variation = &"DimLabel"
		ready_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(ready_l)
		_dock_button(box, "Read & solve", begin_read)
	else:
		_dock_button(box, "Invest everything you carry", invest_all)

	_chart_root.add_child(_dock)


## A two-layer bar: slate track + a colour fill scaled to `frac` via an anchor.
func _dock_bar(frac: float, fill_col: Color) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, DOCK_BAR_H)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := ColorRect.new()
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.color = TechChart.COL_FRAME_BG
	bar.add_child(track)
	var fill := ColorRect.new()
	fill.anchor_left = 0.0
	fill.anchor_right = clampf(frac, 0.0, 1.0)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_right = 0.0
	fill.offset_top = 0.0
	fill.offset_bottom = 0.0
	fill.color = fill_col
	bar.add_child(fill)
	return bar


func _dock_button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	box.add_child(b)


## Resolve a typed unlock {type, id} to a display name (building ids → their def name).
func _display_unlock(u: Dictionary) -> String:
	var id := str(u.get("id", ""))
	if str(u.get("type", "")) == "building" and _building_defs.has(id):
		return str(_building_defs[id]["name"])
	return id


# =====================================================================================
# Reading page (READ → QUIZ / PUZZLE → LOCKED / AHA) — the original scrolling page.
# =====================================================================================

func _build_page() -> void:
	_page_root = MarginContainer.new()
	_page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_root.add_theme_constant_override("margin_left", GUTTER_X)
	_page_root.add_theme_constant_override("margin_right", GUTTER_X)
	_page_root.add_theme_constant_override("margin_top", GUTTER_Y)
	_page_root.add_theme_constant_override("margin_bottom", GUTTER_Y)
	add_child(_page_root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)


func _show_page() -> void:
	_chart_root.visible = false
	_page_root.visible = true


func _show_read() -> void:
	_screen = Screen.READ
	_show_page()
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title(str(def["name"]))
	_reading(str(def.get("explanation", "(no explanation authored yet)")))
	if str((def["puzzle"] as Dictionary).get("kind", "quiz")) == "interactive":
		_button("To the gateway — build it", begin_puzzle)
	else:
		_button("I have it — ask me", begin_quiz)
	_button("Close (keeps progress)", close)


func _show_quiz(feedback: String = "") -> void:
	_screen = Screen.QUIZ
	_show_page()
	_clear()
	var q := _current_question()
	_title("Question %d of %d" % [_quiz_index + 1, _questions().size()])
	_reading(str(q.get("q", "?")))
	if not feedback.is_empty():
		var fb := Label.new()
		fb.text = feedback
		fb.modulate = Color(1.0, 0.6, 0.5)
		_rows.add_child(fb)
	# Shuffle the display order; each button still answers with its DATA index.
	var options: Array = q.get("options", [])
	var order := range(options.size())
	order.shuffle()
	for i: int in order:
		var b := Button.new()
		b.text = str(options[i])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(answer.bind(i))
		_rows.add_child(b)


## The quiz is locked (a wrong answer this run). No answer buttons — a run has to pass
## before Sophia will hear the answer again. Diegetic line in the plain register.
func _show_locked() -> void:
	_screen = Screen.LOCKED
	_show_page()
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title(str(def["name"]))
	_reading("Sophia: That's not it. Go make a run and clear your head. Ask me again when you're back.")
	_button("Back", _show_chart)
	_button("Close (keeps progress)", close)


func _show_aha() -> void:
	_screen = Screen.AHA
	_show_page()
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title("✦ " + str(def["name"]), true)  # the one celebratory screen — gold title
	_reading(str(def.get("aha", "")))
	var unlocks: Array = def.get("unlocks", [])
	if not unlocks.is_empty():
		var names := PackedStringArray()
		for u: Dictionary in unlocks:
			names.append("%s %s" % [str(u.get("type", "")), str(u.get("id", ""))])
		_label("Unlocked: " + ", ".join(names))
	_button("Finish", finish)


# --- Reading-page UI helpers ---------------------------------------------------------

func _clear() -> void:
	for child in _rows.get_children():
		child.queue_free()


func _title(text: String, gold: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.theme_type_variation = &"TitleLabel"
	if gold:
		l.add_theme_color_override("font_color", SlateHud.COL_READY)
	_rows.add_child(l)


func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


## Long-form text (explanations and ahas are essays, by design). The PAGE scrolls, so this
## is just a wrapping label at reading width.
func _reading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(l)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	_rows.add_child(b)


func _questions() -> Array:
	return (_defs[_node_id]["puzzle"] as Dictionary).get("data", {}).get("questions", [])


func _current_question() -> Dictionary:
	var qs := _questions()
	return qs[_quiz_index] if _quiz_index < qs.size() else {}
