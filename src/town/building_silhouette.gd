extends Control
class_name BuildingSilhouette
## One building silhouette, drawn from a small registry keyed by building id, in a local
## ground-origin box (local y=0 is the plot line; the building rises into negative y). Used two
## ways: the build panel paints the selected building LARGE via the static `paint()`, and the
## survey embeds a BuildingSilhouette instance per row (setup(id, level) → _draw). The shape
## grows/extends with the built level. An unknown building id falls back to its monogram
## (HudCore.monogram), so a future building never crashes the screens.
##
## HUMAN: the geometry, widths, and colours are PLACEHOLDERS for the painterly pass — real
## drawn buildings replace these primitives later (no combat feel, so no `# FEEL:` tag).

# =====================================================================================
# Style — placeholders. (Palette elsewhere is shared — see EmberHud.)
# =====================================================================================
const COL_BODY_FILL := Color(46.0 / 255, 44.0 / 255, 55.0 / 255)     # #2e2c37 wall body
const COL_BODY_STROKE := Color(74.0 / 255, 71.0 / 255, 86.0 / 255)   # #4a4756 edge
const COL_DETAIL_FILL := Color(34.0 / 255, 31.0 / 255, 40.0 / 255)   # #221f28 door / detail
const LOCAL_W := 260.0   # nominal local box width (for the instance-node scale)

var id: String = ""
var level: int = 1
var fill_col: Color = COL_BODY_FILL
var stroke_col: Color = COL_BODY_STROKE
var line_w: float = 2.0
var mono_font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(building_id: String, lvl: int, mono: Font,
		fill := COL_BODY_FILL, stroke := COL_BODY_STROKE) -> void:
	id = building_id
	level = lvl
	mono_font = mono
	fill_col = fill
	stroke_col = stroke
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0:
		return
	var scale := size.x / LOCAL_W
	var baseline := Vector2(size.x * 0.5, size.y * 0.82)
	paint(self, id, baseline, scale, fill_col, stroke_col, line_w, mono_font, int(size.y * 0.4), level)


## Strokes for `id` at `level`, in a local box where y=0 is the plot line (building rises up
## into -y). Each is one of: {"t":"poly", pts, fill, stroke, grip}, {"t":"line", a, b}.
static func _strokes(id: String, level: int) -> Array:
	var lv := clampi(level, 1, 3)
	match id:
		"sophias-study":  # a tall narrow house (research tower), taller per level
			var h := 46.0 + 20.0 * float(lv)
			return [
				{"t": "poly", "pts": [Vector2(-26, 0), Vector2(26, 0), Vector2(26, -h),
					Vector2(-26, -h)], "fill": true, "stroke": true},
				{"t": "poly", "pts": [Vector2(-34, -h), Vector2(0, -h - 30), Vector2(34, -h)],
					"fill": true, "stroke": true},
				{"t": "poly", "pts": [Vector2(-8, 0), Vector2(8, 0), Vector2(8, -22),
					Vector2(-8, -22)], "fill": true, "stroke": true, "grip": true},  # door
				{"t": "line", "a": Vector2(-14, -h + 16), "b": Vector2(14, -h + 16)},  # window sill
			]
		"farm":  # a house on the left + field furrows on the right, one more furrow per level
			var strokes: Array = [
				{"t": "poly", "pts": [Vector2(-92, 0), Vector2(-44, 0), Vector2(-44, -42),
					Vector2(-92, -42)], "fill": true, "stroke": true},
				{"t": "poly", "pts": [Vector2(-100, -42), Vector2(-68, -70), Vector2(-36, -42)],
					"fill": true, "stroke": true},
				{"t": "poly", "pts": [Vector2(-74, 0), Vector2(-62, 0), Vector2(-62, -24),
					Vector2(-74, -24)], "fill": true, "stroke": true, "grip": true},  # door
			]
			for i in lv + 1:
				var y := -6.0 - 12.0 * float(i)
				strokes.append({"t": "line", "a": Vector2(-18, y), "b": Vector2(96, y)})
			return strokes
		"quarry":  # a pyramid of hewn stone blocks, one more row per level
			var strokes2: Array = []
			var rows := lv + 1
			for r in rows:
				var wide := rows - r
				var by := -22.0 * float(r)
				var bx0 := -22.0 * float(wide)
				for b in wide:
					var x := bx0 + 44.0 * float(b)
					strokes2.append({"t": "poly", "pts": [Vector2(x, by), Vector2(x + 40, by),
						Vector2(x + 40, by - 20), Vector2(x, by - 20)], "fill": true, "stroke": true})
			return strokes2
		"town-walls":  # a wall run with crenellations, wider + more merlons per level
			var w := 70.0 + 18.0 * float(lv)
			var strokes3: Array = [
				{"t": "poly", "pts": [Vector2(-w, 0), Vector2(w, 0), Vector2(w, -46),
					Vector2(-w, -46)], "fill": true, "stroke": true},
			]
			var merlons := 3 + lv
			var mw := (2.0 * w) / (2.0 * float(merlons) + 1.0)
			for m in merlons:
				var mx := -w + mw * (2.0 * float(m) + 1.0)
				strokes3.append({"t": "poly", "pts": [Vector2(mx, -46), Vector2(mx + mw, -46),
					Vector2(mx + mw, -62), Vector2(mx, -62)], "fill": true, "stroke": true})
			return strokes3
	return []


## Paint the silhouette for `building_id` at `level`, its plot line at `baseline`, `scale`
## mapping local units to px, in the given metal colours. Unknown id → its monogram, centred.
static func paint(ci: CanvasItem, building_id: String, baseline: Vector2, scale: float,
		fill_col: Color, stroke_col: Color, line_w: float, mono: Font, mono_fs: int,
		level := 1) -> void:
	var strokes := _strokes(building_id, level)
	if strokes.is_empty():
		if mono != null:
			var m := HudCore.monogram(building_id.capitalize())
			var tw := mono.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs).x
			var c := baseline - Vector2(0, mono_fs * 0.8)
			var y := c.y + (mono.get_ascent(mono_fs) - mono.get_descent(mono_fs)) * 0.5
			ci.draw_string(mono, Vector2(c.x - tw * 0.5, y), m,
				HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs, fill_col)
		return
	for s: Dictionary in strokes:
		match str(s["t"]):
			"poly":
				var pts := PackedVector2Array()
				for p: Vector2 in s["pts"]:
					pts.append(baseline + p * scale)
				if bool(s.get("fill", false)):
					var col := COL_DETAIL_FILL if bool(s.get("grip", false)) else fill_col
					ci.draw_colored_polygon(pts, col)
				if bool(s.get("stroke", false)):
					var closed := pts
					closed.append(pts[0])
					ci.draw_polyline(closed, stroke_col, line_w, true)
			"line":
				ci.draw_line(baseline + Vector2(s["a"]) * scale, baseline + Vector2(s["b"]) * scale,
					stroke_col, line_w, true)
