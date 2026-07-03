extends PanelContainer
class_name SlotSelect
## Boot slot-select screen (architecture-schemas.md §1: slot meta is shown WITHOUT
## loading the full save). Code-built fullscreen page like the other panels.
##
## This screen only browses and deletes; it emits `slot_chosen(slot)` and the game
## does the loading (and the checkpoint-resume routing). Delete is two-step: the
## button arms first ("Really delete?"), a second press deletes — destructive
## actions never fire on one click.

signal slot_chosen(slot: int)

const GUTTER_X := 240
const GUTTER_Y := 48

var slot_count: int = 3
var _rows: VBoxContainer
var _armed_delete: int = -1  # slot awaiting delete confirmation; -1 = none


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GUTTER_X)
	margin.add_theme_constant_override("margin_right", GUTTER_X)
	margin.add_theme_constant_override("margin_top", GUTTER_Y)
	margin.add_theme_constant_override("margin_bottom", GUTTER_Y)
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 14)
	margin.add_child(_rows)
	_refresh()


## Public so the headless smoke (and later a "continue last slot" shortcut) can
## drive the real selection path.
func choose(slot: int) -> void:
	slot_chosen.emit(slot)


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "TYCHO — choose a saga"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	_rows.add_child(title)
	var by_slot := {}
	for entry in SaveManager.list_slots():
		by_slot[int(entry["slot"])] = entry
	for slot in range(1, slot_count + 1):
		_rows.add_child(_slot_row(slot, by_slot.get(slot, {})))


func _slot_row(slot: int, entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if entry.is_empty():
		info.text = "Slot %d — empty" % slot
		info.modulate = Color(1, 1, 1, 0.6)
		row.add_child(info)
		row.add_child(_button("New game", func() -> void: choose(slot)))
		return row
	var meta: Dictionary = entry["meta"]
	info.text = "Slot %d — %s · Age %d · %d runs · %s · saved %s" % [
		slot, str(meta["name"]), int(meta["age"]), int(meta["runs"]),
		_fmt_playtime(float(meta["playtime_s"])), str(meta["updated_at"])]
	row.add_child(info)
	var cp_floor := int(entry.get("checkpoint_floor", 0))
	if cp_floor > 0:
		var badge := Label.new()
		badge.text = "⚔ mid-run — resumes at floor %d" % cp_floor
		badge.modulate = Color(1.0, 0.8, 0.4)
		row.add_child(badge)
	row.add_child(_button("Continue", func() -> void: choose(slot)))
	var wants_confirm := _armed_delete == slot
	row.add_child(_button("Really delete?" if wants_confirm else "Delete", func() -> void:
		if _armed_delete == slot:
			SaveManager.delete_slot(slot)
			_armed_delete = -1
		else:
			_armed_delete = slot
		_refresh()))
	return row


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	return b


func _fmt_playtime(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	return "%dh %02dm" % [mins / 60, mins % 60] if mins >= 60 else "%dm" % mins
