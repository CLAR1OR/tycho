extends RefCounted
class_name TownHudCore
## Pure presentation helpers for the town HUD ("Slate" T1 design — design/ui-hud.md).
## No engine state: string builders + the day-tick projection/toast math, all
## unit-testable headless. The TownHud node (src/town/town_hud.gd) does the drawing;
## this owns the day-chip text, the per-resource day deltas + their "+n/d" projection
## strings, and the overnight-toast segment list. Numbers here are semantic (not FEEL);
## colours/sizes/timings live as placeholder constants in town_hud.gd.

## Short display labels for the resources whose ids read badly in a strip/toast.
const _LABELS := {
	"knowledge-shards": "shards", "resonance-ore": "ore", "resonance-dust": "dust",
}
## Toast column display order (the rest follow alphabetically).
const _TOAST_ORDER: Array[String] = ["gold", "stone", "food", "knowledge"]


## The top-left day chip text:
##   "Day 1"                 before any day has ticked (has_ticked == false);
##   "Day 4 · Well-Fed +25%" when the last tick left the town fed;
##   "Day 4 · Short on food" when it did not.
## The +25% literal is derived from TownCore.WELL_FED_BONUS so the two can't drift.
static func day_chip_text(day: int, well_fed: bool, has_ticked: bool) -> String:
	if not has_ticked:
		return "Day %d" % day
	if well_fed:
		return "Day %d · Well-Fed +%s%%" % [day, str(int(TownCore.WELL_FED_BONUS * 100))]
	return "Day %d · Short on food" % day


## Per-resource signed NET per-day amount from a TownCore.tick(...) result: every
## `produced` entry as +amount, and Food as produced-food MINUS food_consumed (Food may
## be absent from `produced` — then the net is a pure negative). Derived ONLY from the
## tick RESULT (`produced` is the single truth — knowledge rides its own effect kind
## inside tick but lands in `produced` all the same); never re-walks building effects.
static func day_deltas(tick: Dictionary) -> Dictionary:
	var out := {}
	var produced: Dictionary = tick.get("produced", {})
	for res: String in produced:
		out[res] = float(produced[res])
	var consumed := float(tick.get("food_consumed", 0.0))
	if consumed != 0.0:
		out["food"] = float(out.get("food", 0.0)) - consumed
	return out


## A projection string for one resource's net day delta: "" when zero, else "+3/d" /
## "-2/d" (ints clean, one decimal otherwise — "+3.8/d").
static func projection_text(delta: float) -> String:
	if delta == 0.0:
		return ""
	return "%s/d" % _fmt_amount(delta)


## Ordered segment dicts [{text, id}] for the overnight toast: produced resources first
## (gold, stone, food, knowledge, then anything else alphabetically) as "+5 gold", then
## a "-5 eaten" segment when any Food was consumed, then a "Well-Fed" segment when fed.
static func toast_segments(tick: Dictionary) -> Array:
	var out: Array = []
	var produced: Dictionary = tick.get("produced", {})
	var seen := {}
	for id: String in _TOAST_ORDER:
		if produced.has(id):
			out.append({"text": "%s %s" % [_fmt_amount(float(produced[id])), _label(id)], "id": id})
			seen[id] = true
	var rest: Array[String] = []
	for id: String in produced:
		if not seen.has(id):
			rest.append(id)
	rest.sort()
	for id: String in rest:
		out.append({"text": "%s %s" % [_fmt_amount(float(produced[id])), _label(id)], "id": id})
	var consumed := float(tick.get("food_consumed", 0.0))
	if consumed > 0.0:
		out.append({"text": "%s eaten" % _fmt_amount(-consumed), "id": "eaten"})
	if bool(tick.get("well_fed", false)):
		out.append({"text": "Well-Fed", "id": "fed"})
	return out


## The set (id -> true) of resources ANY defined building can generate on a day tick —
## walks every def's levels' effects (kind "produce" → its resource; the "knowledge"
## kind → knowledge; other kinds generate nothing). The strip's town/run split derives
## from this (human decision 2026-07-07): building-producible = the town economy,
## everything else only ever comes home from runs. Data-driven on purpose — a future
## gold-producing Market would migrate gold to the town group by itself.
static func producible_resources(building_defs: Dictionary) -> Dictionary:
	var out := {}
	for id: String in building_defs:
		for level: Dictionary in (building_defs[id] as Dictionary).get("levels", []):
			for effect: Dictionary in level.get("effects", []):
				match str(effect.get("kind", "")):
					"produce":
						var res := str(effect.get("resource", ""))
						if not res.is_empty():
							out[res] = true
					"knowledge":
						out["knowledge"] = true
	return out


## Short label for a resource id (falls back to the id itself).
static func _label(id: String) -> String:
	return str(_LABELS.get(id, id))


## Signed amount: "+3" / "-2" / "+3.8" — a trailing ".0" is stripped so whole numbers
## read clean. ASCII +/- signs.
static func _fmt_amount(v: float) -> String:
	var s := "%+.1f" % v
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return s
