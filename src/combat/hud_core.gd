extends RefCounted
class_name HudCore
## Pure presentation helpers for the in-run HUD ("Slate" design — design/ui-hud.md).
## No engine state: string/array builders + thresholds, all unit-testable headless.
## The RunHud node (src/combat/run_hud.gd) does the drawing; this owns the segment
## rules for the info chip, the echo-shelf folding, the monogram scheme, and the
## low-HP threshold. Numbers here are semantic (not FEEL) — colours/sizes/timings
## live as placeholder constants in run_hud.gd.

## Room-kind tokens the chip understands. "combat"/"boss" come straight from RunFlow;
## "reprieve" is a HUD-only distinction the room derives from its incoming door sigil.
const KIND_COMBAT := "combat"
const KIND_BOSS := "boss"
const KIND_REPRIEVE := "reprieve"

## <= this fraction of max HP flips the low-HP treatment (border + number tint + vignette).
const LOW_HP_THRESHOLD := 0.25


## The top-left info chip text, segments joined by " · ":
##   floor short-form always ("F2");
##   room segment: "R{room}/{rooms}" for combat, "BOSS" / "Reprieve" for those kinds;
##   a " ⚠" is appended to the room segment when the room was entered through a peril door;
##   "Wave {wave_idx+1}/{wave_count}" only in a multi-wave room while still uncleared.
## `wave_idx` is 0-based (combat_room._wave_index); `wave_count` is the total waves (0/1
## outside multi-wave rooms).
static func chip_text(floor_num: int, room: int, rooms: int, kind: String,
		peril: bool, wave_idx: int, wave_count: int, cleared: bool) -> String:
	var room_seg := ""
	match kind:
		KIND_BOSS:
			room_seg = "BOSS"
		KIND_REPRIEVE:
			room_seg = "Reprieve"
		_:
			room_seg = "R%d/%d" % [room, rooms]
	if peril:
		room_seg += " ⚠"
	var segs: Array[String] = ["F%d" % floor_num, room_seg]
	if wave_count > 1 and not cleared:
		segs.append("Wave %d/%d" % [wave_idx + 1, wave_count])
	return " · ".join(segs)


## Fold a run's echo picks into ordered tiles: [{id, name, monogram, count}], in the
## order each id was FIRST picked; `count` folds stackable repeats into one tile.
static func fold_echoes(picks: Array, defs: Dictionary) -> Array:
	var order: Array[String] = []
	var counts := {}
	for id: String in picks:
		if not counts.has(id):
			order.append(id)
			counts[id] = 0
		counts[id] = int(counts[id]) + 1
	var out: Array = []
	for id: String in order:
		var nm := str((defs.get(id, {}) as Dictionary).get("name", id))
		out.append({"id": id, "name": nm, "monogram": monogram(nm), "count": int(counts[id])})
	return out


## A 1-2 letter monogram from a display name's word initials, uppercased
## ("Tempest Stride" → "TS", "Vital Core" → "VC", "Push" → "P"). One word → one letter;
## long multi-word names cap at the first two initials.
static func monogram(name: String) -> String:
	var words := name.strip_edges().split(" ", false)
	if words.is_empty():
		return "?"
	var out := ""
	for w: String in words:
		if w.is_empty():
			continue
		out += w.substr(0, 1).to_upper()
		if out.length() >= 2:
			break
	return out if not out.is_empty() else "?"


## Low-HP state: hp is at or below LOW_HP_THRESHOLD of max (guards max_hp <= 0).
static func is_low_hp(hp: int, max_hp: int) -> bool:
	if max_hp <= 0:
		return false
	return float(hp) / float(max_hp) <= LOW_HP_THRESHOLD
