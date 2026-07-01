extends Node
## Ledger autoload — thin wrapper around LedgerCore (architecture-schemas.md §2).
##
## Every mutation emits `resource_changed(id, old, new, reason)` on the EventBus —
## dialogue gates, achievements, and UI all subscribe; nobody polls. Keep this thin:
## logic belongs in LedgerCore (pure, unit-tested), meaning belongs in
## data/resources/*.json.
##
## `reason` is a free-form tag for subscribers/analytics ("run-drop", "town-tick",
## "building-cost", …) — pass something honest, "" if truly anonymous.

var _core := LedgerCore.new()


func get_amount(id: String) -> float:
	return _core.get_amount(id)


func add(id: String, n: float, reason: String = "") -> void:
	var old := _core.get_amount(id)
	var new_amount := _core.add(id, n)
	if new_amount != old:
		EventBus.resource_changed.emit(id, old, new_amount, reason)


func try_spend(id: String, n: float, reason: String = "") -> bool:
	var old := _core.get_amount(id)
	if not _core.try_spend(id, n):
		return false
	EventBus.resource_changed.emit(id, old, _core.get_amount(id), reason)
	return true


func can_afford(costs: Dictionary) -> bool:
	return _core.can_afford(costs)


## Spend a whole {id: amount} cost dict atomically (all or nothing).
func try_spend_all(costs: Dictionary, reason: String = "") -> bool:
	if not _core.can_afford(costs):
		return false
	for id: String in costs:
		add(id, -float(costs[id]), reason)
	return true


# --- Save round-trip (SaveManager calls these) --------------------------------

func to_dict() -> Dictionary:
	return _core.to_dict()


## Replace all amounts wholesale (slot load). Deliberately does NOT emit per-resource
## events — SaveManager emits one `save_loaded` and subscribers re-read.
func reset(amounts: Dictionary) -> void:
	_core.reset(amounts)
