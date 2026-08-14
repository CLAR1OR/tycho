extends EmberHud
class_name DialoguePanel
## Plays one dialogue snippet (PRD §7.12) — a bottom talk box, line by line;
## E / click / accept advances. Fully scripted, the player never chooses (locked
## design). Cutscenes ("kind": "cutscene") dim the world behind the box — the
## painterly stills come later; the dim + narration lines are the placeholder.
##
## Pauses the game while open; emits `finished` (then frees) so the caller does
## the bookkeeping (DialogueCore.mark_shown → save). `advance()` is public for
## the smoke driver. Code-built, like every panel so far.
##
## MIGRATED TO EMBER 2026-08-14 (Tier C — the last Slate surface). A restyle: `play`,
## `advance`, `finished`, the pause semantics and every authored line are byte-identical.
##
## **This is the one surface where Ember does NOT go opaque**, and the reason is worth
## keeping: it is not a screen, it is someone talking to you in the town, and you have to
## be able to see who. So the box gets a SOLID ground of its own (drawn here, bottom band +
## one hairline along its top edge) while the rest of the world stays visible around it.
## The theme's transparent PanelContainer would have left the lines floating on the world —
## legible over a dark wall and not over a lit fountain.
##
## The `E / click — continue` line is gone (the no-on-screen-instructions directive,
## 2026-08-14). Advancing is a single key or a click anywhere; the game teaches it on the
## first line of the first conversation.

signal finished

const BOX_HEIGHT := 150.0
const MARGIN_X := 180.0
## The box's own ground. Opaque like a screen's scrim, but only under the box.
const BOX_LIFT := 16.0        # the box's bottom edge, above the screen's
const CUTSCENE_DIM := Color(0, 0, 0, 0.55)
const FS_WHO := 16            # speaker name (display, gold)
const FS_LINE := 19           # the spoken line (prose — Garamond runs small)
const COL_WHO := Color(1.0, 0.85, 0.5)   # the warm gold the speaker name has always worn

var _def: Dictionary = {}
var _line_index := 0
var _cutscene := false
var _who_label: Label
var _text_label: Label


func _ready() -> void:
	super._ready()  # EmberHud: the five shared fonts
	# EmberHud ignores the mouse; this panel swallows clicks so they never reach the town
	# behind it (a click anywhere advances the line — see _input).
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	_sync_viewport_size()  # EmberHud: the CanvasLayer-under-_ready layout quirk


## The band the box occupies — the ground it is drawn on, and where `_draw` puts its rule.
func _box_rect() -> Rect2:
	return Rect2(MARGIN_X, size.y - BOX_LIFT - BOX_HEIGHT,
		maxf(0.0, size.x - MARGIN_X * 2.0), BOX_HEIGHT)


func _draw() -> void:
	if size.x < 1.0:
		return
	if _cutscene:
		draw_rect(Rect2(Vector2.ZERO, size), CUTSCENE_DIM, true)
	var r := _box_rect()
	draw_rect(r, COL_SCRIM, true)
	_hairline(r.position.x, r.end.x, r.position.y)


func play(def: Dictionary) -> void:
	_def = def
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_panel")
	theme = EmberTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cutscene = str((def.get("scene", {}) as Dictionary).get("kind", "talk")) == "cutscene"
	var box := PanelContainer.new()   # transparent under EmberTheme; _draw paints the band
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = MARGIN_X
	box.offset_right = -MARGIN_X
	box.offset_top = -(BOX_HEIGHT + BOX_LIFT)
	box.offset_bottom = -BOX_LIFT
	add_child(box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)
	_who_label = Label.new()
	# Speaker name in the Cinzel display voice, sized down for the talk box, keeping the
	# warm gold it has always worn.
	_who_label.theme_type_variation = &"EmberTitle"
	_who_label.add_theme_font_size_override("font_size", FS_WHO)
	_who_label.add_theme_color_override("font_color", COL_WHO)
	rows.add_child(_who_label)
	_text_label = Label.new()
	# The spoken line is prose, and reads bigger than the shared body size.
	_text_label.theme_type_variation = &"EmberProse"
	_text_label.add_theme_font_size_override("font_size", FS_LINE)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_text_label)
	get_tree().paused = true
	queue_redraw()
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
