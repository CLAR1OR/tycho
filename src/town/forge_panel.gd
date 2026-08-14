extends Control
class_name ForgePanel
## Mara's Forge — "The anvil" (F2, human-picked 2026-07-08 via claude.ai/design, with the
## "NO stat bars" amendment: the BITE/PACE/REACH bars from the mocks are rejected and built
## nowhere). One weapon at a time lies large on Mara's anvil in the ember light; the three
## tabs on the left switch it; refining is the screen's single ceremony (name + level over the
## weapon, description + pip track + the one gold button in the strip below). Fullscreen,
## code-built, EMBER-themed (migrated 2026-08-14, Tier B); pauses the game while open. Opened
## from Mara once the forge is unlocked (B1). A REBUILD of the old scrolling list — the
## mechanics are byte-identical.
##
## The Ember migration is a RESTYLE: every public method, the transaction, the pause
## semantics and all copy are byte-identical, and the smoke drives it unchanged. What moved:
## the backdrop ColorRect is gone (ForgeAnvil draws the shared scrim), the bottom strip's
## panel is transparent and bounded by a hairline instead of a border, the five refine pips
## are the shared `EmberPips` node rather than five bordered `Panel`s, and Refine is the
## screen's one `EmberAction` — gold is state, so only the thing you came here to press
## wears it.
##
## v1-slice scope: EQUIP one of the three weapons + buy FLAT levels (Resonance Ore, 5 levels,
## +15% damage each). The future resonance-effects track joins as a SECOND (dust-cyan) pip row
## in the strip when it exists. Logic in WeaponCore + ForgePanelCore (pure, tested); this is
## screens + wiring. open()/close()/equip()/upgrade()/selected_weapon() are public so the
## headless smoke drives the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in EmberHud;
# the anvil/weapon/tab visuals in ForgeAnvil/WeaponSilhouette). ALL copy below is HUMAN pen.
# =====================================================================================
const STRIP_GUTTER := 230.0     # left/right inset of the bottom strip
const STRIP_BOTTOM := 26.0
const STRIP_SEP := 28
const SUBTITLE := "She keeps working while you look."
const LEVEL_LINE := "REFINED L%d OF %d · +%d%%/L"   # placeholder format

var _defs: Dictionary = {}
var _selected: String = ""

var _anvil: ForgeAnvil
var _title: Label
var _subtitle: Label
var _strip: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("forge_panel")
	theme = EmberTheme.get_theme()


func open() -> void:
	_defs = WeaponCore.defs()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The anvil stage (drawn + tab hit-tested). It draws the scrim as its first act, so this
	# screen no longer carries a backdrop ColorRect of its own — one scrim dial, in EmberHud.
	_anvil = ForgeAnvil.new()
	_anvil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_anvil)
	_anvil.setup(_defs, select_weapon)
	# Header: title + subtitle (top-left).
	_title = Label.new()
	_title.text = "Mara's Forge"
	_title.theme_type_variation = &"EmberTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"EmberDim"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
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


func _input(event: InputEvent) -> void:
	# ESC closes the panel (the 2026-07-09 ESC-close pass replaces the Close button). The pause
	# menu stays inert: its own _input bails while the tree is paused, and marking the event
	# handled keeps it from opening on the same press.
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under town.gd's $HUD CanvasLayer get no layout pass
	# (size stays 0,0) — sync to the viewport, like the etchings/tech panels do.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	# Title band from EmberMenuCore, so the forge's header sits exactly where the build,
	# survey, market and etchings headers sit. The band's y is the line's CENTRE; a Label
	# positions by its top-left, so lift it by half its measured height.
	var bands := EmberMenuCore.catalogue(size)
	if _title != null:
		_title.position = EmberMenuCore.label_pos(bands["title"], _title.size.y)
	if _subtitle != null:
		_subtitle.position = EmberMenuCore.label_pos(bands["subtitle"], _subtitle.size.y)
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

	_strip = PanelContainer.new()   # transparent under EmberTheme — it groups and pads only
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_strip.add_child(margin)
	# A hairline over the strip, doing the job the panel border used to: it says "this band
	# belongs together" without drawing a box the eye has to read past.
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	stack.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", STRIP_SEP)
	stack.add_child(row)

	# Left: description + level line + pip track.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var desc := Label.new()
	desc.text = str(def.get("desc", ""))       # authored data copy — verbatim
	desc.theme_type_variation = &"EmberProse"  # a weapon's description is flavour, not a label
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(desc)
	var lv := Label.new()
	lv.text = LEVEL_LINE % [level, max_level, per_level]
	lv.theme_type_variation = &"EmberNum"
	left.add_child(lv)
	var pips := EmberPips.new()
	left.add_child(pips)
	pips.setup(level, max_level)   # after add_child: setup sizes the node, _ready re-anchors

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


## The gold refine button below max, or the inert "Flat track maxed" gold-dim label at max.
func _refine_action(def: Dictionary, level: int) -> Control:
	var action := ForgePanelCore.refine_action(def, level)
	if str(action["kind"]) == "maxed":
		var l := Label.new()
		l.text = "Flat track maxed"
		l.theme_type_variation = &"EmberDim"
		l.add_theme_color_override("font_color", EmberHud.COL_ACCENT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var cost := int(action["cost"])
	var b := Button.new()
	# The screen's ONE gold control — refining is why the forge exists. Equip stays a plain
	# frame beside it, so the two never compete for the same read.
	b.theme_type_variation = &"EmberAction"
	b.text = "Refine to L%d  (%d Resonance Ore)" % [int(action["to_level"]), cost]
	b.disabled = Ledger.get_amount("resonance-ore") < float(cost)
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(upgrade.bind(_selected))
	return b
