extends Control
class_name SlotSelectSky
## The night-sky backdrop of the slot-select / title screen — "Under the night sky" (S2,
## human-picked 2026-07-08 via claude.ai/design). Drawn entirely in `_draw`: a vertical
## gradient, a DETERMINISTIC scatter of faint stars, ONE faint cyan constellation upper-right
## (the research chart's visual language leaking into the title — Tycho Brahe again), a dark
## ridge silhouette along the bottom with a soft darkening above it, and the big Cinzel TYCHO
## title with a cool glow + the dim Garamond subtitle. The three saga plaques sit on top as
## panel siblings; this Control is pure pixels (MOUSE_FILTER_IGNORE), never re-randomized.
##
## MIGRATED TO EMBER 2026-08-14 (Tier C) — the smallest migration in the whole project,
## because this node is an ILLUSTRATION rather than a UI surface: it draws its own opaque
## sky, so it borrowed only three colours from Slate. Those three now come from EmberHud
## and nothing else changed. The title screen was always going to be the least affected.
##
## HUMAN: everything under "Style" is a PLACEHOLDER — gradient stops, the star/constellation/
## ridge geometry, the title size/spacing/glow, and the subtitle copy. Dial like FEEL numbers
## (no combat feel, so no `# FEEL:` tag). The shared palette + fonts live in EmberHud.

# =====================================================================================
# Style — placeholders. (Shared palette + fonts are in EmberHud.)
# =====================================================================================
# Gradient (three vertical stops; hex in the comment, Color(r/255,…) so it const-folds).
const COL_SKY_TOP := Color(10.0/255, 9.0/255, 16.0/255)        # #0a0910
const COL_SKY_MID := Color(18.0/255, 17.0/255, 26.0/255)       # #12111a
const COL_SKY_LOW := Color(25.0/255, 23.0/255, 34.0/255)       # #191722
const SKY_MID_STOP := 0.55                                     # where the mid stop sits
const GRAD_STRIPS := 64
# Stars — {pos (normalized to size), r (px), a}. A FIXED scatter; never re-randomized.
const COL_STAR := Color(201.0/255, 197.0/255, 214.0/255)       # #c9c5d6
const STARS: Array[Dictionary] = [
	{"p": Vector2(0.08, 0.10), "r": 1.4, "a": 0.35},
	{"p": Vector2(0.16, 0.26), "r": 1.1, "a": 0.20},
	{"p": Vector2(0.27, 0.08), "r": 1.4, "a": 0.30},
	{"p": Vector2(0.38, 0.19), "r": 1.1, "a": 0.22},
	{"p": Vector2(0.56, 0.07), "r": 1.4, "a": 0.30},
	{"p": Vector2(0.68, 0.22), "r": 1.1, "a": 0.20},
	{"p": Vector2(0.79, 0.11), "r": 1.7, "a": 0.40},
	{"p": Vector2(0.90, 0.24), "r": 1.1, "a": 0.24},
	{"p": Vector2(0.05, 0.44), "r": 1.1, "a": 0.18},
	{"p": Vector2(0.94, 0.47), "r": 1.4, "a": 0.25},
]
# One constellation, upper-right (cyan stars + thin slate joins). Normalized points.
const CONSTELLATION_PTS: Array[Vector2] = [
	Vector2(0.750, 0.250), Vector2(0.805, 0.181), Vector2(0.867, 0.215), Vector2(0.918, 0.139),
]
const CONSTELLATION_R: Array[float] = [2.4, 3.0, 2.2, 2.8]
const CONSTELLATION_A: Array[float] = [0.80, 0.90, 0.70, 0.85]
const CONSTELLATION_LINE_A := 0.55
# Ridge silhouette — a jagged near-black polygon pinned to the bottom RIDGE_H px.
# {x normalized, y in px measured DOWN from the top of the ridge band}.
const RIDGE_H := 70.0
const COL_RIDGE := Color(14.0/255, 13.0/255, 19.0/255)         # #0e0d13
const RIDGE_PTS: Array[Vector2] = [
	Vector2(0.000, 44), Vector2(0.109, 52), Vector2(0.250, 30), Vector2(0.406, 48),
	Vector2(0.547, 26), Vector2(0.703, 44), Vector2(0.844, 34), Vector2(1.000, 50),
]
# Horizon darkening above the ridge (transparent → near-black).
const HORIZON_H := 130.0
const HORIZON_STRIPS := 26
const HORIZON_MAX_A := 0.80
# Title.
const COL_TITLE := Color(230.0/255, 227.0/255, 240.0/255)      # #e6e3f0 (brighter than COL_TEXT)
const TITLE_TEXT := "TYCHO"
const TITLE_FS := 72
const TITLE_SPACING := 16                                      # per-glyph letter spacing
const TITLE_TOP_FRAC := 0.135                                  # title baseline band, of size.y
const TITLE_GLOW_LAYERS := 5
const TITLE_GLOW_R := 150.0                                    # outer glow radius
const SUBTITLE_TEXT := "choose a saga"                         # placeholder copy
const SUBTITLE_FS := 16
const SUBTITLE_SPACING := 3
const SUBTITLE_DY := 22.0                                      # below the title box

## Two bespoke FontVariations: the title and subtitle carry per-glyph letter spacing, which
## the shared `EmberHud` variations must not (every other label would inherit it).
var _font_title: FontVariation
var _font_sub: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font_title = EmberHud._with_fallback(EmberHud.FONT_DISPLAY_FILE)
	_font_title.set_spacing(TextServer.SPACING_GLYPH, TITLE_SPACING)
	_font_sub = EmberHud._with_fallback(EmberHud.FONT_BODY_FILE)
	_font_sub.set_spacing(TextServer.SPACING_GLYPH, SUBTITLE_SPACING)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 1.0:
		return
	_draw_gradient()
	_draw_stars()
	_draw_constellation()
	_draw_horizon()
	_draw_ridge()
	_draw_title()


func _draw_gradient() -> void:
	var strip := size.y / float(GRAD_STRIPS)
	for i in GRAD_STRIPS:
		var t := (float(i) + 0.5) / float(GRAD_STRIPS)
		var col: Color
		if t < SKY_MID_STOP:
			col = COL_SKY_TOP.lerp(COL_SKY_MID, t / SKY_MID_STOP)
		else:
			col = COL_SKY_MID.lerp(COL_SKY_LOW, (t - SKY_MID_STOP) / (1.0 - SKY_MID_STOP))
		draw_rect(Rect2(0.0, strip * i, size.x, strip + 1.0), col)


func _draw_stars() -> void:
	for s: Dictionary in STARS:
		draw_circle(Vector2(s["p"]) * size, float(s["r"]), Color(COL_STAR, float(s["a"])))


func _draw_constellation() -> void:
	var pts: Array[Vector2] = []
	for np: Vector2 in CONSTELLATION_PTS:
		pts.append(np * size)
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], Color(EmberHud.COL_RING, CONSTELLATION_LINE_A), 1.0, true)
	for i in pts.size():
		draw_circle(pts[i], CONSTELLATION_R[i], Color(EmberHud.COL_KNOWLEDGE, CONSTELLATION_A[i]))


func _draw_horizon() -> void:
	var top := size.y - HORIZON_H
	var strip := HORIZON_H / float(HORIZON_STRIPS)
	for i in HORIZON_STRIPS:
		var a := HORIZON_MAX_A * (float(i) + 1.0) / float(HORIZON_STRIPS)
		draw_rect(Rect2(0.0, top + strip * i, size.x, strip + 1.0), Color(COL_SKY_TOP, a))


func _draw_ridge() -> void:
	var band_top := size.y - RIDGE_H
	var poly: PackedVector2Array = []
	for rp: Vector2 in RIDGE_PTS:
		poly.append(Vector2(rp.x * size.x, band_top + rp.y))
	poly.append(Vector2(size.x, size.y))   # bottom-right
	poly.append(Vector2(0.0, size.y))      # bottom-left
	draw_colored_polygon(poly, COL_RIDGE)


func _draw_title() -> void:
	var cx := size.x * 0.5
	var title_y := size.y * TITLE_TOP_FRAC
	# Cool glow behind the title.
	var glow_centre := Vector2(cx, title_y)
	for i in TITLE_GLOW_LAYERS:
		var t := float(i) / float(TITLE_GLOW_LAYERS)
		draw_circle(glow_centre, TITLE_GLOW_R * (1.0 - t * 0.7),
			Color(EmberHud.COL_KNOWLEDGE, 0.05 * (1.0 - t)))
	# TYCHO — big Cinzel, letter-spaced, centred.
	var tw := _font_title.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS).x
	var ty := title_y + _font_title.get_ascent(TITLE_FS) * 0.5
	draw_string(_font_title, Vector2(cx - tw * 0.5, ty), TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS, COL_TITLE)
	# Subtitle — dim Garamond, centred below.
	var sw := _font_sub.get_string_size(SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_FS).x
	var sy := ty + _font_title.get_descent(TITLE_FS) + SUBTITLE_DY + _font_sub.get_ascent(SUBTITLE_FS)
	draw_string(_font_sub, Vector2(cx - sw * 0.5, sy), SUBTITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_FS, EmberHud.COL_INK_DIM)
