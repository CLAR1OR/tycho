extends Control
class_name ForgePanel
## Mara's Forge — "The anvil" (F2, human-picked 2026-07-08 via claude.ai/design, with the
## "NO stat bars" amendment: the BITE/PACE/REACH bars from the mocks are rejected and built
## nowhere). One weapon at a time lies large on Mara's anvil in the ember light; the three
## tabs on the left switch it; refining is the screen's single ceremony (name + level over the
## weapon, description + pip track + the one gold button in the strip below). Fullscreen,
## code-built, Slate-themed; pauses the game while open. Opened from Mara once the forge is
## unlocked (B1). A REBUILD of the old scrolling list — the mechanics are byte-identical.
##
## v1-slice scope: EQUIP one of the three weapons + buy FLAT levels (Resonance Ore, 5 levels,
## +15% damage each). The future resonance-effects track joins as a SECOND (dust-cyan) pip row
## in the strip when it exists. Logic in WeaponCore + ForgePanelCore (pure, tested); this is
## screens + wiring. open()/close()/equip()/upgrade()/selected_weapon() are public so the
## headless smoke drives the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in SlateHud;
# the anvil/weapon/tab visuals in ForgeAnvil/WeaponSilhouette). ALL copy below is HUMAN pen.
# =====================================================================================
const MARGIN := 20.0
const STRIP_GUTTER := 230.0     # left/right inset of the bottom strip
const STRIP_BOTTOM := 26.0
const STRIP_SEP := 28
const PIP_SIZE := Vector2(26, 11)
const PIP_RADIUS := 6
const SUBTITLE := "She keeps working while you look."
const LEVEL_LINE := "REFINED L%d OF %d · +%d%%/L"   # placeholder format

var _defs: Dictionary = {}
var _selected: String = ""

var _anvil: ForgeAnvil
var _title: Label
var _subtitle: Label
var _close_btn: Button
var _strip: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("forge_panel")
	theme = SlateTheme.get_theme()


func open() -> void:
	_defs = WeaponCore.defs()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A near-opaque backdrop over the whole screen (the frame bg of the mock).
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = TechChart.COL_FRAME_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# The anvil stage (drawn + tab hit-tested).
	_anvil = ForgeAnvil.new()
	_anvil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_anvil)
	_anvil.setup(_defs, select_weapon)
	# Header: title + subtitle (top-left).
	_title = Label.new()
	_title.text = "Mara's Forge"
	_title.theme_type_variation = &"TitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"DimLabel"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	# Close (bottom-left).
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func() -> void: Sfx.play("ui-click"))
	_close_btn.pressed.connect(close)
	add_child(_close_btn)
	# Default selection = the equipped weapon.
	_selected = str(SaveManager.state["combat"].get("current_weapon", "sword"))
	if not _defs.has(_selected):
		_selected = "sword"
	_anvil.set_selected(_selected)
	_build_strip()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under town.gd's $HUD CanvasLayer get no layout pass
	# (size stays 0,0) — sync to the viewport, like the etchings/tech panels do.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _title != null:
		_title.position = Vector2(MARGIN + 8.0, MARGIN)
	if _subtitle != null:
		_subtitle.position = Vector2(MARGIN + 9.0, MARGIN + 32.0)
	if _close_btn != null:
		_close_btn.position = Vector2(MARGIN, size.y - MARGIN - _close_btn.size.y)
	if _strip != null:
		var w := maxf(0.0, size.x - 2.0 * STRIP_GUTTER)
		_strip.custom_minimum_size.x = w
		_strip.size.x = w
		_strip.position = Vector2(STRIP_GUTTER, size.y - STRIP_BOTTOM - _strip.size.y)


# --- Public (tab callback, strip buttons, and the smoke driver all land here) -----------

## A tab was clicked (or the smoke drives it) — select that weapon and rebuild the strip.
func select_weapon(id: String) -> void:
	_selected = id
	_anvil.set_selected(id)
	_build_strip()


## The currently-selected weapon on the anvil (smoke/debug).
func selected_weapon() -> String:
	return _selected


func equip(weapon_id: String) -> void:
	if not _defs.has(weapon_id):
		push_error("Forge: unknown weapon \"%s\"" % weapon_id)
		return
	SaveManager.state["combat"]["current_weapon"] = weapon_id
	SaveManager.save_current()
	_refresh()


func upgrade(weapon_id: String) -> void:
	if not _defs.has(weapon_id):
		push_error("Forge: unknown weapon \"%s\"" % weapon_id)
		return
	var combat: Dictionary = SaveManager.state["combat"]
	var level := WeaponCore.flat_level(combat, weapon_id)
	var cost := WeaponCore.next_flat_cost(_defs[weapon_id], level)
	if cost.is_empty():
		return  # maxed — the strip already says so
	if not Ledger.try_spend_all(cost, "forge-flat"):
		return  # can't afford — the button is disabled at the price
	SaveManager.state["combat"] = WeaponCore.with_flat_level(combat, weapon_id, level + 1)
	SaveManager.save_current()
	_refresh()


func _refresh() -> void:
	if _anvil != null:
		_anvil.refresh()
	_build_strip()


# --- The bottom strip (rebuilt per selection) -------------------------------------------

func _build_strip() -> void:
	if _strip != null:
		_strip.queue_free()
		_strip = null
	if _selected.is_empty():
		return
	var def: Dictionary = _defs.get(_selected, {})
	var combat: Dictionary = SaveManager.state["combat"]
	var level := WeaponCore.flat_level(combat, _selected)
	var equipped := str(combat.get("current_weapon", "sword")) == _selected
	var max_level := int((def.get("flat", {}) as Dictionary).get("costs", []).size())
	var per_level := int(round(float((def.get("flat", {}) as Dictionary).get(
		"damage_mult_per_level", 0.0)) * 100.0))

	_strip = PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_strip.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", STRIP_SEP)
	margin.add_child(row)

	# Left: description + level line + pip track.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var desc := Label.new()
	desc.text = str(def.get("desc", ""))       # authored data copy — verbatim
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(desc)
	var lv := Label.new()
	lv.text = LEVEL_LINE % [level, max_level, per_level]
	lv.theme_type_variation = &"NumLabel"
	left.add_child(lv)
	left.add_child(_pip_track(level, max_level))

	# Right: the refine action (+ Equip when this weapon isn't the equipped one).
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_refine_action(def, level))
	if not equipped:
		var eq := Button.new()
		eq.text = "Equip"
		eq.pressed.connect(func() -> void: Sfx.play("ui-click"))
		eq.pressed.connect(equip.bind(_selected))
		right.add_child(eq)

	add_child(_strip)


## The 5-pip refine track: filled = ore violet (glow), next = ore-violet outline, rest = slate
## outline; ALL-gold at max (the states card).
func _pip_track(level: int, max_level: int) -> HBoxContainer:
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 7)
	var maxed := level >= max_level
	for i in max_level:
		var pip := Panel.new()
		pip.custom_minimum_size = PIP_SIZE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(PIP_RADIUS)
		sb.set_border_width_all(2)
		if maxed:                                   # all gold at max
			sb.bg_color = SlateHud.COL_READY
			sb.border_color = SlateHud.COL_READY
			sb.shadow_color = Color(SlateHud.COL_READY, 0.5)
			sb.shadow_size = 4
		elif i < level:                             # filled — ore violet + glow
			sb.bg_color = SlateHud.COL_ORE
			sb.border_color = SlateHud.COL_ORE
			sb.shadow_color = Color(SlateHud.COL_ORE, 0.5)
			sb.shadow_size = 4
		elif i == level:                            # next — ore-violet outline
			sb.draw_center = false
			sb.border_color = SlateHud.COL_ORE
		else:                                       # rest — slate outline
			sb.draw_center = false
			sb.border_color = SlateHud.COL_SLATE_BORDER
		pip.add_theme_stylebox_override("panel", sb)
		track.add_child(pip)
	return track


## The gold refine button below max, or the inert "Flat track maxed" gold-dim label at max.
func _refine_action(def: Dictionary, level: int) -> Control:
	var action := ForgePanelCore.refine_action(def, level)
	if str(action["kind"]) == "maxed":
		var l := Label.new()
		l.text = "Flat track maxed"
		l.theme_type_variation = &"DimLabel"
		l.add_theme_color_override("font_color", SlateHud.COL_READY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var cost := int(action["cost"])
	var b := Button.new()
	b.text = "Refine to L%d  (%d Resonance Ore)" % [int(action["to_level"]), cost]
	b.disabled = Ledger.get_amount("resonance-ore") < float(cost)
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(upgrade.bind(_selected))
	return b
