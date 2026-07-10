extends RefCounted
class_name MarketCore
## Pure Market helpers (design/town-economy.md, 2026-07-10): the exchange rates and
## the caravan-deal rotation. The economy math itself lives where it always has —
## the auto-sell inside TownCore.tick, the transactions on the Ledger at the panel —
## this class only answers "what is on offer today". No autoloads, no engine state,
## no RNG state: the rotation is a pure function of the day number, so it is stable
## across save/load and identical on every reopen. Unit-tests headless.
##
## The Market trades CIVILIAN resources only (gold/stone/food) — it never touches
## Resonance (IC-14); the deal table (data/town/caravan-deals.json) is linted for
## that in market_core_test.


## The Market's capability effect (rates + deal_slots) at `level` — {} when unbuilt /
## out of range / no market capability on that level. Levels REPLACE: only the
## current level's rates apply. Thin wrapper over the generic TownCore reader so the
## panel and the tick can never disagree on which effect carries the numbers.
static func caps(market_def: Dictionary, level: int) -> Dictionary:
	return TownCore.capability_effect(market_def, level, "market")


## The deal ids in their canonical rotation order (sorted — deterministic regardless
## of JSON parse order).
static func deal_order(deals: Dictionary) -> Array:
	var ids: Array = deals.keys()
	ids.sort()
	return ids


## The deal on offer for `day` in `slot` (0 = the always-present slot, 1 = the L3
## second slot). Slot 0 rotates deals[day mod n]; slot 1 is offset by a hash of the
## day (deterministic, NO RNG state) and never collides with slot 0. "" when the
## table is empty, the slot index is out of range, or a second slot has no distinct
## deal to offer (n == 1).
static func deal_id_for_slot(deals: Dictionary, day: int, slot: int) -> String:
	var ids := deal_order(deals)
	var n := ids.size()
	if n == 0 or slot < 0 or slot > 1:
		return ""
	var base := posmod(day, n)
	if slot == 0:
		return str(ids[base])
	if n == 1:
		return ""  # one deal total — a second slot has nothing new to show
	var offset := 1 + posmod(hash(day), n - 1)  # 1..n-1 → always distinct from base
	return str(ids[posmod(base + offset, n)])


## May the town accept a caravan deal today? One accept per day, across all slots
## (town.market_deal_done_day remembers the last accepted day; -1 = never).
static func can_accept_deal(town: Dictionary, day: int) -> bool:
	return int(town.get("market_deal_done_day", -1)) != day


## Pure update: return a NEW town dict with today's deal marked accepted.
static func mark_deal_done(town: Dictionary, day: int) -> Dictionary:
	var out := town.duplicate(true)
	out["market_deal_done_day"] = day
	return out
