extends "res://tests/test_suite.gd"
## Tests EchoOfferCore (src/combat/echo_offer_core.gd) — the pure echo-offer helpers:
## the desc → effect-line split (drawback flagging), the held-stack count, and the
## synergy detection + parents resolution. Real echo data where natural.


func test_effect_lines_single_and_multi() -> void:
	var one := EchoOfferCore.effect_lines("+15% move speed")
	check_eq(one.size(), 1, "a comma-less desc is one line")
	check_eq(bool(one[0]["drawback"]), false, "no drawback on a plain effect")
	var two := EchoOfferCore.effect_lines("+10% move speed, -15% dash cooldown")
	check_eq(two.size(), 2, "a two-effect desc splits at ', '")
	check_eq(str(two[1]["text"]), "-15% dash cooldown", "second segment kept verbatim")
	check_eq(bool(two[1]["drawback"]), false, "neither segment is a drawback")


func test_effect_lines_drawback_real_data() -> void:
	var defs := DataLoader.load_domain("echoes")
	var lines := EchoOfferCore.effect_lines(str((defs["heavy-hand"] as Dictionary)["desc"]))
	check_eq(lines.size(), 2, "Heavy Hand splits into gain + trade")
	check_eq(bool(lines[0]["drawback"]), false, "the gain line is not a drawback")
	check_eq(bool(lines[1]["drawback"]), true, "the 'but …' clause is flagged drawback")


func test_held_count() -> void:
	check_eq(EchoOfferCore.held_count("swift-step", ["swift-step", "keen-edge", "swift-step"]), 2,
		"counts every copy already held")
	check_eq(EchoOfferCore.held_count("swift-step", []), 0, "none held → 0")
	check_eq(EchoOfferCore.held_count("keen-edge", ["swift-step"]), 0, "a different pick doesn't count")


func test_is_synergy() -> void:
	var defs := DataLoader.load_domain("echoes")
	check(EchoOfferCore.is_synergy(defs["tempest-stride"]), "Tempest Stride is a synergy (has requires)")
	check(not EchoOfferCore.is_synergy(defs["keen-edge"]), "Keen Edge is a plain echo")


func test_parents_line_real_data() -> void:
	var defs := DataLoader.load_domain("echoes")
	check_eq(EchoOfferCore.parents_line(defs["tempest-stride"], defs), "SWIFT STEP + QUICK DASH",
		"parents resolved to display names, upper-cased, ' + '-joined")
	check_eq(EchoOfferCore.parents_line(defs["keen-edge"], defs), "",
		"a non-synergy has no parents line")
