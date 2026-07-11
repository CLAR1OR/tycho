extends Control
class_name AchievementToast
## The achievement unlock banner (architecture-schemas.md §5) — a small Slate strip in
## the pickup-strip language (run_hud.gd): monogram chip + name, slides in under the top
## margin, holds, fades, and plays the queue one at a time if several unlock at once.
##
## Owned by the Achievements autoload on its OWN CanvasLayer, so it works in town AND
## in-run and survives every scene swap. PROCESS_MODE_ALWAYS: unlocks can land while a
## panel owns the pause (building_built fires from the paused build panel) and the toast
## must still play. Draws itself in _draw off SlateHud's shared style; enqueue() is the
## only way in (the Achievements autoload calls it per unlock).
##
## HUMAN: everything under "Style" is a PLACEHOLDER — colours, sizes, timings. Dial like
## FEEL numbers (no combat feel rides this, so no `# FEEL:` tag).

# =====================================================================================
# Style — placeholders (sizes / colours / timings). Dial freely.
# =====================================================================================
const TOAST_W := 340.0
const TOAST_H := 56.0
const ICON_BOX := 40.0
const TOP_MARGIN := 14.0
const SLIDE_S := 0.25       # slide/fade in
const HOLD_S := 3.0         # fully shown
const FADE_S := 0.6         # fade out
const SLIDE_PX := 24.0      # slide-in travel
const FS_CAPTION := 10      # the small "ACHIEVEMENT" caption (num font)
const FS_NAME := 16         # the achievement name (display font)
const FS_ICON := 15         # the monogram (display font)
const CAPTION := "ACHIEVEMENT"  # HUMAN: placeholder copy

var _queue: Array[Dictionary] = []   # [{name, icon}] waiting their turn
var _current: Dictionary = {}        # the toast on screen ({} = none)
var _t := 0.0                        # seconds into the current toast's life
var _shown_total := 0                # cumulative count (smoke getter)

var _font_display: FontVariation
var _font_num: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("achievement_toast")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_display = SlateHud._with_fallback(SlateHud.FONT_DISPLAY_FILE)
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)


## Queue one unlock banner. Toasts play strictly one at a time, in enqueue order.
func enqueue(display_name: String, icon: String) -> void:
	_queue.append({"name": display_name, "icon": icon})


# --- Smoke/test getters ----------------------------------------------------------------

func showing() -> bool:
	return not _current.is_empty()


func current_name() -> String:
	return str(_current.get("name", ""))


func queued() -> int:
	return _queue.size()


func shown_total() -> int:
	return _shown_total


# --- Animation ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# The CanvasLayer-under-_ready layout quirk: keep the rect synced to the viewport.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _current.is_empty():
		if _queue.is_empty():
			return
		_current = _queue.pop_front()
		_shown_total += 1
		_t = 0.0
	_t += delta
	if _t >= SLIDE_S + HOLD_S + FADE_S:
		_current = {}
	queue_redraw()


## The current toast's alpha from its life phase (slide-in ramp, hold, fade-out).
func _alpha() -> float:
	if _t < SLIDE_S:
		return _t / SLIDE_S
	if _t < SLIDE_S + HOLD_S:
		return 1.0
	return maxf(0.0, 1.0 - (_t - SLIDE_S - HOLD_S) / FADE_S)


func _draw() -> void:
	if _current.is_empty() or size.x < 1.0:
		return
	var a := _alpha()
	var slide := (1.0 - minf(_t / SLIDE_S, 1.0)) * -SLIDE_PX
	var rect := Rect2((size.x - TOAST_W) * 0.5, TOP_MARGIN + slide, TOAST_W, TOAST_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(SlateHud.COL_SLATE_BG, 0.92 * a)
	sb.border_color = Color(SlateHud.COL_READY, a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, rect)
	# Monogram chip (left).
	var pad := (TOAST_H - ICON_BOX) * 0.5
	var chip := Rect2(rect.position.x + pad, rect.position.y + pad, ICON_BOX, ICON_BOX)
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color(SlateHud.COL_READY, 0.9 * a)
	chip_sb.set_corner_radius_all(6)
	draw_style_box(chip_sb, chip)
	_centered(chip, str(_current.get("icon", "?")), _font_display, FS_ICON,
		Color(SlateHud.COL_BADGE_TEXT, a))
	# Caption + name (right of the chip).
	var tx := chip.position.x + ICON_BOX + 12.0
	var caption_y := rect.position.y + 10.0 + _font_num.get_ascent(FS_CAPTION)
	draw_string(_font_num, Vector2(tx, caption_y), CAPTION, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FS_CAPTION, Color(SlateHud.COL_KEY_TEXT, a))
	var name_y := rect.position.y + TOAST_H - 12.0
	draw_string(_font_display, Vector2(tx, name_y), current_name(), HORIZONTAL_ALIGNMENT_LEFT,
		-1, FS_NAME, Color(SlateHud.COL_TEXT, a))


func _centered(rect: Rect2, s: String, font: Font, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := rect.position.y + rect.size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(rect.position.x + (rect.size.x - w) * 0.5, y), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
