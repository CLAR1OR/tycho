extends RefCounted
class_name ArchPuzzleCore
## Pure state machine for the Masonry & the Arch interactive puzzle
## (design/tech-nodes/medieval-masonry-the-arch.md §5 + §9: a SCRIPTED state
## machine with pre-baked hold/crack/splay outcomes — deliberately NOT a physics
## sim). Three beats, each forcing one true idea:
##   beat 1 — the flat lintel cracks along its underside (tension vs. compression)
##   beat 2 — voussoirs need centering; the ring only stands once the KEYSTONE closes it
##   beat 3 — the finished arch shoves OUTWARD; brace both feet or it splays
## Win: keystone seated + both feet braced + the wall load held. beat 4 = solved.
##
## Every action is a pure `(state, …) -> {state, event}` — the view renders events,
## this class never touches the engine. Failures teach: each destructive outcome
## says WHERE and WHY via its event id (the view maps events to authored text).

const VOUSSOIR_COUNT := 6           # 3 per side; springers (0 left, 3 right) rest on the piers
const SPRINGERS: Array[int] = [0, 3]


static func initial_state() -> Dictionary:
	return {
		"beat": 1,
		"lintel": false,      # the flat slab is currently laid across the gap
		"cracked": false,     # the lintel failure has been witnessed (unlocks the arch)
		"centering": false,   # the temporary wooden frame is up
		"voussoirs": [false, false, false, false, false, false],
		"keystone": false,
		"abutments": {"left": false, "right": false},
		"pointed": false,     # round ↔ pointed profile (optional mastery beat)
		"solved": false,
		"load_tests": 0,
		"fails": 0,
	}


# --- Actions ----------------------------------------------------------------------

static func place_lintel(s: Dictionary) -> Dictionary:
	if int(s["beat"]) != 1 or bool(s["lintel"]):
		return _ev(s, "invalid")
	var out := _copy(s)
	out["lintel"] = true
	return _ev(out, "lintel_placed")


## After the lintel has cracked, the player abandons flat spans and curves the gap.
static func choose_arch(s: Dictionary) -> Dictionary:
	if int(s["beat"]) != 1 or not bool(s["cracked"]):
		return _ev(s, "invalid")
	var out := _copy(s)
	out["beat"] = 2
	return _ev(out, "arch_chosen")


static func toggle_centering(s: Dictionary) -> Dictionary:
	if int(s["beat"]) != 2:
		return _ev(s, "invalid")
	var out := _copy(s)
	if not bool(s["centering"]):
		out["centering"] = true
		return _ev(out, "centering_up")
	# Pulling the frame from under an unfinished ring drops every stone the piers
	# aren't holding — the half-ring "visibly wants to fall" lesson, the hard way.
	out["centering"] = false
	var fell := false
	var v: Array = out["voussoirs"]
	for i in VOUSSOIR_COUNT:
		if bool(v[i]) and i not in SPRINGERS:
			v[i] = false
			fell = true
	if fell:
		out["fails"] = int(out["fails"]) + 1
		return _ev(out, "ring_fell")
	return _ev(out, "centering_down")


static func place_voussoir(s: Dictionary, index: int) -> Dictionary:
	if int(s["beat"]) != 2 or index < 0 or index >= VOUSSOIR_COUNT:
		return _ev(s, "invalid")
	if bool((s["voussoirs"] as Array)[index]):
		return _ev(s, "invalid")
	# Springers rest on the piers; every other wedge needs the frame under it.
	if index not in SPRINGERS and not bool(s["centering"]):
		var out_fell := _copy(s)
		out_fell["fails"] = int(out_fell["fails"]) + 1
		return _ev(out_fell, "voussoir_fell")
	var out := _copy(s)
	(out["voussoirs"] as Array)[index] = true
	return _ev(out, "voussoir_placed")


static func place_keystone(s: Dictionary) -> Dictionary:
	if int(s["beat"]) != 2 or bool(s["keystone"]):
		return _ev(s, "invalid")
	if not ring_complete(s):
		# Nothing for the wedge to bear on — keystone comes LAST.
		var out_fell := _copy(s)
		out_fell["fails"] = int(out_fell["fails"]) + 1
		return _ev(out_fell, "keystone_fell")
	var out := _copy(s)
	out["keystone"] = true
	out["centering"] = false  # seat it, and the frame comes away — it stands
	out["beat"] = 3
	return _ev(out, "keystone_seated")


static func place_abutment(s: Dictionary, side: String) -> Dictionary:
	if int(s["beat"]) < 2 or bool(s["solved"]) or side not in ["left", "right"]:
		return _ev(s, "invalid")
	if bool((s["abutments"] as Dictionary)[side]):
		return _ev(s, "invalid")
	var out := _copy(s)
	(out["abutments"] as Dictionary)[side] = true
	return _ev(out, "abutment_placed")


## Profile is chosen before stones go up (re-cutting a built ring isn't a toggle).
static func toggle_pointed(s: Dictionary) -> Dictionary:
	if int(s["beat"]) != 2 or bool(s["keystone"]) or placed_count(s) > 0:
		return _ev(s, "invalid")
	var out := _copy(s)
	out["pointed"] = not bool(s["pointed"])
	return _ev(out, "profile_pointed" if bool(out["pointed"]) else "profile_round")


## "Load it and see" — drop the wall section on whatever stands. The heart of the
## puzzle: every wrong structure fails in its own instructive way.
static func load(s: Dictionary) -> Dictionary:
	if bool(s["solved"]):
		return _ev(s, "invalid")
	var out := _copy(s)
	out["load_tests"] = int(out["load_tests"]) + 1
	match int(s["beat"]):
		1:
			if not bool(s["lintel"]):
				return _ev(out, "load_nothing")
			# Bending stretches the underside; stone is feeble in tension.
			out["lintel"] = false
			out["cracked"] = true
			out["fails"] = int(out["fails"]) + 1
			return _ev(out, "lintel_cracked")
		2:
			if placed_count(s) == 0:
				return _ev(out, "load_nothing")
			# A ring isn't a ring until the keystone closes it.
			for i in VOUSSOIR_COUNT:
				(out["voussoirs"] as Array)[i] = false
			out["fails"] = int(out["fails"]) + 1
			return _ev(out, "unkeyed_collapse")
		3:
			var ab: Dictionary = s["abutments"]
			if bool(ab["left"]) and bool(ab["right"]):
				out["solved"] = true
				out["beat"] = 4
				return _ev(out, "holds")
			# The arch shoves OUTWARD at its feet; unbraced, it splays and falls.
			out["keystone"] = false
			for i in VOUSSOIR_COUNT:
				(out["voussoirs"] as Array)[i] = false
			out["beat"] = 2
			out["fails"] = int(out["fails"]) + 1
			return _ev(out, "splayed")
	return _ev(out, "invalid")


# --- Queries ----------------------------------------------------------------------

static func ring_complete(s: Dictionary) -> bool:
	for placed: bool in s["voussoirs"]:
		if not placed:
			return false
	return true


static func placed_count(s: Dictionary) -> int:
	var n := 0
	for placed: bool in s["voussoirs"]:
		if placed:
			n += 1
	return n


# --- Internals ---------------------------------------------------------------------

static func _copy(s: Dictionary) -> Dictionary:
	return s.duplicate(true)


static func _ev(state: Dictionary, event: String) -> Dictionary:
	return {"state": state, "event": event}
