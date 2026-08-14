extends Control
class_name WeaponSilhouette
## One weapon silhouette, drawn from a small registry keyed by weapon id (geometry lifted
## from the F2 "anvil" mock's inline SVGs, in a local center-origin box). The forge screen
## paints the three known weapons two ways — small on the left tabs and large on the anvil —
## via the static `paint()` (one geometry, a `scale` param). An unknown weapon id falls back
## to the weapon's monogram (HudCore.monogram), so a future weapon never crashes the forge.
##
## HUMAN: the geometry, widths, and metal colours are PLACEHOLDERS for the painterly pass —
## real forged blades replace these primitives later (no combat feel, so no `# FEEL:` tag).

# =====================================================================================
# Style — placeholders. (Palette elsewhere is shared — see EmberHud.)
# =====================================================================================
const COL_METAL_FILL := Color(46.0/255, 44.0/255, 55.0/255)     # #2e2c37 blade body
const COL_METAL_STROKE := Color(67.0/255, 65.0/255, 79.0/255)   # #43414f edge
const COL_GRIP_FILL := Color(34.0/255, 31.0/255, 40.0/255)      # #221f28 grip / haft

## Each weapon is a list of "parts". A part carries an optional assembly transform
## (angle + offset, in the local box) and a list of strokes. A stroke is one of:
##   {"t":"poly",   "pts":[Vector2...], "fill":bool, "stroke":bool}   (closed if filled)
##   {"t":"pline",  "pts":[Vector2...]}                                (open outline)
##   {"t":"line",   "a":Vector2, "b":Vector2}
##   {"t":"circle", "c":Vector2, "r":float, "fill":bool}
## `fill` uses `fill_col`/COL_GRIP (per stroke's "grip" flag); strokes/lines use `stroke_col`.
static func _geometry(id: String) -> Array:
	match id:
		"sword":
			return [{
				"angle": 0.0, "off": Vector2.ZERO, "strokes": [
					# blade
					{"t": "poly", "pts": [Vector2(-240, 0), Vector2(-190, -14), Vector2(180, -6),
						Vector2(225, 0), Vector2(180, 6), Vector2(-190, 14)], "fill": true, "stroke": true},
					{"t": "line", "a": Vector2(180, -6), "b": Vector2(180, 6)},   # guard edge
					# crossguard (vertical bar)
					{"t": "poly", "pts": [Vector2(174, -31), Vector2(186, -31), Vector2(186, 31),
						Vector2(174, 31)], "fill": true, "stroke": true, "grip": true},
					# grip
					{"t": "poly", "pts": [Vector2(186, -8), Vector2(238, -8), Vector2(238, 9),
						Vector2(186, 9)], "fill": true, "stroke": true, "grip": true},
					{"t": "circle", "c": Vector2(248, 0), "r": 9.0, "fill": true, "grip": true},  # pommel
				]}]
		"daggers":
			var blade: Array = [
				{"t": "poly", "pts": [Vector2(-90, 0), Vector2(-70, -7), Vector2(60, -5),
					Vector2(78, 0), Vector2(60, 5), Vector2(-70, 7)], "fill": true, "stroke": true},
				{"t": "poly", "pts": [Vector2(78, -9), Vector2(86, -9), Vector2(86, 9),
					Vector2(78, 9)], "fill": true, "stroke": true, "grip": true},           # guard
				{"t": "poly", "pts": [Vector2(86, -4), Vector2(120, -4), Vector2(120, 4),
					Vector2(86, 4)], "fill": true, "stroke": true, "grip": true},           # grip
			]
			return [
				{"angle": -0.14, "off": Vector2(0, -26), "strokes": blade},
				{"angle": 0.14, "off": Vector2(0, 26), "strokes": blade},
			]
		"bow":
			# Stave sampled as a parabola bulging up; string across the tips; a grip nock.
			var stave := PackedVector2Array()
			var inner := PackedVector2Array()
			var steps := 12
			for i in steps + 1:
				var t := -1.0 + 2.0 * float(i) / float(steps)
				var x := 200.0 * t
				var y := -110.0 * (1.0 - t * t)
				stave.append(Vector2(x, y))
				inner.append(Vector2(x, y + 9.0))
			return [{
				"angle": 0.0, "off": Vector2.ZERO, "strokes": [
					{"t": "pline", "pts": Array(stave)},
					{"t": "pline", "pts": Array(inner)},
					{"t": "line", "a": Vector2(-200, 0), "b": Vector2(200, 0)},   # string
					{"t": "circle", "c": Vector2(0, 0), "r": 7.0, "fill": true, "grip": true},  # grip
				]}]
	return []


## Paint the silhouette for `weapon_id` centred at `center`, `scale` mapping the local box
## to pixels, tilted by `angle` (radians). Unknown id → the monogram text, centred.
static func paint(ci: CanvasItem, weapon_id: String, center: Vector2, scale: float,
		fill_col: Color, stroke_col: Color, line_w: float, mono: Font, mono_fs: int,
		angle := 0.0) -> void:
	var parts := _geometry(weapon_id)
	if parts.is_empty():
		if mono != null:
			var m := HudCore.monogram(weapon_id.capitalize())
			var tw := mono.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs).x
			var y := center.y + (mono.get_ascent(mono_fs) - mono.get_descent(mono_fs)) * 0.5
			ci.draw_string(mono, Vector2(center.x - tw * 0.5, y), m,
				HORIZONTAL_ALIGNMENT_LEFT, -1, mono_fs, fill_col)
		return
	for part: Dictionary in parts:
		var pa := float(part.get("angle", 0.0))
		var po := Vector2(part.get("off", Vector2.ZERO))
		for stroke: Dictionary in part["strokes"]:
			match str(stroke["t"]):
				"poly":
					var pts := _xform(stroke["pts"], pa, po, angle, scale, center)
					if bool(stroke.get("fill", false)):
						var col := COL_GRIP_FILL if bool(stroke.get("grip", false)) else fill_col
						ci.draw_colored_polygon(pts, col)
					if bool(stroke.get("stroke", false)):
						var closed := pts
						closed.append(pts[0])
						ci.draw_polyline(closed, stroke_col, line_w, true)
				"pline":
					ci.draw_polyline(_xform(stroke["pts"], pa, po, angle, scale, center),
						stroke_col, line_w, true)
				"line":
					var a := _pt(Vector2(stroke["a"]), pa, po, angle, scale, center)
					var b := _pt(Vector2(stroke["b"]), pa, po, angle, scale, center)
					ci.draw_line(a, b, stroke_col, line_w, true)
				"circle":
					var c := _pt(Vector2(stroke["c"]), pa, po, angle, scale, center)
					var r := float(stroke["r"]) * scale
					if bool(stroke.get("fill", false)):
						var col := COL_GRIP_FILL if bool(stroke.get("grip", false)) else fill_col
						ci.draw_circle(c, r, col)
					ci.draw_arc(c, r, 0.0, TAU, 24, stroke_col, line_w, true)


static func _pt(p: Vector2, part_angle: float, part_off: Vector2, angle: float,
		scale: float, center: Vector2) -> Vector2:
	# Assemble in the local box (rotate the part, add its offset), tilt the whole weapon,
	# then scale to pixels and place at the centre.
	return center + (p.rotated(part_angle) + part_off).rotated(angle) * scale


static func _xform(pts: Array, part_angle: float, part_off: Vector2, angle: float,
		scale: float, center: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(_pt(p, part_angle, part_off, angle, scale, center))
	return out
