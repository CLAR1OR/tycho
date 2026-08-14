extends Control
class_name SlotSelect
## Boot slot-select / title screen — "Under the night sky" (S2, human-picked 2026-07-08 via
## claude.ai/design). This is the game's de-facto TITLE screen (F5 boots here; game.gd plays
## the title track over it). Over the drawn night sky (SlotSelectSky) sit three saga PLAQUES.
##
## THE PLAQUE IS THE BUTTON (design/ui-hud.md): clicking an occupied plaque continues that
## saga (choose(slot)); clicking an empty one starts a new one (choose(slot) too). There are
## no separate Continue / New-game buttons anymore. The screen only browses + deletes; it
## emits `slot_chosen(slot)` and game.gd does the loading + checkpoint-resume routing.
##
## Two-step delete (destructive actions never fire on one click): the quiet ✕ ARMS the slot
## (border turns danger-red, a red "Really delete?" appears, the ✕ goes red); a second ✕
## deletes. ANY other click disarms — clicking a DIFFERENT plaque disarms then continues it;
## clicking the armed plaque's own body just disarms (never continues mid-delete).
##
## Meta strings are the pure SlotSelectCore; this file is pixels + wiring. choose()/on_plaque()/
## on_delete() and the plaque_count()/armed_slot() getters are public so the smoke drives the
## real path.
##
## MIGRATED TO EMBER 2026-08-14 (Tier C) — a restyle; the plaque-is-the-button rule, the
## two-step delete and every public method are byte-identical, and the smoke drives it
## unchanged. **This is where `_dashed_rect` finally pays off.** The empty plaque always
## wanted a dashed frame and could not have one, because `StyleBoxFlat` has no dashed border
## — the old source said so out loud and approximated it with a thinner, dimmer box. The
## plaque is now a plain Control wearing one `EmberFrame` child, so idle / hover / armed /
## empty are four states of one mark and the empty one is a REAL dashed frame. The two meta
## badges lost their boxes (gold tracked caps carry them).
##
## HUMAN: everything under "Style / copy" is a PLACEHOLDER — plaque sizes, frame states, the
## flavor/subtitle copy. Dial like FEEL numbers (shared palette/fonts live in EmberHud; the
## sky's own placeholders in SlotSelectSky).

signal slot_chosen(slot: int)
## A quiet "settings" word in the corner was clicked (SET1, 2026-07-09) — game.gd opens the page.
signal settings_requested

# =====================================================================================
# Style / copy — placeholders. (Shared palette + fonts are in EmberHud.)
# =====================================================================================
const PLAQUE_W := 620.0
const PLAQUE_H := 74.0
const PLAQUE_GAP := 22.0
const PLAQUE_TOP_FRAC := 0.417          # top of the plaque stack, of size.y (300/720)
const PAD_X := 22
const HBOX_SEP := 18
const RN_W := 26.0
const NAME_W := 150.0
const DEL_SIZE := 26.0
const FS_RN := 15
const FS_NAME_ROW := 20                 # a saga's name on its plaque (display)
const FS_META := 12
const FS_CHIP := 10
const FS_CONFIRM := 15
const FS_FLAVOR := 14
const CHIP_TRACKING := 1.2
const NEW_NAME := "New saga"             # placeholder copy
const FLAVOR := "an unwritten sky"       # placeholder copy
const SETTINGS_TEXT := "settings"        # placeholder copy — the quiet corner link (SET1)
const FS_SETTINGS := 15
const SETTINGS_MARGIN := 24.0
const CONFIRM_TEXT := "Really delete?"   # existing string — byte-identical
const ROMAN := ["I", "II", "III", "IV", "V", "VI"]

var slot_count: int = 3

var _sky: SlotSelectSky
var _plaques: Array[Control] = []
var _armed_delete: int = -1              # slot awaiting delete confirmation; -1 = none
var _settings_link: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("slot_select")
	theme = EmberTheme.get_theme()
	_sky = SlotSelectSky.new()
	add_child(_sky)
	# A quiet "settings" word in the bottom-right corner (SET1) — hover lightens, click opens the
	# page. Unobtrusive: it does not disturb the sky/plaque composition.
	_settings_link = Label.new()
	_settings_link.text = SETTINGS_TEXT
	_settings_link.theme_type_variation = &"EmberDim"
	_settings_link.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_link.add_theme_font_size_override("font_size", FS_SETTINGS)
	_settings_link.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("ui-click")
			settings_requested.emit())
	_settings_link.mouse_entered.connect(func() -> void:
		_settings_link.add_theme_color_override("font_color", EmberHud.COL_INK))
	_settings_link.mouse_exited.connect(func() -> void:
		_settings_link.add_theme_color_override("font_color", EmberHud.COL_INK_DIM))
	add_child(_settings_link)
	_refresh()


## Public so the headless smoke can drive the real selection path.
func choose(slot: int) -> void:
	slot_chosen.emit(slot)


## The ✕ handler: first press arms, a second press on the armed slot deletes.
func on_delete(slot: int) -> void:
	Sfx.play("ui-click")
	if _armed_delete == slot:
		SaveManager.delete_slot(slot)
		_armed_delete = -1
	else:
		_armed_delete = slot
	_refresh()


## A plaque body was clicked. Armed rules: same plaque → just disarm (never continue);
## different plaque → disarm then continue it; nothing armed → continue.
func on_plaque(slot: int) -> void:
	Sfx.play("ui-click")
	if _armed_delete != -1:
		var same := _armed_delete == slot
		_armed_delete = -1
		if same:
			_refresh()                    # disarm only — must NOT choose
			return
		# different plaque: disarm + perform its normal choose (screen transitions away).
	choose(slot)


# --- Debug (the headless smoke reads these) ------------------------------------------

func plaque_count() -> int:
	return _plaques.size()


func armed_slot() -> int:
	return _armed_delete


## The corner settings link exists (smoke/debug — SET1).
func has_settings_entry() -> bool:
	return _settings_link != null


# --- Build ---------------------------------------------------------------------------

func _refresh() -> void:
	for p in _plaques:
		p.queue_free()
	_plaques.clear()
	var by_slot := {}
	for entry in SaveManager.list_slots():
		by_slot[int(entry["slot"])] = entry
	for slot in range(1, slot_count + 1):
		var plaque := _build_plaque(slot, by_slot.get(slot, {}))
		add_child(plaque)
		_plaques.append(plaque)


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under game.gd's $HUD CanvasLayer get no layout
	# pass (size stays 0,0) — sync to the viewport, like the other rebuilt Slate screens.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	# The sky is a full-rect child, and anchors set in a child's own _ready get no layout
	# pass under a CanvasLayer (the house quirk) — so drive its size from here. Without
	# this the sky stays 0x0, its `_draw` bails on the size guard, and the title screen
	# renders as bare plaques on whatever is behind them.
	if _sky != null and _sky.size != size:
		_sky.size = size
	# Re-lay the plaques: centred column, stacked from PLAQUE_TOP_FRAC.
	var x := (size.x - PLAQUE_W) * 0.5
	var top := size.y * PLAQUE_TOP_FRAC
	var step := PLAQUE_H + PLAQUE_GAP
	for i in _plaques.size():
		var p := _plaques[i]
		p.size = Vector2(PLAQUE_W, PLAQUE_H)
		p.position = Vector2(x, top + step * i)
	if _settings_link != null:
		_settings_link.position = Vector2(
			size.x - _settings_link.size.x - SETTINGS_MARGIN,
			size.y - _settings_link.size.y - SETTINGS_MARGIN)


func _build_plaque(slot: int, entry: Dictionary) -> Control:
	var empty := entry.is_empty()
	var armed := _armed_delete == slot
	# A plain Control, not a PanelContainer: the plaque wears an EmberFrame (which a
	# PanelContainer would treat as content to lay out) and the frame is the whole visual.
	var plaque := Control.new()
	plaque.custom_minimum_size = Vector2(PLAQUE_W, PLAQUE_H)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := EmberFrame.new()
	plaque.add_child(frame)
	_style_frame(frame, empty, armed, false)
	# The plaque IS the button.
	plaque.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_plaque(slot))
	if not armed:
		plaque.mouse_entered.connect(func() -> void: _style_frame(frame, empty, false, true))
		plaque.mouse_exited.connect(func() -> void: _style_frame(frame, empty, false, false))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAD_X)
	margin.add_theme_constant_override("margin_right", PAD_X)
	plaque.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", HBOX_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	# Roman numeral.
	var rn := _label(str(ROMAN[slot - 1]) if slot - 1 < ROMAN.size() else str(slot),
		&"EmberTitle", EmberHud.COL_INK_DIM, FS_RN)
	rn.custom_minimum_size = Vector2(RN_W, 0)
	row.add_child(rn)

	if empty:
		var nm := _label(NEW_NAME, &"EmberTitle", EmberHud.COL_INK_DIM, FS_NAME_ROW)
		nm.custom_minimum_size = Vector2(NAME_W, 0)
		row.add_child(nm)
		var flavor := _label(FLAVOR, &"EmberProse", EmberHud.COL_INK_DIM, FS_FLAVOR)
		flavor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(flavor)
		return plaque

	var meta: Dictionary = entry["meta"]
	# Name.
	var name_l := _label(str(meta.get("name", "")), &"EmberTitle", EmberHud.COL_INK,
		FS_NAME_ROW)
	name_l.custom_minimum_size = Vector2(NAME_W, 0)
	row.add_child(name_l)

	if armed:
		# Armed: a red "Really delete?" takes the flex space (the plaque has turned).
		var confirm := _label(CONFIRM_TEXT, &"EmberTitle", EmberHud.COL_DANGER, FS_CONFIRM)
		confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(confirm)
	else:
		# Meta line in three parts so the runs count takes the knowledge colour.
		row.add_child(_meta_box(meta))

	# Mid-run badge (gold, from checkpoint_floor).
	var badge := SlotSelectCore.badge_text(int(entry.get("checkpoint_floor", 0)))
	if not badge.is_empty():
		row.add_child(_chip(badge))
	# Act I complete badge — only ever renders once saves write act1_complete (Phase E).
	# Absent until then; no waiting UI.
	if bool(meta.get("act1_complete", false)):
		row.add_child(_chip("ACT I"))

	# The delete ✕.
	row.add_child(_del_button(slot, armed))
	return plaque


func _meta_box(meta: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts := SlotSelectCore.meta_parts(meta)
	box.add_child(_label(str(parts["prefix"]), &"EmberNum", EmberHud.COL_INK_DIM, FS_META))
	box.add_child(_label(str(parts["runs"]), &"EmberNum", EmberHud.COL_KNOWLEDGE, FS_META))
	box.add_child(_label(str(parts["suffix"]), &"EmberNum", EmberHud.COL_INK_DIM, FS_META))
	return box


func _label(text: String, variation: StringName, col: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	if fs > 0:
		l.add_theme_font_size_override("font_size", fs)
	return l


## A meta badge — gold tracked caps, no box. Both badges (mid-run, ACT I) are state, which
## is what gold means here; the outline-vs-filled distinction Slate drew between them was
## decoration, and the two words already say which is which.
func _chip(text: String) -> Control:
	var l := _label(text, &"EmberHead", EmberHud.COL_ACCENT, FS_CHIP)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_constant_override("outline_size", 0)
	return l


## The delete ✕ — a small round-ish button that arms/deletes via on_delete. Red when armed.
func _del_button(slot: int, armed: bool) -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(DEL_SIZE, DEL_SIZE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var border := EmberHud.COL_DANGER if armed else EmberHud.COL_RING
	var fg := EmberHud.COL_DANGER if armed else EmberHud.COL_INK_DIM
	var normal := _del_box(border)
	var hover := _del_box(EmberHud.COL_DANGER)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", EmberHud.COL_DANGER)
	b.add_theme_color_override("font_pressed_color", EmberHud.COL_DANGER)
	b.add_theme_font_size_override("font_size", FS_CHIP + 2)
	b.pressed.connect(on_delete.bind(slot))
	return b


func _del_box(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)   # a frame over the sky, like every Ember control
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(DEL_SIZE * 0.5))
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


## The plaque's frame, per state — the four states of ONE mark.
##   armed  danger-red frame over a red wash (the plaque has turned)
##   hover  ink frame, brighter wash
##   empty  a REAL dashed frame — an unwritten saga, drawn as an outline waiting to be
##          filled. This is the mark Slate had to approximate, and the reason EmberFrame
##          exists (StyleBoxFlat cannot draw a dashed border).
##   idle   a hairline over the resting wash
func _style_frame(frame: EmberFrame, empty: bool, armed: bool, hover: bool) -> void:
	if armed:
		frame.setup(EmberFrame.Shape.RECT, EmberHud.COL_DANGER,
			Color(EmberHud.COL_DANGER, 0.10))
	elif hover:
		frame.setup(EmberFrame.Shape.RECT, EmberHud.COL_INK, EmberHud.COL_ROW_HOVER)
	elif empty:
		frame.setup(EmberFrame.Shape.DASHED, EmberHud.COL_RING,
			Color(EmberHud.COL_ROW, EmberHud.COL_ROW.a * 0.5))
	else:
		frame.setup(EmberFrame.Shape.RECT, EmberHud.COL_HAIR, EmberHud.COL_ROW)
