extends Control
class_name DialoguePanel
## Plays one dialogue snippet (PRD §7.12) — a bottom talk box, line by line;
## E / click / accept advances. Fully scripted, the player never chooses (locked
## design). Cutscenes ("kind": "cutscene") dim the world behind the box — the
## painterly stills come later; the dim + narration lines are the placeholder.
##
## Pauses the game while open; emits `finished` (then frees) so the caller does
## the bookkeeping (DialogueCore.mark_shown → save). `advance()` is public for
## the smoke driver. Code-built, like every panel so far.

signal finished

const BOX_HEIGHT := 150.0
const MARGIN_X := 180.0

var _def: Dictionary = {}
var _line_index := 0
var _who_label: Label
var _text_label: Label


func play(def: Dictionary) -> void:
	_def = def
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_panel")
	theme = SlateTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if str((def.get("scene", {}) as Dictionary).get("kind", "talk")) == "cutscene":
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = MARGIN_X
	box.offset_right = -MARGIN_X
	box.offset_top = -(BOX_HEIGHT + 16.0)
	box.offset_bottom = -16.0
	add_child(box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)
	_who_label = Label.new()
	# Speaker name in the Cinzel display voice (TitleLabel), sized down for the talk box,
	# kept the warm gold accent.
	_who_label.theme_type_variation = &"TitleLabel"
	_who_label.add_theme_font_size_override("font_size", 16)
	_who_label.modulate = Color(1.0, 0.85, 0.5)
	rows.add_child(_who_label)
	_text_label = Label.new()
	# The spoken line reads bigger than the shared body size (Garamond runs small).
	_text_label.add_theme_font_size_override("font_size", 19)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_text_label)
	var hint := Label.new()
	hint.text = "E / click — continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.theme_type_variation = &"DimLabel"
	hint.add_theme_font_size_override("font_size", 12)
	rows.add_child(hint)
	get_tree().paused = true
	_show_line()


## Show the next line; past the last one, finish. Public — the smoke drives it.
func advance() -> void:
	_line_index += 1
	if _line_index >= _lines().size():
		_finish()
	else:
		_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines()[_line_index] if _line_index < _lines().size() else {}
	var who := str(line.get("who", ""))
	# An empty speaker is narration (cutscene captions). Names route through the pure
	# display-name map — `linnea` must render as "The Woman", never her name (Act I rule).
	_who_label.text = DialogueCore.display_name(who) if not who.is_empty() else "—"
	_text_label.text = str(line.get("text", ""))


func _finish() -> void:
	get_tree().paused = false
	finished.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var clicked := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _lines() -> Array:
	return (_def.get("scene", {}) as Dictionary).get("lines", [])
