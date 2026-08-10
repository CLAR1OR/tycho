extends Control
class_name EmberHud
## Shared base for the game's "Ember" HUDs — the second UI language, converged from the
## human-picked reference anchors (assets_src/anchors/in-run-hud-reference.png and
## weapon-menu-reference.png) on 2026-08-10. Spec: design/ui-hud.md § "In-run HUD — Ember".
##
## Ember is defined by what it does NOT draw. Where Slate (src/core/slate_hud.gd) states
## itself in opaque rounded panels with visible borders, Ember has no panels at all:
## every element floats directly on the world and is held together by hairline rules,
## thin rings, negative space, and gold used ONLY for state. It reads better over a dark
## 2.5D field because it never fights the scene for contrast.
##
## Ember sits BESIDE Slate, not on top of it. SlateHud and every menu screen that extends
## it are untouched; only RunHud (src/combat/run_hud.gd) speaks Ember today. If the
## language wins in combat, the menu screens migrate one at a time — that is a later
## decision, deliberately not pre-empted here.
##
## Subclasses own their own pixels + state; this file owns the palette, the three project
## fonts, the draw primitives (hairline / ring / arc / diamond / tracked caps / shadowed
## text) and the code-drawn glyph library.
##
## HUMAN: EVERYTHING under "Shared style" is a PLACEHOLDER — colours, sizes, fonts, and
## every coordinate in the glyph table. Dial them like FEEL numbers (they carry no combat
## feel, so no `# FEEL:` tag). Dial board: design/feel-tuning.md § Ember HUD.

# =====================================================================================
# Shared style — placeholders (palette / fonts / sizes). Dial freely.
# =====================================================================================
# Palette. Ember draws no backgrounds, so every colour here is either ink on the world or
# an accent. (Color(r/255,...) so the values are const-foldable — the hex is in the comment.)
const COL_INK := Color(229.0/255, 228.0/255, 224.0/255)            # #e5e4e0 primary text
const COL_INK_DIM := Color(154.0/255, 150.0/255, 145.0/255)        # #9a9691 labels, keys, headers
const COL_INK_FAINT := Color(154.0/255, 150.0/255, 145.0/255, 0.55) # completed rows, empty slots
const COL_HAIR := Color(1.0, 1.0, 1.0, 0.14)                       # section rules
const COL_RING := Color(1.0, 1.0, 1.0, 0.22)                       # idle medallion / slot rings
const COL_ACCENT := Color(224.0/255, 168.0/255, 60.0/255)          # #e0a83c THE gold — state only
const COL_ON_ACCENT := Color(26.0/255, 22.0/255, 16.0/255)         # dark text on a gold disc
const COL_TRACK := Color(1.0, 1.0, 1.0, 0.16)                      # the unfilled part of any bar
const COL_SHADOW := Color(0.0, 0.0, 0.0, 0.7)                      # text legibility over the world
const COL_DANGER := Color(255.0/255, 92.0/255, 92.0/255)           # #ff5c5c peril mark
# Resource identity colours are deliberately shared with Slate (src/core/slate_hud.gd) so
# gold/ore/dust/shards mean the same colour on every screen, whichever language draws it.
const COL_GOLD := Color(255.0/255, 230.0/255, 128.0/255)           # #ffe680
const COL_ORE := Color(176.0/255, 164.0/255, 224.0/255)            # #b0a4e0
const COL_DUST := Color(128.0/255, 230.0/255, 255.0/255)           # #80e6ff
const COL_SHARDS := Color(208.0/255, 143.0/255, 255.0/255)         # #d08fff
# Fonts — the same three OFL files Slate uses (assets/fonts/, provenance in SOURCES.md).
# Ember adds NO fourth font: the reference anchors use a light humanist sans we do not own,
# and buying into one is a separate call. Roles: DISPLAY = engraved caps (monograms, boss
# name), NUM = every number/readout (mono, so digits don't shuffle), BODY = prose (hint,
# objective labels — Ember speaks in sentences more than Slate did).
const FONT_DISPLAY_FILE := preload("res://assets/fonts/Cinzel-SemiBold.ttf")
const FONT_BODY_FILE := preload("res://assets/fonts/EBGaramond-Medium.ttf")
const FONT_NUM_FILE := preload("res://assets/fonts/JetBrainsMono-Medium.ttf")
const FS_HEAD := 12      # tracked section headers (num)
const FS_LABEL := 17     # objective labels / prose rows (body)
const FS_VALUE := 15     # counters, HP numerals (num)
const FS_BIG := 22       # the bare resource readouts (num)
const FS_KEY := 10       # ability key badges (num)
const FS_MONO := 13      # echo medallion monograms (display)
## Extra advance per character for tracked caps (the reference's letter-spaced headers).
const TRACKING := 1.6
## Layout margin from screen edges.
const MARGIN := 22.0

var _font_display: FontVariation
var _font_body: FontVariation
var _font_num: FontVariation


func _ready() -> void:
	# Common Ember setup; subclasses override _ready and call super._ready() FIRST, then
	# add their own group + signal wiring.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_display = _with_fallback(FONT_DISPLAY_FILE)
	_font_body = _with_fallback(FONT_BODY_FILE)
	_font_num = _with_fallback(FONT_NUM_FILE)


static func _with_fallback(base: Font) -> FontVariation:
	# Glyphs the family lacks (e.g. the header's "⚠") fall back to the system font.
	# A wrapper, so the shared imported resource is never mutated.
	var f := FontVariation.new()
	f.base_font = base
	f.fallbacks = [ThemeDB.fallback_font]
	return f


## Sync `size` to the viewport each frame — subclasses call this from their own _process.
## Godot quirk (same one SlateHud documents): anchors set in a Control's own _ready never
## get a layout pass under a CanvasLayer, so `size` stays (0,0) and everything anchored to
## size.x/size.y draws off-screen. Sync explicitly; also covers window resizes.
func _sync_viewport_size() -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp


# =====================================================================================
# Draw primitives — the Ember vocabulary
# =====================================================================================

## A section rule. Ember's replacement for a panel border: one faint horizontal line.
func _hairline(from_x: float, to_x: float, y: float, col: Color = COL_HAIR, w: float = 1.0) -> void:
	draw_line(Vector2(from_x, y), Vector2(to_x, y), col, w, true)


## A full thin circle — the medallion / ability-slot frame.
func _ring(centre: Vector2, radius: float, width: float, col: Color) -> void:
	draw_arc(centre, radius, 0.0, TAU, 48, col, width, true)


## A partial circle starting at 12 o'clock and sweeping clockwise. `frac` in 0..1.
## This is the cooldown read: the arc GROWS back as the ability recovers.
func _arc_sweep(centre: Vector2, radius: float, width: float, frac: float, col: Color) -> void:
	var f := clampf(frac, 0.0, 1.0)
	if f <= 0.0:
		return
	var start := -PI * 0.5
	draw_arc(centre, radius, start, start + TAU * f, maxi(6, int(48.0 * f)), col, width, true)


## The recurring gold rhombus: bar centre-piece, objective bullet, ornament.
func _diamond(centre: Vector2, half: float, col: Color, filled: bool = true, w: float = 1.5) -> void:
	var pts := PackedVector2Array([
		centre + Vector2(0.0, -half), centre + Vector2(half, 0.0),
		centre + Vector2(0.0, half), centre + Vector2(-half, 0.0),
	])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, col, w, true)


## A filled disc (the stack-count badge behind a number).
func _disc(centre: Vector2, radius: float, col: Color) -> void:
	draw_circle(centre, radius, col)


func _text_w(s: String, fs: int, font: Font) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Text drawn from a LEFT baseline-free anchor: `pos` is the left edge at the vertical
## centre of the intended line. Returns the advance, so callers can chain segments.
func _text_at(pos: Vector2, s: String, col: Color, fs: int, font: Font) -> float:
	var y := pos.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(pos.x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return _text_w(s, fs, font)


## Same, with a 1px dark offset underneath — Ember has no panel behind its text, so prose
## over a bright patch of world needs the shadow to stay legible.
func _text_shadowed(pos: Vector2, s: String, col: Color, fs: int, font: Font) -> float:
	_text_at(pos + Vector2(1.0, 1.0), s, Color(COL_SHADOW, COL_SHADOW.a * col.a), fs, font)
	return _text_at(pos, s, col, fs, font)


## Text centred horizontally on `centre_x`, vertically on `pos_y`.
func _text_centred(centre_x: float, pos_y: float, s: String, col: Color, fs: int,
		font: Font, shadow: bool = false) -> void:
	var x := centre_x - _text_w(s, fs, font) * 0.5
	if shadow:
		_text_shadowed(Vector2(x, pos_y), s, col, fs, font)
	else:
		_text_at(Vector2(x, pos_y), s, col, fs, font)


## Letter-spaced text — the reference's tracked headers. Drawn glyph by glyph because
## Godot's draw_string has no tracking parameter. Returns the total advance.
##
## Because it already walks characters, it can recolour a few of them for free: any char
## appearing in `hl` is drawn in `hl_col`. That is how the room header keeps its peril "⚠"
## red inside an otherwise dim line, without splitting the string upstream.
func _text_tracked(pos: Vector2, s: String, col: Color, fs: int, font: Font,
		tracking: float = TRACKING, hl: String = "", hl_col: Color = Color.WHITE) -> float:
	var x := pos.x
	for i in s.length():
		var ch := s.substr(i, 1)
		var c := hl_col if (not hl.is_empty() and hl.contains(ch)) else col
		x += _text_at(Vector2(x, pos.y), ch, c, fs, font) + tracking
	return maxf(0.0, x - pos.x - tracking)


## Width the tracked draw above will occupy — for right-aligning or centring a header.
func _text_tracked_w(s: String, fs: int, font: Font, tracking: float = TRACKING) -> float:
	var w := 0.0
	for i in s.length():
		w += _text_w(s.substr(i, 1), fs, font) + tracking
	return maxf(0.0, w - tracking)


# =====================================================================================
# Glyph library — code-drawn vector marks
# =====================================================================================
# The reference anchors are icon-native and the project owns ZERO icon assets (the
# asset-pipeline gate has never run). Rather than block the HUD on that gate, every mark
# is drawn here as a path in a unit square centred on (0,0), spanning -0.5..0.5, y-DOWN
# (screen coords). One `size` argument scales it. Adding a glyph is one `match` arm and a
# point list — and when real icons eventually exist, `_glyph` is the single swap point.
#
# HUMAN: every coordinate below is a placeholder silhouette, not final art.

## Filled shapes, per glyph id.
const GLYPH_FILL := {
	# Resource crystals — four distinguishable silhouettes, told apart by shape AND colour.
	"gold": [Vector2(0, -0.48), Vector2(0.30, -0.14), Vector2(0.21, 0.42),
		Vector2(-0.21, 0.42), Vector2(-0.30, -0.14)],
	"dust": [Vector2(0.04, -0.50), Vector2(0.31, -0.02), Vector2(0.13, 0.46),
		Vector2(-0.15, 0.42), Vector2(-0.30, -0.10)],
	"ore": [Vector2(-0.08, -0.42), Vector2(0.27, -0.30), Vector2(0.42, 0.08),
		Vector2(0.19, 0.42), Vector2(-0.25, 0.35), Vector2(-0.42, -0.04)],
	"shards": [Vector2(-0.04, -0.48), Vector2(0.15, -0.08), Vector2(0.05, 0.33),
		Vector2(-0.17, 0.08)],
	# Abilities that read better solid than stroked.
	"bolt": [Vector2(0.14, -0.48), Vector2(-0.22, 0.04), Vector2(0.01, 0.04),
		Vector2(-0.11, 0.48), Vector2(0.24, -0.06), Vector2(0.01, -0.06)],
}
## A second filled piece for glyphs built from two shapes.
const GLYPH_FILL2 := {
	"shards": [Vector2(0.17, 0.01), Vector2(0.34, 0.19), Vector2(0.23, 0.46), Vector2(0.11, 0.27)],
}
## Stroked polylines, per glyph id (a list of separate strokes).
const GLYPH_STROKE := {
	# Facet lines that make the crystals read as faceted rather than flat.
	"gold": [[Vector2(0, -0.48), Vector2(0, 0.42)], [Vector2(-0.30, -0.14), Vector2(0.30, -0.14)]],
	"dust": [[Vector2(0.04, -0.50), Vector2(-0.02, 0.44)]],
	"ore": [[Vector2(-0.08, -0.42), Vector2(0.04, 0.02), Vector2(0.42, 0.08)],
		[Vector2(0.04, 0.02), Vector2(-0.25, 0.35)]],
	# Push — a braced bar shoving a chevron outward.
	"push": [[Vector2(-0.34, -0.36), Vector2(-0.34, 0.36)],
		[Vector2(-0.02, -0.30), Vector2(0.30, 0.0), Vector2(-0.02, 0.30)],
		[Vector2(-0.20, 0.0), Vector2(0.22, 0.0)]],
	# Surge — an eight-point burst (cardinals long, diagonals short).
	"surge": [[Vector2(0, -0.14), Vector2(0, -0.48)], [Vector2(0, 0.14), Vector2(0, 0.48)],
		[Vector2(-0.14, 0), Vector2(-0.48, 0)], [Vector2(0.14, 0), Vector2(0.48, 0)],
		[Vector2(-0.10, -0.10), Vector2(-0.30, -0.30)], [Vector2(0.10, -0.10), Vector2(0.30, -0.30)],
		[Vector2(-0.10, 0.10), Vector2(-0.30, 0.30)], [Vector2(0.10, 0.10), Vector2(0.30, 0.30)]],
	# Dash — speed lines trailing a chevron.
	"dash": [[Vector2(-0.44, -0.20), Vector2(0.02, -0.20)],
		[Vector2(-0.48, 0.0), Vector2(0.14, 0.0)],
		[Vector2(-0.44, 0.20), Vector2(0.02, 0.20)],
		[Vector2(0.12, -0.26), Vector2(0.40, 0.0), Vector2(0.12, 0.26)]],
	# Snare — a closed loop with four inward hooks (the net cinching).
	"snare": [[Vector2(-0.30, -0.30), Vector2(-0.18, -0.18)],
		[Vector2(0.30, -0.30), Vector2(0.18, -0.18)],
		[Vector2(-0.30, 0.30), Vector2(-0.18, 0.18)],
		[Vector2(0.30, 0.30), Vector2(0.18, 0.18)]],
}
## Glyphs that also want one or more concentric arcs: id -> [[radius, from_rad, to_rad], ...].
const GLYPH_ARCS := {
	"snare": [[0.26, 0.0, TAU]],
	# Shockwave — three nested arcs opening to the right.
	"shockwave": [[0.16, -0.95, 0.95], [0.30, -0.95, 0.95], [0.44, -0.95, 0.95]],
}


## Draw glyph `id` centred on `centre`, scaled to `size` px, in `col`.
## Unknown ids draw a small hollow diamond so a typo is visible instead of silent.
func _glyph(centre: Vector2, glyph_size: float, id: String, col: Color, stroke_w: float = 1.6) -> void:
	var known := GLYPH_FILL.has(id) or GLYPH_STROKE.has(id) or GLYPH_ARCS.has(id)
	if not known:
		_diamond(centre, glyph_size * 0.32, col, false, stroke_w)
		return
	for key: String in ["", "2"]:
		var table: Dictionary = GLYPH_FILL2 if key == "2" else GLYPH_FILL
		if table.has(id):
			draw_colored_polygon(_scaled(table[id], centre, glyph_size), col)
	if GLYPH_STROKE.has(id):
		for stroke: Array in GLYPH_STROKE[id]:
			draw_polyline(_scaled(stroke, centre, glyph_size), col, stroke_w, true)
	if GLYPH_ARCS.has(id):
		for a: Array in GLYPH_ARCS[id]:
			draw_arc(centre, glyph_size * float(a[0]), float(a[1]), float(a[2]), 32, col, stroke_w, true)


## Unit-square points -> screen points.
static func _scaled(pts: Array, centre: Vector2, glyph_size: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(centre + p * glyph_size)
	return out
