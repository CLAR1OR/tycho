extends RefCounted
class_name LedgerCore
## The pure resource-ledger logic (architecture-schemas.md §2): a dumb id → amount
## map. All *meaning* (roles, ages, retirement) lives in data/resources/ definitions;
## this class knows nothing about them.
##
## Pure and engine-free on purpose (godot-conventions.md rule 3): the Ledger autoload
## delegates here and adds the EventBus emission on top. Unit-tested headless.
##
## Amounts are floats (Knowledge accrues fractionally, e.g. 1.2); display rounding is
## a UI concern. Amounts never go below zero.

var _amounts: Dictionary = {}


func get_amount(id: String) -> float:
	return _amounts.get(id, 0.0)


## Add (or, with a negative n, remove — floored at 0). Returns the new amount.
func add(id: String, n: float) -> float:
	var new_amount := maxf(0.0, get_amount(id) + n)
	_amounts[id] = new_amount
	return new_amount


## Spend n if (and only if) the balance covers it. Returns whether it happened.
func try_spend(id: String, n: float) -> bool:
	if n < 0.0:
		return false
	if get_amount(id) < n:
		return false
	_amounts[id] = get_amount(id) - n
	return true


## Can every cost in an {id: amount} dict be paid at once? (No partial spends.)
func can_afford(costs: Dictionary) -> bool:
	for id: String in costs:
		if get_amount(id) < float(costs[id]):
			return false
	return true


## Spend a whole {id: amount} cost dict atomically. Returns whether it happened.
func try_spend_all(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for id: String in costs:
		add(id, -float(costs[id]))
	return true


# --- Save round-trip ---------------------------------------------------------

func to_dict() -> Dictionary:
	return _amounts.duplicate()


func reset(amounts: Dictionary) -> void:
	_amounts.clear()
	for id: String in amounts:
		_amounts[id] = maxf(0.0, float(amounts[id]))
