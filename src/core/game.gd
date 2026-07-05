extends Node
## Game root — the vertical-slice orchestrator (PRD §12 milestone 3).
##
## Owns the macro loop: boot a save slot → town → (portal) → run of combat rooms →
## victory or death → day tick → back to town → save. Scenes below it (town,
## combat_room) signal UP; cross-domain bookkeeping flows through EventBus.
##
## Story bookkeeping (run/death/boss-kill counters, the has-<resource> pickup flags,
## the full-clear codex shard) now lives in the StoryState autoload over pure
## StoryCore, and the tech auto-solve moved to the TechState autoload over pure
## TechCore — game.gd keeps only scene flow. ORDERING: both are autoloads, so they
## subscribe to run_ended BEFORE this scene does; their counters/tech state are
## therefore already updated when _on_run_ended defers the town swap + slot save. See
## story_state.gd / tech_state.gd headers for the full guarantee (the smoke re-reads
## the file to prove it). The age-advance hook (_on_tech_researched) stays here — it
## mutates town/meta.age, not the tech section.
##
## Boot: the slot-select screen (SlotSelect) → choose_slot() → town, or straight
## back into a run at floor start if the slot holds a mid-run checkpoint (§7.13).

const TOWN_SCENE := preload("res://scenes/town/town.tscn")
const ROOM_SCENE := preload("res://scenes/combat/combat_room.tscn")

const SLOT_COUNT := 3
const DEFAULT_SLOT_NAME := "Tycho"

## Run shape for the SLICE — the full game is 5 floors x 6-10 rooms (PRD §7.6).
@export var run_floors: int = 1
@export var rooms_min: int = 3
@export var rooms_max: int = 4

## Ledger readout order for the HUD (resource meaning stays in data/resources/).
const HUD_RESOURCES: Array[String] = ["gold", "stone", "food", "knowledge", "knowledge-shards"]

var _scene: Node = null       # the live town or combat room
var _session_t: float = 0.0   # unsaved playtime (flushed into meta.playtime_s on save)

@onready var _world: Node = $World
@onready var _res_label: Label = $HUD/Resources
@onready var _echo_label: Label = $HUD/Echoes


func _ready() -> void:
	EventBus.resource_changed.connect(func(_id: String, _o: float, _n: float, _r: String) -> void:
		_refresh_resources())
	# The has-<resource> pickup flags + all story counters now ride StoryState (an
	# autoload, so it subscribes before this scene) — game.gd only reacts to the HUD.
	EventBus.save_loaded.connect(func(_slot: int) -> void: _refresh_resources())
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.tech_researched.connect(_on_tech_researched)
	# Playtest cheat panel (F2) — lives on the HUD layer so it survives scene swaps.
	var cheats := CheatPanel.new()
	cheats.setup(self)
	$HUD.add_child(cheats)
	_show_slot_select()


## Boot screen: pick/create a slot. Nothing is loaded until the player chooses.
func _show_slot_select() -> void:
	Music.play("title")
	var select := SlotSelect.new()
	select.slot_count = SLOT_COUNT
	select.slot_chosen.connect(func(slot: int) -> void:
		select.queue_free()
		choose_slot(slot))
	$HUD.add_child(select)


## Load (or create) a slot and enter the game: town, or — if the slot carries a
## mid-run checkpoint — straight back into the run at floor start.
func choose_slot(slot: int) -> void:
	if not SaveManager.load_slot(slot):
		SaveManager.create_slot(slot, DEFAULT_SLOT_NAME)
	_refresh_resources()
	var checkpoint: Variant = SaveManager.state.get("checkpoint")
	if checkpoint is Dictionary and not (checkpoint as Dictionary).is_empty():
		RunState.resume_from(checkpoint)
		_refresh_echoes()
		_next_room()
	else:
		_goto_town()


func _process(delta: float) -> void:
	_session_t += delta


# --- Scene flow ------------------------------------------------------------------
# Transitions are deferred: the triggering signals (portal body_entered, the last
# kill's died chain) fire during the physics step, when freeing/adding scenes is
# not safe.

func _goto_town() -> void:
	Music.play("town")
	var town := TOWN_SCENE.instantiate()
	_swap(town)
	town.run_requested.connect(func() -> void: call_deferred("_start_run"))
	_refresh_echoes()  # run is over — the echo readout clears with it
	_save()


func _start_run() -> void:
	var run_number := int(SaveManager.state["story"]["counters"]["runs"]) + 1
	RunState.start_run(
		{"floors": run_floors, "rooms_min": rooms_min, "rooms_max": rooms_max},
		randi(), run_number)
	_next_room()


func _next_room() -> void:
	# Per-floor autosave (PRD §7.13): a floor's first room = the resume point.
	# RunState is already positioned there, so the snapshot IS the floor start.
	if int(RunState.run["room"]) == 1:
		# A new floor: no incoming door yet, and (re)generate this floor's door plan.
		# Deterministic in the run seed, so a resume rebuilds the identical plan — the
		# checkpoint carries none of this (design/run-structure.md).
		RunState.pending_door = {}
		var profile := _floor_profile(int(RunState.run["floor"]))
		RunState.build_floor_doors(profile["door_weights"], float(profile["peril_chance"]))
		SaveManager.state["checkpoint"] = RunState.to_checkpoint()
		_save()
	Music.play("boss" if RunState.room_kind() == RunFlow.KIND_BOSS else "dungeon")
	var room := ROOM_SCENE.instantiate()
	room.setup(
		int(RunState.run["floor"]), int(RunState.run["room"]),
		int(RunState.run["rooms_this_floor"]), RunState.room_kind(), RunState.pending_door)
	_swap(room)
	room.cleared.connect(_on_room_cleared.bind(room))
	room.exit_entered.connect(func() -> void: call_deferred("_next_room"))
	room.player_died.connect(func() -> void: RunState.player_died())


## The floor profile (door weights + peril chance), clamped to the highest authored
## file for floors past the last one (design/run-structure.md; strata env fields land
## in these same files later).
func _floor_profile(floor_num: int) -> Dictionary:
	var floors := DataLoader.load_domain("floors")
	if floors.has(str(floor_num)):
		return floors[str(floor_num)]
	var best := {}
	var highest := 0
	for id: String in floors:
		if int(floors[id]["id"]) >= highest:
			highest = int(floors[id]["id"])
			best = floors[id]
	if best.is_empty():
		push_error("game.gd: no floor profiles in data/floors/ — using inert defaults")
		return {"door_weights": {"gold": 1, "echo": 1, "reprieve": 1}, "peril_chance": 0.0}
	push_warning("game.gd: floor %d beyond authored profiles — clamping to floor %d" % [floor_num, highest])
	return best


func _swap(next_scene: Node) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = next_scene
	_world.add_child(next_scene)


# --- Run events --------------------------------------------------------------------

func _on_room_cleared(room: Node) -> void:
	var was_boss: bool = room.kind == RunFlow.KIND_BOSS
	var boss_id: String = room.BOSS_ID if was_boss else ""
	# The door that led INTO this room decides what it PAYS (design/run-structure.md).
	# Captured before RunState.room_cleared advances / a new door is picked.
	var incoming: Dictionary = RunState.pending_door.duplicate()
	var cleared_floor := int(RunState.run["floor"])
	if not RunState.room_cleared(boss_id):
		return  # the run just ended (final boss) — _on_run_ended takes it from here
	if was_boss:
		# Boss valve (PRD §7.7 heal): repair 30% of missing HP, then the GUARANTEED
		# post-boss echo (the new cadence), then the plain exit to the next floor.
		room.apply_missing_heal(DoorCore.BOSS_HEAL_PCT)
		_offer_echo(room, func() -> void: room.open_exit())
		return
	# Non-boss: pay the incoming door's reward, then show the next room's doors.
	var next_offer := DoorCore.offer_for_room(RunState.door_plan, room.room_index)
	var after_reward := func() -> void: _present_doors(room, next_offer)
	if str(incoming.get("sigil", "")) == DoorCore.SIGIL_ECHO:
		# Echo door: the pick IS the reward (echoes now come only from echo doors + the
		# post-boss guarantee — the old every-room offer is retired).
		_offer_echo(room, after_reward)
	else:
		_pay_cache(incoming, cleared_floor)
		after_reward.call()


## Pay a cache door's resource on clear (gold/ore/dust caches; reprieve/boss/empty pay
## nothing here — the heal / boss loot are handled elsewhere). Peril doubles it.
func _pay_cache(door: Dictionary, floor_num: int) -> void:
	if door.is_empty():
		return  # a floor's first room has no incoming door
	var reward := DoorCore.cache_reward(
		str(door.get("sigil", "")), floor_num, bool(door.get("peril", false)))
	if reward.is_empty():
		return
	Ledger.add(str(reward["resource"]), float(reward["amount"]), "door-reward")


## Roll and present an echo offer, then run `on_done` (echo picks feed the same
## deterministic RNG; an empty pool just falls through).
func _offer_echo(room: Node, on_done: Callable) -> void:
	var offers := EchoCore.generate_offer(
		EchoCore.defs(), RunState.echoes, int(RunState.run["seed"]), RunState.echo_offers_made)
	RunState.echo_offers_made += 1
	if offers.is_empty():
		on_done.call()
		return
	room.present_echo_offer(offers, func(id: String) -> void:
		RunState.pick_echo(id)
		_refresh_echoes(), on_done)


## Open the next room's doors; walking into one records the chosen door on RunState so
## the next room spawns from it (reprieve/peril) and pays from it on clear.
func _present_doors(room: Node, offer: Array) -> void:
	if offer.is_empty():
		room.open_exit()  # no offer (shouldn't happen off the boss path) — plain exit
		return
	room.present_doors(offer, func(door: Dictionary) -> void:
		RunState.pending_door = door.duplicate())


func _on_run_ended(_victory: bool, _floor_reached: int, _stats: Dictionary) -> void:
	# The counters + the full-clear codex shard rode StoryState, and Sophia's tech
	# auto-solve rode TechState (both fired already — they subscribed first as
	# autoloads). game.gd handles only the scene-flow tail.
	SaveManager.state["checkpoint"] = null  # the run is over — nothing to resume
	# The day tick: 1 day = 1 run, win OR die (locked decision, PRD §6.2). The tick
	# also runs the Food upkeep pass (design/food-upkeep.md): production comes in, the
	# town eats, and covered → Well-Fed → +25% to all other production (already folded
	# into `produced`). Spend Food AFTER adding production so the stock math matches
	# the core's "harvest first" rule.
	Sfx.play("day-chime")
	var tick := TownCore.tick(
		SaveManager.state["town"], DataLoader.load_domain("buildings"), Ledger.get_amount("food"))
	var produced: Dictionary = tick["produced"]
	for id: String in produced:
		Ledger.add(id, float(produced[id]), "town-tick")
	Ledger.try_spend("food", float(tick["food_consumed"]), "upkeep")
	SaveManager.state["town"]["well_fed"] = bool(tick["well_fed"])
	call_deferred("_goto_town")


func _on_tech_researched(tech_id: String) -> void:
	# The first researched tech of an age turns the town's page to it (schemas §3).
	var defs := DataLoader.load_domain("tech")
	var node_age := int((defs.get(tech_id, {}) as Dictionary).get("age", 1))
	if node_age > int(SaveManager.state["town"]["age"]):
		SaveManager.state["town"]["age"] = node_age
		SaveManager.state["meta"]["age"] = node_age
		EventBus.age_advanced.emit(node_age)


# --- Save / HUD ---------------------------------------------------------------------

func _save() -> void:
	SaveManager.state["meta"]["playtime_s"] = float(SaveManager.state["meta"]["playtime_s"]) + _session_t
	_session_t = 0.0
	SaveManager.save_current()


func _refresh_resources() -> void:
	var parts := PackedStringArray()
	for id in HUD_RESOURCES:
		parts.append("%s: %d" % [id, int(Ledger.get_amount(id))])
	_res_label.text = "\n".join(parts)


func _refresh_echoes() -> void:
	if not RunState.in_run() or RunState.echoes.is_empty():
		_echo_label.text = ""
		return
	# Fold repeats of stackable picks into "name ×n".
	var counts := {}
	for id in RunState.echoes:
		counts[id] = int(counts.get(id, 0)) + 1
	var defs := EchoCore.defs()
	var parts := PackedStringArray(["Echoes:"])
	for id: String in counts:
		var display := str((defs.get(id, {}) as Dictionary).get("name", id))
		parts.append(display if int(counts[id]) == 1 else "%s ×%d" % [display, int(counts[id])])
	_echo_label.text = "\n".join(parts)
