extends Control
class_name SigilIcon
## One etching sigil, drawn from a small registry keyed by ability id (geometry lifted from
## the E1 mock's inline SVGs, in a 40x40 viewbox). Used two ways: the arms panel paints the
## four site sigils via the static `paint()`, and the skill menu embeds a SigilIcon instance
## in its header. An unknown id falls back to the ability's monogram (HudCore.monogram), so
## an old save with e.g. Bolt equipped still renders a mark.
##
## HUMAN: the geometry + widths are placeholders for the painterly pass — real engraved
## sigils replace these primitives later.

## Registry: id → list of strokes. A stroke is {t:"poly"|"circle"|"arc", ...} in the 40-box.
##   poly:   {pts: [Vector2,...], closed: bool}
##   circle: {c: Vector2, r: float, fill: bool}
##   arc:    {c: Vector2, r: float, a0: float, a1: float}   (radians)
const SIGILS: Dictionary = {
	# Push — three nested upward chevrons.
	"push": [
		{"t": "poly", "pts": [Vector2(12, 30), Vector2(20, 22), Vector2(28, 30)]},
		{"t": "poly", "pts": [Vector2(12, 21), Vector2(20, 13), Vector2(28, 21)]},
		{"t": "poly", "pts": [Vector2(15, 11), Vector2(20, 6), Vector2(25, 11)]},
	],
	# Snare — concentric circles + a center dot.
	"snare": [
		{"t": "circle", "c": Vector2(20, 20), "r": 13.0, "fill": false},
		{"t": "circle", "c": Vector2(20, 20), "r": 6.5, "fill": false},
	],
	# Shockwave — a point with radiating arcs above it.
	"shockwave": [
		{"t": "circle", "c": Vector2(20, 24), "r": 3.0, "fill": true},
		{"t": "arc", "c": Vector2(20, 30), "r": 12.0, "a0": -2.55, "a1": -0.59},
		{"t": "arc", "c": Vector2(20, 30), "r": 19.0, "a0": -2.36, "a1": -0.78},
	],
	# Dash — three slanted, rising dashes.
	"dash": [
		{"t": "poly", "pts": [Vector2(6, 26), Vector2(16, 26)]},
		{"t": "poly", "pts": [Vector2(14, 19), Vector2(26, 19)]},
		{"t": "poly", "pts": [Vector2(22, 12), Vector2(34, 12)]},
	],
}

## Ability ids whose center dot marks an AWAKE mark (a sigil with a "core"). Concentric
## sigils (snare) drop a filled dot in the middle; chevron/arc ones don't.
const HAS_CENTER_DOT: Array[String] = ["snare"]

var id: String = ""
var col: Color = SigilIcon._dust()
var box: float = 34.0
var line_w: float = 2.4
var mono_font: Font = null


static func _dust() -> Color:
	return SlateHud.COL_DUST


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box, box)


func setup(ability_id: String, colour: Color, mono: Font) -> void:
	id = ability_id
	col = colour
	mono_font = mono
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	paint(self, id, center, box / 40.0, col, line_w, false, mono_font, int(box * 0.5))


## Paint one sigil onto any CanvasItem. `scale` maps the 40-box to pixels; `dot` draws the
## awake center core when the sigil supports one. Unknown id → the monogram text.
static func paint(ci: CanvasItem, ability_id: String, center: Vector2, scale: float,
		colour: Color, width: float, dot: bool, mono: Font, mono_fs: int) -> void:
	if not SIGILS.has(ability_id):
		if mono != null:
			var m := HudCore.monogram(ability_id.capitalize())
			var tw := mono.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs).x
			var y := center.y + (mono.get_ascent(mono_fs) - mono.get_descent(mono_fs)) * 0.5
			ci.draw_string(mono, Vector2(center.x - tw * 0.5, y), m,
				HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs, colour)
		return
	for stroke: Dictionary in SIGILS[ability_id]:
		match str(stroke["t"]):
			"poly":
				var pts := PackedVector2Array()
				for p: Vector2 in stroke["pts"]:
					pts.append(center + (p - Vector2(20, 20)) * scale)
				ci.draw_polyline(pts, colour, width, true)
			"circle":
				var c: Vector2 = center + (Vector2(stroke["c"]) - Vector2(20, 20)) * scale
				var r := float(stroke["r"]) * scale
				if bool(stroke.get("fill", false)):
					ci.draw_circle(c, r, colour)
				else:
					ci.draw_arc(c, r, 0.0, TAU, 40, colour, width, true)
			"arc":
				var ac: Vector2 = center + (Vector2(stroke["c"]) - Vector2(20, 20)) * scale
				ci.draw_arc(ac, float(stroke["r"]) * scale, float(stroke["a0"]),
					float(stroke["a1"]), 24, colour, width, true)
	# The awake core dot for concentric sigils.
	if dot and ability_id in HAS_CENTER_DOT:
		ci.draw_circle(center, maxf(1.4 * scale, 1.5), colour)
