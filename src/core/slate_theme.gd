extends RefCounted
class_name SlateTheme
## Shared Godot `Theme` for the game's Slate-language panels (design/ui-hud.md) — the
## pause menu, forge, tech, etchings, dialogue, and echo-offer panels all set
## `theme = SlateTheme.get_theme()` on their root and let it inherit to every child.
##
## It reads its colours and fonts OFF `SlateHud` (src/core/slate_hud.gd) so there is ONE
## dial source: the human tunes the Slate palette / fonts in SlateHud and both the HUDs
## (which draw in `_draw`) and these Control-tree panels move together. Never duplicate a
## SlateHud colour or font literal here.
##
## HUMAN: the SIZES / MARGINS / RADII below are placeholders — dial them like FEEL numbers
## (they carry no combat feel, so no `# FEEL:` tag).
##
## Type variations (apply per-node via `theme_type_variation`):
##   TitleLabel  — Cinzel display caps, panel titles.
##   NumLabel    — mono, purely-numeric readout labels.
##   DimLabel    — Garamond in the dim key colour, hints / footnotes / statuses.
##   MenuButton  — Button in Cinzel with roomier margins (the pause menu's big buttons).

const FS_DEFAULT := 16
const FS_TITLE := 20
const FS_NUM := 14
const FS_MENU_BUTTON := 18
const BTN_RADIUS := 8
const PANEL_RADIUS := 10
const PANEL_ALPHA := 0.97
## Button content margins (x, y) — the plain Button vs. the roomier MenuButton.
const BTN_MARGIN := Vector2(14, 8)
const MENU_BTN_MARGIN := Vector2(20, 12)
## Hover text (a touch brighter than the resting COL_TEXT).
const COL_HOVER_TEXT := Color(240.0 / 255, 238.0 / 255, 246.0 / 255)  # #f0eef6

static var _theme: Theme = null


## The one shared Slate Theme, built once and cached.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var display := SlateHud._with_fallback(SlateHud.FONT_DISPLAY_FILE)
	var body := SlateHud._with_fallback(SlateHud.FONT_BODY_FILE)
	var num := SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)

	# Default prose font (Garamond) — every Label/Button inherits it unless overridden.
	t.default_font = body
	t.default_font_size = FS_DEFAULT

	# --- Button ---------------------------------------------------------------------
	_apply_button(t, &"Button", BTN_MARGIN)
	t.set_color("font_color", "Button", SlateHud.COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_HOVER_TEXT)
	t.set_color("font_pressed_color", "Button", COL_HOVER_TEXT)
	t.set_color("font_focus_color", "Button", SlateHud.COL_TEXT)
	t.set_color("font_disabled_color", "Button", SlateHud.COL_KEY_TEXT)

	# --- Panel / PanelContainer -----------------------------------------------------
	var panel_bg := SlateHud.COL_SLATE_BG
	panel_bg.a = PANEL_ALPHA
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = panel_bg
	panel_sb.border_color = SlateHud.COL_SLATE_BORDER
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(PANEL_RADIUS)
	t.set_stylebox("panel", "Panel", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	# --- Label ----------------------------------------------------------------------
	t.set_color("font_color", "Label", SlateHud.COL_TEXT)

	# --- Type variations ------------------------------------------------------------
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", display)
	t.set_font_size("font_size", "TitleLabel", FS_TITLE)
	t.set_color("font_color", "TitleLabel", SlateHud.COL_TEXT)

	t.set_type_variation("NumLabel", "Label")
	t.set_font("font", "NumLabel", num)
	t.set_font_size("font_size", "NumLabel", FS_NUM)
	t.set_color("font_color", "NumLabel", SlateHud.COL_TEXT)

	t.set_type_variation("DimLabel", "Label")
	t.set_font("font", "DimLabel", body)
	t.set_color("font_color", "DimLabel", SlateHud.COL_KEY_TEXT)

	t.set_type_variation("MenuButton", "Button")
	_apply_button(t, &"MenuButton", MENU_BTN_MARGIN)
	t.set_font("font", "MenuButton", display)
	t.set_font_size("font_size", "MenuButton", FS_MENU_BUTTON)

	_theme = t
	return t


## Register the five Button styleboxes (normal/hover/pressed/focus/disabled) for a Button
## type (or Button variation), all in the Slate language, with `margin` content padding.
static func _apply_button(t: Theme, type: StringName, margin: Vector2) -> void:
	var normal := _btn_box(SlateHud.COL_SLATE_BG, SlateHud.COL_SLATE_BORDER, margin)
	var hover := _btn_box(SlateHud.COL_SLATE_BG, SlateHud.COL_TEXT, margin)
	var pressed := _btn_box(SlateHud.COL_SLATE_BG.darkened(0.3), SlateHud.COL_SLATE_BORDER, margin)
	var focus := _btn_box(SlateHud.COL_SLATE_BG, SlateHud.COL_READY, margin)
	var disabled := _btn_box(SlateHud.COL_SLATE_BG, SlateHud.COL_CHIP_BORDER, margin)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("focus", type, focus)
	t.set_stylebox("disabled", type, disabled)


static func _btn_box(bg: Color, border: Color, margin: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(BTN_RADIUS)
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	return sb
