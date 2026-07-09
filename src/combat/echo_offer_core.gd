extends RefCounted
class_name EchoOfferCore
## Pure helpers for the in-run echo offer ("The etchings answer" — O1, human-picked
## 2026-07-09 via claude.ai/design). Static + unit-tested: the display split of an
## echo's `desc` into stacked effect lines (the drawback clause flagged), the held-stack
## count, and the synergy detection + parents resolution. The panel (EchoOfferPanel) owns
## the pixels + hit-testing; these own the strings/rules so they test headless.
##
## The desc text itself is NEVER edited — the split is display-only (line breaks at ", ").


## Split an echo's `desc` into stacked lines for the mark. Each entry is
## {text, drawback}: a segment that begins with "but " renders in the soft drawback red
## (the offer's only red). Splits at ", " — the comma form every multi-effect desc uses.
static func effect_lines(desc: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seg in desc.split(", ", false):
		var s := str(seg)
		out.append({"text": s, "drawback": s.begins_with("but ")})
	return out


## How many copies of `id` the run already holds (only stackables can reappear). Drives
## the gold ×n badge on a ring — the shelf's own count badge, previewed on the offer.
static func held_count(id: String, picked: Array) -> int:
	var n := 0
	for p in picked:
		if str(p) == id:
			n += 1
	return n


## True when the echo is a synergy weave (has `requires`) — it only enters the pool once
## both parents are picked, so on-screen it should feel found: a woven double ring.
static func is_synergy(def: Dictionary) -> bool:
	return not (def.get("requires", []) as Array).is_empty()


## The parents' display names, upper-cased and " + "-joined ("SWIFT STEP + QUICK DASH");
## "" when the echo isn't a synergy. The panel wraps this in its "woven from …" copy.
static func parents_line(def: Dictionary, all_defs: Dictionary) -> String:
	var reqs: Array = def.get("requires", [])
	if reqs.is_empty():
		return ""
	var names: Array[String] = []
	for req: String in reqs:
		names.append(str((all_defs.get(req, {}) as Dictionary).get("name", req)).to_upper())
	return " + ".join(names)
