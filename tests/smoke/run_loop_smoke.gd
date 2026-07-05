extends Node
## Headless END-TO-END smoke of the vertical-slice loop (agent tool, not a unit
## test — the unit runner only discovers tests/core/). Runs as a SCENE so the
## autoloads exist (`godot -s` never registers them): it boots the REAL game.tscn
## as a child, then drives it — choose a slot on the REAL slot-select screen, start
## a 3-floor run, slaughter every room, quit mid-run at floor 2 and resume from the
## per-floor checkpoint, and after the final boss check we came back to town with
## counters, drops, and the codex shard applied. Then a second run that dies.
##
## Run:  /path/to/godot --headless res://tests/smoke/run_loop_smoke.tscn
## Uses a THROWAWAY save slot (see SMOKE_SLOT) and deletes it afterwards; boot
## itself loads nothing, so the human's slots are never touched. Exits 0/1.

const SMOKE_SLOT := 99
const MAX_ROOMS := 30  # watchdog: a slice run is ~4 rooms; runaway = fail

var _game: Node
var _failures: PackedStringArray = []


func _ready() -> void:
	_run_smoke()


func _run_smoke() -> void:
	_boot_game()
	await get_tree().process_frame
	await get_tree().process_frame

	# Boot waits at the slot-select screen — nothing loads until a slot is chosen.
	_check(_scene_node() == null, "boot waits at slot select, no slot loaded")
	_game.call("choose_slot", SMOKE_SLOT)
	await get_tree().process_frame
	var runs_before := int(SaveManager.state["story"]["counters"]["runs"])

	_check(_scene_file() == "town.tscn", "fresh slot enters town (got %s)" % _scene_file())
	_check(Music.current_id == "town", "town scene plays town music (%s)" % Music.current_id)

	# --- Unlock cascade (PRD §7.1): a fresh save opens nothing. The forge, the
	# research desk, and the build plots are all shut until their story beats fire. ---
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "weapons"), "fresh save: forge locked")
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "tech"), "fresh save: research desk locked")
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "building"), "fresh save: build plots locked")
	_check(_scene_node().call("open_forge_panel") == null, "forge panel refuses while locked")
	_check(_scene_node().call("open_tech_panel") == null, "research panel refuses while locked")
	_scene_node().call("_try_build", "sophias-study")
	_check(TownCore.building_level(SaveManager.state["town"], "sophias-study") == 0,
		"build refused while the building system is locked")

	# --- Run 1: full clear over 3 floors, with a mid-run quit + resume at floor 2 ---
	_game.call("_start_run")
	await get_tree().process_frame
	var rooms_seen := 0
	var resume_tested := false
	var music_dungeon_ok := false
	var music_boss_ok := false
	while RunState.in_run() and rooms_seen < MAX_ROOMS:
		rooms_seen += 1
		# The run swaps music per room kind (game.gd _next_room) — sample it once
		# each while we sit in a dungeon room and in a boss room.
		if _scene_file() == "combat_room.tscn":
			if RunState.room_kind() == RunFlow.KIND_BOSS and not music_boss_ok:
				music_boss_ok = true
				_check(Music.current_id == "boss", "boss room plays boss music (%s)" % Music.current_id)
			elif RunState.room_kind() == RunFlow.KIND_COMBAT and not music_dungeon_ok:
				music_dungeon_ok = true
				_check(Music.current_id == "dungeon", "dungeon room plays dungeon music (%s)" % Music.current_id)
		if not resume_tested and int(RunState.run["floor"]) == 2:
			resume_tested = true
			await _quit_and_resume()
		await _clear_current_room()
	_check(resume_tested, "the run reached floor 2 (checkpoint beat exercised)")
	_check(music_dungeon_ok and music_boss_ok, "both dungeon and boss music beats sampled")
	_check(rooms_seen < MAX_ROOMS, "run finished within the watchdog (%d rooms)" % rooms_seen)
	await _settle(30)
	_check(_scene_file() == "town.tscn", "victory returns to town (got %s)" % _scene_file())
	_check(SaveManager.state["checkpoint"] == null, "run over — checkpoint cleared")
	var c: Dictionary = SaveManager.state["story"]["counters"]
	_check(int(c["runs"]) == runs_before + 1, "runs counter ticked (%d)" % int(c["runs"]))
	_check(int(c["boss_kills"]) >= 1, "boss kill counted (%d)" % int(c["boss_kills"]))
	_check(int(c["full_clears"]) == 1, "full clear counted")
	_check(int(SaveManager.state["codex"]["shards"]) == 1, "codex shard slotted")
	_check(Ledger.get_amount("gold") > 0.0, "gold dropped (%.0f)" % Ledger.get_amount("gold"))
	_check(Ledger.get_amount("knowledge-shards") >= 1.0, "boss dropped knowledge shards")
	_check(RunState.echoes.size() >= 1, "echo picks recorded (%d)" % RunState.echoes.size())
	_check(RunState.player_health > 0, "player HP carried between rooms (%d)" % RunState.player_health)

	# StoryState (autoload) updates the counters BEFORE game.gd's deferred town-swap
	# save runs — re-read the slot file from disk to prove the ordering guarantee: the
	# persisted counters must match the in-memory ones, not the pre-run values.
	var on_disk := _read_slot_from_disk()
	var disk_c: Dictionary = on_disk["story"]["counters"]
	_check(int(disk_c["runs"]) == runs_before + 1, "disk: runs counter persisted (%d)" % int(disk_c["runs"]))
	_check(int(disk_c["full_clears"]) == 1, "disk: full clear persisted")
	_check(int(disk_c["boss_kills"]) >= 1, "disk: boss kills persisted (%d)" % int(disk_c["boss_kills"]))
	_check(int(on_disk["codex"]["shards"]) == 1, "disk: codex shard persisted")
	_check(int(on_disk["meta"]["runs"]) == runs_before + 1, "disk: meta.runs mirror persisted")

	# --- The unlock cascade fires on the run-1 town return (PRD §7.1) ---------------
	# B3 (Sophia cracks the shards) force-plays because run 1's 3 boss kills tripped
	# its gate; then B1 (Mara, talk) and B4 (Herzog, talk) open the forge and plots.
	await _settle(5)
	var dlg_defs: Dictionary = DataLoader.load_domain("dialogue")
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "tech"), "desk still locked as B3 opens")
	var b3dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(b3dlg != null, "B3 'Sophia cracks the shards' force-played (3rd boss kill)")
	if b3dlg != null:
		for i in ((dlg_defs["b3-sophia-shards"]["scene"] as Dictionary)["lines"] as Array).size():
			b3dlg.advance()
		await _settle(3)
	_check(bool(SaveManager.state["story"]["flags"].get("b3", false)), "B3 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "tech"), "research desk unlocked after B3")

	_check(not UnlocksCore.is_unlocked(SaveManager.state, "weapons"), "forge locked before B1")
	var b1dlg: DialoguePanel = _scene_node().call("talk_to", "mara")
	_check(b1dlg != null, "Mara offers B1 (resonance ore is in the pack from the boss drops)")
	if b1dlg != null:
		for i in ((dlg_defs["b1-mara-ore"]["scene"] as Dictionary)["lines"] as Array).size():
			b1dlg.advance()
		await _settle(3)
	_check(bool(SaveManager.state["story"]["flags"].get("b1", false)), "B1 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "weapons"), "forge unlocked after B1")

	_check(not UnlocksCore.is_unlocked(SaveManager.state, "building"), "build plots locked before B4")
	var b4dlg: DialoguePanel = _scene_node().call("talk_to", "herzog")
	_check(b4dlg != null, "Herzog offers B4 (gold over the cheapest building cost; A4 needs runs>=2)")
	if b4dlg != null:
		for i in ((dlg_defs["b4-herzog-ledger"]["scene"] as Dictionary)["lines"] as Array).size():
			b4dlg.advance()
		await _settle(3)
	_check(bool(SaveManager.state["story"]["flags"].get("b4", false)), "B4 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "building"), "build plots unlocked after B4")
	# mark_shown replaced the story dict three times — re-grab the counters ref.
	c = SaveManager.state["story"]["counters"]

	# --- Build in town -------------------------------------------------------------
	# The wave gold (>= 40) buys Sophia's Study L1; the next day tick must produce.
	var gold_before_build := Ledger.get_amount("gold")
	_scene_node().call("_try_build", "sophias-study")
	var lvl: int = TownCore.building_level(SaveManager.state["town"], "sophias-study")
	_check(lvl == 1, "build plot built the study (level %d)" % lvl)
	_check(Ledger.get_amount("gold") < gold_before_build, "build spent gold")

	# --- Research at Sophia's desk ---------------------------------------------------
	# Quarry must be tech-gated first; then drive the REAL panel path end-to-end:
	# arithmetic (prereq) → masonry → quarry buildable. Smoke funds the research.
	_scene_node().call("_try_build", "quarry")
	_check(TownCore.building_level(SaveManager.state["town"], "quarry") == 0,
		"quarry blocked before masonry is researched")
	Ledger.add("knowledge", 100.0, "smoke-grant")
	Ledger.add("gold", 100.0, "smoke-grant")
	var panel: TechPanel = _scene_node().call("open_tech_panel")
	await _settle(3)
	# Arithmetic: the quiz form, incl. one deliberately wrong answer (must retry).
	panel.select_node("med-arithmetic-zero")
	panel.invest_all()
	panel.begin_read()
	panel.begin_quiz()
	panel.answer(1)
	var questions: int = ((DataLoader.load_domain("tech")["med-arithmetic-zero"]["puzzle"] as Dictionary)["data"]["questions"] as Array).size()
	for i in questions:
		panel.answer(0)  # authored data keeps the correct option at index 0
	panel.finish()
	# Masonry: the REAL interactive arch puzzle — the full didactic path, all three
	# authored failures (lintel crack, unkeyed collapse, splay), then the win.
	panel.select_node("med-masonry-arch")
	panel.invest_all()
	panel.begin_read()
	panel.begin_puzzle()
	var arch: Node = panel.puzzle_node()
	_check(arch != null, "the arch puzzle embedded in the panel")
	if arch != null:
		_check(str(arch.call("act", "lintel")) == "lintel_placed", "beat 1: lintel laid")
		_check(str(arch.call("act", "load")) == "lintel_cracked", "beat 1: lintel cracks under load")
		_check(str(arch.call("act", "arch")) == "arch_chosen", "beat 2: curve the span")
		_check(str(arch.call("act", "voussoir", 1)) == "voussoir_fell", "wedge falls without centering")
		arch.call("act", "centering")
		for i in 6:
			arch.call("act", "voussoir", i)
		_check(str(arch.call("act", "load")) == "unkeyed_collapse", "loading the open ring collapses it")
		for i in 6:
			arch.call("act", "voussoir", i)
		_check(str(arch.call("act", "keystone")) == "keystone_seated", "keystone locks the ring")
		_check(str(arch.call("act", "load")) == "splayed", "beat 3: unbraced arch splays outward")
		arch.call("act", "abutment", "left")
		arch.call("act", "abutment", "right")
		arch.call("act", "centering")
		for i in 6:
			arch.call("act", "voussoir", i)
		arch.call("act", "keystone")
		_check(str(arch.call("act", "load")) == "holds", "braced + keyed: the gateway holds")
		await _settle(3)
		panel.finish()
	panel.close()
	await _settle(3)
	var researched: Array = SaveManager.state["tech"]["researched"]
	_check(researched.has("med-arithmetic-zero") and researched.has("med-masonry-arch"),
		"both nodes researched through read → quiz → aha (%s)" % str(researched))
	_scene_node().call("_try_build", "quarry")
	_check(TownCore.building_level(SaveManager.state["town"], "quarry") == 1,
		"masonry unlock makes the quarry buildable")

	# TechState (autoload) owns the tech-section writes now — the panel's finish() and
	# Sophia's auto-solve both route through it. Re-read the slot straight off disk to
	# prove the TechState-mutated tech dict lands there (same ordering proof as the
	# story counters above).
	var disk_tech: Dictionary = _read_slot_from_disk().get("tech", {})
	var disk_researched: Array = disk_tech.get("researched", [])
	_check(disk_researched.has("med-arithmetic-zero") and disk_researched.has("med-masonry-arch"),
		"disk: TechState research persisted (%s)" % str(disk_researched))
	_check(str(disk_tech.get("active", "?")) == "", "disk: active node cleared on completion")
	_check(not (disk_tech.get("in_progress", {}) as Dictionary).has("med-masonry-arch"),
		"disk: completed node's in-progress/auto-solve counter cleared")

	# --- Mara's Forge ----------------------------------------------------------------
	Ledger.add("resonance-ore", 5.0, "smoke-grant")
	var ore_before := Ledger.get_amount("resonance-ore")
	_check(ore_before >= 7.0, "boss dropped guaranteed ore (have %.0f incl. 5 granted)" % ore_before)
	var forge: ForgePanel = _scene_node().call("open_forge_panel")
	await _settle(3)
	forge.upgrade("sword")
	_check(WeaponCore.flat_level(SaveManager.state["combat"], "sword") == 1,
		"forge refined the sword to flat L1")
	_check(Ledger.get_amount("resonance-ore") == ore_before - 1.0, "refine spent 1 ore")
	forge.equip("daggers")
	_check(str(SaveManager.state["combat"]["current_weapon"]) == "daggers", "daggers equipped")
	forge.close()
	await _settle(3)

	# --- Run 2: death ------------------------------------------------------------
	_game.call("_start_run")
	await _settle(10)
	var player := _find_player()
	_check(player != null, "run 2 spawned a player")
	if player != null:
		_check(player.attack_damage < 25, "daggers kit applied to the run player (damage %d)" % player.attack_damage)
		_check(player.attack_windup < 0.05, "daggers are faster (windup %.3f)" % player.attack_windup)
	if player != null:
		player.take_damage(99999)
	await _settle(30)
	_check(_scene_file() == "town.tscn", "death returns to town (got %s)" % _scene_file())
	_check(SaveManager.state["checkpoint"] == null, "death clears the checkpoint too")
	_check(int(c["deaths"]) == 1, "death counted")
	_check(int(c["runs"]) == runs_before + 2, "died run still ticks the day")
	_check(Ledger.get_amount("knowledge") >= 1.0, "study produced knowledge on the day tick")
	_check(Ledger.get_amount("stone") >= 2.0, "quarry produced stone on the day tick")

	# --- Dialogue (PRD §7.12): masonry was researched during this save, so B5 ("the
	# first wall", force_play) must have auto-played on THIS town return.
	var dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(dlg != null, "B5 'the first wall' force-played on town entry")
	_check(bool(SaveManager.state["story"]["flags"].get("has-resonance-ore", false)),
		"first-pickup flag set from the run's ore drop")
	if dlg != null:
		var b5_lines: int = ((DataLoader.load_domain("dialogue")["b5-the-first-wall"]["scene"] as Dictionary)["lines"] as Array).size()
		for i in b5_lines:
			dlg.advance()
		await _settle(3)
		_check(not get_tree().paused, "finished dialogue unpauses the game")
		_check(bool(SaveManager.state["story"]["flags"].get("b5", false)), "B5 set its flag")
		_check((SaveManager.state["story"]["seen"] as Array).has("b5-the-first-wall"),
			"B5 marked seen (a spine beat never repeats)")
	# Talking: Herzog offers his single highest-priority eligible snippet — A4
	# (spine, runs >= 2) outranks the gold-gated contextual.
	var talk: DialoguePanel = _scene_node().call("talk_to", "herzog")
	_check(talk != null, "Herzog has something to say")
	if talk != null:
		var a4_lines: int = ((DataLoader.load_domain("dialogue")["a4-herzog-fetch"]["scene"] as Dictionary)["lines"] as Array).size()
		for i in a4_lines:
			talk.advance()
		await _settle(3)
		_check(bool(SaveManager.state["story"]["flags"].get("a4", false)),
			"A4 played first (spine > contextual, B4 already seen) and set its flag")
		_check(int((SaveManager.state["story"]["talked_to"] as Dictionary).get("herzog", 0)) == 2,
			"talked_to counted (B4 earlier + A4 now)")

	# mark_shown replaces the story section (pure copy) — re-grab the counters ref.
	c = SaveManager.state["story"]["counters"]

	# --- Cheat panel (F2 playtest tool) — must mirror the real paths exactly --------
	var cheats: CheatPanel = get_tree().get_first_node_in_group("cheat_panel")
	_check(cheats != null, "cheat panel lives on the HUD layer")
	if cheats != null:
		var gold_now := Ledger.get_amount("gold")
		cheats.grant("gold", 100.0)
		_check(Ledger.get_amount("gold") == gold_now + 100.0, "cheat grants gold via the Ledger")
		var stone_now := Ledger.get_amount("stone")
		cheats.simulate_run(true)
		await _settle(10)
		_check(int(c["runs"]) == runs_before + 3, "simulated run ticks the runs counter")
		_check(int(c["full_clears"]) == 2, "simulated run counts a full clear")
		_check(int(c["boss_kills"]) >= 2, "simulated run counts the boss kill")
		_check(int(SaveManager.state["codex"]["shards"]) == 2, "simulated run slots a codex shard")
		_check(Ledger.get_amount("stone") > stone_now, "simulated run still ticks the day (quarry)")
		_check(_scene_file() == "town.tscn", "simulated run lands back in town")
		cheats.grant_codex_shard()
		_check(int(SaveManager.state["codex"]["shards"]) == 3, "codex shard cheat applies")

	SaveManager.delete_slot(SMOKE_SLOT)
	print("---")
	if _failures.is_empty():
		print("SMOKE OK — full loop: town → run → boss → town → death → town")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("SMOKE FAIL: " + f)
		get_tree().quit(1)


func _boot_game() -> void:
	_game = (load("res://scenes/core/game.tscn") as PackedScene).instantiate()
	# 3 floors: a floor TRANSITION exists (checkpoint beat), AND one full clear scores
	# 3 cumulative boss kills — which trips the B3 cascade gate (boss_kills >= 3), so
	# the smoke exercises the tech-desk unlock naturally on the run-1 town return.
	_game.set("run_floors", 3)
	add_child(_game)


## The mid-run quit: assert the floor-start checkpoint hit the disk, then throw the
## whole game away and boot a fresh one — choosing the slot must resume the run at
## floor start with echoes and carried HP intact (PRD §7.13).
func _quit_and_resume() -> void:
	var cp: Variant = SaveManager.state["checkpoint"]
	_check(cp is Dictionary and int((cp["run"] as Dictionary)["floor"]) == 2,
		"checkpoint snapshotted at floor 2 start")
	var echoes_before := RunState.echoes.duplicate()
	var hp_before := RunState.player_health
	_check(echoes_before.size() >= 1, "picks exist before the quit (floor 1 echo beats)")
	_game.queue_free()
	await _settle(5)
	_boot_game()
	await _settle(5)
	_check(_scene_node() == null, "rebooted game waits at slot select")
	var badge_floor := -1
	for entry: Dictionary in SaveManager.list_slots():
		if int(entry["slot"]) == SMOKE_SLOT:
			badge_floor = int(entry["checkpoint_floor"])
	_check(badge_floor == 2, "slot list shows the mid-run badge (floor %d)" % badge_floor)
	_game.call("choose_slot", SMOKE_SLOT)
	await _settle(10)
	_check(_scene_file() == "combat_room.tscn", "resume boots into the run (got %s)" % _scene_file())
	_check(int(RunState.run["floor"]) == 2 and int(RunState.run["room"]) == 1,
		"resume lands at floor 2, room 1")
	_check(RunState.echoes == echoes_before, "echo picks survive the quit (via checkpoint)")
	_check(RunState.player_health == hp_before, "carried HP survives the quit (%d)" % RunState.player_health)


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


## Re-read the smoke slot straight off disk (bypassing SaveManager.state) — used to
## prove StoryState's counter writes are persisted, not just held in memory.
func _read_slot_from_disk() -> Dictionary:
	var f := FileAccess.open(SaveManager.slot_path(SMOKE_SLOT), FileAccess.READ)
	if f == null:
		_check(false, "could not re-read the slot file from disk")
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


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
