extends Control
class_name SlateHud
## Shared base for the game's "Slate" HUDs (design/ui-hud.md) — the in-run RunHud
## (src/combat/run_hud.gd) and the town TownHud (src/town/town_hud.gd) both extend it.
## It owns the SHARED visual language so the human dials palette / fonts / margins in
## ONE place: the Slate palette + pickup colours, the three project fonts (assets/fonts/,
## all OFL), the shared font sizes + margin, and the draw plumbing (rounded panels via a
## StyleBoxFlat, baseline-centred text, the viewport-size sync). Subclasses own only
## their own pixels + state.
##
## HUMAN: EVERYTHING under "Shared style" is a PLACEHOLDER — colours, sizes, fonts.
## Dial them like FEEL numbers (they carry no combat feel, so no `# FEEL:` tag). The
## RunHud/TownHud files add their own placeholder consts on top for their own pieces.

# =====================================================================================
# Shared style — placeholders (palette / fonts / sizes). Dial freely.
# =====================================================================================
# Palette (Color(r/255,...) so the values are const-foldable — the hex is in the comment)
const COL_SLATE_BG := Color(23.0/255, 22.0/255, 28.0/255)          # #17161c panel body
const COL_SLATE_BORDER := Color(74.0/255, 71.0/255, 86.0/255)      # #4a4756
const COL_CHIP_BG := Color(23.0/255, 22.0/255, 28.0/255, 0.78)     # #17161c @ 0.78
const COL_CHIP_BORDER := Color(58.0/255, 56.0/255, 68.0/255)       # #3a3844
const COL_TEXT := Color(201.0/255, 197.0/255, 214.0/255)           # #c9c5d6
const COL_READY := Color(255.0/255, 230.0/255, 128.0/255)          # #ffe680 gold ready/badge
const COL_BADGE_TEXT := Color(30.0/255, 28.0/255, 24.0/255)        # dark text on the gold badge
const COL_KEY_TEXT := Color(150.0/255, 146.0/255, 162.0/255)       # dim key-badge label
const COL_PERIL := Color(255.0/255, 92.0/255, 92.0/255)            # #ff5c5c (glyph lives in chip text)
# Pickup / resource colours (per resource id)
const COL_GOLD := Color(255.0/255, 230.0/255, 128.0/255)           # #ffe680
const COL_ORE := Color(176.0/255, 164.0/255, 224.0/255)            # #b0a4e0
const COL_DUST := Color(128.0/255, 230.0/255, 255.0/255)           # #80e6ff
const COL_SHARDS := Color(208.0/255, 143.0/255, 255.0/255)         # #d08fff
const COL_STONE := Color(181.0/255, 173.0/255, 160.0/255)          # #b5ada0
const COL_FOOD := Color(164.0/255, 217.0/255, 122.0/255)           # #a4d97a
const COL_KNOWLEDGE := Color(159.0/255, 220.0/255, 255.0/255)      # #9fdcff
# Fonts — files under assets/fonts/ (all OFL; provenance in assets/fonts/SOURCES.md).
# Roles: DISPLAY = engraved caps (monograms, section heads), NUM = every number/readout
# (mono, so digits don't shuffle as they tick), BODY = prose (hint lines). Swap a role =
# swap its .ttf here.
const FONT_DISPLAY_FILE := preload("res://assets/fonts/Cinzel-SemiBold.ttf")
const FONT_BODY_FILE := preload("res://assets/fonts/EBGaramond-Medium.ttf")
const FONT_NUM_FILE := preload("res://assets/fonts/JetBrainsMono-Medium.ttf")
const FS_CHIP := 13      # info chip (num)
const FS_BODY := 14      # readouts / strip values / cooldown seconds (num)
const FS_HINT := 19      # contextual hint (body — Garamond runs small, so it sits larger)
const FS_SMALL := 10     # key badges, stack-count badges, projections (num)
# Layout margin from screen edges
const MARGIN := 14.0

var _font_display: FontVariation
var _font_body: FontVariation
var _font_num: FontVariation
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	# Common Slate setup; subclasses override _ready and call super._ready() FIRST, then
	# add their own group + signal wiring.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_display = _with_fallback(FONT_DISPLAY_FILE)
	_font_body = _with_fallback(FONT_BODY_FILE)
	_font_num = _with_fallback(FONT_NUM_FILE)


static func _with_fallback(base: Font) -> FontVariation:
	# Glyphs the family lacks (e.g. the chip's "⚠") fall back to the system font.
	# A wrapper, so the shared imported resource is never mutated.
	var f := FontVariation.new()
	f.base_font = base
	f.fallbacks = [ThemeDB.fallback_font]
	return f


## Sync `size` to the viewport each frame — subclasses call this from their own _process.
## Godot quirk: anchors set in a Control's own _ready never get a layout pass under a
## CanvasLayer (size stays 0,0 and everything anchored to size.x/size.y draws off-screen).
## Sync to the viewport explicitly; also covers window resizes.
func _sync_viewport_size() -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp


# =====================================================================================
# Shared draw helpers
# =====================================================================================

func _panel(rect: Rect2, bg: Color, border: Color, border_w: int, radius: int) -> void:
	_sb.bg_color = bg
	_sb.border_color = border
	_sb.set_border_width_all(border_w)
	_sb.set_corner_radius_all(radius)
	draw_style_box(_sb, rect)


func _text_w(s: String, fs: int, font: Font) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _text_in(rect: Rect2, s: String, col: Color, fs: int, font: Font,
		halign := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	# Text vertically centred in rect via baseline math: a line box is ascent+descent
	# tall, so the baseline sits at centre + (ascent - descent)/2. (A naive helper that
	# sizes boxes by the font-size px and drops by the full ascent rides low.)
	var x := rect.position.x
	if halign == HORIZONTAL_ALIGNMENT_CENTER:
		x += (rect.size.x - _text_w(s, fs, font)) * 0.5
	var y := rect.position.y + rect.size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
