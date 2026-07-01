extends "res://tests/test_suite.gd"
## Unit tests for LedgerCore (src/core/ledger_core.gd) — pure resource-map logic.


func test_get_unknown_is_zero() -> void:
	var c := LedgerCore.new()
	check_eq(c.get_amount("gold"), 0.0, "unknown resource reads as 0")


func test_add_and_get() -> void:
	var c := LedgerCore.new()
	check_eq(c.add("gold", 5.0), 5.0, "add returns new amount")
	c.add("gold", 2.5)
	check_eq(c.get_amount("gold"), 7.5, "amounts accumulate")


func test_negative_add_floors_at_zero() -> void:
	var c := LedgerCore.new()
	c.add("gold", 3.0)
	c.add("gold", -10.0)
	check_eq(c.get_amount("gold"), 0.0, "amount never drops below zero")


func test_try_spend() -> void:
	var c := LedgerCore.new()
	c.add("gold", 10.0)
	check(c.try_spend("gold", 4.0), "spend within balance succeeds")
	check_eq(c.get_amount("gold"), 6.0, "balance reduced by spend")
	check(not c.try_spend("gold", 100.0), "overspend refused")
	check_eq(c.get_amount("gold"), 6.0, "refused spend leaves balance untouched")
	check(not c.try_spend("gold", -1.0), "negative spend refused")


func test_can_afford_and_spend_all() -> void:
	var c := LedgerCore.new()
	c.add("gold", 50.0)
	c.add("stone", 20.0)
	check(c.can_afford({"gold": 50, "stone": 20}), "exact cost is affordable")
	check(not c.can_afford({"gold": 50, "stone": 21}), "one short resource fails the whole cost")
	check(not c.try_spend_all({"gold": 10, "stone": 999}), "atomic spend refuses if any part is short")
	check_eq(c.get_amount("gold"), 50.0, "refused atomic spend takes nothing")
	check(c.try_spend_all({"gold": 10, "stone": 5}), "affordable atomic spend succeeds")
	check_eq(c.get_amount("gold"), 40.0, "gold part deducted")
	check_eq(c.get_amount("stone"), 15.0, "stone part deducted")


func test_save_round_trip() -> void:
	var c := LedgerCore.new()
	c.add("gold", 12.0)
	c.add("knowledge", 1.2)
	var d := c.to_dict()
	var c2 := LedgerCore.new()
	c2.reset(d)
	check_eq(c2.get_amount("gold"), 12.0, "round-trip keeps gold")
	check_eq(c2.get_amount("knowledge"), 1.2, "round-trip keeps fractional knowledge")
	c2.reset({"stone": 3})
	check_eq(c2.get_amount("gold"), 0.0, "reset replaces wholesale")
	check_eq(c2.get_amount("stone"), 3.0, "reset coerces json ints to float")
