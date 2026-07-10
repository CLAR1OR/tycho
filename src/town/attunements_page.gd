extends Control
class_name AttunementsPage
## The etchings panel's SECOND page — "The Body": Passive Attunements (bible "Passive
## Attunements", PRD §7.4). The E1 "arms" page (the marks) stays the default; a quiet tab
## row swaps to this. Seven ledger-style rows, each with a name, a short line of what it
## does, a 3-pip level track (the house pip grammar), the current effect line, and a
## Deepen button (Resonance Dust — the SAME sink as the active abilities). Read-and-buy
## only; all the cost/level/effect math is AttunementsCore (pure, tested).
##
## HUMAN: everything here is a PLACEHOLDER — the layout consts, the effect-line copy, and
## the ordering. Dial like FEEL numbers. Shared palette/fonts live in SlateHud; the attunement
## numbers themselves are the data (data/attunements/*.json).

# =====================================================================================
# Style / copy — placeholders.
# =====================================================================================
const SHEET_W := 700.0
const SHEET_TOP := 150.0
const DUST_SUBTITLE := "resonance dust"
const FS_DUST := 30
const FS_DUST_LABEL := 11
const DUST_GLYPH_N := 5
## Display order (unknown ids appended sorted → a future attunement never vanishes).
const ORDER: Array[String] = ["vitality", "recovery", "quickening", "resonance-flow",
	"focus", "resilience", "attunement"]

var _defs: Dictionary = {}
var _on_deepen: Callable = Callable()
var _rows: VBoxContainer
var _sheet: PanelContainer
var _font_num: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)


func setup(defs_in: Dictionary, on_deepen_cb: Callable) -> void:
	_defs = defs_in
	_on_deepen = on_deepen_cb
	_build()


## The attunement ids in display order: the authored ORDER first, then any unknown id sorted.
func _ordered_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if _defs.has(id):
			out.append(id)
	var extra: Array[String] = []
	for id: String in _defs:
		if id not in out:
			extra.append(id)
	extra.sort()
	out.append_array(extra)
	return out


func _build() -> void:
	if _rows != null:
		_rows.queue_free()
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	sheet.add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	margin.add_child(_rows)
	var etchings_dust := Ledger.get_amount("resonance-dust")
	var attn: Dictionary = SaveManager.state["combat"].get("attunements", {})
	var ids := _ordered_ids()
	for i in ids.size():
		_rows.add_child(_row(ids[i], _defs[ids[i]], attn, etchings_dust))
		if i < ids.size() - 1:
			_rows.add_child(HSeparator.new())
	# Centre the sheet horizontally, pin it below the header.
	sheet.position = Vector2((size.x - SHEET_W) * 0.5, SHEET_TOP)
	add_child(sheet)
	_sheet = sheet  # kept to recentre on resize (_process)


func _process(_delta: float) -> void:
	if _sheet != null:
		_sheet.position = Vector2((size.x - SHEET_W) * 0.5, SHEET_TOP)


func refresh() -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_build()
	queue_redraw()


# --- One attunement row ---------------------------------------------------------------

func _row(id: String, def: Dictionary, attn: Dictionary, dust: float) -> VBoxContainer:
	var lvl := AttunementsCore.level(attn, id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	# Top line: name + the 3-pip track.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var name_l := Label.new()
	name_l.text = str(def.get("name", id))
	name_l.theme_type_variation = &"TitleLabel"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_l)
	top.add_child(_pips(lvl))
	box.add_child(top)

	# What it does (dim).
	var desc := Label.new()
	desc.text = str(def.get("desc", ""))
	desc.theme_type_variation = &"DimLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	# Bottom line: current effect + the action.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	var eff := Label.new()
	eff.text = _effect_line(def, maxi(1, lvl))  # dormant shows L1's effect
	eff.theme_type_variation = &"NumLabel"
	if lvl < 1:
		eff.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)  # dimmer while un-owned
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(eff)
	bottom.add_child(_action(id, def, attn, dust))
	box.add_child(bottom)
	return box


func _pips(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for lvl in range(1, AttunementsCore.MAX_LEVEL + 1):
		var p := Label.new()
		if lvl <= level:                              # earned — filled gold
			p.text = "●"
			p.add_theme_color_override("font_color", SlateHud.COL_READY)
		elif lvl == level + 1:                        # next — hollow gold
			p.text = "○"
			p.add_theme_color_override("font_color", SlateHud.COL_READY)
		else:                                         # further — slate
			p.text = "○"
			p.add_theme_color_override("font_color", SlateHud.COL_SLATE_BORDER)
		row.add_child(p)
	return row


func _action(id: String, def: Dictionary, attn: Dictionary, dust: float) -> Control:
	var lvl := AttunementsCore.level(attn, id)
	if lvl >= AttunementsCore.MAX_LEVEL:
		var l := Label.new()
		l.text = "Mastered"
		l.theme_type_variation = &"DimLabel"
		l.add_theme_color_override("font_color", SlateHud.COL_READY)  # inert gold-dim
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l
	var cost := AttunementsCore.next_cost(def, lvl)
	var b := Button.new()
	b.text = "Deepen  (%d Dust)" % cost
	b.disabled = dust < float(cost)  # never red — just disabled when short
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Sfx.play("ui-click")
		if _on_deepen.is_valid():
			_on_deepen.call(id))
	return b


## Placeholder effect copy per kind — dial freely (HUMAN).
func _effect_line(def: Dictionary, level: int) -> String:
	var levels: Array = def.get("levels", [])
	if level - 1 < 0 or level - 1 >= levels.size():
		return ""
	var e: Dictionary = levels[level - 1]
	match str(e.get("kind", "")):
		"stat":
			return _stat_line(e.get("mods", []))
		"heal_on_clear":
			return "Heal %d%% of missing on clear" % int(round(float(e.get("pct", 0.0)) * 100.0))
		"find_rate":
			return "+%d%% Dust and Ore find" % int(round((float(e.get("mult", 1.0)) - 1.0) * 100.0))
		"damage_reduction":
			return "-%d damage taken per hit" % int(e.get("amount", 0))
		"ability_cooldown":
			return "Ability cooldowns x%.2f" % float(e.get("mult", 1.0))
	return ""


func _stat_line(mods: Array) -> String:
	if mods.is_empty():
		return ""
	var m: Dictionary = mods[0]
	var stat := str(m.get("stat", ""))
	if stat == "max_health":
		return "+%d max health" % int(m.get("add", 0))
	if stat == "dash_cooldown":
		return "Dash cooldown x%.2f" % float(m.get("mult", 1.0))
	if stat == "attack_damage":
		return "+%d%% damage" % int(round((float(m.get("mult", 1.0)) - 1.0) * 100.0))
	return "%s" % stat


# --- Dust readout (top-right; the E1 mote-cluster pattern) -----------------------------

func _draw() -> void:
	if size.x < 1.0 or _font_num == null:
		return
	var n := int(Ledger.get_amount("resonance-dust"))
	var num := str(n)
	var right := size.x - SlateHud.MARGIN - 6.0
	var top := SlateHud.MARGIN + 6.0
	var nw := _font_num.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_DUST).x
	var ny := top + _font_num.get_ascent(FS_DUST)
	draw_string(_font_num, Vector2(right - nw, ny), num, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FS_DUST, SlateHud.COL_DUST)
	var gx := right - nw - 20.0
	var gy := top + FS_DUST * 0.5
	var offs: Array[Vector2] = [Vector2(0, 0), Vector2(-9, -6), Vector2(-14, 5), Vector2(-4, 9), Vector2(-18, -4)]
	var sizes: Array[float] = [4.0, 2.6, 3.2, 2.2, 2.0]
	for i in mini(DUST_GLYPH_N, offs.size()):
		_diamond(Vector2(gx, gy) + offs[i], sizes[i], Color(SlateHud.COL_DUST, 0.55 + 0.1 * i))
	var lw := _font_num.get_string_size(DUST_SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_DUST_LABEL).x
	draw_string(_font_num, Vector2(right - lw, ny + FS_DUST_LABEL + 4.0), DUST_SUBTITLE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_DUST_LABEL, SlateHud.COL_KEY_TEXT)


func _diamond(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), col)
