extends Node
## Game root — the vertical-slice orchestrator (PRD §12 milestone 3).
##
## Owns the macro loop: boot a save slot → town → (portal) → run of combat rooms →
## victory or death → day tick + counters → back to town → save. Scenes below it
## (town, combat_room) signal UP; cross-domain bookkeeping flows through EventBus.
##
## Interim ownership notes, to migrate as the real systems land:
## - Story counters (runs/deaths/boss_kills/full_clears) are updated here from
##   EventBus signals; a StoryState autoload will own them later.
## - Victory == full clear while the slice config is 1 floor; the codex shard drop
##   rides on that (PRD §7.11).
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
const HUD_RESOURCES: Array[String] = ["gold", "stone", "knowledge", "knowledge-shards"]

var _scene: Node = null       # the live town or combat room
var _session_t: float = 0.0   # unsaved playtime (flushed into meta.playtime_s on save)

@onready var _world: Node = $World
@onready var _res_label: Label = $HUD/Resources
@onready var _echo_label: Label = $HUD/Echoes


func _ready() -> void:
	EventBus.resource_changed.connect(func(_id: String, _o: float, _n: float, _r: String) -> void:
		_refresh_resources())
	EventBus.save_loaded.connect(func(_slot: int) -> void: _refresh_resources())
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.death.connect(_on_death)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.tech_researched.connect(_on_tech_researched)
	# Playtest cheat panel (F2) — lives on the HUD layer so it survives scene swaps.
	var cheats := CheatPanel.new()
	cheats.setup(self)
	$HUD.add_child(cheats)
	_show_slot_select()


## Boot screen: pick/create a slot. Nothing is loaded until the player chooses.
func _show_slot_select() -> void:
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
		SaveManager.state["checkpoint"] = RunState.to_checkpoint()
		_save()
	var room := ROOM_SCENE.instantiate()
	room.setup(
		int(RunState.run["floor"]), int(RunState.run["room"]),
		int(RunState.run["rooms_this_floor"]), RunState.room_kind())
	_swap(room)
	room.cleared.connect(_on_room_cleared.bind(room))
	room.exit_entered.connect(func() -> void: call_deferred("_next_room"))
	room.player_died.connect(func() -> void: RunState.player_died())


func _swap(next_scene: Node) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = next_scene
	_world.add_child(next_scene)


# --- Run events --------------------------------------------------------------------

func _on_room_cleared(room: Node) -> void:
	var was_boss: bool = room.kind == RunFlow.KIND_BOSS
	var boss_id: String = room.BOSS_ID if was_boss else ""
	if not RunState.room_cleared(boss_id):
		return  # the run just ended (final boss) — _on_run_ended takes it from here
	if was_boss:
		room.open_exit()  # boss rooms pay in loot; echo beats follow combat rooms
		return
	# The echo beat (PRD §7.5): pause, pick 1 of 3, then the exit opens.
	var offers := EchoCore.generate_offer(
		EchoCore.defs(), RunState.echoes, int(RunState.run["seed"]), RunState.echo_offers_made)
	RunState.echo_offers_made += 1
	if offers.is_empty():
		room.open_exit()
		return
	room.present_echo_offer(offers, func(id: String) -> void:
		RunState.pick_echo(id)
		_refresh_echoes())


func _on_run_ended(victory: bool, _floor_reached: int, _stats: Dictionary) -> void:
	SaveManager.state["checkpoint"] = null  # the run is over — nothing to resume
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	counters["runs"] = int(counters["runs"]) + 1
	SaveManager.state["meta"]["runs"] = counters["runs"]
	if victory:
		# Slice config is one floor, so a victory IS a full clear → codex shard
		# (PRD §7.11). With more floors this stays correct: victory means all floors.
		counters["full_clears"] = int(counters["full_clears"]) + 1
		var shards := int(SaveManager.state["codex"]["shards"]) + 1
		SaveManager.state["codex"]["shards"] = shards
		EventBus.codex_shard_added.emit(shards)
	# The day tick: 1 day = 1 run, win OR die (locked decision, PRD §6.2).
	var produced := TownCore.tick(SaveManager.state["town"], DataLoader.load_domain("buildings"))
	for id: String in produced:
		Ledger.add(id, float(produced[id]), "town-tick")
	# Linnea works the ACTIVE node between runs; after enough runs she just solves
	# it — reward thinking, never hard-gate on the puzzle (IC-10, PRD §7.8).
	var active := str(SaveManager.state["tech"].get("active", ""))
	if not active.is_empty():
		SaveManager.state["tech"] = TechCore.tick_auto_solve(SaveManager.state["tech"], active)
		var tech_defs := DataLoader.load_domain("tech")
		if tech_defs.has(active) and TechCore.auto_solve_ready(tech_defs[active], SaveManager.state["tech"]):
			SaveManager.state["tech"] = TechCore.complete(SaveManager.state["tech"], active)
			EventBus.tech_researched.emit(active)
	call_deferred("_goto_town")


func _on_death(_source_id: String) -> void:
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	counters["deaths"] = int(counters["deaths"]) + 1


func _on_boss_killed(_boss_id: String, _floor: int) -> void:
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	counters["boss_kills"] = int(counters["boss_kills"]) + 1


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
