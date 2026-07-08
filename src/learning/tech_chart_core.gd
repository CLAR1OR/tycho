extends RefCounted
class_name TechChartCore
## Pure state grammar for the research STAR CHART (R1 — the constellation view of the
## tech tree, human-picked 2026-07-08 via claude.ai/design). Layered on top of the
## existing TechCore predicates (researched list, is_ready, prereqs) — this adds only the
## per-node display state, the edge kind between a prereq and its dependent, and the
## chart position (with a deterministic fallback). No engine state, unit-tested headless.
##
## States (see design/ui-hud.md → "Research screen — Star chart"):
##   researched — gold filled star.
##   ready      — funded, awaiting read & solve; the screen's one call-to-action (gold).
##   active     — == tech.active and not yet ready; Sophia's current focus (cyan + arc).
##   available  — prereqs met, not funded, not the active node (slate outline).
##   locked     — a prereq is unmet (dim dot).
## Quiz-lock is ORTHOGONAL (a ready node whose quiz is locked) and stays a panel concern
## (TechCore.is_quiz_locked) painted as red meta — it is not a distinct chart state.


## The per-node chart state. Precedence: researched > locked (prereq unmet) > ready >
## active > available. (ready beats active so a funded focus reads as the call-to-action.)
static func node_state(def: Dictionary, tech: Dictionary, id: String) -> StringName:
	var researched: Array = tech.get("researched", [])
	if id in researched:
		return &"researched"
	for req: String in def.get("prereqs", []):
		if req not in researched:
			return &"locked"
	if TechCore.is_ready(def, tech):
		return &"ready"
	if str(tech.get("active", "")) == id:
		return &"active"
	return &"available"


## The edge kind between a prereq node and the node that depends on it. Precedence:
## lit (the prereq is researched — the line has been "traversed") > dim (the dependent is
## still locked by some prereq) > open (both ends are at least available).
static func edge_kind(prereq_state: StringName, dependent_state: StringName) -> StringName:
	if prereq_state == &"researched":
		return &"lit"
	if dependent_state == &"locked":
		return &"dim"
	return &"open"


## True when `def` carries a valid authored `chart_pos` (a 2-element array). The panel
## uses it to warn when a node falls back to a computed position (keeping this func pure).
static func has_chart_pos(def: Dictionary) -> bool:
	var cp: Variant = def.get("chart_pos", null)
	return cp is Array and (cp as Array).size() == 2


## The node's normalized 0..1 [x, y] chart position: the authored `chart_pos` when valid,
## else a DETERMINISTIC fallback derived from the id, clamped to a safe band (x 0.1..0.55,
## y 0.15..0.8) that never overlaps the right-side detail dock. Same id → same position;
## different ids → generally different — so an unpositioned node never crashes or stacks.
static func chart_pos(def: Dictionary, id: String) -> Vector2:
	if has_chart_pos(def):
		var cp: Array = def["chart_pos"]
		return Vector2(float(cp[0]), float(cp[1]))
	var h := absi(id.hash())
	var x := 0.1 + float(h % 1000) / 999.0 * (0.55 - 0.1)
	var y := 0.15 + float((h / 1000) % 1000) / 999.0 * (0.8 - 0.15)
	return Vector2(x, y)
