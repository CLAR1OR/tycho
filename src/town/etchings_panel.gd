extends PanelContainer
class_name EtchingsPanel
## Thomas's meditation menu (design/etchings.md, PRD §7.3) — the etching loadout screen,
## opened from the meditation spot once the etchings system is unlocked (B2). Placeholder
## fullscreen scrolling page in the forge/tech-panel mold; pauses the game while open.
##
## All 9 abilities show, grouped by slot. The 5 IMPLEMENTED ones are learnable (spend
## Resonance Dust) and equippable; the 4 DORMANT ones show but say the resonance does not
## answer them yet (implementation status is code, not data — EtchingsCore.IMPLEMENTED).
## Logic is EtchingsCore (pure, tested); this is screens + wiring. learn()/equip() are
## public so the headless smoke drives the real path.

const GUTTER_X := 240
const GUTTER_Y := 24
const SLOT_ORDER: Array[String] = ["rmb", "q", "r"]
const SLOT_TITLE := {"rmb": "RMB — Strikes", "q": "Q — Fields", "r": "R — Surges"}

var _defs: Dictionary = {}
var _rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("etchings_panel")


func open() -> void:
	_defs = EtchingsCore.defs()
	# Grant Push + auto-equip it the first time the screen opens after B2 (idempotent).
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var flags: Dictionary = SaveManager.state["story"]["flags"]
	SaveManager.state["combat"]["etchings"] = EtchingsCore.ensure_baseline(etchings, _defs, flags)
	SaveManager.save_current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GUTTER_X)
	margin.add_theme_constant_override("margin_right", GUTTER_X)
	margin.add_theme_constant_override("margin_top", GUTTER_Y)
	margin.add_theme_constant_override("margin_bottom", GUTTER_Y)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_rebuild()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


# --- Actions (public — buttons and the smoke driver both land here) ---------------

## Learn or level up an etching, spending Resonance Dust. On a fresh unlock it auto-equips
## to an empty matching slot (friendlier than forcing a separate equip). No-op if dormant,
## maxed, or unaffordable.
func learn(id: String) -> void:
	if not _defs.has(id):
		push_error("EtchingsPanel: unknown etching \"%s\"" % id)
		return
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	if not EtchingsCore.can_learn(_defs[id], Ledger.get_amount("resonance-dust"), etchings):
		return
	var was_new := not EtchingsCore.is_unlocked(etchings, id)
	var cost := EtchingsCore.learn_cost(_defs[id], EtchingsCore.level_of(etchings, id))
	if not Ledger.try_spend("resonance-dust", float(cost), "etching"):
		return
	etchings = EtchingsCore.learn(etchings, id)
	# Auto-equip a fresh unlock into an empty slot of its kind.
	var slot := str((_defs[id] as Dictionary).get("slot", ""))
	if was_new and str((etchings.get("slots", {}) as Dictionary).get(slot, "")) == "":
		etchings = EtchingsCore.equip(etchings, slot, id, _defs)
	SaveManager.state["combat"]["etchings"] = etchings
	SaveManager.save_current()
	_rebuild()


func equip(slot: String, id: String) -> void:
	SaveManager.state["combat"]["etchings"] = EtchingsCore.equip(
		SaveManager.state["combat"]["etchings"], slot, id, _defs)
	SaveManager.save_current()
	_rebuild()


# --- Screen -------------------------------------------------------------------------

func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var slots: Dictionary = etchings.get("slots", {})
	_title("Thomas's Favorite Spot — Etchings")
	_label("You carry: %d Resonance Dust" % int(Ledger.get_amount("resonance-dust")))
	for slot: String in SLOT_ORDER:
		_title(str(SLOT_TITLE[slot]))
		var equipped := str(slots.get(slot, ""))
		for id: String in _defs:
			var def: Dictionary = _defs[id]
			if str(def.get("slot", "")) != slot:
				continue
			_etching_row(id, def, etchings, equipped == id)
	_button("Close", close)


func _etching_row(id: String, def: Dictionary, etchings: Dictionary, is_equipped: bool) -> void:
	var level := EtchingsCore.level_of(etchings, id)
	var head := "%s  [%s]%s" % [
		str(def["name"]), str(def.get("principle", "")),
		"  (equipped)" if is_equipped else ""]
	if level > 0:
		head += "  —  L%d" % level
	_label(head)
	if not EtchingsCore.is_implemented(id):
		_dim("The resonance does not answer this one yet.")
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)
	var cost := EtchingsCore.learn_cost(def, level)
	if cost < 0:
		var maxed := Label.new()
		maxed.text = "Mastered (L%d)" % EtchingsCore.MAX_LEVEL
		row.add_child(maxed)
	else:
		var learn_btn := Button.new()
		learn_btn.text = ("Learn" if level == 0 else "Deepen to L%d" % (level + 1)) + "  (%d Dust)" % cost
		learn_btn.disabled = not EtchingsCore.can_learn(def, Ledger.get_amount("resonance-dust"), etchings)
		learn_btn.pressed.connect(func() -> void: Sfx.play("ui-click"))
		learn_btn.pressed.connect(learn.bind(id))
		row.add_child(learn_btn)
	if level >= 1 and not is_equipped:
		var eq := Button.new()
		eq.text = "Equip"
		eq.pressed.connect(func() -> void: Sfx.play("ui-click"))
		eq.pressed.connect(equip.bind(str(def.get("slot", "")), id))
		row.add_child(eq)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	_rows.add_child(l)


func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


func _dim(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.55)
	_rows.add_child(l)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	_rows.add_child(b)
