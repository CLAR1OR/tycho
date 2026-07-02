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
## - Slot 1 is loaded/created implicitly; a main-menu slot-select screen replaces
##   that in a later slice.
## - Victory == full clear while the slice config is 1 floor; the codex shard drop
##   rides on that (PRD §7.11).

const TOWN_SCENE := preload("res://scenes/town/town.tscn")
const ROOM_SCENE := preload("res://scenes/combat/combat_room.tscn")

const SLOT := 1

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


func _ready() -> void:
	EventBus.resource_changed.connect(func(_id: String, _o: float, _n: float, _r: String) -> void:
		_refresh_resources())
	EventBus.save_loaded.connect(func(_slot: int) -> void: _refresh_resources())
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.death.connect(_on_death)
	EventBus.boss_killed.connect(_on_boss_killed)
	if not SaveManager.load_slot(SLOT):
		SaveManager.create_slot(SLOT, "Tycho")
	_refresh_resources()
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
	_save()


func _start_run() -> void:
	var run_number := int(SaveManager.state["story"]["counters"]["runs"]) + 1
	RunState.start_run(
		{"floors": run_floors, "rooms_min": rooms_min, "rooms_max": rooms_max},
		randi(), run_number)
	_next_room()


func _next_room() -> void:
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
	var boss_id: String = room.BOSS_ID if room.kind == RunFlow.KIND_BOSS else ""
	if RunState.room_cleared(boss_id):
		room.open_exit()
	# else the run just ended (final boss) — _on_run_ended takes it from here.


func _on_run_ended(victory: bool, _floor_reached: int, _stats: Dictionary) -> void:
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
	call_deferred("_goto_town")


func _on_death(_source_id: String) -> void:
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	counters["deaths"] = int(counters["deaths"]) + 1


func _on_boss_killed(_boss_id: String, _floor: int) -> void:
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	counters["boss_kills"] = int(counters["boss_kills"]) + 1


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
