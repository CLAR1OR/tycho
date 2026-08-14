extends EmberHud
class_name SettingsPanel
## Settings screen — "The quiet page" (SET1, human-picked 2026-07-09 via claude.ai/design,
## "Settings" group; both proposals accepted — the DISPLAY window row + the dormant ASSIST row).
##
## A fullscreen page over an opaque ground: three volume rows (12-notch tracks that live-apply
## to the audio buses as the hand moves), a Window mode chip pair, and a dormant
## Reinforcement-Protocol row (a home for assist mode when it lands — PRD IC-10). Everything is
## drawn in `_draw`; mouse hit-testing is in `_gui_input`; ESC / arrows in `_input`.
##
## MIGRATED TO EMBER 2026-08-14 (Tier C) — a restyle; every public method, the live-apply /
## persist-on-close contract, the pause ownership and all copy are byte-identical, and the smoke
## drives it unchanged. Being entirely drawn, it just became an `EmberHud` subclass: the backdrop
## ColorRect gave way to `_scrim()`, the section heads to the shared `_section`, and the two
## window chips to `_row_box` — the same selected/hover/idle mark a weapon row wears in the forge,
## which is the point, since picking a window mode and picking a weapon are the same gesture.
##
## Live-apply, persist-on-close: every value change writes `SaveManager.profile.settings` and calls
## Music.apply_audio_settings() (audio) / SettingsPanel.apply_window_mode() (display) IMMEDIATELY;
## the profile is written to disk ONCE, on close(). NO Apply/Confirm buttons, NO Close button —
## ESC closes (the house ESC rule).
##
## Pause ownership: open() pauses only if the tree was not already paused (so it can open OVER the
## pause menu without stealing its pause); close() unpauses only if it owns the pause. Spawned on
## demand onto game.gd's $HUD via game.open_settings(); queue_free on close.
##
## Logic is pure SettingsCore; this is pixels + wiring. open()/close()/set_volume()/set_window_mode()
## + the volume()/window_mode() getters are public so the headless smoke drives the real paths.
##
## HUMAN: everything under "Style / copy" is a PLACEHOLDER — dial like FEEL numbers (the shared
## palette/fonts live in EmberHud; the two local colours + all copy are placeholders here).

signal closed

# =====================================================================================
# Style / copy — placeholders. (Shared palette + fonts are in EmberHud.)
# =====================================================================================
## Hover-bright for a lit notch (the O1 precedent).
const COL_HOVER_BRIGHT := Color(191.0 / 255, 242.0 / 255, 255.0 / 255)  # #bff2ff
const COL_NOTCH_UNLIT := Color(1.0, 1.0, 1.0, 0.16)   # the shared unfilled-bar wash

const COLUMN_W := 700.0
const TOP_FRAC := 0.13          # top of the content column, of size.y
const NAME_W := 170.0
const NUM_W := 84.0
const RIGHT_PAD := 20.0
const ROW_H := 56.0
const TRACK_H := 26.0
const NOTCH_COUNT := 12
const NOTCH_GAP := 6.0
const SECTION_GAP := 30.0
const SECTION_HEADER_H := 34.0
const CHIP_W := 132.0
const CHIP_GAP := 12.0
const CHIP_H := 34.0
const FS_TITLE_BIG := 40
const FS_SUBTITLE := 16   # NOT `FS_SUB` — EmberHud declares that, and a shadowed const is
                          # a parse error the editor pass does not report (see conventions)
const FS_SECTION := 13
const FS_NAME := 18
const FS_NUM := 30
const FS_CHIP := 13
const FS_NOTE := 15
const FS_FOOTER := 14

const TITLE := "Settings"
const SUBTITLE := "Set once. Kept for you, not the saga."
const SEC_SOUND := "SOUND"
const SEC_DISPLAY := "DISPLAY"
const SEC_ASSIST := "ASSIST"
const WINDOW_LABEL := "Window"
const CHIP_WINDOWED := "WINDOWED"
const CHIP_FULLSCREEN := "FULLSCREEN"
const ASSIST_NAME := "Reinforcement Protocol"
const ASSIST_NOTE := "The nanobots do not answer this one yet."
const FOOTER := "Changes take hold as you make them."

var _owns_pause := false
var _focus_row := 0             # keyboard focus among the volume rows (0..2)
var _hover_track := -1
var _hover_chip := -1
var _dragging := -1             # the row track being dragged, or -1


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")
	theme = EmberTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks so they don't fall through
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)


## Open the page. Pause the tree only if it was not already paused (so it can open OVER the pause
## menu without stealing its pause — close() then leaves that pause alone).
func open() -> void:
	_owns_pause = not get_tree().paused
	if _owns_pause:
		get_tree().paused = true
	# `size` is synced to the viewport in _process (the CanvasLayer-under-_ready quirk) — NOT here:
	# open() runs synchronously right after _ready (game.open_settings adds then opens), and setting
	# size before the first layout pass warns. _process picks it up next frame (build_panel's pattern).
	grab_focus()
	queue_redraw()


## Close: persist the profile once (values were applied live), unpause if we own the pause, tell the
## return-target to reappear (via `closed`), and free.
func close() -> void:
	SaveManager.save_profile()
	closed.emit()
	if _owns_pause:
		get_tree().paused = false
	queue_free()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under a CanvasLayer get no layout pass (size stays 0,0)
	# — sync to the viewport, like every other rebuilt Slate screen.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_focus_row = maxi(0, _focus_row - 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_focus_row = mini(SettingsCore.VOLUME_ROWS.size() - 1, _focus_row + 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_nudge_focused(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_nudge_focused(1)
		get_viewport().set_input_as_handled()


func _nudge_focused(dir: int) -> void:
	var key := str(SettingsCore.VOLUME_ROWS[_focus_row]["key"])
	set_volume(key, SettingsCore.nudge(volume(key), dir))
	Sfx.play("ui-click")


# --- Public API (the smoke drives these; they are the same code paths the mouse uses) --------

## Set a volume exactly as a drag would: clamp, write the profile, live-apply to the bus.
func set_volume(key: String, v: float) -> void:
	SaveManager.profile["settings"][key] = SettingsCore.value_from_ratio(v)
	Music.apply_audio_settings()
	queue_redraw()


func volume(key: String) -> float:
	return float((SaveManager.profile.get("settings", {}) as Dictionary).get(key, 1.0))


## Set the window mode as a chip click would: write the profile, apply immediately (headless-guarded).
func set_window_mode(mode: String) -> void:
	var m := "fullscreen" if mode == "fullscreen" else "windowed"
	SaveManager.profile["settings"]["window_mode"] = m
	apply_window_mode(SaveManager.profile)
	queue_redraw()


func window_mode() -> String:
	return SettingsCore.window_mode(SaveManager.profile)


## Map the profile's window mode onto the real window (headless-guarded so the smoke never tries).
## Static so game.gd can apply it once at boot too; the profile write is the caller's job.
static func apply_window_mode(profile: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := SettingsCore.window_mode(profile)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if mode == "fullscreen"
		else DisplayServer.WINDOW_MODE_WINDOWED)


# --- Input (mouse) ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging >= 0:
			_set_from_x(_dragging, mm.position.x)
			return
		var ht := _track_at(mm.position)
		var hc := _chip_at(mm.position)
		if ht != _hover_track or hc != _hover_chip:
			_hover_track = ht
			_hover_chip = hc
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var ti := _track_at(mb.position)
			if ti >= 0:
				_dragging = ti
				_focus_row = ti
				_set_from_x(ti, mb.position.x)
				return
			var ci := _chip_at(mb.position)
			if ci >= 0:
				set_window_mode("fullscreen" if ci == 1 else "windowed")
				Sfx.play("ui-click")
		else:
			if _dragging >= 0:
				_dragging = -1
				Sfx.play("ui-click")  # the drag-END clicks, not per-pixel


## Set a track's value from a mouse x, mapping across the track rect.
func _set_from_x(row: int, x: float) -> void:
	var track: Rect2 = _layout()["tracks"][row]["rect"]
	var r := (x - track.position.x) / maxf(track.size.x, 1.0)
	set_volume(str(SettingsCore.VOLUME_ROWS[row]["key"]), SettingsCore.value_from_ratio(r))


func _track_at(pos: Vector2) -> int:
	# A generous hit band: the whole row height around the track, so a click just above/below still lands.
	for t: Dictionary in _layout()["tracks"]:
		var band := Rect2(t["rect"].position.x, t["row_y"], t["rect"].size.x, ROW_H)
		if band.has_point(pos):
			return int(t["index"])
	return -1


func _chip_at(pos: Vector2) -> int:
	var chips: Array = _layout()["chips"]
	for i in chips.size():
		if (chips[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1


# --- Layout (pure from size — shared by _draw and hit-testing) -------------------------------

func _layout() -> Dictionary:
	var col_x := (size.x - COLUMN_W) * 0.5
	var track_w := COLUMN_W - NAME_W - NUM_W - RIGHT_PAD
	var out := {"col_x": col_x}
	var y := size.y * TOP_FRAC
	out["title_y"] = y
	y += FS_TITLE_BIG + 6.0
	out["subtitle_y"] = y
	y += FS_SUBTITLE + SECTION_GAP
	out["sound_y"] = y
	y += SECTION_HEADER_H
	var tracks: Array = []
	for i in SettingsCore.VOLUME_ROWS.size():
		var rect := Rect2(col_x + NAME_W, y + (ROW_H - TRACK_H) * 0.5, track_w, TRACK_H)
		tracks.append({"rect": rect, "row_y": y, "index": i})
		y += ROW_H
	out["tracks"] = tracks
	y += SECTION_GAP
	out["display_y"] = y
	y += SECTION_HEADER_H
	out["window_row_y"] = y
	var chips_left := col_x + COLUMN_W - (CHIP_W * 2.0 + CHIP_GAP)
	var chip_y := y + (ROW_H - CHIP_H) * 0.5
	out["chips"] = [
		{"rect": Rect2(chips_left, chip_y, CHIP_W, CHIP_H), "mode": "windowed"},
		{"rect": Rect2(chips_left + CHIP_W + CHIP_GAP, chip_y, CHIP_W, CHIP_H), "mode": "fullscreen"},
	]
	y += ROW_H + SECTION_GAP
	out["assist_y"] = y
	y += SECTION_HEADER_H
	out["assist_row_y"] = y
	y += ROW_H + SECTION_GAP
	out["footer_y"] = y
	return out


# --- Draw ------------------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim()  # the opaque ground every Ember screen sits on
	var g := _layout()
	var col_x: float = g["col_x"]
	var center_x := col_x + COLUMN_W * 0.5
	# Title + a gold flourish under it — the anchor's "this is a page" mark, and the reason
	# this screen needs no chrome at all.
	_text(_font_display, TITLE, FS_TITLE_BIG, COL_INK, center_x, g["title_y"], HORIZONTAL_ALIGNMENT_CENTER)
	_text(_font_body, SUBTITLE, FS_SUBTITLE, COL_INK_DIM, center_x, g["subtitle_y"], HORIZONTAL_ALIGNMENT_CENTER)
	# SOUND
	_head(SEC_SOUND, col_x, float(g["sound_y"]), 1.0)
	for t: Dictionary in g["tracks"]:
		_draw_volume_row(int(t["index"]), t["rect"], float(t["row_y"]), col_x)
	# DISPLAY
	_head(SEC_DISPLAY, col_x, float(g["display_y"]), 1.0)
	_draw_window_row(g, col_x, float(g["window_row_y"]))
	# ASSIST (dim, inert)
	_head(SEC_ASSIST, col_x, float(g["assist_y"]), 0.4)
	_draw_assist_row(col_x, float(g["assist_row_y"]))
	# Footer
	_text(_font_body, FOOTER, FS_FOOTER, COL_INK_DIM, center_x, g["footer_y"], HORIZONTAL_ALIGNMENT_CENTER)


## A section head, via the shared `_section` primitive (tracked caps over a hairline).
## Named `_head` because `_section` is the parent's and its signature differs.
func _head(label: String, col_x: float, top_y: float, alpha: float) -> void:
	_section(col_x, col_x + COLUMN_W, top_y + SECTION_HEADER_H * 0.35, label,
		Color(COL_INK_DIM, alpha))


func _draw_volume_row(index: int, track: Rect2, row_y: float, col_x: float) -> void:
	var key := str(SettingsCore.VOLUME_ROWS[index]["key"])
	var label := str(SettingsCore.VOLUME_ROWS[index]["label"])
	var v := volume(key)
	var muted := v <= 0.0
	var focused := index == _focus_row
	var hovered := index == _hover_track
	# Name (left) — muted rows dim; the focused row brightens.
	var name_col := COL_INK_DIM if muted else COL_INK
	if focused and not muted:
		name_col = COL_HOVER_BRIGHT
	_text_band(_font_display, label, FS_NAME, name_col, col_x, row_y, ROW_H, HORIZONTAL_ALIGNMENT_LEFT)
	# Notches.
	var lit := SettingsCore.notches_lit(v, NOTCH_COUNT)
	var nw := (track.size.x - float(NOTCH_COUNT - 1) * NOTCH_GAP) / float(NOTCH_COUNT)
	for n in NOTCH_COUNT:
		var nx := track.position.x + float(n) * (nw + NOTCH_GAP)
		var r := Rect2(nx, track.position.y, nw, track.size.y)
		var col := COL_NOTCH_UNLIT
		if n < lit:
			col = COL_HOVER_BRIGHT if hovered else COL_DUST
			# The moving edge notch renders gold while dragging.
			if _dragging == index and n == lit - 1:
				col = COL_ACCENT
		draw_rect(r, col)
	# Number (right).
	var num := str(SettingsCore.display_value(v))
	var num_col := COL_INK_DIM if muted else COL_INK
	_text_band(_font_num, num, FS_NUM, num_col, col_x + COLUMN_W - RIGHT_PAD, row_y, ROW_H, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_window_row(g: Dictionary, col_x: float, row_y: float) -> void:
	_text_band(_font_display, WINDOW_LABEL, FS_NAME, COL_INK, col_x, row_y, ROW_H, HORIZONTAL_ALIGNMENT_LEFT)
	var current := window_mode()
	var chips: Array = g["chips"]
	for i in chips.size():
		var rect: Rect2 = chips[i]["rect"]
		var mode := str(chips[i]["mode"])
		var selected := mode == current
		var hovered := i == _hover_chip
		# The shared row-box mark, not a bordered chip: picking a window mode and picking a
		# weapon in the forge are the same gesture, so they wear the same selected frame.
		var state := "idle"
		var text_col := COL_INK_DIM
		if selected:
			state = "selected"
			text_col = COL_ACCENT
		elif hovered:
			state = "hover"
			text_col = COL_INK
		_row_box(rect, state)
		var label := CHIP_WINDOWED if mode == "windowed" else CHIP_FULLSCREEN
		_text_band(_font_ui_med, label, FS_CHIP, text_col, rect.get_center().x, rect.position.y,
			rect.size.y, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_assist_row(col_x: float, row_y: float) -> void:
	_text_band(_font_display, ASSIST_NAME, FS_NAME, Color(COL_INK, 0.4), col_x, row_y, ROW_H,
		HORIZONTAL_ALIGNMENT_LEFT)
	# Right-aligned to the column's edge, where the volume numbers sit. Left-aligning it at
	# `col_x + NAME_W` printed it straight through the name: "Reinforcement Protocol" in
	# Cinzel at 18 px is far wider than NAME_W, which is sized for "Interface".
	_text_band(_font_body, ASSIST_NOTE, FS_NOTE, Color(COL_INK_DIM, 0.5),
		col_x + COLUMN_W - RIGHT_PAD, row_y, ROW_H, HORIZONTAL_ALIGNMENT_RIGHT)


# --- draw helpers ----------------------------------------------------------------------------

## Draw text with a fixed baseline y (for title/subtitle/section rows placed by their top y).
func _text(font: FontVariation, s: String, fs: int, col: Color, x: float, top_y: float,
		halign: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dx := x
	if halign == HORIZONTAL_ALIGNMENT_CENTER:
		dx = x - w * 0.5
	elif halign == HORIZONTAL_ALIGNMENT_RIGHT:
		dx = x - w
	draw_string(font, Vector2(dx, top_y + font.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Draw text vertically centred in a band [top_y, top_y+band_h], anchored at x by halign.
func _text_band(font: FontVariation, s: String, fs: int, col: Color, x: float, top_y: float,
		band_h: float, halign: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dx := x
	if halign == HORIZONTAL_ALIGNMENT_CENTER:
		dx = x - w * 0.5
	elif halign == HORIZONTAL_ALIGNMENT_RIGHT:
		dx = x - w
	var by := top_y + band_h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(dx, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
