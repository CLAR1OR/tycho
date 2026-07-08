extends RefCounted
class_name SlotSelectCore
## Pure helpers for the slot-select / title screen (SlotSelect, src/core/slot_select.gd).
## Static + unit-tested: the meta-line text a plaque shows (built from the exact
## SaveManager.list_slots() meta the old screen used, without loading the save), the
## playtime formatting, and the mid-run badge string. The screen owns the pixels; these
## own the strings so they can be tested headless.
##
## The meta line renders in THREE parts so the runs count can take the knowledge colour
## while the rest stays dim (design/ui-hud.md → "Slot select"): AGE-prefix · <runs> ·
## RUNS-and-tail. `meta_parts` returns the parts; `meta_line` is their concatenation (the
## honest full string, for a shape test).


## Format playtime seconds → "3h 22m" over an hour, else "41m" (moved verbatim from the
## old SlotSelect._fmt_playtime — same output).
static func fmt_playtime(seconds: float) -> String:
	var mins := int(seconds / 60.0)
	return "%dh %02dm" % [mins / 60, mins % 60] if mins >= 60 else "%dm" % mins


## The mid-run badge: "" when not mid-run (checkpoint_floor 0), else "⚔ FLOOR n". This
## SHORTENS the old "⚔ mid-run — resumes at floor n" (sanctioned 2026-07-08).
static func badge_text(checkpoint_floor: int) -> String:
	return "" if checkpoint_floor <= 0 else "⚔ FLOOR %d" % checkpoint_floor


## The three parts of an occupied plaque's mono meta line. `runs` is rendered separately
## so the panel can tint it (COL_KNOWLEDGE); prefix + suffix stay dim. The saved date is
## the date portion of meta.updated_at (the ISO "…T…" timestamp), trimmed to the day.
static func meta_parts(meta: Dictionary) -> Dictionary:
	var age := int(meta.get("age", 1))
	var runs := int(meta.get("runs", 0))
	var playtime := fmt_playtime(float(meta.get("playtime_s", 0.0)))
	var saved := str(meta.get("updated_at", "")).split("T")[0]
	return {
		"prefix": "AGE %d · " % age,
		"runs": "%d" % runs,
		"suffix": " RUNS · %s · saved %s" % [playtime, saved],
	}


## The full flat meta line (parts concatenated) — the honest text a plaque renders, minus
## the runs-colour split. Used for a shape test.
static func meta_line(meta: Dictionary) -> String:
	var p := meta_parts(meta)
	return str(p["prefix"]) + str(p["runs"]) + str(p["suffix"])
