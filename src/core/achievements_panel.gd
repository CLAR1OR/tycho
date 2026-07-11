extends Control
class_name AchievementsPanel
## The achievements page (architecture-schemas.md §5) — a fullscreen Slate panel listing
## every authored def: monogram chip + name + desc, progress n/count for progress
## achievements, greyed until unlocked. `hidden` defs render masked ("???") until they
## unlock. Reached from the ESC pause menu's Achievements button (placeholder placement,
## the human may move it).
##
## Conventions follow settings_panel.gd: ESC closes (the house ESC rule), and pause
## ownership — open() pauses only if the tree was not already paused (so it can open
## OVER the pause menu without stealing its pause); close() unpauses only if it owns
## the pause. Spawned on demand onto game.gd's $HUD via game.open_achievements();
## queue_free on close. Built from Controls under SlateTheme (a scrolling list wants
## containers, not _draw). Public open()/close()/row_count()/lists_unlocked() let the
## headless smoke drive the real paths.
##
## HUMAN: everything under "Style / copy" is a PLACEHOLDER — dial like FEEL numbers.

signal closed

# =====================================================================================
# Style / copy — placeholders. (Shared palette + fonts ride SlateTheme/SlateHud.)
# =====================================================================================
## Fullscreen backdrop: the pause menu's near-opaque dark (HUMAN placeholder).
const COL_BACKDROP := Color(12.0 / 255, 11.0 / 255, 16.0 / 255, 0.88)  # #0c0b10 @ 0.88
const COLUMN_W := 700.0
const TOP_MARGIN := 70.0
const BOTTOM_MARGIN := 50.0
const ROW_SEPARATION := 10
const ICON_BOX := 44.0
const LOCKED_ALPHA := 0.45      # locked rows grey out to this
const TITLE := "Achievements"
const MASKED := "???"           # hidden-and-locked rows mask name/desc/icon
const FOOTER := "Esc — back"

var _owns_pause := false
var _rows: VBoxContainer = null
var _row_unlocked: Dictionary = {}   # id -> bool, as rendered (smoke getter)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("achievements_panel")
	theme = SlateTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks so they don't fall through
	var backdrop := ColorRect.new()
	backdrop.color = COL_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var title := Label.new()
	title.text = TITLE
	title.theme_type_variation = &"TitleLabel"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 24.0
	add_child(title)
	var footer := Label.new()
	footer.text = FOOTER
	footer.theme_type_variation = &"DimLabel"
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position.y = -34.0
	add_child(footer)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = TOP_MARGIN
	scroll.offset_bottom = -BOTTOM_MARGIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(center)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(COLUMN_W, 0)
	_rows.add_theme_constant_override("separation", ROW_SEPARATION)
	center.add_child(_rows)
	_rebuild()


## Open the page. Pause the tree only if it was not already paused (so it can open OVER
## the pause menu without stealing its pause — close() then leaves that pause alone).
func open() -> void:
	_owns_pause = not get_tree().paused
	if _owns_pause:
		get_tree().paused = true
	# size syncs in _process (the CanvasLayer-under-_ready quirk — settings_panel's pattern).
	_rebuild()


## Close: unpause if we own the pause, tell the return-target to reappear (via `closed`),
## and free. Nothing to persist — the page only reads.
func close() -> void:
	closed.emit()
	if _owns_pause:
		get_tree().paused = false
	queue_free()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under a CanvasLayer get no layout pass —
	# sync to the viewport, like every other rebuilt Slate screen.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Smoke/test getters ----------------------------------------------------------------

func row_count() -> int:
	return _rows.get_child_count() if _rows != null else 0


## True when `id`'s row rendered as unlocked on the last rebuild.
func lists_unlocked(id: String) -> bool:
	return bool(_row_unlocked.get(id, false))


# --- List ------------------------------------------------------------------------------

func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)  # out of the tree NOW, so row_count() never double-reads
		child.queue_free()
	_row_unlocked = {}
	var defs: Dictionary = Achievements.defs()
	var achievements: Dictionary = SaveManager.profile.get("achievements", {})
	for id: String in _sorted_ids(defs, achievements):
		_rows.add_child(_build_row(id, defs[id], achievements))


## Row order (placeholder — human may re-rank): unlocked first, then locked visible,
## masked hidden last; alphabetical by name within a band. Deterministic for the smoke.
func _sorted_ids(defs: Dictionary, achievements: Dictionary) -> Array:
	var ids: Array = defs.keys()
	var band := func(id: String) -> int:
		if AchievementCore.is_unlocked(achievements, id):
			return 0
		return 2 if bool(defs[id].get("hidden", false)) else 1
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ba: int = band.call(a)
		var bb: int = band.call(b)
		if ba != bb:
			return ba < bb
		return str(defs[a]["name"]) < str(defs[b]["name"]))
	return ids


func _build_row(id: String, def: Dictionary, achievements: Dictionary) -> Control:
	var unlocked := AchievementCore.is_unlocked(achievements, id)
	var masked := bool(def.get("hidden", false)) and not unlocked
	_row_unlocked[id] = unlocked
	var row := PanelContainer.new()
	if not unlocked:
		row.modulate = Color(1, 1, 1, LOCKED_ALPHA)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	# Monogram chip.
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	var mono := Label.new()
	mono.text = MASKED if masked else str(def.get("icon", "?"))
	mono.theme_type_variation = &"TitleLabel"
	mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(mono)
	h.add_child(chip)
	# Name + desc.
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = MASKED if masked else str(def["name"])
	name_label.theme_type_variation = &"TitleLabel"
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = MASKED if masked else str(def["desc"])
	desc.theme_type_variation = &"DimLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	h.add_child(text)
	# Progress readout (right): n/count for progress achievements, blank at count 1.
	var count := AchievementCore.trigger_count(def)
	if count > 1 and not masked:
		var progress := Label.new()
		var n := count if unlocked else mini(AchievementCore.progress_of(achievements, id), count)
		progress.text = "%d/%d" % [n, count]
		progress.theme_type_variation = &"NumLabel"
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(progress)
	return row
