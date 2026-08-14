extends EmberHud
class_name SurveyPanel
## Town building — "The survey" (B3, human-picked 2026-07-09 via claude.ai/design, group "Town
## Building"). A Planning Table next to Herzog opens this read-only, whole-town sheet: every
## building def as a ledger row (including the dormant `town-walls` def, which has NO plot in
## the scene — a row needs no plot). It answers "where should the next 100 gold go"; the ONE
## build path stays at the plots (BuildPanel), so this sheet has NO build buttons. Fullscreen,
## code-built, EMBER (migrated 2026-08-14, Tier B); pauses while open. NO Close button — ESC
## closes (2026-07-09).
##
## The Ember migration is a RESTYLE — `row_count()`, the ordering and all copy are
## byte-identical, and the smoke drives it unchanged (it counts the 9 building defs). What
## moved: the sheet's panel is transparent with real hairlines between rows, the "●/○" text
## pips became the shared drawn `EmberPips`, and the carry stack became `_resource_readout`.
## Being read-only, this page has NO gold at all except a built pip — which is exactly the
## right reading of "gold means state", since there is no action here to spend it on.
##
## Logic is BuildPanelCore + TownCore (pure, tested); this is the screen + wiring.
## open()/close()/row_count() are public so the headless smoke drives the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in EmberHud).
# =====================================================================================
const SHEET_W := 800.0
const SHEET_TOP := 116.0
const RES_Y := 40.0   # the shared carry readout's row, level with the title band
const TITLE := "The Town Ledger"
const SUBTITLE := "The whole town, at a glance. Herzog keeps it current."
const WELL_FED_FMT := "The town is Well-Fed. Production pays %d%% more."
const RESEARCH_FMT := "research: %s"
const NEXT_FMT := "next: %s"
const MAXED := "max level"
## The resources the survey's carry readout shows (a fixed set — town economy at a glance).
const CARRY_IDS: Array[String] = ["gold", "stone", "food"]

var _tech_defs: Dictionary = {}
var _rows: int = 0

var _title: Label
var _subtitle: Label
var _sheet: PanelContainer
var _footnote: Label


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("survey_panel")
	theme = EmberTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func open() -> void:
	_tech_defs = DataLoader.load_domain("tech")
	_title = Label.new()
	_title.text = TITLE
	_title.theme_type_variation = &"EmberTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"EmberDim"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	_footnote = Label.new()
	_footnote.theme_type_variation = &"EmberDim"
	_footnote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footnote.visible = bool(SaveManager.state["town"].get("well_fed", false))
	_footnote.text = WELL_FED_FMT % int(round(TownCore.WELL_FED_BONUS * 100.0))
	add_child(_footnote)
	_build_sheet()
	queue_redraw()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	# Bands from EmberMenuCore, so this header and footer sit where every Ember screen's do.
	var bands := EmberMenuCore.catalogue(size)
	if _title != null:
		_title.position = EmberMenuCore.label_pos(bands["title"], _title.size.y)
	if _subtitle != null:
		_subtitle.position = EmberMenuCore.label_pos(bands["subtitle"], _subtitle.size.y)
	if _footnote != null:
		_footnote.position = EmberMenuCore.label_pos(bands["footer"], _footnote.size.y)
	if _sheet != null:
		var col: Rect2 = EmberMenuCore.column(size, SHEET_W)["column"]
		_sheet.position = Vector2(col.position.x, SHEET_TOP)
		_sheet.size = Vector2(SHEET_W,
			maxf(0.0, size.y - EmberMenuCore.CONTENT_BOTTOM_PX - SHEET_TOP))


## The number of building rows on the sheet (smoke/debug) — every building def, incl. dormant.
func row_count() -> int:
	return _rows


# --- The sheet (one row per building def) -----------------------------------------------

func _build_sheet() -> void:
	var defs := DataLoader.load_domain("buildings")
	_sheet = PanelContainer.new()   # transparent under EmberTheme — it groups and pads only
	_sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	_sheet.add_child(margin)
	# Nine building defs already run off the bottom of a 720p screen (the menu probe caught
	# it, and later ages add more) — so the whole-town sheet scrolls inside the content band.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_rows = 0
	var order := BuildPanelCore.survey_order(defs)
	for i in order.size():
		var id: String = order[i]
		box.add_child(_survey_row(defs[id], id))
		_rows += 1
		if i < order.size() - 1:
			box.add_child(HSeparator.new())
	add_child(_sheet)


func _survey_row(def: Dictionary, id: String) -> Control:
	var town: Dictionary = SaveManager.state["town"]
	var level := TownCore.building_level(town, id)
	var maxlvl := (def.get("levels", []) as Array).size()
	var tech_locked := not TownCore.is_unlocked(def, SaveManager.state["tech"]["researched"])

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)

	# Building sketch (small, at its current-or-L1 form).
	var icon := BuildingSilhouette.new()
	icon.custom_minimum_size = Vector2(76, 58)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.setup(id, maxi(level, 1), _font_ui_med)
	hb.add_child(icon)

	# Name + category.
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nv.add_theme_constant_override("separation", 2)
	var name_l := Label.new()
	# Display names go through TownCore.display_name — a built band opener renames
	# the building (Library → University, town-economy.md).
	name_l.text = TownCore.display_name(def, level)   # theme default: UI voice, row size
	nv.add_child(name_l)
	var cat_l := Label.new()
	cat_l.text = str(def.get("category", "")).to_upper()
	cat_l.theme_type_variation = &"EmberHead"
	nv.add_child(cat_l)
	hb.add_child(nv)

	# 3-pip level track.
	hb.add_child(_pip_track(level, maxlvl))

	# Yield + next cost (or the research line when tech-locked).
	var rv := VBoxContainer.new()
	rv.custom_minimum_size = Vector2(230, 0)
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rv.add_theme_constant_override("separation", 2)
	if tech_locked:
		var res := Label.new()
		res.text = RESEARCH_FMT % _gate_name(def)
		res.theme_type_variation = &"EmberNum"
		res.add_theme_color_override("font_color", EmberHud.COL_KNOWLEDGE)
		res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(res)
	else:
		var show_lvl := maxi(level, 1)
		var yl := BuildPanelCore.yield_line((def["levels"][show_lvl - 1] as Dictionary)["effects"])
		var y_l := Label.new()
		y_l.text = str(yl["text"])
		var y_res := str(yl["resource"])
		y_l.add_theme_color_override("font_color",
			EmberHud.resource_color(y_res) if not y_res.is_empty() else EmberHud.COL_INK)
		if level == 0:
			y_l.modulate = Color(1, 1, 1, 0.6)  # unbuilt → its L1 yield, dimmer
		rv.add_child(y_l)
		# The next-level line: cost, "max level", or "Requires <tech>" when the next
		# level's own gate isn't met (age-banded levels, town-economy.md).
		var act := BuildPanelCore.action(def, level, SaveManager.state["tech"]["researched"])
		var nxt := Label.new()
		match str(act["kind"]):
			"maxed":
				nxt.text = MAXED
			"locked":
				nxt.text = BuildPanelCore.LOCKED_FMT % BuildPanelCore.gate_tech_name(
					str(act.get("requires", "")), _tech_defs)
			_:
				nxt.text = NEXT_FMT % _cost_text(act["cost"])
		nxt.theme_type_variation = &"EmberNum"
		nxt.add_theme_color_override("font_color", EmberHud.COL_INK_DIM)
		rv.add_child(nxt)
	hb.add_child(rv)

	if tech_locked:
		hb.modulate = Color(1, 1, 1, 0.6)
	return hb


## The building's level track — the shared drawn pips, sized to the building's own authored
## level count (3 in Age I, 4 for the Library), so a row shows how far it can still go.
func _pip_track(level: int, maxlvl: int) -> Control:
	var track := EmberPips.new()
	track.setup(level, maxlvl)
	return track


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in cost:
		parts.append("%d %s" % [int(cost[id]), id])
	return ", ".join(parts)


func _gate_name(def: Dictionary) -> String:
	var gate: Dictionary = def.get("unlocked_by") if def.get("unlocked_by") != null else {}
	# An unauthored gate tech reads as the placeholder line, never a raw id.
	return BuildPanelCore.gate_tech_name(str(gate.get("id", "")), _tech_defs)


# --- Draw (bg + the carry readout) ------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim()  # the ground every Ember menu sits on
	_resource_readout(size.x - EmberMenuCore.PAD_PX, RES_Y, CARRY_IDS)
