extends EmberHud
class_name AttunementsPage
## The etchings panel's SECOND page — "The Body": Passive Attunements (bible "Passive
## Attunements", PRD §7.4). The E1 "arms" page (the marks) stays the default; a quiet tab
## row swaps to this. Seven ledger-style rows, each with a name, a short line of what it
## does, a 3-pip level track (the house pip grammar), the current effect line, and a
## Deepen button (Resonance Dust — the SAME sink as the active abilities). Read-and-buy
## only; all the cost/level/effect math is AttunementsCore (pure, tested).
##
## MIGRATED TO EMBER 2026-08-14 (Tier B) — a restyle; every public method and all copy are
## byte-identical and the smoke drives it unchanged. The sheet's panel is transparent and its
## rows are separated by real hairlines (EmberTheme styles `HSeparator`); the "●/○" text pips
## became the shared drawn `EmberPips`; and the hand-rolled mote cluster + big Dust number
## became `_resource_readout`, so Dust wears the same mark here as on the arms page it shares
## a screen with. The sheet is centred by `EmberMenuCore.column`, which is the same band the
## settings and achievements pages will use — that is what makes a read-down page in this
## game look like a read-down page anywhere else in it.
##
## HUMAN: everything here is a PLACEHOLDER — the layout consts, the effect-line copy, and the
## ordering. Dial like FEEL numbers. Shared palette/fonts live in EmberHud; the attunement
## numbers themselves are the data (data/attunements/*.json).

# =====================================================================================
# Style / copy — placeholders.
# =====================================================================================
const SHEET_W := 700.0
const SHEET_TOP := 150.0
const RES_Y := 40.0   # the shared Dust readout's row, level with the title band
## Display order (unknown ids appended sorted → a future attunement never vanishes).
const ORDER: Array[String] = ["vitality", "recovery", "quickening", "resonance-flow",
	"focus", "resilience", "attunement"]

var _defs: Dictionary = {}
var _on_deepen: Callable = Callable()
var _rows: VBoxContainer
var _sheet: PanelContainer


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	# EmberHud defaults to MOUSE_FILTER_IGNORE; this page is a buy screen and takes clicks.
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	var sheet := PanelContainer.new()   # transparent under EmberTheme — it groups and pads
	sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	sheet.add_child(margin)
	# Seven rows already run off the bottom of a 720p screen (the menu probe caught it), and
	# the attunement roster is budgeted to grow — so the sheet scrolls inside the content
	# band rather than trusting the roster to stay short. This is what EmberTheme's
	# hairline-thin scrollbar styling exists for.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)
	var etchings_dust := Ledger.get_amount("resonance-dust")
	var attn: Dictionary = SaveManager.state["combat"].get("attunements", {})
	var ids := _ordered_ids()
	for i in ids.size():
		_rows.add_child(_row(ids[i], _defs[ids[i]], attn, etchings_dust))
		if i < ids.size() - 1:
			_rows.add_child(HSeparator.new())
	sheet.position = _sheet_pos()
	sheet.size = Vector2(SHEET_W, _sheet_h())
	add_child(sheet)
	_sheet = sheet  # kept to recentre + re-height on resize (_process)


## The sheet's top-left. EmberMenuCore.column centres it in the same content band every
## other read-down Ember page uses, so the margins agree across screens.
func _sheet_pos() -> Vector2:
	var col: Rect2 = EmberMenuCore.column(size, SHEET_W)["column"]
	return Vector2(col.position.x, SHEET_TOP)


## How tall the sheet may be: down to the content band's floor, never past it.
func _sheet_h() -> float:
	return maxf(0.0, size.y - EmberMenuCore.CONTENT_BOTTOM_PX - SHEET_TOP)


func _process(_delta: float) -> void:
	if _sheet != null:
		_sheet.position = _sheet_pos()
		_sheet.size = Vector2(SHEET_W, _sheet_h())


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
	name_l.text = str(def.get("name", id))   # theme default: the UI voice at list-row size
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_l)
	var track := EmberPips.new()
	top.add_child(track)
	box.add_child(top)

	# What it does (dim).
	var desc := Label.new()
	desc.text = str(def.get("desc", ""))
	desc.theme_type_variation = &"EmberDim"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	# Bottom line: current effect + the action.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	var eff := Label.new()
	eff.text = _effect_line(def, maxi(1, lvl))  # dormant shows L1's effect
	eff.theme_type_variation = &"EmberNum"
	if lvl < 1:
		eff.add_theme_color_override("font_color", EmberHud.COL_INK_DIM)  # dimmer while un-owned
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(eff)
	bottom.add_child(_action(id, def, attn, dust))
	box.add_child(bottom)
	# After add_child: setup() sizes the node, and EmberPips' own _ready re-anchors it.
	track.setup(lvl, AttunementsCore.MAX_LEVEL)
	return box


func _action(id: String, def: Dictionary, attn: Dictionary, dust: float) -> Control:
	var lvl := AttunementsCore.level(attn, id)
	if lvl >= AttunementsCore.MAX_LEVEL:
		var l := Label.new()
		l.text = "Mastered"
		l.theme_type_variation = &"EmberDim"
		l.add_theme_color_override("font_color", EmberHud.COL_ACCENT)  # inert gold
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l
	var cost := AttunementsCore.next_cost(def, lvl)
	var b := Button.new()
	# Seven rows, so seven Deepen buttons: these stay PLAIN frames on purpose. Gold marks the
	# one thing a screen wants you to press, and a page of gold buttons marks nothing.
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


# --- Draw (the scrim + the shared Dust readout) ----------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	# This page covers the arms page, which is what draws the scrim on the marks tab — so it
	# has to lay its own down, or the arms would show through the ledger.
	_scrim()
	_resource_readout(size.x - EmberMenuCore.PAD_PX, RES_Y, ["resonance-dust"])
