extends RefCounted
class_name EmberMenuCore
## Pure layout + formatting rules for the "Ember" MENU screens (design/ui-hud.md §
## "Ember menu vocabulary"). Static, engine-free, unit-tested — `EmberHud` subclasses own
## only pixels, exactly as `HudCore` sits under `RunHud`.
##
## Why a core at all: fifteen screens are about to migrate off Slate, and the thing that
## makes them read as ONE language is that they agree on where the columns are and how a
## cost / delta / pip track is phrased. Agreeing in code (and in tests) beats fifteen
## screens each re-deriving it from the anchor by eye.
##
## The grammar comes from the human-picked anchor assets_src/anchors/weapon-menu-reference.png:
##
##   ┌ title band ─────────────────────────────────────── resources ┐
##   │ rail │  list column  │   hero stage   │   detail dock        │
##   └ footer band (prompts) ───────────────────────────────────────┘
##
## Not every screen wants all four columns — `catalogue()` gives the full grammar,
## `column()` gives the centred single-column variant (settings / achievements / any
## read-down page). Both hand back the SAME title/resources/footer bands, which is what
## keeps a four-column forge and a one-column settings page looking related.
##
## HUMAN: every number under "Layout dials" is a PLACEHOLDER. Dial like FEEL numbers
## (no combat feel rides on them). Dial board: design/feel-tuning.md § Ember menus.

# =====================================================================================
# Layout dials — placeholders. Fractions of the screen unless the name says PX.
# =====================================================================================
## Screen-edge margin. Deliberately larger than the HUD's `EmberHud.MARGIN`: a menu owns
## the whole screen and its negative space is doing the work a panel border used to do.
const PAD_PX := 46.0
## Title band: the big Cinzel name + its subtitle, above everything.
const TITLE_TOP_PX := 30.0      # title centre, below the top edge
const SUBTITLE_DROP_PX := 30.0  # subtitle centre, below the title centre
const CONTENT_TOP_PX := 96.0    # first content row, below the top edge
## Footer band: the `Ⓑ Back` / `Ⓐ Select` prompt row.
const FOOTER_BOTTOM_PX := 34.0  # prompt centre, above the bottom edge
const CONTENT_BOTTOM_PX := 66.0 # content stops here, above the bottom edge
## The four columns. Rail is fixed-width; list/hero/dock split the remainder by weight.
const RAIL_W_PX := 74.0
const COL_GAP_PX := 26.0
const LIST_WEIGHT := 0.34
const HERO_WEIGHT := 0.32
const DOCK_WEIGHT := 0.34
## The centred single-column variant.
const COLUMN_W_PX := 700.0

## Below this width the rail is dropped rather than squeezed (the layout degrades to
## list/hero/dock). Guards tiny windows without every screen writing its own branch.
const RAIL_MIN_W_PX := 900.0


# =====================================================================================
# Layout
# =====================================================================================

## The full four-column catalogue grammar (forge, etchings, build, market, tech, …).
## Returns Rect2s keyed: `title`, `subtitle`, `resources`, `rail`, `list`, `hero`, `dock`,
## `footer`, plus `content` (the whole band the four columns sit in).
##
## `title`/`subtitle`/`resources`/`footer` are ANCHOR rects: full-width bands one line
## tall, so a caller centres or edge-aligns its text inside them without re-deriving y.
static func catalogue(size: Vector2) -> Dictionary:
	var out := _bands(size)
	var content: Rect2 = out["content"]
	var x := content.position.x
	var show_rail := size.x >= RAIL_MIN_W_PX
	if show_rail:
		out["rail"] = Rect2(x, content.position.y, RAIL_W_PX, content.size.y)
		x += RAIL_W_PX + COL_GAP_PX
	else:
		out["rail"] = Rect2(x, content.position.y, 0.0, content.size.y)
	# Three columns share what the rail left, minus the two gaps between them.
	var free := maxf(0.0, content.end.x - x - COL_GAP_PX * 2.0)
	var total := LIST_WEIGHT + HERO_WEIGHT + DOCK_WEIGHT
	var list_w := free * (LIST_WEIGHT / total)
	var hero_w := free * (HERO_WEIGHT / total)
	out["list"] = Rect2(x, content.position.y, list_w, content.size.y)
	x += list_w + COL_GAP_PX
	out["hero"] = Rect2(x, content.position.y, hero_w, content.size.y)
	x += hero_w + COL_GAP_PX
	out["dock"] = Rect2(x, content.position.y, maxf(0.0, content.end.x - x), content.size.y)
	return out


## The centred single-column variant (settings, achievements, any read-down page).
## Same bands, one `column` rect instead of rail/list/hero/dock.
static func column(size: Vector2, width: float = COLUMN_W_PX) -> Dictionary:
	var out := _bands(size)
	var content: Rect2 = out["content"]
	var w := minf(width, content.size.x)
	out["column"] = Rect2(content.position.x + (content.size.x - w) * 0.5,
		content.position.y, w, content.size.y)
	return out


## The bands both layouts share.
static func _bands(size: Vector2) -> Dictionary:
	var left := PAD_PX
	var right := maxf(left, size.x - PAD_PX)
	var w := right - left
	var top := CONTENT_TOP_PX
	var bottom := maxf(top, size.y - CONTENT_BOTTOM_PX)
	return {
		"title": Rect2(left, TITLE_TOP_PX, w, 0.0),
		"subtitle": Rect2(left, TITLE_TOP_PX + SUBTITLE_DROP_PX, w, 0.0),
		"resources": Rect2(left, TITLE_TOP_PX, w, 0.0),
		"footer": Rect2(left, maxf(0.0, size.y - FOOTER_BOTTOM_PX), w, 0.0),
		"content": Rect2(left, top, w, bottom - top),
	}


## Where a `Label` node's TOP-LEFT goes so the label sits centred on a band's line.
##
## The bands above give a line's CENTRE (a drawn screen measures its own text and centres
## it), but a Control-tree screen positions a `Label` by its top-left — and every migrated
## panel was about to write the same `y - height * 0.5` by hand. Six copies of that is six
## chances to write `- height` instead, which reads as "the title drifted up a bit".
static func label_pos(band: Rect2, label_height: float) -> Vector2:
	return Vector2(band.position.x, band.position.y - label_height * 0.5)


## Evenly stack `count` rows of `row_h` (plus `gap`) down a column, starting at its top.
## Returns the row rects — the list column's one job, and the same maths every screen with
## a stacked list would otherwise repeat.
static func stack(col: Rect2, count: int, row_h: float, gap: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in maxi(0, count):
		out.append(Rect2(col.position.x, col.position.y + float(i) * (row_h + gap),
			col.size.x, row_h))
	return out


## How many `row_h`+`gap` rows fit in `col` — for deciding when a list needs to scroll.
static func rows_that_fit(col: Rect2, row_h: float, gap: float) -> int:
	if row_h <= 0.0:
		return 0
	return maxi(0, int(floorf((col.size.y + gap) / (row_h + gap))))


# =====================================================================================
# Formatting rules
# =====================================================================================

## A stat row's `38 › 44` upgrade delta. Returns `{from, to, changed, improved}` with the
## numbers already stringified per `unit`:
##   ""    -> "38"        (plain)
##   "%"   -> "120%"      (whole percent)
##   "x"   -> "0.80"      (two decimals — attack speed, multipliers)
## `changed` false means there is no arrow to draw (the caller prints `from` alone).
static func stat_delta(from: float, to: float, unit: String = "") -> Dictionary:
	return {
		"from": format_stat(from, unit),
		"to": format_stat(to, unit),
		"changed": not is_equal_approx(from, to),
		"improved": to > from,
	}


static func format_stat(v: float, unit: String = "") -> String:
	match unit:
		"%":
			return "%d%%" % roundi(v)
		"x":
			return "%.2f" % v
		_:
			# Whole numbers print bare; a genuinely fractional value keeps one decimal
			# rather than silently rounding a 1.5 into a 2.
			if is_equal_approx(v, roundf(v)):
				return "%d" % roundi(v)
			return "%.1f" % v


## The `80 / 128` cost readout under an action button. `costs` is the shipped
## `{resource_id: amount}` shape (TownCore / WeaponCore / EtchingsCore all speak it);
## `have` is what the Ledger holds. Returns `{rows, affordable}` where each row is
## `{id, need, have, ok}` and `affordable` is true only when EVERY row is ok.
##
## Row order follows `costs`' own key order — the data authored it, so gold-then-stone in
## a def stays gold-then-stone on screen.
static func cost_rows(costs: Dictionary, have: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	var all_ok := true
	for id: String in costs.keys():
		var need := float(costs[id])
		var got := float(have.get(id, 0))
		var ok := got >= need
		all_ok = all_ok and ok
		rows.append({"id": id, "need": need, "have": got, "ok": ok})
	return {"rows": rows, "affordable": all_ok}


## The pip track shared by the forge's refine levels, the build panel's building levels,
## and the etchings' mark depth. Returns one state per pip:
##   "filled" — a level you own      "next" — the one you can buy next      "rest" — beyond
## At max every pip reads "filled" (the caller paints them all gold — the track is
## finished, so it stops advertising a next step).
static func pip_states(level: int, max_level: int) -> Array[String]:
	var out: Array[String] = []
	for i in maxi(0, max_level):
		var n := i + 1
		if n <= level:
			out.append("filled")
		elif n == level + 1:
			out.append("next")
		else:
			out.append("rest")
	return out


## True when the track is complete — the one place that rule is written down, so
## "all gold" and "no action button" can never disagree.
static func is_maxed(level: int, max_level: int) -> bool:
	return max_level > 0 and level >= max_level


## Trim `s` to at most `max_chars`, ending in an ellipsis. Character-based (not pixel), so
## it stays pure; pixel-exact eliding needs a font and lives in `EmberHud._elide`.
static func truncate(s: String, max_chars: int) -> String:
	if max_chars <= 0:
		return ""
	if s.length() <= max_chars:
		return s
	return s.substr(0, maxi(0, max_chars - 1)).strip_edges(false, true) + "…"
