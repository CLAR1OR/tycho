extends Control
class_name BuildPanel
## Town building — "Herzog's ledger" (B2, human-picked 2026-07-09 via claude.ai/design, group
## "Town Building"). Pressing E at a build plot opens THIS fullscreen page for that one building
## (diegetically the town ledger Herzog opened at B4 — one building per page, no tabs; the town
## is the tab bar). A REBUILD of the old raw-Label3D + instant-E-build flow — the build
## TRANSACTION is byte-identical, just relocated behind the page's button. Fullscreen,
## code-built, Slate-themed; pauses the game while open. NO Close button — ESC closes (the
## panel-wide ESC-close pass, 2026-07-09).
##
## The frozen transaction (one press = one level): TownCore.next_level_cost → Ledger.try_spend_all
## (reason "building-cost") → TownCore.set_building → EventBus.building_built → SaveManager.save.
## Gating: pre-B4 the plot never opens a panel (town.gd flashes "Herzog: not yet."); a tech-locked
## building DOES open here, showing a locked page (the readable "why", no action button).
##
## Logic is BuildPanelCore + TownCore (pure, tested); this is the screen + wiring.
## open()/close()/build()/shown_building()/entry_count() are public so the headless smoke drives
## the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in SlateHud;
# the building sketch in BuildingSilhouette). ALL copy below is HUMAN pen (Herzog's register:
# short declaratives, no aphorisms, no em dashes).
# =====================================================================================
const MARGIN := 20.0
const DOCK_W := 384.0
const DOCK_TOP := 120.0
const STAGE_CENTER := Vector2(0.34, 0.60)   # normalized: the plot line for the big sketch
const STAGE_SCALE := 1.6
const NAME_Y := 0.185
const META_Y := 0.238
const FS_NAME := 30
const FS_META := 12
const FS_CARRY := 30
const FS_CARRY_LABEL := 11
const TITLE := "The Town Ledger"
const SUBTITLE := "Herzog keeps it current."
const WELL_FED_FMT := "The town is Well-Fed. Production pays %d%% more."
const RESEARCH_FMT := "research: %s"
const TRADE_LABEL := "Trade at the stalls"  # the built Market's row button (PLACEHOLDER copy)

var _defs: Dictionary = {}
var _tech_defs: Dictionary = {}
var _building_id: String = ""

var _title: Label
var _subtitle: Label
var _dock: PanelContainer
var _footnote: Label
var _font_display: FontVariation
var _font_num: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("build_panel")
	theme = SlateTheme.get_theme()
	_font_display = SlateHud._with_fallback(SlateHud.FONT_DISPLAY_FILE)
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks so they don't fall through to the town
	resized.connect(queue_redraw)


func open(building_id: String) -> void:
	_defs = DataLoader.load_domain("buildings")
	_tech_defs = DataLoader.load_domain("tech")
	_building_id = building_id
	# Header: title + subtitle (top-left).
	_title = Label.new()
	_title.text = TITLE
	_title.theme_type_variation = &"TitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"DimLabel"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	# Well-Fed footnote (bottom-left) — only when the town is Well-Fed.
	_footnote = Label.new()
	_footnote.theme_type_variation = &"DimLabel"
	_footnote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footnote.visible = bool(SaveManager.state["town"].get("well_fed", false))
	_footnote.text = WELL_FED_FMT % int(round(TownCore.WELL_FED_BONUS * 100.0))
	add_child(_footnote)
	_build_dock()
	queue_redraw()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	# ESC closes the panel from anywhere (the 2026-07-09 ESC-close pass replaces the Close
	# button). The pause menu stays inert: its own _input bails while the tree is paused, and
	# marking the event handled keeps it from opening on the same press.
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under town.gd's $HUD CanvasLayer get no layout pass
	# (size stays 0,0) — sync to the viewport, like the forge/etchings/tech panels do.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _title != null:
		_title.position = Vector2(MARGIN + 8.0, MARGIN)
	if _subtitle != null:
		_subtitle.position = Vector2(MARGIN + 9.0, MARGIN + 32.0)
	if _footnote != null:
		_footnote.position = Vector2(MARGIN + 8.0, size.y - MARGIN - _footnote.size.y)
	if _dock != null:
		_dock.custom_minimum_size.x = DOCK_W
		_dock.size.x = DOCK_W
		_dock.position = Vector2(size.x - MARGIN - DOCK_W, DOCK_TOP)


# --- Public (the dock's build button + the smoke driver land here) ----------------------

## Build/raise the shown building one level — the frozen town transaction, relocated behind
## the button. No-op if pre-B4, tech-locked, maxed, or unaffordable (the page already says why).
func build() -> void:
	if _building_id.is_empty() or not _defs.has(_building_id):
		return
	if not UnlocksCore.is_unlocked(SaveManager.state, "building"):
		return
	var def: Dictionary = _defs[_building_id]
	if not TownCore.is_unlocked(def, SaveManager.state["tech"]["researched"]):
		return  # tech-locked — the page shows the research line, no action
	var town: Dictionary = SaveManager.state["town"]
	var level := TownCore.building_level(town, _building_id)
	var cost := TownCore.next_level_cost(def, level)
	if cost.is_empty():
		return  # maxed
	if not TownCore.is_level_unlocked(def, level, SaveManager.state["tech"]["researched"]):
		return  # the next level's own tech gate isn't met — the page shows Requires …
	if not Ledger.try_spend_all(cost, "building-cost"):
		return  # can't afford — the button is disabled at the price
	SaveManager.state["town"] = TownCore.set_building(town, _building_id, level + 1)
	EventBus.building_built.emit(_building_id, level + 1)
	SaveManager.save_current()  # a built building must never be lost to a crash
	_refresh()


## The building this page shows (smoke/debug).
func shown_building() -> String:
	return _building_id


## The number of level entries on the page (smoke/debug) — the building's authored
## levels (age-banded: 3 in Age I, more as later ages land; the Library ships 4).
func entry_count() -> int:
	if not _defs.has(_building_id):
		return 0
	return (_defs[_building_id].get("levels", []) as Array).size()


## Swap this ledger page for the Market's trade page (the "Trade" button — the chosen
## home of the exchange/caravan UI, see MarketPanel's header). Null unless the shown
## building is the BUILT Market. Public so the smoke can drive it.
func open_market() -> MarketPanel:
	if _building_id != "market":
		return null
	if TownCore.building_level(SaveManager.state["town"], "market") < 1:
		return null
	var host := get_parent()
	close()
	var panel := MarketPanel.new()
	host.add_child(panel)
	panel.open()
	return panel


func _refresh() -> void:
	_build_dock()
	queue_redraw()


## Resource id → its SlateHud strip colour (shared with the survey). Placeholder-free — the
## colours live in SlateHud, the ONE dial source.
static func res_color(id: String) -> Color:
	match id:
		"gold": return SlateHud.COL_GOLD
		"stone": return SlateHud.COL_STONE
		"food": return SlateHud.COL_FOOD
		"knowledge": return SlateHud.COL_KNOWLEDGE
		"knowledge-shards": return SlateHud.COL_SHARDS
		"resonance-ore": return SlateHud.COL_ORE
		"resonance-dust": return SlateHud.COL_DUST
	return SlateHud.COL_TEXT


# --- The ledger dock (right column, rebuilt per state) ----------------------------------

func _build_dock() -> void:
	if _dock != null:
		_dock.queue_free()
		_dock = null
	if not _defs.has(_building_id):
		return
	var def: Dictionary = _defs[_building_id]
	var level := TownCore.building_level(SaveManager.state["town"], _building_id)
	var tech_locked := not TownCore.is_unlocked(def, SaveManager.state["tech"]["researched"])

	_dock = PanelContainer.new()
	_dock.custom_minimum_size = Vector2(DOCK_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	_dock.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	for row: Dictionary in BuildPanelCore.entry_rows(def, level):
		box.add_child(_entry_row(row))

	var sep := HSeparator.new()
	box.add_child(sep)

	if tech_locked:
		var res := Label.new()
		res.text = RESEARCH_FMT % _gate_name(def)
		res.theme_type_variation = &"NumLabel"
		res.add_theme_color_override("font_color", SlateHud.COL_KNOWLEDGE)
		res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(res)
	else:
		box.add_child(_action_node(def, level))
		# The built Market's page carries the door to its trade page (the chosen home
		# of the exchange/caravan UI — see open_market / MarketPanel).
		if _building_id == "market" and level >= 1:
			var trade := Button.new()
			trade.text = TRADE_LABEL
			trade.pressed.connect(func() -> void: Sfx.play("ui-click"))
			trade.pressed.connect(func() -> void: open_market())
			box.add_child(trade)

	add_child(_dock)


func _entry_row(row: Dictionary) -> Control:
	var state := str(row["state"])
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var pip := Label.new()
	pip.text = "●" if state == "built" else "○"
	pip.add_theme_color_override("font_color",
		SlateHud.COL_READY if state != "beyond" else SlateHud.COL_SLATE_BORDER)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(pip)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	var lv_l := Label.new()
	lv_l.text = "LEVEL %d" % int(row["level"])
	lv_l.theme_type_variation = &"NumLabel"
	mid.add_child(lv_l)
	var yl: Dictionary = row["yield"]
	if not str(yl["text"]).is_empty():
		var y_l := Label.new()
		y_l.text = str(yl["text"])
		var res := str(yl["resource"])
		y_l.add_theme_color_override("font_color",
			res_color(res) if not res.is_empty() else SlateHud.COL_TEXT)
		y_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(y_l)
	hb.add_child(mid)

	# Debit column, right-aligned: the price, plus a gold BUILT stamp for built levels.
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price := Label.new()
	price.text = _cost_text(row["cost"])
	price.theme_type_variation = &"NumLabel"
	right.add_child(price)
	if state == "built":
		price.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)  # dim (stands for struck)
		var stamp := Label.new()
		stamp.text = "BUILT"
		stamp.theme_type_variation = &"NumLabel"
		stamp.add_theme_color_override("font_color", SlateHud.COL_READY)
		right.add_child(stamp)
	hb.add_child(right)

	if state == "beyond":
		hb.modulate = Color(1, 1, 1, 0.45)
	return hb


## The gold build/raise button below max, the inert "Max level" label at max, or the
## "Requires <tech>" line when the next level's own gate isn't met (age-banded levels).
func _action_node(def: Dictionary, level: int) -> Control:
	var action := BuildPanelCore.action(def, level, SaveManager.state["tech"]["researched"])
	var kind := str(action["kind"])
	if kind == "maxed":
		var l := Label.new()
		l.text = "Max level"
		l.theme_type_variation = &"DimLabel"
		l.add_theme_color_override("font_color", SlateHud.COL_READY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	if kind == "locked":
		var lock := Label.new()
		lock.text = BuildPanelCore.LOCKED_FMT % BuildPanelCore.gate_tech_name(
			str(action.get("requires", "")), _tech_defs)
		lock.theme_type_variation = &"NumLabel"
		lock.add_theme_color_override("font_color", SlateHud.COL_KNOWLEDGE)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return lock
	var cost: Dictionary = action["cost"]
	var b := Button.new()
	if kind == "build":
		b.text = "Build (%s)" % _cost_text(cost)
	else:
		b.text = "Raise to L%d (%s)" % [int(action["to_level"]), _cost_text(cost)]
	b.disabled = not Ledger.can_afford(cost)
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(build)
	return b


func _cost_text(cost: Dictionary) -> String:
	# Matches town.gd's _cost_text format byte-for-byte ("%d %s", ", "-joined).
	var parts := PackedStringArray()
	for id: String in cost:
		parts.append("%d %s" % [int(cost[id]), id])
	return ", ".join(parts)


func _gate_name(def: Dictionary) -> String:
	var gate: Dictionary = def.get("unlocked_by") if def.get("unlocked_by") != null else {}
	# An unauthored gate tech reads as the placeholder line, never a raw id.
	return BuildPanelCore.gate_tech_name(str(gate.get("id", "")), _tech_defs)


# --- Draw (bg + the big sketch + name/meta + the carry readout) --------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), TechChart.COL_FRAME_BG)
	if not _defs.has(_building_id):
		return
	var def: Dictionary = _defs[_building_id]
	var level := TownCore.building_level(SaveManager.state["town"], _building_id)
	var c := Vector2(STAGE_CENTER.x * size.x, STAGE_CENTER.y * size.y)
	# The plot line the building stands on.
	draw_line(Vector2(size.x * 0.08, c.y), Vector2(size.x * 0.62, c.y),
		Color(SlateHud.COL_SLATE_BORDER, 0.8), 2.0, true)
	BuildingSilhouette.paint(self, _building_id, c, STAGE_SCALE,
		BuildingSilhouette.COL_BODY_FILL, BuildingSilhouette.COL_BODY_STROKE, 2.5,
		_font_display, FS_NAME, level)
	_draw_name_meta(def, level, c.x)
	_draw_carry(def)


func _draw_name_meta(def: Dictionary, level: int, cx: float) -> void:
	# Display names go through TownCore.display_name — a built band opener renames
	# the building (Library → University, town-economy.md).
	var nm := TownCore.display_name(def, level)
	var tw := _font_display.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_NAME).x
	var ty := NAME_Y * size.y + _font_display.get_ascent(FS_NAME)
	draw_string(_font_display, Vector2(cx - tw * 0.5, ty), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_NAME, SlateHud.COL_TEXT)
	var cat := str(def.get("category", "")).to_upper()
	var maxlvl := (def.get("levels", []) as Array).size()
	var lvl_txt := "UNBUILT" if level == 0 else "L%d OF %d" % [level, maxlvl]
	var meta := "%s · %s" % [cat, lvl_txt]
	var mw := _font_num.get_string_size(meta, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_META).x
	var my := META_Y * size.y + _font_num.get_ascent(FS_META)
	draw_string(_font_num, Vector2(cx - mw * 0.5, my), meta,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_META, SlateHud.COL_KEY_TEXT)


## The carry readout (top-right, bare — no box): one row per resource in this building's costs,
## the dim label then the big number, right-aligned (the E1/F2 Dust/Ore readout pattern).
func _draw_carry(def: Dictionary) -> void:
	var right := size.x - MARGIN
	var y := MARGIN + 6.0
	for id: String in BuildPanelCore.carry_resources(def):
		var num := str(int(Ledger.get_amount(id)))
		var nw := _font_num.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY).x
		var by := y + _font_num.get_ascent(FS_CARRY)
		draw_string(_font_num, Vector2(right - nw, by), num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY, res_color(id))
		var lw := _font_num.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY_LABEL).x
		draw_string(_font_num, Vector2(right - nw - 10.0 - lw, by), id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY_LABEL, SlateHud.COL_KEY_TEXT)
		y += FS_CARRY + 10.0
