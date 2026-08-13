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
## Ember is becoming the WHOLE game's language (human directive, 2026-08-13: "I want all
## of my ingame HUD and menus to be in the new style"). Slate (src/core/slate_hud.gd +
## src/core/slate_theme.gd) is now legacy: it still dresses the fifteen unmigrated screens
## and the two languages coexist until the last one moves, at which point Slate is deleted
## so there is one dial source again. Migration order: design/ui-hud.md § "Migrating to
## Ember".
##
## Subclasses own their own pixels + state; this file owns the palette, the four project
## fonts, the draw primitives — the HUD set (hairline / ring / arc / diamond / tracked caps
## / shadowed text) and the MENU set (scrim / flourish / dashed frame / row box / pip track
## / prompt) — and the code-drawn glyph library. Pure menu layout + formatting rules live
## beside it in EmberMenuCore (src/core/ember_menu_core.gd), and Control-TREE screens
## (containers, not _draw) get the same language from EmberTheme (src/core/ember_theme.gd).
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
# Menu-only additions. A menu owns the whole screen, so it needs a ground to sit on and a
# way to bound a row — but Ember still refuses opaque panels: the scrim is a dim of the
# world behind, and a "row" is a barely-there wash inside a hairline, never a filled box.
const COL_SCRIM := Color(10.0/255, 9.0/255, 13.0/255, 0.90)        # #0a090d @ .90 backdrop
const COL_ROW := Color(1.0, 1.0, 1.0, 0.035)                       # resting row wash
const COL_ROW_HOVER := Color(1.0, 1.0, 1.0, 0.075)                 # hovered row wash
const COL_ROW_SELECTED := Color(224.0/255, 168.0/255, 60.0/255, 0.10) # gold wash, selected
const COL_DISABLED := Color(154.0/255, 150.0/255, 145.0/255, 0.38) # unaffordable / locked
# Resource identity colours are deliberately shared with Slate (src/core/slate_hud.gd) so
# gold/ore/dust/shards mean the same colour on every screen, whichever language draws it.
const COL_GOLD := Color(255.0/255, 230.0/255, 128.0/255)           # #ffe680
const COL_ORE := Color(176.0/255, 164.0/255, 224.0/255)            # #b0a4e0
const COL_DUST := Color(128.0/255, 230.0/255, 255.0/255)           # #80e6ff
const COL_SHARDS := Color(208.0/255, 143.0/255, 255.0/255)         # #d08fff
# The three town-economy resources. The run HUD never showed them (they are never picked
# up in a run), but the town HUD does, so they belong beside the other four.
const COL_STONE := Color(181.0/255, 173.0/255, 160.0/255)          # #b5ada0
const COL_FOOD := Color(164.0/255, 217.0/255, 122.0/255)           # #a4d97a
const COL_KNOWLEDGE := Color(159.0/255, 220.0/255, 255.0/255)      # #9fdcff

## Ledger id -> the glyph that means it, everywhere in the game. Lives here rather than in
## each screen so a resource cannot end up wearing two different marks on two screens.
const RESOURCE_GLYPH := {
	"gold": "gold", "stone": "stone", "food": "leaf", "knowledge": "book",
	"knowledge-shards": "shards", "resonance-ore": "ore", "resonance-dust": "dust",
}
## Ledger id -> its identity colour. Same reason.
const RESOURCE_COLOR := {
	"gold": COL_GOLD, "stone": COL_STONE, "food": COL_FOOD, "knowledge": COL_KNOWLEDGE,
	"knowledge-shards": COL_SHARDS, "resonance-ore": COL_ORE, "resonance-dust": COL_DUST,
}


## The mark + colour for a Ledger resource id. Unknown ids fall back to a hollow diamond
## (what `_glyph` draws for anything it doesn't know) in plain ink, so a new resource is
## visible rather than silently missing.
static func resource_glyph(id: String) -> String:
	return str(RESOURCE_GLYPH.get(id, id))


static func resource_color(id: String) -> Color:
	return RESOURCE_COLOR.get(id, COL_INK)
# Fonts — four OFL files (assets/fonts/, provenance in SOURCES.md). Roles:
#   DISPLAY (Cinzel)          engraved caps — screen titles, monograms, the boss name
#   BODY    (EB Garamond)     prose — descriptions, flavour, dialogue
#   NUM     (JetBrains Mono)  every number/readout — mono, so digits don't shuffle
#   UI      (Alegreya Sans)   interface voice — labels, list rows, section heads, buttons
#
# The UI role is NEW (2026-08-13, human: "use new font as fits best"). Ember originally
# shipped with three and pressed Garamond into label duty, because the reference anchors
# are set in a humanist sans the project did not own. Both anchors put every interface
# label in that sans — Garamond was standing in, and in a menu (which is almost entirely
# labels) the stand-in shows. Alegreya Sans is the pick: humanist rather than geometric,
# drawn by Huerta Tipografica from the same old-style calligraphic roots as EB Garamond,
# so the two sit on a screen together as one system instead of two. Regular is the
# workhorse; Medium is for small tracked caps, where Regular goes thin against the world.
const FONT_DISPLAY_FILE := preload("res://assets/fonts/Cinzel-SemiBold.ttf")
const FONT_BODY_FILE := preload("res://assets/fonts/EBGaramond-Medium.ttf")
const FONT_NUM_FILE := preload("res://assets/fonts/JetBrainsMono-Medium.ttf")
const FONT_UI_FILE := preload("res://assets/fonts/AlegreyaSans-Regular.ttf")
const FONT_UI_MED_FILE := preload("res://assets/fonts/AlegreyaSans-Medium.ttf")
const FS_HEAD := 12      # tracked section headers (ui med)
const FS_LABEL := 17     # objective labels / list-row names (ui)
const FS_VALUE := 15     # counters, HP numerals (num)
const FS_BIG := 22       # the bare resource readouts (num)
const FS_KEY := 10       # ability key badges (num)
const FS_MONO := 13      # echo medallion monograms (display)
# Menu-only sizes.
const FS_TITLE := 34     # the screen's name (display)
const FS_SUB := 16       # the line under the title (body — the one place prose leads)
const FS_ROW := 17       # list-row names, dock labels (ui)
const FS_ROW_SM := 13    # meta lines, level captions, costs (ui)
const FS_HERO := 26      # the centre stage's big name (display)
const FS_PROMPT := 14    # footer prompt labels (ui)
## Extra advance per character for tracked caps (the reference's letter-spaced headers).
const TRACKING := 1.6
## Layout margin from screen edges.
const MARGIN := 22.0

var _font_display: FontVariation
var _font_body: FontVariation
var _font_num: FontVariation
var _font_ui: FontVariation
var _font_ui_med: FontVariation


func _ready() -> void:
	# Common Ember setup; subclasses override _ready and call super._ready() FIRST, then
	# add their own group + signal wiring. NOTE the mouse_filter default: the HUD is
	# non-interactive, so it ignores the mouse. A menu subclass must set MOUSE_FILTER_STOP
	# itself (it wants the clicks, and it wants to swallow them from the world behind).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_display = _with_fallback(FONT_DISPLAY_FILE)
	_font_body = _with_fallback(FONT_BODY_FILE)
	_font_num = _with_fallback(FONT_NUM_FILE)
	_font_ui = _with_fallback(FONT_UI_FILE)
	_font_ui_med = _with_fallback(FONT_UI_MED_FILE)


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


## Text ending at `right_x` instead of starting at a left edge — dock values, costs, any
## right-aligned column. Returns the width drawn.
func _text_right(right_x: float, y: float, s: String, col: Color, fs: int,
		font: Font, shadow: bool = false) -> float:
	var w := _text_w(s, fs, font)
	var pos := Vector2(right_x - w, y)
	if shadow:
		_text_shadowed(pos, s, col, fs, font)
	else:
		_text_at(pos, s, col, fs, font)
	return w


## Pixel-exact ellipsis: the longest prefix of `s` that fits `max_w`, plus "…".
## (EmberMenuCore.truncate is the pure character-count version, for tests and for callers
## that have no font in hand. This one is what a real row should use.)
func _elide(s: String, max_w: float, fs: int, font: Font) -> String:
	if max_w <= 0.0:
		return ""
	if _text_w(s, fs, font) <= max_w:
		return s
	var ell := "…"
	var ell_w := _text_w(ell, fs, font)
	var cut := s.length()
	while cut > 0 and _text_w(s.substr(0, cut), fs, font) + ell_w > max_w:
		cut -= 1
	return s.substr(0, cut).strip_edges(false, true) + ell


# =====================================================================================
# Menu primitives — the Ember vocabulary, part two
# =====================================================================================
# The HUD floats on live gameplay; a MENU owns the screen and pauses it. That asks for
# four things the HUD never needed: a ground to sit on (the scrim), a way to bound a row
# without drawing a panel (the wash + hairline), a way to mark the ONE actionable thing
# (the dashed gold frame), and a footer that names its inputs (prompts). Everything else
# is the same vocabulary — hairlines, thin rings, negative space, gold only for state.
#
# HUMAN: every default below is a PLACEHOLDER. Dial board: design/feel-tuning.md.

## The dim over whatever the menu opened on top of. Ember's answer to Slate's opaque
## fullscreen panel: you can still see the world, it just stops competing.
func _scrim(col: Color = COL_SCRIM) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col, true)


## A vertical hairline — the rail/list divider, or any column separator.
func _v_rule(x: float, from_y: float, to_y: float, col: Color = COL_HAIR,
		w: float = 1.0) -> void:
	draw_line(Vector2(x, from_y), Vector2(x, to_y), col, w, true)


## The anchor's title ornament: a tapering rule running INTO a small gold diamond, drawn
## on both sides of a screen title. It is the one purely decorative mark in the language —
## it says "this is a page", which is the job a panel border used to do.
## `half_w` is the length of one wing, measured from the diamond outward.
func _flourish(centre: Vector2, half_w: float, col: Color = COL_ACCENT,
		diamond_half: float = 4.0) -> void:
	_diamond(centre, diamond_half, col)
	# The rule fades out as it travels away from the diamond, so it dissolves into the
	# negative space rather than stopping at a hard end.
	var steps := 12
	var start := diamond_half + 4.0
	var seg := (half_w - start) / float(steps)
	if seg <= 0.0:
		return
	for i in steps:
		var t := float(i) / float(steps)
		var a := col.a * (1.0 - t)
		var x0 := start + seg * float(i)
		var x1 := x0 + seg
		var c := Color(col, a)
		draw_line(centre + Vector2(x0, 0.0), centre + Vector2(x1, 0.0), c, 1.0, true)
		draw_line(centre - Vector2(x1, 0.0), centre - Vector2(x0, 0.0), c, 1.0, true)


## A dashed rectangle — the anchor uses it for the SELECTED list row and for the primary
## action button, and it is exactly the "approximated-dashed" mark the Slate slot-select
## had to fake with a dimmer stylebox (StyleBoxFlat has no dashed border). Drawn by hand
## so it is a real dash, and so the dash length is dialable.
func _dashed_rect(rect: Rect2, col: Color, w: float = 1.5, dash: float = 7.0,
		gap: float = 5.0) -> void:
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)
	for e: Array in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		_dashed_line(e[0], e[1], col, w, dash, gap)


func _dashed_line(from: Vector2, to: Vector2, col: Color, w: float = 1.5,
		dash: float = 7.0, gap: float = 5.0) -> void:
	var span := from.distance_to(to)
	if span <= 0.0 or dash <= 0.0:
		return
	var dir := (to - from) / span
	var travelled := 0.0
	while travelled < span:
		var seg := minf(dash, span - travelled)
		draw_line(from + dir * travelled, from + dir * (travelled + seg), col, w, true)
		travelled += dash + gap


## A list row's bounds. NOT a panel: a barely-there wash inside a hairline, so the row
## groups its contents without acquiring a border the eye has to read past. `state` is one
## of "idle" / "hover" / "selected" / "disabled"; selected gets the dashed gold frame that
## marks the screen's single active thing.
func _row_box(rect: Rect2, state: String = "idle", radius: float = 0.0) -> void:
	var fill := COL_ROW
	var border := COL_HAIR
	match state:
		"hover":
			fill = COL_ROW_HOVER
			border = COL_RING
		"selected":
			fill = COL_ROW_SELECTED
		"disabled":
			fill = Color(COL_ROW, COL_ROW.a * 0.5)
			border = Color(COL_HAIR, COL_HAIR.a * 0.6)
	if radius > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(radius))
		draw_style_box(sb, rect)
	else:
		draw_rect(rect, fill, true)
	if state == "selected":
		_dashed_rect(rect, COL_ACCENT)
	else:
		draw_rect(rect, border, false, 1.0)


## A level track: one small diamond per level, from EmberMenuCore.pip_states.
## filled = gold, next = a gold outline (the affordance), rest = a faint outline.
## Centred on `centre`; returns the track's total width so a caller can lay out beside it.
func _pips(centre: Vector2, states: Array[String], half: float = 4.5,
		gap: float = 13.0) -> float:
	var n := states.size()
	if n == 0:
		return 0.0
	var total := float(n - 1) * gap
	var x := centre.x - total * 0.5
	for s: String in states:
		var p := Vector2(x, centre.y)
		match s:
			"filled":
				_diamond(p, half, COL_ACCENT)
			"next":
				_diamond(p, half, COL_ACCENT, false, 1.4)
			_:
				_diamond(p, half * 0.85, COL_RING, false, 1.2)
		x += gap
	return total + half * 2.0


## A footer input prompt: the key in a thin ring, then its label. The anchor's `Ⓑ Back` /
## `Ⓐ Select` row — it is where a menu says what its inputs do, now that the Close buttons
## are gone (the ESC-close pass, design/ui-hud.md). Returns the total width drawn.
func _prompt(pos: Vector2, key: String, label: String, col: Color = COL_INK_DIM,
		radius: float = 9.0, gap: float = 9.0) -> float:
	var centre := Vector2(pos.x + radius, pos.y)
	_ring(centre, radius, 1.2, col)
	_text_centred(centre.x, centre.y, key, col, FS_KEY, _font_ui_med)
	var lx := pos.x + radius * 2.0 + gap
	return radius * 2.0 + gap + _text_at(Vector2(lx, pos.y), label, col, FS_PROMPT, _font_ui)


## Width `_prompt` will occupy — for right-aligning one against the screen edge.
func _prompt_w(key: String, label: String, radius: float = 9.0, gap: float = 9.0) -> float:
	var _unused := key  # the ring is a fixed size whatever the key is
	return radius * 2.0 + gap + _text_w(label, FS_PROMPT, _font_ui)


## A section head: tracked caps sitting over a hairline that runs to `to_x`. The dock's
## `WEAPON LEVEL` / `UPGRADE COST` grammar — Ember's replacement for a titled panel.
## Returns the y the first row under it should use.
func _section(from_x: float, to_x: float, y: float, label: String,
		col: Color = COL_INK_DIM, rule_drop: float = 13.0,
		first_row_drop: float = 24.0) -> float:
	_text_tracked(Vector2(from_x, y), label, col, FS_HEAD, _font_ui_med)
	_hairline(from_x, to_x, y + rule_drop)
	return y + first_row_drop


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
	# --- Menu marks (added 2026-08-13 with the menu vocabulary) -------------------------
	# The town's other two resources, so all seven now have a mark (the run HUD only ever
	# showed four). The anchor uses a green leaf for its third resource — kept for food.
	"leaf": [Vector2(0, -0.46), Vector2(0.26, -0.10), Vector2(0.20, 0.24),
		Vector2(0, 0.46), Vector2(-0.20, 0.24), Vector2(-0.26, -0.10)],
	"stone": [Vector2(-0.40, 0.10), Vector2(-0.22, -0.26), Vector2(0.14, -0.32),
		Vector2(0.40, -0.02), Vector2(0.36, 0.30), Vector2(-0.10, 0.38),
		Vector2(-0.36, 0.30)],
	# Category / screen marks — the anchor's left icon rail and its stat rows.
	"sword": [Vector2(0, -0.48), Vector2(0.09, -0.32), Vector2(0.09, 0.10),
		Vector2(-0.09, 0.10), Vector2(-0.09, -0.32)],
	"shield": [Vector2(0, -0.44), Vector2(0.34, -0.29), Vector2(0.30, 0.12),
		Vector2(0, 0.46), Vector2(-0.30, 0.12), Vector2(-0.34, -0.29)],
	"heart": [Vector2(0, -0.20), Vector2(0.14, -0.40), Vector2(0.34, -0.36),
		Vector2(0.45, -0.16), Vector2(0.38, 0.08), Vector2(0, 0.46),
		Vector2(-0.38, 0.08), Vector2(-0.45, -0.16), Vector2(-0.34, -0.36),
		Vector2(-0.14, -0.40)],
	"boot": [Vector2(-0.20, -0.44), Vector2(0.02, -0.44), Vector2(0.05, 0.08),
		Vector2(0.40, 0.20), Vector2(0.42, 0.40), Vector2(-0.20, 0.40)],
	"star": [Vector2(0, -0.48), Vector2(0.11, -0.11), Vector2(0.48, 0),
		Vector2(0.11, 0.11), Vector2(0, 0.48), Vector2(-0.11, 0.11),
		Vector2(-0.48, 0), Vector2(-0.11, -0.11)],
	"anvil": [Vector2(-0.32, -0.26), Vector2(0.22, -0.26), Vector2(0.45, -0.15),
		Vector2(0.22, -0.05), Vector2(0.11, -0.03), Vector2(0.09, 0.20),
		Vector2(0.28, 0.40), Vector2(-0.28, 0.40), Vector2(-0.09, 0.20),
		Vector2(-0.11, -0.03), Vector2(-0.32, -0.08)],
	"lock": [Vector2(-0.27, 0.02), Vector2(0.27, 0.02), Vector2(0.27, 0.40),
		Vector2(-0.27, 0.40)],
}
## A second filled piece for glyphs built from two shapes.
const GLYPH_FILL2 := {
	"shards": [Vector2(0.17, 0.01), Vector2(0.34, 0.19), Vector2(0.23, 0.46), Vector2(0.11, 0.27)],
	# The sword's crossguard — without it the blade reads as a spike.
	"sword": [Vector2(-0.28, 0.10), Vector2(0.28, 0.10), Vector2(0.28, 0.20),
		Vector2(-0.28, 0.20)],
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
	# --- Menu marks --------------------------------------------------------------------
	# Sword — the grip + pommel below the crossguard. Without them the blade and guard
	# read as a letter T (caught in the first render_menu.tscn pass).
	"sword": [[Vector2(0, 0.20), Vector2(0, 0.42)],
		[Vector2(-0.09, 0.44), Vector2(0.09, 0.44)]],
	"leaf": [[Vector2(0, -0.42), Vector2(0, 0.42)]],
	"stone": [[Vector2(-0.22, -0.26), Vector2(-0.04, 0.02), Vector2(0.40, -0.02)],
		[Vector2(-0.04, 0.02), Vector2(-0.10, 0.38)]],
	# Book — a spine with two pages falling away from it (knowledge, the codex).
	"book": [[Vector2(0, -0.26), Vector2(0, 0.32)],
		[Vector2(0, -0.26), Vector2(-0.20, -0.34), Vector2(-0.44, -0.28),
			Vector2(-0.44, 0.26), Vector2(-0.20, 0.32), Vector2(0, 0.32)],
		[Vector2(0, -0.26), Vector2(0.20, -0.34), Vector2(0.44, -0.28),
			Vector2(0.44, 0.26), Vector2(0.20, 0.32), Vector2(0, 0.32)]],
	# House — the town / buildings mark.
	"house": [[Vector2(-0.40, 0.02), Vector2(0, -0.38), Vector2(0.40, 0.02)],
		[Vector2(-0.30, 0.02), Vector2(-0.30, 0.40), Vector2(0.30, 0.40),
			Vector2(0.30, 0.02)]],
	# Check — a researched node, a built level, a met requirement.
	"check": [[Vector2(-0.36, 0.02), Vector2(-0.10, 0.30), Vector2(0.38, -0.30)]],
}
## Glyphs that also want one or more arcs. Entry: [radius, from_rad, to_rad] — with an
## optional 4th/5th element giving the arc's centre OFFSET in unit-square coords, for
## marks whose arc is not concentric with the glyph (the padlock's shackle).
const GLYPH_ARCS := {
	"snare": [[0.26, 0.0, TAU]],
	# Shockwave — three nested arcs opening to the right.
	"shockwave": [[0.16, -0.95, 0.95], [0.30, -0.95, 0.95], [0.44, -0.95, 0.95]],
	# Lock — the shackle: a half circle sitting on top of the body, opening downward.
	"lock": [[0.19, PI, TAU, 0.0, 0.02]],
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
			var off := Vector2.ZERO
			if a.size() >= 5:
				off = Vector2(float(a[3]), float(a[4])) * glyph_size
			draw_arc(centre + off, glyph_size * float(a[0]), float(a[1]), float(a[2]),
				32, col, stroke_w, true)


## Unit-square points -> screen points.
static func _scaled(pts: Array, centre: Vector2, glyph_size: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(centre + p * glyph_size)
	return out
