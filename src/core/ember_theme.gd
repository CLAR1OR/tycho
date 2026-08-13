extends RefCounted
class_name EmberTheme
## Shared Godot `Theme` for the "Ember" screens that are Control TREES rather than one
## `_draw` (design/ui-hud.md § "Ember menu vocabulary"). The mirror of `SlateTheme`, and
## its eventual replacement: a screen migrates by swapping `SlateTheme.get_theme()` for
## `EmberTheme.get_theme()` and re-pointing its `theme_type_variation`s.
##
## Which screens need this rather than `EmberHud`: the ones whose content is a variable
## number of stacked rows that must scroll or reflow — the achievements page, the pause
## menu's button column, the dialogue panel. Everything laid out at fixed positions is
## cheaper and more controllable drawn directly in an `EmberHud` subclass.
##
## It reads every colour and font OFF `EmberHud` so there is ONE dial source, exactly as
## SlateTheme reads SlateHud. Never duplicate an EmberHud colour or font literal here —
## only sizes, margins and the one radius are this file's own.
##
## THE INVERSION vs Slate, and the whole reason this file is not a palette swap: Slate's
## `Panel` was an opaque slate box with a 2 px border, and its `Button` was the same box
## again. Ember has no panels — `Panel`/`PanelContainer` here are TRANSPARENT (they group
## and pad, they do not draw), and a `Button` is a hairline frame over nothing that goes
## gold when it is the actionable thing. If a migrated screen still looks boxy, something
## is setting its own StyleBox instead of taking these.
##
## HUMAN: the SIZES / MARGINS / RADIUS below are placeholders — dial like FEEL numbers.
##
## Type variations (apply per-node via `theme_type_variation`):
##   EmberTitle    — Cinzel, the screen's name.
##   EmberHead     — Alegreya Sans Medium caps-ish, small + dim: section heads.
##   EmberDim      — the same UI font in the dim ink: meta lines, footnotes, statuses.
##   EmberNum      — JetBrains Mono: any purely numeric readout.
##   EmberProse    — EB Garamond: descriptions, flavour, dialogue lines.
##   EmberAction   — the primary Button, gold-framed (one per screen, at most).

const FS_DEFAULT := EmberHud.FS_ROW
const FS_TITLE := EmberHud.FS_TITLE
const FS_HEAD := EmberHud.FS_HEAD
const FS_NUM := EmberHud.FS_VALUE
const FS_PROSE := 18
## Ember frames are square by default — the language is hairlines and negative space, not
## rounded chrome. A small radius on buttons only, so a tappable thing reads as a control.
const BTN_RADIUS := 3
## Button content margins (x, y) — the plain Button vs. the roomier EmberAction.
const BTN_MARGIN := Vector2(16, 9)
const ACTION_MARGIN := Vector2(26, 13)
## Panels group and pad; they never paint. This is the padding they contribute.
const PANEL_MARGIN := 18

static var _theme: Theme = null


## The one shared Ember Theme, built once and cached.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var display := EmberHud._with_fallback(EmberHud.FONT_DISPLAY_FILE)
	var body := EmberHud._with_fallback(EmberHud.FONT_BODY_FILE)
	var num := EmberHud._with_fallback(EmberHud.FONT_NUM_FILE)
	var ui := EmberHud._with_fallback(EmberHud.FONT_UI_FILE)
	var ui_med := EmberHud._with_fallback(EmberHud.FONT_UI_MED_FILE)

	# The interface voice is the default — under Ember most text on a screen is a label,
	# not prose. (Slate defaulted to Garamond because it had no UI font to default to.)
	t.default_font = ui
	t.default_font_size = FS_DEFAULT

	# --- Button ---------------------------------------------------------------------
	_apply_button(t, &"Button", BTN_MARGIN, EmberHud.COL_RING)
	t.set_color("font_color", "Button", EmberHud.COL_INK)
	t.set_color("font_hover_color", "Button", EmberHud.COL_INK)
	t.set_color("font_pressed_color", "Button", EmberHud.COL_ACCENT)
	t.set_color("font_focus_color", "Button", EmberHud.COL_ACCENT)
	t.set_color("font_disabled_color", "Button", EmberHud.COL_DISABLED)

	# --- Panel / PanelContainer -------------------------------------------------------
	# Transparent by design. They exist to group and pad; the hairlines do the bounding.
	var panel_sb := StyleBoxEmpty.new()
	panel_sb.content_margin_left = PANEL_MARGIN
	panel_sb.content_margin_right = PANEL_MARGIN
	panel_sb.content_margin_top = PANEL_MARGIN
	panel_sb.content_margin_bottom = PANEL_MARGIN
	t.set_stylebox("panel", "Panel", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	# --- Label ------------------------------------------------------------------------
	t.set_color("font_color", "Label", EmberHud.COL_INK)

	# --- ScrollContainer --------------------------------------------------------------
	# A scrolling page is the main reason a screen is a Control tree at all, so its
	# furniture has to speak Ember too: no track, a hairline-thin grabber.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = EmberHud.COL_RING
	grabber.set_corner_radius_all(2)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = EmberHud.COL_INK_DIM
	grabber_hl.set_corner_radius_all(2)
	grabber_hl.content_margin_left = 3
	grabber_hl.content_margin_right = 3
	for bar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, StyleBoxEmpty.new())
		t.set_stylebox("grabber", bar, grabber)
		t.set_stylebox("grabber_highlight", bar, grabber_hl)
		t.set_stylebox("grabber_pressed", bar, grabber_hl)

	# --- Type variations --------------------------------------------------------------
	t.set_type_variation("EmberTitle", "Label")
	t.set_font("font", "EmberTitle", display)
	t.set_font_size("font_size", "EmberTitle", FS_TITLE)
	t.set_color("font_color", "EmberTitle", EmberHud.COL_INK)

	t.set_type_variation("EmberHead", "Label")
	t.set_font("font", "EmberHead", ui_med)
	t.set_font_size("font_size", "EmberHead", FS_HEAD)
	t.set_color("font_color", "EmberHead", EmberHud.COL_INK_DIM)

	t.set_type_variation("EmberDim", "Label")
	t.set_font("font", "EmberDim", ui)
	t.set_color("font_color", "EmberDim", EmberHud.COL_INK_DIM)

	t.set_type_variation("EmberNum", "Label")
	t.set_font("font", "EmberNum", num)
	t.set_font_size("font_size", "EmberNum", FS_NUM)
	t.set_color("font_color", "EmberNum", EmberHud.COL_INK)

	t.set_type_variation("EmberProse", "Label")
	t.set_font("font", "EmberProse", body)
	t.set_font_size("font_size", "EmberProse", FS_PROSE)
	t.set_color("font_color", "EmberProse", EmberHud.COL_INK)

	t.set_type_variation("EmberAction", "Button")
	_apply_button(t, &"EmberAction", ACTION_MARGIN, EmberHud.COL_ACCENT)
	t.set_font("font", "EmberAction", ui_med)
	t.set_color("font_color", "EmberAction", EmberHud.COL_ACCENT)
	t.set_color("font_hover_color", "EmberAction", EmberHud.COL_INK)
	t.set_color("font_pressed_color", "EmberAction", EmberHud.COL_INK)
	t.set_color("font_focus_color", "EmberAction", EmberHud.COL_ACCENT)
	t.set_color("font_disabled_color", "EmberAction", EmberHud.COL_DISABLED)

	_theme = t
	return t


## Register the five Button styleboxes for a Button type (or variation). `rest_border` is
## the resting frame colour — hairline grey for a plain Button, gold for the one action.
## Every box is bg-less: an Ember button is a frame over the screen, never a filled chip.
static func _apply_button(t: Theme, type: StringName, margin: Vector2,
		rest_border: Color) -> void:
	var wash := Color(1.0, 1.0, 1.0, 0.05)
	t.set_stylebox("normal", type, _btn_box(Color(0, 0, 0, 0), rest_border, margin))
	t.set_stylebox("hover", type, _btn_box(wash, EmberHud.COL_INK, margin))
	t.set_stylebox("pressed", type, _btn_box(Color(EmberHud.COL_ACCENT, 0.14),
		EmberHud.COL_ACCENT, margin))
	t.set_stylebox("focus", type, _btn_box(Color(0, 0, 0, 0), EmberHud.COL_ACCENT, margin))
	t.set_stylebox("disabled", type, _btn_box(Color(0, 0, 0, 0), EmberHud.COL_DISABLED,
		margin))


static func _btn_box(bg: Color, border: Color, margin: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(BTN_RADIUS)
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	return sb
