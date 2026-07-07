extends PanelContainer
class_name ForgePanel
## Mara's Forge (PRD §7.2) — placeholder shop UI, fullscreen scrolling page like
## the tech panel (a centered box is how UIs overflow). Pauses the game while open.
##
## v1-slice scope: EQUIP one of the three weapons and buy FLAT levels (Resonance
## Ore, 5 levels, +damage per level). The resonance-effects track and Forge L2
## land later. Logic in WeaponCore (pure, tested); this is screens + wiring.
## equip()/upgrade() are public so the headless smoke drives the real path.

const GUTTER_X := 240
const GUTTER_Y := 24

var _defs: Dictionary = {}
var _rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("forge_panel")
	theme = SlateTheme.get_theme()


func open() -> void:
	_defs = WeaponCore.defs()
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

func equip(weapon_id: String) -> void:
	if not _defs.has(weapon_id):
		push_error("Forge: unknown weapon \"%s\"" % weapon_id)
		return
	SaveManager.state["combat"]["current_weapon"] = weapon_id
	SaveManager.save_current()
	_rebuild()


func upgrade(weapon_id: String) -> void:
	if not _defs.has(weapon_id):
		push_error("Forge: unknown weapon \"%s\"" % weapon_id)
		return
	var combat: Dictionary = SaveManager.state["combat"]
	var level := WeaponCore.flat_level(combat, weapon_id)
	var cost := WeaponCore.next_flat_cost(_defs[weapon_id], level)
	if cost.is_empty():
		return  # maxed — the row already says so
	if not Ledger.try_spend_all(cost, "forge-flat"):
		return  # can't afford — the row shows the price
	SaveManager.state["combat"] = WeaponCore.with_flat_level(combat, weapon_id, level + 1)
	SaveManager.save_current()
	_rebuild()


# --- Screen -------------------------------------------------------------------------

func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var combat: Dictionary = SaveManager.state["combat"]
	var current := str(combat.get("current_weapon", "sword"))
	_title("Mara's Forge")
	_label("You carry: %d Resonance Ore" % int(Ledger.get_amount("resonance-ore")))
	for id: String in _defs:
		var def: Dictionary = _defs[id]
		var level := WeaponCore.flat_level(combat, id)
		_title("%s%s  —  flat L%d (%.0f%% damage)" % [
			str(def["name"]), "  [equipped]" if id == current else "",
			level, WeaponCore.damage_mult(def, level) * 100.0])
		_label(str(def.get("desc", "")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)
		if id != current:
			var eq := Button.new()
			eq.text = "Equip"
			eq.pressed.connect(equip.bind(id))
			row.add_child(eq)
		var cost := WeaponCore.next_flat_cost(def, level)
		var up := Button.new()
		if cost.is_empty():
			up.text = "Flat track maxed"
			up.disabled = true
		else:
			up.text = "Refine to L%d  (%d Resonance Ore)" % [level + 1, int(cost["resonance-ore"])]
			up.disabled = not Ledger.can_afford(cost)
			up.pressed.connect(upgrade.bind(id))
		row.add_child(up)
	_button("Close", close)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"TitleLabel"
	_rows.add_child(l)


func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	_rows.add_child(b)
