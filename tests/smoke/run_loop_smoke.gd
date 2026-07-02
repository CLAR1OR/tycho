extends Node
## Headless END-TO-END smoke of the vertical-slice loop (agent tool, not a unit
## test — the unit runner only discovers tests/core/). Runs as a SCENE so the
## autoloads exist (`godot -s` never registers them): it boots the REAL game.tscn
## as a child, then drives it — start a run, slaughter every room, step into the
## exit portal, and after the final boss check we came back to town with counters,
## drops, and the codex shard applied. Then a second run that dies on floor 1.
##
## Run:  /path/to/godot --headless res://tests/smoke/run_loop_smoke.tscn
## Uses a THROWAWAY save slot (see SMOKE_SLOT) and deletes it afterwards, so it
## never touches the human's slot 1. Exits 0 on green / 1 on any failure.

const SMOKE_SLOT := 99
const MAX_ROOMS := 30  # watchdog: a slice run is ~4 rooms; runaway = fail

var _game: Node
var _failures: PackedStringArray = []


func _ready() -> void:
	_run_smoke()


func _run_smoke() -> void:
	var game_scene: PackedScene = load("res://scenes/core/game.tscn")
	_game = game_scene.instantiate()
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	# game._ready loaded/created slot 1 — switch to the smoke slot instead.
	SaveManager.create_slot(SMOKE_SLOT, "Smoke")
	var runs_before := int(SaveManager.state["story"]["counters"]["runs"])

	_check(_scene_file() == "town.tscn", "boots into town (got %s)" % _scene_file())

	# --- Run 1: full clear -------------------------------------------------------
	_game.call("_start_run")
	await get_tree().process_frame
	var rooms_seen := 0
	while RunState.in_run() and rooms_seen < MAX_ROOMS:
		rooms_seen += 1
		await _clear_current_room()
	_check(rooms_seen < MAX_ROOMS, "run finished within the watchdog (%d rooms)" % rooms_seen)
	await _settle(30)
	_check(_scene_file() == "town.tscn", "victory returns to town (got %s)" % _scene_file())
	var c: Dictionary = SaveManager.state["story"]["counters"]
	_check(int(c["runs"]) == runs_before + 1, "runs counter ticked (%d)" % int(c["runs"]))
	_check(int(c["boss_kills"]) >= 1, "boss kill counted (%d)" % int(c["boss_kills"]))
	_check(int(c["full_clears"]) == 1, "full clear counted")
	_check(int(SaveManager.state["codex"]["shards"]) == 1, "codex shard slotted")
	_check(Ledger.get_amount("gold") > 0.0, "gold dropped (%.0f)" % Ledger.get_amount("gold"))
	_check(Ledger.get_amount("knowledge-shards") >= 1.0, "boss dropped knowledge shards")
	_check(RunState.echoes.size() >= 1, "echo picks recorded (%d)" % RunState.echoes.size())
	_check(RunState.player_health > 0, "player HP carried between rooms (%d)" % RunState.player_health)

	# --- Build in town -------------------------------------------------------------
	# The wave gold (>= 40) buys Linnea's Study L1; the next day tick must produce.
	var gold_before_build := Ledger.get_amount("gold")
	_scene_node().call("_try_build")
	var lvl: int = TownCore.building_level(SaveManager.state["town"], "linneas-study")
	_check(lvl == 1, "build plot built the study (level %d)" % lvl)
	_check(Ledger.get_amount("gold") < gold_before_build, "build spent gold")

	# --- Run 2: death ------------------------------------------------------------
	_game.call("_start_run")
	await _settle(10)
	var player := _find_player()
	_check(player != null, "run 2 spawned a player")
	if player != null:
		player.take_damage(99999)
	await _settle(30)
	_check(_scene_file() == "town.tscn", "death returns to town (got %s)" % _scene_file())
	_check(int(c["deaths"]) == 1, "death counted")
	_check(int(c["runs"]) == runs_before + 2, "died run still ticks the day")
	_check(Ledger.get_amount("knowledge") >= 1.0, "study produced knowledge on the day tick")

	SaveManager.delete_slot(SMOKE_SLOT)
	print("---")
	if _failures.is_empty():
		print("SMOKE OK — full loop: town → run → boss → town → death → town")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("SMOKE FAIL: " + f)
		get_tree().quit(1)


## Kill the current room's wave, wait for the exit to open, walk into it (or, on
## the final boss, just wait for the town swap).
func _clear_current_room() -> void:
	await _settle(10)
	if _scene_file() != "combat_room.tscn":
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(99999)
	if not RunState.in_run():
		return  # that was the final boss — run is over, town swap is in flight
	# Combat clears pause for the echo offer — pick the first card, like a player.
	await _settle(10)
	var offer_panel: Node = get_tree().get_first_node_in_group("echo_offer")
	if offer_panel != null:
		offer_panel.call("pick", 0)
	# Exit opens after the room's respawn_delay beat; give it a generous margin.
	await _settle(90)
	var player := _find_player()
	if player != null:
		player.global_position = Vector3(0, 0.1, -23)  # the exit portal's spot
	await _settle(20)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## The live scene's file name ("town.tscn" / "combat_room.tscn"). Node names are
## unreliable here: during a swap the old scene is still queue_freed-pending, so
## Godot auto-renames the new sibling.
func _scene_file() -> String:
	var live := _scene_node()
	return live.scene_file_path.get_file() if live != null else "(none)"


func _scene_node() -> Node:
	var newest: Node = null
	for child in _game.get_node("World").get_children():
		if not child.is_queued_for_deletion():
			newest = child
	return newest


func _find_player() -> Player:
	var world := _game.get_node("World")
	for child in world.get_children():
		var p := child.get_node_or_null("Player")
		if p is Player and not child.is_queued_for_deletion():
			return p
	return null


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  " + msg)
	else:
		_failures.append(msg)
		printerr("  FAIL " + msg)
