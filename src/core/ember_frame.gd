extends EmberHud
class_name EmberFrame
## A bounding mark as a packable Control — the hairline rect, the dashed rect, or the thin
## ring, drawn to fill this node's own rect. The Control-tree counterpart of `_row_box` /
## `_dashed_rect` / `_ring`, the way `EmberPips` is the counterpart of `_pips`.
##
## Why it exists: a `StyleBoxFlat` cannot draw a dashed border, and it cannot draw a circle.
## Both are Ember marks with meaning — the dashed frame is "this is the selected/empty
## thing" and the ring is the medallion an echo, an achievement and an ability slot all
## wear — so a Control-tree screen that needs either had to fake it. The slot-select's own
## source said so out loud ("dashed borders aren't a StyleBoxFlat feature — approximated"),
## and the menu vocabulary promised `_dashed_rect` would retire that approximation. This is
## how it does, without rebuilding the plaques into a drawn screen.
##
## Add it as a child of the thing it bounds, anchored full-rect, and it paints over that
## node's whole area. Mouse-transparent, so the parent keeps its own hit-testing.
##
## HUMAN: the widths below are placeholders — dial like FEEL numbers.

## `rect` — a plain 1 px frame · `dashed` — the dashed selected/empty frame · `ring` — a
## circle inscribed in the rect (used for medallions, where the node is square).
enum Shape { RECT, DASHED, RING }

const WIDTH := 1.0
const RING_WIDTH := 1.6
const WASH_INSET := 0.0   # shrink the frame inside its rect, if a row needs breathing room

var shape: int = Shape.RECT
var col: Color = COL_HAIR
## Optional barely-there wash inside the frame — the `_row_box` half of the mark. Leave
## fully transparent (the default) for a frame that only outlines.
var wash: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	super._ready()
	# EmberHud presets a full-rect HUD overlay, which is right here: this node fills its
	# parent. It must not eat the parent's clicks, and EmberHud already ignores the mouse.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Point the frame at a shape + colour. Kept as one call so a caller re-styling on hover
## cannot set the shape and forget the colour.
func setup(shape_in: int, col_in: Color, wash_in: Color = Color(0, 0, 0, 0)) -> void:
	shape = shape_in
	col = col_in
	wash = wash_in
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var r := Rect2(Vector2(WASH_INSET, WASH_INSET),
		size - Vector2(WASH_INSET, WASH_INSET) * 2.0)
	match shape:
		Shape.RING:
			var centre := size * 0.5
			var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH
			if wash.a > 0.0:
				_disc(centre, radius, wash)
			_ring(centre, radius, RING_WIDTH, col)
		Shape.DASHED:
			if wash.a > 0.0:
				draw_rect(r, wash, true)
			_dashed_rect(r, col)
		_:
			if wash.a > 0.0:
				draw_rect(r, wash, true)
			draw_rect(r, col, false, WIDTH)
