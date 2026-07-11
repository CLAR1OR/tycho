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
const MAX_ROOMS := 40  # watchdog: run 1 is 3 floors x 5 rooms (+ a resume replay); runaway = fail

var _game: Node
var _failures: PackedStringArray = []

# SAFETY (achievements, 2026-07-11): profile.json is GLOBAL — the human's REAL profile
# (settings + achievements, shared across their real slots). The smoke's events unlock
# real achievements and the Achievements autoload persists them, so the file is
# snapshotted BYTE-EXACTLY at boot and restored (or deleted, if it did not exist) right
# before the single exit point below — covering both the ok and the fail path.
var _profile_existed := false
var _profile_bytes := PackedByteArray()
# Every achievement_unlocked the run emitted (captured before anything plays).
var _unlocks_seen: PackedStringArray = []

# Door-choice coverage flags — each mechanic is exercised once, then skipped (below).
var _door_offer_checked: bool = false
var _dust_tested: bool = false
var _wellspring_tested: bool = false
var _boss_heal_tested: bool = false
var _postboss_echo_tested: bool = false
var _multiwave_checked: bool = false  # a real combat room ran >1 wave (2026-07-06)
var _strata_checked: bool = false     # env applied + hazard plan matches spawned (2026-07-10)
var _dualuse_checked: bool = false    # a hazard damaged an enemy by direct call (2026-07-10)
var _final_boss_disk_checked: bool = false  # the statistics invariant window (2026-07-07)
var _den_warden_tested: bool = false        # floor-1 boss = the data-driven Den-Warden (2026-07-10)
var _placeholder_boss_checked: bool = false # floors without a def keep the placeholder boss
# RunHud coverage (the Slate in-run HUD, 2026-07-07) — each checked once.
var _shelf_checked: bool = false      # echo shelf tile count == folded pick count
var _pickup_checked: bool = false     # pickup strip lights on a drop
var _echo_geom_checked: bool = false  # echo offer panel geometry + mark count (O1, 2026-07-09)


func _ready() -> void:
	_run_smoke()


func _run_smoke() -> void:
	# FIRST, before any event can make the Achievements autoload write it: snapshot the
	# human's real profile.json byte-exactly (see the header note; restored at the end).
	_profile_existed = FileAccess.file_exists(SaveManager.profile_path())
	if _profile_existed:
		_profile_bytes = FileAccess.get_file_as_bytes(SaveManager.profile_path())
	EventBus.achievement_unlocked.connect(func(id: String) -> void: _unlocks_seen.append(id))
	_boot_game()
	# Run telemetry (2026-07-10, diagnostics tooling, NOT the save system): redirect to a
	# throwaway temp file for the WHOLE smoke, so a real run/death/forfeit here never
	# touches the human's real user://telemetry/runs.jsonl.
	var telemetry_path := OS.get_temp_dir().path_join("tycho_smoke_telemetry_%d.jsonl" % OS.get_process_id())
	Telemetry.path_override = telemetry_path
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
	# The build path is now the BuildPanel (B2) + the Planning Table survey (B3) — both refuse
	# (return null) while the build system is locked; a fresh save builds nothing.
	_check(_scene_node().call("open_build_panel", "sophias-study") == null,
		"build panel refuses while the building system is locked")
	_check(_scene_node().call("open_survey_panel") == null,
		"survey panel refuses while the building system is locked")
	_check(TownCore.building_level(SaveManager.state["town"], "sophias-study") == 0,
		"nothing built while the building system is locked")

	# --- New enemy types (2026-07-06): both scenes must load, extend EnemyDummy, and
	# carry their signature exports — so the wave pipeline can spawn them in a real room. ---
	var slammer: Node = load("res://scenes/combat/enemy_slammer.tscn").instantiate()
	_check(slammer is EnemyDummy, "slammer scene loads and extends EnemyDummy")
	_check(slammer.get("slam_radius") != null, "slammer exposes its AoE-radius export")
	slammer.free()
	var charger: Node = load("res://scenes/combat/enemy_charger.tscn").instantiate()
	_check(charger is EnemyDummy, "charger scene loads and extends EnemyDummy")
	_check(charger.get("charge_speed") != null, "charger exposes its charge-speed export")
	charger.free()
	# Wave composition is pure/seeded — prove both new types are reachable in the mix.
	var mix_has_slammer := false
	var mix_has_charger := false
	for s in 200:
		for w: Array in WaveCore.compose(1, 1 + s % 5, 3, s):
			if w.has(WaveCore.TYPE_SLAMMER):
				mix_has_slammer = true
			if w.has(WaveCore.TYPE_CHARGER):
				mix_has_charger = true
	_check(mix_has_slammer and mix_has_charger, "WaveCore mixes in Slammer + Charger from floor 1")

	# --- Boss #1 as data (2026-07-10, design/bosses/floor-1-boss.md): the Den-Warden def
	# loads + validates, and the pure core agrees on the 50% boundary + the loop wrap. ---
	var bosses := DataLoader.load_domain("bosses")
	_check(bosses.has("den-warden"), "data/bosses/den-warden.json loads")
	var bdef: Dictionary = bosses.get("den-warden", {})
	_check(BossCore.validate(bdef).is_empty(), "den-warden def passes BossCore.validate")
	_check(BossCore.phase_for(bdef, 1.0) == 0 and BossCore.phase_for(bdef, 0.51) == 0
		and BossCore.phase_for(bdef, 0.5) == 1,
		"BossCore.phase_for: phase 2 starts exactly at the 50% boundary")
	var wrap := BossCore.next_move(bdef, 1, 2)
	_check(str(wrap.get("id")) == "vent_call" and int(wrap.get("next_position", -1)) == 0,
		"BossCore.next_move wraps phase 2's loop (%s -> %d)"
		% [str(wrap.get("id")), int(wrap.get("next_position", -1))])

	# --- Run 1: full clear over 3 floors, with a mid-run quit + resume at floor 2 ---
	_game.call("_start_run")
	await get_tree().process_frame
	var rooms_seen := 0
	var resume_tested := false
	var music_dungeon_ok := false
	var music_boss_ok := false
	while RunState.in_run() and rooms_seen < MAX_ROOMS:
		rooms_seen += 1
		# The run swaps music per room kind (game.gd _next_room) — sample it once each.
		# Read the SCENE's kind, not RunState's: reprieve rooms auto-clear and advance
		# RunState, so it can point a room ahead of what is on screen.
		if _scene_file() == "combat_room.tscn":
			var scene_kind: String = str(_scene_node().get("kind"))
			if scene_kind == RunFlow.KIND_BOSS and not music_boss_ok:
				music_boss_ok = true
				_check(Music.current_id == "boss", "boss room plays boss music (%s)" % Music.current_id)
			elif scene_kind == RunFlow.KIND_COMBAT and not music_dungeon_ok:
				music_dungeon_ok = true
				_check(Music.current_id == "dungeon", "dungeon room plays dungeon music (%s)" % Music.current_id)
		if not resume_tested and int(RunState.run["floor"]) == 2:
			resume_tested = true
			await _quit_and_resume()
		await _play_room()
	_check(resume_tested, "the run reached floor 2 (checkpoint beat exercised)")
	_check(music_dungeon_ok and music_boss_ok, "both dungeon and boss music beats sampled")
	_check(rooms_seen < MAX_ROOMS, "run finished within the watchdog (%d rooms)" % rooms_seen)
	# Door-choice coverage (design/run-structure.md) — each path was hit during the run.
	_check(_multiwave_checked, "a combat room ran multiple sequential waves")
	_check(_strata_checked, "a combat room applied its stratum env + spawned its hazard plan")
	_check(_door_offer_checked, "a door offer with 1-2 distinct sigils was shown")
	_check(_dust_tested, "a paying door granted its cache on clear (reason door-reward)")
	_check(_wellspring_tested, "a reprieve door's Wellspring healed 40% of missing")
	_check(_boss_heal_tested, "a boss kill healed 30% of missing")
	_check(_postboss_echo_tested, "the guaranteed post-boss echo offer fired")
	_check(_den_warden_tested, "floor 1's boss was the data-driven Den-Warden")
	_check(_placeholder_boss_checked, "a later floor still ran the placeholder boss")
	await _settle(30)
	_check(_scene_file() == "town.tscn", "victory returns to town (got %s)" % _scene_file())
	_check(SaveManager.state["checkpoint"] == null, "run over — checkpoint cleared")

	# --- Town HUD (Slate T1 + overnight toast + projections, 2026-07-07) ---------------
	# The run-end return fires the overnight production toast, and the day chip reads the
	# new day + the last tick's Food status. Also the CanvasLayer-under-_ready geometry
	# regression net (same as RunHud's): the HUD must span the viewport.
	var thud: Node = get_tree().get_first_node_in_group("town_hud")
	_check(thud != null, "town HUD present on the victory return")
	_check(bool(thud.call("toast_visible")), "overnight toast shown on the day-tick town return")
	var dc := str(thud.call("day_chip"))
	_check(dc.begins_with("Day 2"), "town day chip reads Day 2 on the run-1 return (%s)" % dc)
	var fed_now := bool(SaveManager.state["town"]["well_fed"])
	_check(dc.contains("Well-Fed") if fed_now else dc.contains("Short"),
		"day chip shows the last tick's food status (%s)" % dc)
	var tvp: Vector2 = get_viewport().get_visible_rect().size
	_check(thud is Control and (thud as Control).size == tvp,
		"TownHud spans the viewport (%s == %s)" % [
			str((thud as Control).size) if thud is Control else "?", str(tvp)])
	# The strip's town/run split (2026-07-07): town = building-producible (derived from
	# the building defs), run = everything only ever brought home from runs.
	var tgroup: Array = thud.call("town_group")
	var rgroup: Array = thud.call("run_group")
	_check(tgroup.has("stone") and tgroup.has("food") and tgroup.has("knowledge")
		and not tgroup.has("gold"),
		"town group = the building-producible resources (%s)" % str(tgroup))
	_check(rgroup.has("gold") and rgroup.has("knowledge-shards") and rgroup.has("resonance-ore")
		and rgroup.has("resonance-dust"),
		"run group = the run-collected pickups (%s)" % str(rgroup))
	var c: Dictionary = SaveManager.state["story"]["counters"]
	_check(int(c["runs"]) == runs_before + 1, "runs counter ticked (%d)" % int(c["runs"]))
	_check(int(c["boss_kills"]) >= 1, "boss kill counted (%d)" % int(c["boss_kills"]))
	_check(int(c["full_clears"]) == 1, "full clear counted")
	# The full clear ended by walking into the codex artifact — Tycho DISSOLVED (a full-clear
	# return), which is a separate counter from a combat death (2026-07-07).
	_check(int(c["dissolves"]) == 1, "dissolve counted at the codex artifact")
	_check(int(c["deaths"]) == 0, "the full-clear dissolve is NOT a combat death")
	# max_floor (2026-07-10): the deepest floor EVER reached, max()'d from run_ended's
	# floor_reached. The full clear walked every configured floor.
	_check(int(c["max_floor"]) == int(_game.get("run_floors")),
		"max_floor recorded the run's deepest floor (%d)" % int(c["max_floor"]))
	_check(int(SaveManager.state["codex"]["shards"]) == 1, "codex shard slotted")
	_check(Ledger.get_amount("gold") > 0.0, "gold dropped (%.0f)" % Ledger.get_amount("gold"))
	_check(Ledger.get_amount("knowledge-shards") >= 1.0, "boss dropped knowledge shards")
	_check(RunState.echoes.size() >= 1, "echo picks recorded (%d)" % RunState.echoes.size())
	_check(RunState.player_health > 0, "player HP carried between rooms (%d)" % RunState.player_health)

	# --- Run telemetry (2026-07-10) — the diagnostics JSONL file, written on run_ended ---
	_check(FileAccess.file_exists(telemetry_path), "telemetry file exists after the first run")
	var t1 := _last_telemetry_line(telemetry_path)
	_check(not t1.is_empty(), "the last telemetry line parses as JSON")
	if not t1.is_empty():
		_check(str(t1.get("outcome", "")) == "victory",
			"run-1 telemetry recorded outcome=victory (%s)" % str(t1.get("outcome", "")))
		var floors_configured := int(_game.get("run_floors"))
		_check(int(t1.get("floor_reached", -1)) == floors_configured,
			"run-1 telemetry recorded floor_reached=%d (%s)" % [floors_configured, str(t1.get("floor_reached"))])

	# StoryState (autoload) updates the counters BEFORE game.gd's deferred town-swap
	# save runs — re-read the slot file from disk to prove the ordering guarantee: the
	# persisted counters must match the in-memory ones, not the pre-run values.
	var on_disk := _read_slot_from_disk()
	var disk_c: Dictionary = on_disk["story"]["counters"]
	_check(int(disk_c["runs"]) == runs_before + 1, "disk: runs counter persisted (%d)" % int(disk_c["runs"]))
	_check(int(disk_c["full_clears"]) == 1, "disk: full clear persisted")
	_check(int(disk_c["boss_kills"]) >= 1, "disk: boss kills persisted (%d)" % int(disk_c["boss_kills"]))
	_check(int(disk_c["dissolves"]) == 1, "disk: dissolves counter persisted")
	_check(int(disk_c["max_floor"]) == int(_game.get("run_floors")),
		"disk: max_floor persisted (%d)" % int(disk_c["max_floor"]))
	_check(int(on_disk["codex"]["shards"]) == 1, "disk: codex shard persisted")
	_check(int(on_disk["meta"]["runs"]) == runs_before + 1, "disk: meta.runs mirror persisted")

	# --- Achievements (schemas §5, 2026-07-11): the full clear unlocked first-clear -----
	# The evaluator rides the same run_ended the counters do; the unlock must be on the
	# bus, in the profile in memory, AND already persisted to profile.json (the autoload
	# saves on change). The run's boss kills also unlocked the boss beats along the way.
	_check(_unlocks_seen.has("first-clear"), "achievement_unlocked(first-clear) observed on the bus")
	_check(_unlocks_seen.has("boss-den-warden"), "the floor-1 Den-Warden kill unlocked its achievement")
	var prof_ach: Dictionary = SaveManager.profile["achievements"]
	_check(AchievementCore.is_unlocked(prof_ach, "first-clear"), "first-clear unlocked in the profile")
	_check(AchievementCore.is_unlocked(prof_ach, "floor-3"),
		"the 3-floor clear unlocked the floor-3 gte achievement")
	_check(not AchievementCore.is_unlocked(prof_ach, "floor-4"),
		"floor-4 stays locked (never reached)")
	var disk_ach: Dictionary = (_read_profile_from_disk().get("achievements", {}) as Dictionary)
	_check(str((disk_ach.get("first-clear", {}) as Dictionary).get("unlocked_at", "")) != "",
		"disk: first-clear persisted to profile.json (unlocked_at stamped)")
	# The unlock toast played on its autoload-owned layer (queued through the run's unlocks).
	var toast: AchievementToast = get_tree().get_first_node_in_group("achievement_toast")
	_check(toast != null, "the achievement toast lives on its autoload CanvasLayer")
	_check(toast != null and toast.shown_total() >= 1,
		"the unlock toast appeared (%d shown so far)" % (toast.shown_total() if toast != null else 0))

	# --- Dialogue volume (2026-07-10): the pool loaded + max_floor gates it -------------
	var dpool := DataLoader.load_domain("dialogue")
	_check(dpool.size() == 112, "the full dialogue pool loaded (%d defs)" % dpool.size())
	# Sophia's stratum reports are the max_floor vocabulary's first consumers: with the
	# whole run walked, the floor-3 report is eligible and a deeper gate stays shut.
	_check(DialogueCore.eligible(dpool["sophia-stratum-3"], SaveManager.state),
		"a max_floor-gated snippet (sophia-stratum-3) is eligible after reaching floor 3")
	_check(not DialogueCore.eval_condition({"counter": "max_floor", "gte": 4}, SaveManager.state),
		"max_floor >= 4 stays shut (never reached)")

	# --- Run-1 victory return: the A3 opening cutscene (dissolve-first-run twin) --------
	# A full clear ends by walking into the codex artifact — Tycho DISSOLVES (not a combat
	# death). So dissolves==1, deaths==0. a3-first-death-alt (dissolves>=1, force_play, 104)
	# claims the one force-play slot: it outranks B3 (92) and the b3-alt fallback is out
	# (runs<6). Its combat-death twin a3-first-death (deaths>=1, 105) stays out (no death
	# yet). Either twin sets `a3`; DialogueCore's flag-suppression silences the other.
	await _settle(5)
	var a3ret: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(a3ret != null, "A3 opening cutscene force-played on the run-1 victory return")
	_check(_panel_id(a3ret) == "a3-first-death-alt",
		"the dissolve-first-run twin played (a3-first-death-alt), not the death variant (%s)" % _panel_id(a3ret))
	if a3ret != null:
		await _drive_panel(a3ret, "a3-first-death-alt")
	_check(bool(SaveManager.state["story"]["flags"].get("a3", false)), "A3 set its flag")
	_check((SaveManager.state["story"]["seen"] as Array).has("a3-first-death-alt"),
		"a3-first-death-alt marked seen")

	# Indicator (moved here): with a3 set, Mara has an unseen SPINE greeting
	# (a-mara-meets) → "!!". Assert it BEFORE talking to her (talking clears the marker).
	_check(str(_scene_node().call("indicator_for_npc", "mara")) == "!!",
		"Mara shows !! for the unseen spine greeting (a-mara-meets)")

	# --- Mara: greeting then ore (greeting-then-ore ordering) ------------------------
	# a-mara-meets (spine 96, flag a3) outranks b1-mara-ore (spine 90, has-ore): the
	# first talk is her greeting, the second is the ore beat that opens the forge.
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "weapons"), "forge locked before B1")
	var greet: DialoguePanel = _scene_node().call("talk_to", "mara")
	_check(_panel_id(greet) == "a-mara-meets", "Mara's first beat is her greeting (a-mara-meets)")
	if greet != null:
		await _drive_panel(greet, "a-mara-meets")
	var b1dlg: DialoguePanel = _scene_node().call("talk_to", "mara")
	_check(_panel_id(b1dlg) == "b1-mara-ore", "Mara's next beat is the ore beat (greeting now seen)")
	if b1dlg != null:
		await _drive_panel(b1dlg, "b1-mara-ore")
	_check(bool(SaveManager.state["story"]["flags"].get("b1", false)), "B1 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "weapons"), "forge unlocked after B1")

	# --- Herzog: B4 opens the build plots (runs==1, so A4's runs>=2 gate keeps it out) ---
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "building"), "build plots locked before B4")
	var b4dlg: DialoguePanel = _scene_node().call("talk_to", "herzog")
	_check(_panel_id(b4dlg) == "b4-herzog-ledger",
		"Herzog offers B4 (gold over the cheapest building cost; A4 needs runs>=2)")
	if b4dlg != null:
		await _drive_panel(b4dlg, "b4-herzog-ledger")
	_check(bool(SaveManager.state["story"]["flags"].get("b4", false)), "B4 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "building"), "build plots unlocked after B4")
	# mark_shown replaced the story dict several times — re-grab the counters ref.
	c = SaveManager.state["story"]["counters"]

	# --- Build in town — via the BuildPanel (B2, 2026-07-09) ---------------------------
	# The wave gold (>= 40) buys Sophia's Study L1; a later day tick must produce. The build
	# transaction is byte-identical, just relocated behind the panel's button (open → build →
	# ESC-close). Prove the panel geometry net + the three level entries + the ESC-close pass.
	var gold_before_build := Ledger.get_amount("gold")
	var bpanel: BuildPanel = _scene_node().call("open_build_panel", "sophias-study")
	_check(bpanel != null, "the plot opens the build panel post-B4")
	await _settle(3)
	var bvp := get_viewport().get_visible_rect().size
	_check((bpanel as Control).size == bvp,
		"build panel spans the viewport (%s == %s)" % [str((bpanel as Control).size), str(bvp)])
	_check(int(bpanel.call("entry_count")) == 3, "build panel shows the building's three level entries")
	_check(str(bpanel.call("shown_building")) == "sophias-study", "build panel shows the pressed building")
	bpanel.call("build")
	var lvl: int = TownCore.building_level(SaveManager.state["town"], "sophias-study")
	_check(lvl == 1, "build panel built the study (level %d)" % lvl)
	_check(Ledger.get_amount("gold") < gold_before_build, "build spent gold")
	# ESC-close pass (2026-07-09): synthesize ui_cancel — the panel closes, the tree unpauses,
	# and the pause menu does NOT open on that press (the panel marks the event handled; the
	# pause menu's own _input bails while the tree is paused).
	var pmenu: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	_esc()
	await _settle(3)
	_check(get_tree().get_first_node_in_group("build_panel") == null, "ESC closed the build panel")
	_check(not get_tree().paused, "ESC-close unpaused the tree")
	_check(pmenu == null or not (pmenu as Control).visible,
		"the pause menu did not open on the ESC-close press")

	# --- Desk still locked; B3 (+ the Food day tick) fire on the NEXT town entry ------
	# B3 (Sophia cracks the shards) is eligible (run 1's 3 boss kills tripped its gate)
	# but A3 outranked it on the last return. It force-plays only once A3 has set its
	# flag (suppressing the a3 twins) — on the next town entry. Prove the desk is still
	# shut, build the Farm, fill the granary, then drive a simulated run to bring B3 and
	# the Food-upkeep day tick (design/food-upkeep.md) in together.
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "tech"), "research desk locked before B3")
	Ledger.add("gold", 40.0, "smoke-grant")
	var fpanel: BuildPanel = _scene_node().call("open_build_panel", "farm")
	fpanel.call("build")
	fpanel.call("close")
	await _settle(3)
	_check(TownCore.building_level(SaveManager.state["town"], "farm") == 1, "farm built (ungated)")

	# --- Planning Table survey (B3, 2026-07-09) — a whole-town read-only sheet -----------
	# One ledger row per building def, INCLUDING the dormant town-walls def (no plot needed
	# for a row). Post-B4 it opens; assert it spans the viewport + shows all 9 buildable
	# defs (town-economy v2, 2026-07-10: +library/observatory/mill/market/cathedral), then close.
	var survey: SurveyPanel = _scene_node().call("open_survey_panel")
	_check(survey != null, "the Planning Table opens the survey post-B4")
	await _settle(3)
	_check((survey as Control).size == get_viewport().get_visible_rect().size,
		"survey panel spans the viewport")
	_check(int(survey.call("row_count")) == 9,
		"survey lists all 9 building defs incl. the new economy roster (%d rows)" % int(survey.call("row_count")))
	survey.call("close")
	await _settle(3)
	var cheats: CheatPanel = get_tree().get_first_node_in_group("cheat_panel")
	_check(cheats != null, "cheat panel available")
	# Buildings now: study + farm (2) → upkeep 2 + 2 = 4; farm L1 makes 3 food; a fat
	# granary covers it → well-fed.
	Ledger.add("food", 50.0, "smoke-grant")
	var food_before := Ledger.get_amount("food")
	var built_count := (SaveManager.state["town"]["buildings"] as Array).size()

	cheats.simulate_run(true)  # sim #1 — trips B3 and runs the Food day tick
	await _settle(10)
	# food = prior stock + farm harvest (3) - upkeep (2 base + 1/building). A simulated
	# run reports exactly 10 rooms cleared = ONE nominal day (SIM_ROOMS_CLEARED), so the
	# flat-tick numbers here stay byte-identical under the room-scaled tick (2026-07-10).
	var expected_food := food_before + 3.0 - (2.0 + 1.0 * float(built_count))
	_check(absf(Ledger.get_amount("food") - expected_food) < 0.001,
		"food = stock + farm harvest - upkeep (%.1f)" % Ledger.get_amount("food"))
	_check(bool(SaveManager.state["town"]["well_fed"]), "well-fed with a full granary")
	_check(bool(_read_slot_from_disk()["town"]["well_fed"]), "disk: well_fed status persisted")

	var b3dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(b3dlg) == "b3-sophia-shards",
		"B3 force-plays on the next town entry (A3 seen; the b3 twins pick the primary)")
	if b3dlg != null:
		await _drive_panel(b3dlg, "b3-sophia-shards")
	_check(bool(SaveManager.state["story"]["flags"].get("b3", false)), "B3 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "tech"), "research desk unlocked after B3")
	c = SaveManager.state["story"]["counters"]

	# --- Research at Sophia's desk ---------------------------------------------------
	# Quarry must be tech-gated first; then drive the REAL panel path end-to-end:
	# arithmetic (prereq) → masonry → quarry buildable. Smoke funds the research.
	# A tech-locked building now OPENS the build panel (it shows the readable why — the
	# research it needs) but its build() refuses; the level stays 0.
	var qlock: BuildPanel = _scene_node().call("open_build_panel", "quarry")
	_check(qlock != null, "a tech-locked building still opens the build panel (the readable why)")
	qlock.call("build")
	_check(TownCore.building_level(SaveManager.state["town"], "quarry") == 0,
		"tech-locked quarry build refused before masonry is researched")
	qlock.call("close")
	await _settle(3)
	var panel: TechPanel = _scene_node().call("open_tech_panel")
	await _settle(3)

	# Star chart (R1) state grammar: arithmetic (no prereq, unfunded) reads AVAILABLE, and
	# masonry reads LOCKED behind it — before any research.
	_check(panel.star_state("med-arithmetic-zero") == &"available",
		"chart: arithmetic reads available before research")
	_check(panel.star_state("med-masonry-arch") == &"locked",
		"chart: masonry reads locked behind arithmetic")

	# Shard turn-in economy (2026-07-06): investing spends KNOWLEDGE ONLY. Knowledge
	# Shards convert to Knowledge only by turning them in at the desk. Run 1's boss and
	# the sim above left shards in the pouch — turn them in and watch Knowledge grow by
	# 5 apiece.
	var shards_held := Ledger.get_amount("knowledge-shards")
	_check(shards_held >= 1.0, "carrying boss knowledge-shards to turn in (%.0f)" % shards_held)
	var kn_before := Ledger.get_amount("knowledge")
	panel.turn_in_shards()
	_check(absf(Ledger.get_amount("knowledge") - (kn_before + shards_held * TechCore.SHARD_KNOWLEDGE_VALUE)) < 0.001,
		"turn-in converted all shards to knowledge at 5 apiece")
	_check(Ledger.get_amount("knowledge-shards") == 0.0, "turn-in emptied the shard pouch")

	# Fund research with Knowledge; park a couple of shards to prove invest never
	# touches them now (the mid-invest auto-convert is gone).
	Ledger.add("knowledge", 100.0, "smoke-grant")
	Ledger.add("gold", 100.0, "smoke-grant")
	Ledger.add("knowledge-shards", 2.0, "smoke-grant")
	var shards_parked := Ledger.get_amount("knowledge-shards")
	panel.select_node("med-arithmetic-zero")
	var kn_pre_invest := Ledger.get_amount("knowledge")
	panel.invest_all()
	_check(Ledger.get_amount("knowledge") < kn_pre_invest, "invest spent Knowledge")
	_check(Ledger.get_amount("knowledge-shards") == shards_parked,
		"invest left Knowledge Shards untouched (no auto-convert)")

	# Quiz gate (2026-07-06): a wrong answer LOCKS the quiz until one run passes.
	panel.begin_read()
	panel.begin_quiz()
	panel.answer(1)  # deliberately wrong
	_check(TechCore.is_quiz_locked(SaveManager.state["tech"], "med-arithmetic-zero"),
		"a wrong quiz answer locks the node's quiz")
	_check(panel.on_locked_screen(), "the panel shows the locked screen (no answer buttons)")
	panel.answer(0)  # locked → no effect, no retry
	_check(not (SaveManager.state["tech"]["researched"] as Array).has("med-arithmetic-zero"),
		"locked quiz can't be answered — still not researched")
	panel.close()
	await _settle(3)

	# A run has to pass before Sophia will hear the answer again. Simulate one (sim #2).
	# Since the dialogue-volume pass (2026-07-10) this return force-plays C1 ("first full
	# clear" — the codex-artifact reveal, full_clears>=1): the a3/b3 twins are suppressed,
	# B5 still needs masonry, and C1 (91) outranks the also-eligible C4 dream (86). It
	# didn't fire earlier because a3 (run-1 return) and B3 (sim #1) claimed those visits'
	# one force-play slot — the spec's one-forced-per-visit backlog behaviour.
	cheats.simulate_run(true)
	await _settle(10)
	var c1dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(c1dlg) == "c1-first-clear",
		"C1 (first-clear artifact reveal) force-plays on the quiz-clear return (%s)" % _panel_id(c1dlg))
	if c1dlg != null:
		await _drive_panel(c1dlg, "c1-first-clear")
	_check(bool(SaveManager.state["story"]["flags"].get("c1", false)), "C1 set its flag")
	# The cheat sims report floor 1 — max_floor is a max() and must NOT regress.
	_check(int(SaveManager.state["story"]["counters"]["max_floor"]) == int(_game.get("run_floors")),
		"max_floor never decreases (floor-1 sims left it alone)")
	_check(not TechCore.is_quiz_locked(SaveManager.state["tech"], "med-arithmetic-zero"),
		"finishing a run clears the quiz lock")

	# Now she'll hear it. Reopen the desk (a fresh town scene after the sim) and answer
	# correctly — arithmetic is still funded from the invest above.
	panel = _scene_node().call("open_tech_panel")
	await _settle(3)
	panel.select_node("med-arithmetic-zero")
	panel.begin_read()
	panel.begin_quiz()
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
	# Both nodes now read RESEARCHED on the chart (finish() routed through TechChartCore).
	_check(panel.star_state("med-arithmetic-zero") == &"researched",
		"chart: arithmetic reads researched after solving")
	_check(panel.star_state("med-masonry-arch") == &"researched",
		"chart: masonry reads researched after the gateway")
	panel.close()
	await _settle(3)
	var researched: Array = SaveManager.state["tech"]["researched"]
	_check(researched.has("med-arithmetic-zero") and researched.has("med-masonry-arch"),
		"both nodes researched through read → quiz → aha (%s)" % str(researched))
	var qpanel: BuildPanel = _scene_node().call("open_build_panel", "quarry")
	qpanel.call("build")
	qpanel.call("close")
	await _settle(3)
	_check(TownCore.building_level(SaveManager.state["town"], "quarry") == 1,
		"masonry unlock makes the quarry buildable")

	# TownHud projection self-consistency: the "+n/d" under the stone column must equal the
	# net stone day-delta computed straight from TownCore.tick with the same live inputs
	# (a quarry produces stone with no stone upkeep → a positive projection).
	var thud2: Node = get_tree().get_first_node_in_group("town_hud")
	var want_stone := float(TownHudCore.day_deltas(TownCore.tick(
		SaveManager.state["town"], DataLoader.load_domain("buildings"),
		Ledger.get_amount("food"))).get("stone", 0.0))
	_check(want_stone > 0.0, "the quarry gives a positive stone projection (%.1f)" % want_stone)
	_check(thud2 != null and absf(float(thud2.call("projection", "stone")) - want_stone) < 0.001,
		"TownHud stone projection matches the computed day delta (%.1f)" % want_stone)

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
	# Economy expectations recomputed from data/exports (rebalance 2026-07-10): the
	# refine cost off the real weapon data, the guaranteed-ore floor off the room export.
	var sword_cost := float(WeaponCore.next_flat_cost(
		DataLoader.load_domain("weapons")["sword"], 0).get("resonance-ore", 0))
	var room_probe: Node = (load("res://scenes/combat/combat_room.tscn") as PackedScene).instantiate()
	var guaranteed_ore := float(room_probe.get("boss_ore")) * float(_game.get("run_floors"))
	room_probe.free()
	Ledger.add("resonance-ore", sword_cost, "smoke-grant")
	var ore_before := Ledger.get_amount("resonance-ore")
	_check(ore_before >= sword_cost + guaranteed_ore,
		"bosses dropped guaranteed ore (have %.0f incl. %.0f granted)" % [ore_before, sword_cost])
	var forge: ForgePanel = _scene_node().call("open_forge_panel")
	await _settle(3)
	# The anvil opens with the EQUIPPED weapon selected (default = sword this early).
	_check(forge.selected_weapon() == str(SaveManager.state["combat"].get("current_weapon", "sword")),
		"anvil opens on the equipped weapon (%s)" % forge.selected_weapon())
	# Clicking a tab switches which weapon lies on the anvil.
	forge.select_weapon("daggers")
	_check(forge.selected_weapon() == "daggers", "tab select puts daggers on the anvil")
	forge.select_weapon("sword")
	forge.upgrade("sword")
	_check(WeaponCore.flat_level(SaveManager.state["combat"], "sword") == 1,
		"forge refined the sword to flat L1")
	_check(Ledger.get_amount("resonance-ore") == ore_before - sword_cost,
		"refine spent the data cost (%.0f ore)" % sword_cost)
	forge.equip("daggers")
	_check(str(SaveManager.state["combat"]["current_weapon"]) == "daggers", "daggers equipped")
	forge.close()
	await _settle(3)

	# --- Etchings: B2 opens the system, then learn a kit before run 2 (design/etchings.md) ---
	# Relocated ahead of run 2 so the run player actually carries the loadout. Thomas's B2
	# is a talk beat (not force_play), so it fires only on talk — and setting b2 here doesn't
	# disturb the later B5 force-play on the death return.
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "etchings"), "etchings locked before B2")
	var thdlg: DialoguePanel = _scene_node().call("talk_to", "thomas")
	_check(_panel_id(thdlg) == "b2-thomas-meditation", "Thomas offers the B2 meditation beat")
	if thdlg != null:
		await _drive_panel(thdlg, "b2-thomas-meditation")
	_check(bool(SaveManager.state["story"]["flags"].get("b2", false)), "B2 set its flag")
	_check(UnlocksCore.is_unlocked(SaveManager.state, "etchings"), "etchings unlocked after B2")
	_check(_scene_node().has_node("MeditationSpot"), "Thomas's meditation spot exists in town")

	var etch: EtchingsPanel = _scene_node().call("open_etchings_panel")
	_check(etch != null, "meditation spot opens the etchings panel once unlocked")
	await _settle(3)
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	_check(EtchingsCore.level_of(etchings, "push") == 1, "ensure_baseline granted Push at L1")
	_check(str(etchings["slots"]["rmb"]) == "push", "Push auto-equipped to the RMB slot")
	# The arms panel shows the four marks (equipped-else-starter + the innate dash).
	_check(etch.site_ability("rmb") == "push", "RMB site shows the equipped Push")
	_check(etch.site_ability("q") == "snare", "Q site shows its Snare starter (dormant)")
	_check(etch.site_ability("spc") == "dash", "SPC site is the innate dash")
	etch.open_menu("spc")  # the dash menu is read-only — no track, no button, no unlock
	_check(not EtchingsCore.is_unlocked(SaveManager.state["combat"]["etchings"], "dash"),
		"opening the dash menu unlocks nothing (it is innate, not an etching)")
	Ledger.add("resonance-dust", 100.0, "smoke-grant")
	var dust_before := Ledger.get_amount("resonance-dust")
	# The unlock costs come off the real data (rebalanced 2026-07-10), not literals.
	var kit_cost := float(EtchingsCore.learn_cost(EtchingsCore.defs()["snare"], 0)
		+ EtchingsCore.learn_cost(EtchingsCore.defs()["shockwave"], 0))
	etch.learn("snare")       # Q — auto-equips to the empty Q slot
	etch.learn("shockwave")   # R — auto-equips to the empty R slot
	etch.equip("q", "snare")  # idempotent (already auto-equipped) — exercises the equip API
	etch.equip("r", "shockwave")
	etchings = SaveManager.state["combat"]["etchings"]
	_check(EtchingsCore.level_of(etchings, "snare") == 1 and str(etchings["slots"]["q"]) == "snare",
		"Snare learned + equipped to Q")
	_check(EtchingsCore.level_of(etchings, "shockwave") == 1 and str(etchings["slots"]["r"]) == "shockwave",
		"Shockwave learned + equipped to R")
	_check(etch.site_ability("q") == "snare" and etch.site_ability("r") == "shockwave",
		"awakening auto-equipped Snare/Shockwave to their sites (no Equip button)")
	_check(absf((dust_before - Ledger.get_amount("resonance-dust")) - kit_cost) < 0.001,
		"learning Snare + Shockwave spent their data unlock costs (%.0f Dust, reason etching)" % kit_cost)
	var edefs := EtchingsCore.defs()
	_check(not EtchingsCore.can_learn(edefs["sentinel"], 999.0, etchings),
		"Sentinel is dormant — not learnable even with Dust")
	etch.learn("sentinel")
	_check(not EtchingsCore.is_unlocked(SaveManager.state["combat"]["etchings"], "sentinel"),
		"learning a dormant etching is a no-op")
	_check((_read_slot_from_disk()["combat"]["etchings"]["unlocked"] as Dictionary).has("shockwave"),
		"disk: the learned etching kit persisted")

	# --- Passive Attunements — "The Body" page (bible, PRD §7.4, 2026-07-10) --------------
	# The etchings panel's second page. The E1 arms page stays the default; the tab swaps to
	# the seven-row attunements sheet. Buy Vitality + Recovery (Dust spent reason "attunement",
	# persisted to disk); prove the buffs ride the next run's player; refuse a broke purchase.
	etch.switch_page("body")
	_check(etch.show_attunements(), "the tab row swaps to the attunements page")
	var dust_pre_attn := Ledger.get_amount("resonance-dust")
	var vit_cost := AttunementsCore.next_cost(AttunementsCore.defs()["vitality"], 0)
	etch.deepen_attunement("vitality")
	_check(etch.attunement_level("vitality") == 1, "Vitality deepened to L1")
	_check(absf((dust_pre_attn - Ledger.get_amount("resonance-dust")) - float(vit_cost)) < 0.001,
		"Vitality L1 spent %d Dust via the Ledger (reason attunement)" % vit_cost)
	etch.deepen_attunement("recovery")
	_check(etch.attunement_level("recovery") == 1, "Recovery deepened to L1")
	_check(int((_read_slot_from_disk()["combat"]["attunements"] as Dictionary).get("vitality", 0)) == 1,
		"disk: the bought attunement persisted")
	# Refused purchase when Dust is short: drain the pouch, a deepen must no-op.
	Ledger.try_spend("resonance-dust", Ledger.get_amount("resonance-dust"), "smoke-drain")
	etch.deepen_attunement("focus")
	_check(etch.attunement_level("focus") == 0, "a deepen with no Dust is refused (level unchanged)")
	Ledger.add("resonance-dust", 20.0, "smoke-grant")  # restore a little for good measure
	etch.close()
	await _settle(3)

	# --- Run 2: death ------------------------------------------------------------
	_game.call("_start_run")
	await _settle(12)
	var player := _find_player()
	_check(player != null, "run 2 spawned a player")
	if player != null:
		_check(player.attack_damage < 25, "daggers kit applied to the run player (damage %d)" % player.attack_damage)
		_check(player.attack_windup < 0.05, "daggers are faster (windup %.3f)" % player.attack_windup)
		# The equipped etchings ride the fresh run player (loaded at spawn).
		_check(player.call("equipped_id", "rmb") == "push", "run player carries Push (RMB)")
		_check(player.call("equipped_id", "q") == "snare", "run player carries Snare (Q)")
		_check(player.call("equipped_id", "r") == "shockwave", "run player carries Shockwave (R)")
		# Passive Attunements ride the run player as the baseline UNDER echoes (PRD §7.4).
		# Vitality L1 raised the max HP by the data value; Resilience/Resonance-Flow unbought
		# so the DR / cooldown-mult hooks read their sane defaults.
		var vit_add := int((AttunementsCore.defs()["vitality"]["levels"][0]["mods"][0] as Dictionary)["add"])
		_check(player.max_health == Player.MAX_HEALTH + vit_add,
			"Vitality L1 raised the run player's max HP to %d" % (Player.MAX_HEALTH + vit_add))
		_check(int(player.get("flat_damage_reduction")) == 0, "no Resilience bought → DR hook is 0")
		_check(absf(float(player.get("ability_cooldown_mult")) - 1.0) < 0.001,
			"no Resonance Flow bought → ability cooldown mult is 1.0")
		# Recovery attunement: one heal via the exact clear-time call site (apply_missing_heal
		# with the room's configured recovery pct) restores % of MISSING HP deterministically.
		var rroom := _scene_node()
		if _scene_file() == "combat_room.tscn" and float(rroom.call("recovery_pct")) > 0.0:
			player.restore_health(60)  # deterministic: 60 of max
			var rpct := float(rroom.call("recovery_pct"))
			var want_hp := 60 + DoorCore.heal_missing(60, player.max_health, rpct)
			rroom.call("apply_missing_heal", rpct)
			_check(player.health == want_hp,
				"Recovery healed %d%% of missing on clear (60 -> %d)" % [int(round(rpct * 100.0)), player.health])
		await _test_abilities_in_run(player)
		_check(_dualuse_checked, "a strata hazard damaged an enemy by direct call (dual-use)")

	# --- ESC quit-gate (Hades rule, design 2026-07-07) on the run-2 combat room ---------
	# A hit closes the gate: the room refuses a menu quit and pause_menu.forfeit() no-ops
	# (still in the run, no state changed). Clearing the room reopens the gate.
	var gate_room := _scene_node()
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	_check(pause != null, "pause menu lives on the HUD layer")
	if player != null and pause != null and _scene_file() == "combat_room.tscn":
		player.take_damage(1)
		await _settle(2)
		_check(not bool(gate_room.call("can_menu_quit")), "a hit closes the room's quit-gate")
		var runs_guard := int(SaveManager.state["story"]["counters"]["runs"])
		pause.forfeit()  # gated → must refuse
		await _settle(2)
		_check(RunState.in_run(), "gated forfeit refused — still in the run")
		_check(_scene_file() == "combat_room.tscn", "gated forfeit left us in the room")
		_check(int(SaveManager.state["story"]["counters"]["runs"]) == runs_guard,
			"gated forfeit touched no counters")
		await _kill_room(gate_room)
		_check(bool(gate_room.call("can_menu_quit")), "clearing the room reopens the quit-gate")
		await _settle(90)  # let the door offer settle so no await dangles when the room frees

	# Room-scaled tick (2026-07-10): the death tick's magnitude derives from the rooms
	# actually cleared this run — compute the expectation from the live state via the
	# REAL core math (run_tick_scale + tick), never a flat-tick literal.
	var death_rooms := int(RunState.run.get("rooms_cleared", 0))
	var stone_pre_death := Ledger.get_amount("stone")
	var death_tick_want := TownCore.tick(
		SaveManager.state["town"], DataLoader.load_domain("buildings"),
		Ledger.get_amount("food"), TownCore.run_tick_scale(death_rooms))
	if player != null:
		player.take_damage(99999)
	await _settle(30)
	_check(_scene_file() == "town.tscn", "death returns to town (got %s)" % _scene_file())
	_check(SaveManager.state["checkpoint"] == null, "death clears the checkpoint too")
	c = SaveManager.state["story"]["counters"]
	_check(int(c["deaths"]) == 1, "death counted")
	# runs: run 1 + sim #1 (B3) + sim #2 (quiz clear) + run 2 death = runs_before + 4.
	_check(int(c["runs"]) == runs_before + 4, "died run still ticks the day")
	_check(Ledger.get_amount("knowledge") >= 1.0, "study produced knowledge on the day tick")
	_check(death_rooms >= 1, "run 2 cleared at least one room before the death (%d)" % death_rooms)
	var stone_want := stone_pre_death + float((death_tick_want["produced"] as Dictionary).get("stone", 0.0))
	_check(absf(Ledger.get_amount("stone") - stone_want) < 0.001,
		"the death tick's quarry stone scales with rooms cleared (%.2f at scale %.1f)" % [
			Ledger.get_amount("stone"), TownCore.run_tick_scale(death_rooms)])
	# Run telemetry (2026-07-10): the death outcome, appended to the SAME redirected file.
	var t2 := _last_telemetry_line(telemetry_path)
	_check(not t2.is_empty() and str(t2.get("outcome", "")) == "death",
		"run-2 telemetry recorded outcome=death (%s)" % (str(t2.get("outcome", "")) if not t2.is_empty() else "missing"))

	# --- Dialogue on the run-2 death return: B5, and the twin-suppression proof ------
	# deaths just hit 1, so a3-first-death's gate (deaths>=1) is finally met — but `a3`
	# is already set (a3-first-death-alt played on the run-1 dissolve return), so
	# a3-first-death is INERT (flag-suppressed). Masonry is researched, so B5 ("the first wall") is the top
	# eligible force-play and claims the slot. This is the twin-suppression proof.
	_check(bool(SaveManager.state["story"]["flags"].get("has-resonance-ore", false)),
		"first-pickup flag set from the run's ore drop")
	var b5: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(b5 != null, "a force-play cutscene fired on the death return")
	_check(_panel_id(b5) == "b5-the-first-wall",
		"B5 played, NOT the suppressed a3-first-death (%s)" % _panel_id(b5))
	if b5 != null:
		await _drive_panel(b5, "b5-the-first-wall")
		_check(not get_tree().paused, "finished cutscene unpauses the game")
		_check(bool(SaveManager.state["story"]["flags"].get("b5", false)), "B5 set its flag")
		_check((SaveManager.state["story"]["seen"] as Array).has("b5-the-first-wall"),
			"B5 marked seen (a spine beat never repeats)")
	c = SaveManager.state["story"]["counters"]
	_check(int(c["full_clears"]) == 3, "full clears: run 1 + two victorious sims")
	_check(int(c["boss_kills"]) >= 2, "boss kills counted (%d)" % int(c["boss_kills"]))
	_check(int(SaveManager.state["codex"]["shards"]) == 3, "codex shards: run 1 + two sims")

	# --- Indicators + character talks on the death return (PRD §7.12) -----------------
	# Tilly has an unseen ARC beat (arc-tilly-eager, runs>=1) → "!". (Mara's greeting is
	# already seen from the run-1 return, so her marker is off — asserted earlier.)
	_check(str(_scene_node().call("indicator_for_npc", "tilly")) == "!",
		"Tilly shows ! for an unseen arc beat")

	# Sophia is now a town NPC (talkable from day 0, ungated). Her queue since the
	# dialogue-volume pass (2026-07-10): C2 ("the question nobody asks" — spine, flag
	# c1+b3) first, then her arc pool, where the new arc-sophia-awe (b3 + runs>=4,
	# priority 58) precedes arc-sophia-method (55) — the awe-then-method arc order.
	_check(_scene_node().has_node("NpcSophia"), "Sophia exists as a town NPC")
	var sdlg: DialoguePanel = _scene_node().call("talk_to", "sophia")
	_check(_panel_id(sdlg) == "c2-sophia-question",
		"Sophia offers C2 first (spine outranks arc; c1 set on the sim-2 return)")
	if sdlg != null:
		await _drive_panel(sdlg, "c2-sophia-question")
	_check(bool(SaveManager.state["story"]["flags"].get("c2", false)), "C2 set its flag")
	var sdlg2: DialoguePanel = _scene_node().call("talk_to", "sophia")
	_check(_panel_id(sdlg2) == "arc-sophia-awe",
		"Sophia's next beat is the new awe arc opener (58 over method's 55)")
	if sdlg2 != null:
		await _drive_panel(sdlg2, "arc-sophia-awe")

	# Tilly's arc beat, then her indicator clears (only a bark remains; barks don't light it).
	var tdlg: DialoguePanel = _scene_node().call("talk_to", "tilly")
	_check(tdlg != null, "Tilly offers her arc beat")
	if tdlg != null:
		await _drive_panel(tdlg, "arc-tilly-eager")
	_check(str(_scene_node().call("indicator_for_npc", "tilly")) == "",
		"the indicator clears once the beat is seen (only a bark left for Tilly)")

	# (Thomas's B2 meditation beat + the etchings kit were exercised BEFORE run 2, above —
	# the run player needs the loadout at spawn.)

	# Talking Herzog: A4 (spine, runs >= 2) outranks the gold-gated contextual; B4 was
	# seen in run 1's return, so A4 is his top beat now.
	var talk: DialoguePanel = _scene_node().call("talk_to", "herzog")
	_check(talk != null, "Herzog has something to say")
	if talk != null:
		await _drive_panel(talk, "a4-herzog-fetch")
		_check(bool(SaveManager.state["story"]["flags"].get("a4", false)),
			"A4 played (spine > contextual, B4 already seen) and set its flag")
		_check(int((SaveManager.state["story"]["talked_to"] as Dictionary).get("herzog", 0)) == 2,
			"talked_to counted (B4 earlier + A4 now)")

	# mark_shown replaced the story section repeatedly — re-grab the counters ref.
	c = SaveManager.state["story"]["counters"]

	# --- Cheat panel (F2 playtest tool) — grant paths mirror the real Ledger ----------
	cheats = get_tree().get_first_node_in_group("cheat_panel")
	_check(cheats != null, "cheat panel lives on the HUD layer")
	if cheats != null:
		var gold_now := Ledger.get_amount("gold")
		cheats.grant("gold", 100.0)
		_check(Ledger.get_amount("gold") == gold_now + 100.0, "cheat grants gold via the Ledger")
		cheats.grant_codex_shard()
		_check(int(SaveManager.state["codex"]["shards"]) == 4, "codex shard cheat applies")

	# --- E2 "The artifact waits" (Phase E, 2026-07-07) --------------------------------
	# The codex puzzle completes at CODEX_SHARDS_MAX; the E2 cutscene then force-plays. Cheat
	# the codex to max (and past it — proving grant_codex_shard clamps), then re-enter town
	# via a sim so E2's town-entry force-play fires. E2 (codex_shards>=6, priority 98) tops
	# the eligible force-plays: a3/b3 twins are flag-suppressed, B5/C1 are seen, and the
	# C4 dream (86) waits its turn behind it (one forced per visit).
	while int(SaveManager.state["codex"]["shards"]) < StoryCore.CODEX_SHARDS_MAX:
		cheats.grant_codex_shard()
	_check(int(SaveManager.state["codex"]["shards"]) == StoryCore.CODEX_SHARDS_MAX,
		"codex reaches the max (%d)" % StoryCore.CODEX_SHARDS_MAX)
	cheats.grant_codex_shard()  # a grant past max
	_check(int(SaveManager.state["codex"]["shards"]) == StoryCore.CODEX_SHARDS_MAX,
		"grant_codex_shard clamps at max (stays %d)" % StoryCore.CODEX_SHARDS_MAX)
	cheats.simulate_run(true)  # re-enter town (its victory codex grant also clamps at max)
	await _settle(10)
	var e2: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(e2) == "e2-artifact-waits",
		"E2 (the artifact waits) force-plays at max codex shards (%s)" % _panel_id(e2))
	if e2 != null:
		await _drive_panel(e2, "e2-artifact-waits")
	_check(bool(SaveManager.state["story"]["flags"].get("e2", false)), "E2 set its flag")

	# --- Town economy v2 (design/town-economy.md, 2026-07-10): Market + Cathedral ------
	# Arithmetic was researched at the desk above, so the Market def is unlocked. Build
	# it, then prove the day tick auto-sells the Food surplus down to the keep-buffer.
	var bdefs := DataLoader.load_domain("buildings")
	_check(TownCore.is_unlocked(bdefs["market"], SaveManager.state["tech"]["researched"]),
		"arithmetic makes the Market buildable")
	Ledger.add("gold", 200.0, "smoke-grant")
	var mktp: BuildPanel = _scene_node().call("open_build_panel", "market")
	mktp.call("build")
	mktp.call("close")
	await _settle(3)
	_check(TownCore.building_level(SaveManager.state["town"], "market") == 1, "market built to L1")
	# Fatten the granary, predict the sale with the REAL core (a simulated run reports
	# 10 rooms = scale 1.0), then tick a day; the sim's own victory grant is +15 gold.
	Ledger.add("food", 200.0, "smoke-grant")
	var sell_want := TownCore.tick(SaveManager.state["town"], bdefs, Ledger.get_amount("food"), 1.0)
	var gold_pre_sale := Ledger.get_amount("gold")
	cheats.simulate_run(true)
	await _settle(10)
	# This town entry's force-play slot goes to C4 (the first dream, codex_shards>=2) —
	# every earlier visit had a higher-priority beat (a3, B3, C1, B5, E2) in front of it.
	# The panel names the second bearer's line "The Woman", never her name (display map).
	var c4dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(c4dlg) == "c4-first-dream",
		"C4 (the first dream) force-plays once the queue in front of it clears (%s)" % _panel_id(c4dlg))
	if c4dlg != null:
		await _drive_panel(c4dlg, "c4-first-dream")
	_check(bool(SaveManager.state["story"]["flags"].get("c4", false)), "C4 set its flag")
	_check(float(sell_want["food_sold"]) > 0.0
		and absf(Ledger.get_amount("gold") - (gold_pre_sale + 15.0 + float(sell_want["gold_from_sale"]))) < 0.001,
		"the day tick auto-sold the surplus (+%.1f gold, reason market-sale)" % float(sell_want["gold_from_sale"]))
	var buffer_want := TownCore.MARKET_KEEP_BUFFER_DAYS * (TownCore.UPKEEP_BASE
		+ TownCore.UPKEEP_PER_BUILDING * float((SaveManager.state["town"]["buildings"] as Array).size()))
	_check(absf(Ledger.get_amount("food") - buffer_want) < 0.001,
		"the granary fell exactly to the keep-buffer (%.1f)" % Ledger.get_amount("food"))
	# Exchange + caravan on the trade page (opened via the public town route; in play it
	# also hangs off the Market BuildPanel's Trade button).
	Ledger.add("stone", 100.0, "smoke-grant")
	Ledger.add("food", 50.0, "smoke-grant")
	var trade: MarketPanel = _scene_node().call("open_market_panel")
	_check(trade != null, "the built market opens its trade page")
	await _settle(3)
	var mcaps := MarketCore.caps(bdefs["market"], 1)
	var xg := Ledger.get_amount("gold")
	var xs := Ledger.get_amount("stone")
	_check(bool(trade.call("buy_stone")), "exchange: bought 1 stone (reason market-exchange)")
	_check(absf(Ledger.get_amount("gold") - (xg - float(mcaps["buy_stone_gold"]))) < 0.001
		and absf(Ledger.get_amount("stone") - (xs + 1.0)) < 0.001,
		"the exchange moved gold->stone at the L1 rate (%d gold each)" % int(mcaps["buy_stone_gold"]))
	var today_deal := str(trade.call("deal_id", 0))
	_check(not today_deal.is_empty(), "a caravan deal is on offer (%s)" % today_deal)
	_check(bool(trade.call("accept_deal", 0)), "the caravan deal accepted once")
	_check(not bool(trade.call("accept_deal", 0)), "a second accept the same day is refused")
	_check(int(_read_slot_from_disk()["town"].get("market_deal_done_day", -1)) > 0,
		"disk: the accepted deal's day persisted")
	trade.call("close")
	await _settle(3)
	# Cathedral: the great-work category rides the normal build panel + transaction.
	Ledger.add("gold", 500.0, "smoke-grant")
	Ledger.add("stone", 60.0, "smoke-grant")
	var catp: BuildPanel = _scene_node().call("open_build_panel", "cathedral")
	catp.call("build")
	catp.call("close")
	await _settle(3)
	_check(TownCore.building_level(SaveManager.state["town"], "cathedral") == 1,
		"cathedral stage 1 raised (great-work builds like any building)")
	# Per-level tech gates: Farm L2 is ungated, L3 waits on the unauthored Three-Field
	# Rotation (dormant forward ref) — the buy refuses, the level holds.
	Ledger.add("gold", 1000.0, "smoke-grant")
	var farmp: BuildPanel = _scene_node().call("open_build_panel", "farm")
	farmp.call("build")  # L1 -> L2, ungated
	_check(TownCore.building_level(SaveManager.state["town"], "farm") == 2, "farm raised to L2 (ungated)")
	farmp.call("build")  # L2 -> L3 must refuse (gate)
	_check(TownCore.building_level(SaveManager.state["town"], "farm") == 2,
		"farm L3 refused — its tech gate names an unauthored node")
	farmp.call("close")
	await _settle(3)
	# Grandfathering: gates guard the PURCHASE only — an already-L3 farm still ticks.
	var fixture := TownCore.set_building({"id": "fix", "buildings": []}, "farm", 3)
	_check(absf(float((TownCore.tick(fixture, bdefs, 0.0)["produced"] as Dictionary).get("food", 0.0)) - 8.0) < 0.001,
		"an already-built L3 farm still ticks its 8 food (grandfathered)")

	# --- Forfeit Run — "like it never happened" (ESC menu, design 2026-07-07) ----------
	# Start a real run, let its first room pay out and clear it, then forfeit: the whole
	# slot rolls back to the portal-entry snapshot (resources, counters, checkpoint), on
	# disk and in memory.
	pause = get_tree().get_first_node_in_group("pause_menu")
	_check(pause != null, "pause menu available for the forfeit test")

	# --- Pause menu — fullscreen geometry net (Slate restyle, 2026-07-07) ---------------
	# It lives on the HUD CanvasLayer, where anchors set in _ready get NO layout pass (the
	# RunHud quirk); open() syncs size to the viewport. Assert it spans the screen, then
	# close and restore state (unpaused, hidden) exactly as it was.
	if pause != null:
		pause.open()
		await _settle(2)
		var pvp: Vector2 = get_viewport().get_visible_rect().size
		_check((pause as Control).size == pvp,
			"pause menu spans the viewport (%s == %s)" % [str((pause as Control).size), str(pvp)])

		# --- Achievements page (schemas §5, 2026-07-11) — opens OVER the pause menu -----
		# The same open-over pattern as Settings: the menu hides without unpausing, the
		# page lists every def (unlocked lit, locked greyed, hidden masked), a progress
		# achievement shows its ticks, and ESC brings the menu back.
		var dlg_progress := AchievementCore.progress_of(
			SaveManager.profile["achievements"], "dialogue-25")
		_check(dlg_progress >= 5,
			"the dialogue_seen progress achievement ticked across the talks (%d)" % dlg_progress)
		pause.open_achievements()  # the same method the button calls
		await _settle(3)
		var apage: AchievementsPanel = get_tree().get_first_node_in_group("achievements_panel")
		_check(apage != null, "the pause menu's Achievements button opens the page")
		_check(not (pause as Control).visible, "the pause menu hid under the achievements page")
		_check(get_tree().paused, "the tree stays paused (the pause menu still owns the pause)")
		if apage != null:
			_check((apage as Control).size == pvp,
				"achievements page spans the viewport (%s == %s)" % [str((apage as Control).size), str(pvp)])
			_check(apage.row_count() == Achievements.defs().size() and apage.row_count() >= 25,
				"the page lists every authored def (%d rows)" % apage.row_count())
			_check(apage.lists_unlocked("first-clear"), "the page lists first-clear as unlocked")
			_check(not apage.lists_unlocked("full-clears-20"),
				"a far-off progress achievement renders locked")
		_esc()
		await _settle(3)
		_check(get_tree().get_first_node_in_group("achievements_panel") == null,
			"ESC closed the achievements page")
		_check((pause as Control).visible, "the pause menu reappeared after the achievements page")
		_check(get_tree().paused, "the pause is still the menu's after the page closed")

		pause.close()
		await _settle(2)
		_check(not (pause as Control).visible and not get_tree().paused,
			"pause menu closed and unpaused after the geometry check")

	# --- Settings — "The quiet page" (SET1, 2026-07-09) --------------------------------------
	# SAFETY: the profile is GLOBAL (the human's real profile.json, shared across their real
	# slots). Snapshot the settings section now and restore it EXACTLY at the end of this block.
	# (Slot writes stay on the throwaway slot 99 as always.)
	var settings_snapshot: Dictionary = (SaveManager.profile["settings"] as Dictionary).duplicate(true)
	# Entry 1: game.open_settings() (the title-screen path uses this with no return target).
	var spanel: SettingsPanel = _game.call("open_settings")
	await _settle(3)
	_check(spanel != null, "open_settings returns a settings panel")
	_check(get_tree().get_first_node_in_group("settings_panel") != null, "settings panel joined its group")
	var svp2: Vector2 = get_viewport().get_visible_rect().size
	_check((spanel as Control).size == svp2,
		"settings panel spans the viewport (%s == %s)" % [str((spanel as Control).size), str(svp2)])
	# A volume drag live-applies: the profile AND the Music bus follow the hand immediately.
	spanel.set_volume("music_volume", 0.5)
	_check(absf(spanel.volume("music_volume") - 0.5) < 0.001, "set_volume moved music to 0.5")
	_check(absf(float(SaveManager.profile["settings"]["music_volume"]) - 0.5) < 0.001,
		"the profile settings followed the slider live")
	var mus_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_check(absf(mus_db - linear_to_db(0.5)) < 0.01,
		"the Music bus followed the slider live (%.2f dB ~= %.2f)" % [mus_db, linear_to_db(0.5)])
	# The window-mode chip writes + applies (headless-guarded — no DisplayServer call, no crash).
	spanel.set_window_mode("fullscreen")
	_check(spanel.window_mode() == "fullscreen", "set_window_mode switched to fullscreen")
	_check(str(SaveManager.profile["settings"]["window_mode"]) == "fullscreen",
		"the profile window_mode updated")
	# ESC closes + persists ONCE on close. Re-read the profile off disk to prove the write.
	_esc()
	await _settle(3)
	_check(get_tree().get_first_node_in_group("settings_panel") == null, "ESC closed the settings panel")
	_check(not get_tree().paused, "ESC-close unpaused the tree (the panel owned the pause in town)")
	var disk_profile := _read_profile_from_disk()
	_check(absf(float((disk_profile["settings"] as Dictionary).get("music_volume", -1.0)) - 0.5) < 0.001,
		"disk: the settings write persisted on close (music_volume 0.5)")
	# RESTORE the human's real settings EXACTLY, and confirm the restore hit disk.
	SaveManager.profile["settings"] = settings_snapshot.duplicate(true)
	SaveManager.save_profile()
	Music.apply_audio_settings()
	var restored := _read_profile_from_disk()
	_check((restored["settings"] as Dictionary) == settings_snapshot,
		"the human's real settings were restored on disk")

	# --- Settings via the pause menu (SET1) — opens OVER the pause without stealing it ---------
	pause = get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	await _settle(2)
	pause.open_settings()  # the same method the Settings button calls
	await _settle(3)
	_check(not (pause as Control).visible, "the pause menu hid when settings opened over it")
	_check(get_tree().paused, "the tree stays paused (the pause menu still owns the pause)")
	_check(get_tree().get_first_node_in_group("settings_panel") != null, "settings opened over the pause menu")
	_esc()
	await _settle(3)
	_check(get_tree().get_first_node_in_group("settings_panel") == null, "ESC closed settings over the pause menu")
	_check((pause as Control).visible, "the pause menu reappeared after settings closed")
	_check(get_tree().paused, "the tree is still paused (settings never owned the pause here)")
	_esc()
	await _settle(3)
	_check(not (pause as Control).visible and not get_tree().paused,
		"a second ESC closed the pause menu and unpaused")

	var gold_pre_run := Ledger.get_amount("gold")
	var runs_pre_run := int(SaveManager.state["story"]["counters"]["runs"])
	_game.call("_start_run")
	await _settle(12)
	_check(_scene_file() == "combat_room.tscn", "forfeit run entered a combat room (got %s)" % _scene_file())
	var fr_room := _scene_node()
	await _kill_room(fr_room)
	await _settle(60)  # let the door offer settle so nothing awaits a freed room on teardown
	_check(Ledger.get_amount("gold") > gold_pre_run, "the forfeit run's room paid out (gold rose)")
	_check(bool(fr_room.call("can_menu_quit")), "the cleared room allows a forfeit")
	pause.forfeit()
	await _settle(30)
	_check(_scene_file() == "town.tscn", "forfeit returns to town (got %s)" % _scene_file())
	# The forfeit rolls the RUN back, but seen dialogue stays seen — the C5 dream chain
	# (one per codex shard after C4, flag-chained c4 -> c5-3 -> c5-4 …) advances on this
	# entry: shards are maxed, c4 is set, so dream 3 takes the slot.
	var c53dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(c53dlg) == "c5-dream-3",
		"the C5 dream series starts on the next entry after C4 (%s)" % _panel_id(c53dlg))
	if c53dlg != null:
		await _drive_panel(c53dlg, "c5-dream-3")
	_check(bool(SaveManager.state["story"]["flags"].get("c5-3", false)), "c5-dream-3 set its chain flag")
	_check(absf(Ledger.get_amount("gold") - gold_pre_run) < 0.001,
		"forfeit rolled gold back to the pre-run value (%.0f)" % Ledger.get_amount("gold"))
	_check(int(SaveManager.state["story"]["counters"]["runs"]) == runs_pre_run,
		"forfeit left the runs counter unchanged")
	_check(SaveManager.state["checkpoint"] == null, "forfeit cleared the checkpoint")
	var fdisk := _read_slot_from_disk()
	_check(absf(float((fdisk["ledger"] as Dictionary).get("gold", 0.0)) - gold_pre_run) < 0.001,
		"disk: forfeit persisted the rolled-back gold")
	_check(int((fdisk["story"]["counters"] as Dictionary)["runs"]) == runs_pre_run,
		"disk: forfeit persisted the unchanged runs counter")
	_check(fdisk.get("checkpoint") == null, "disk: forfeit persisted a null checkpoint")

	# --- Save & Quit from town → slot select → re-enter (round-trip) -------------------
	var runs_saved := int(SaveManager.state["story"]["counters"]["runs"])
	pause.save_and_quit()
	await _settle(5)
	_check(_scene_node() == null, "Save & Quit returned to the slot-select screen")
	_check(Music.current_id == "title", "slot select plays the title track after Save & Quit")
	# Settings entry from the title screen (SET1): the quiet corner opens the page.
	var ssel: Node = get_tree().get_first_node_in_group("slot_select")
	_check(ssel != null and bool(ssel.call("has_settings_entry")),
		"the slot select exposes the corner settings entry")
	ssel.emit_signal("settings_requested")
	await _settle(3)
	var tpanel: SettingsPanel = get_tree().get_first_node_in_group("settings_panel")
	_check(tpanel != null and (tpanel as Control).size == get_viewport().get_visible_rect().size,
		"the title-screen settings entry opens a panel spanning the viewport")
	if tpanel != null:
		tpanel.close()
	await _settle(3)
	_check(not get_tree().paused, "the title settings panel unpaused on close (it owned the pause)")
	_game.call("choose_slot", SMOKE_SLOT)
	await _settle(10)
	_check(_scene_file() == "town.tscn", "re-choosing the slot loads town (got %s)" % _scene_file())
	_check(int(SaveManager.state["story"]["counters"]["runs"]) == runs_saved,
		"counters survived the Save & Quit round-trip (%d)" % int(SaveManager.state["story"]["counters"]["runs"]))
	_check(int(SaveManager.state["story"]["counters"]["max_floor"]) == int(_game.get("run_floors")),
		"max_floor survived the Save & Quit round-trip")
	# The reloaded slot remembers the dream chain (c4/c5-3 flags round-tripped): this
	# fresh town entry force-plays the NEXT dream in the series.
	var c54dlg: DialoguePanel = get_tree().get_first_node_in_group("dialogue_panel")
	_check(_panel_id(c54dlg) == "c5-dream-4",
		"the C5 chain resumes across the save round-trip (%s)" % _panel_id(c54dlg))
	if c54dlg != null:
		await _drive_panel(c54dlg, "c5-dream-4")

	SaveManager.delete_slot(SMOKE_SLOT)
	if FileAccess.file_exists(telemetry_path):
		DirAccess.remove_absolute(telemetry_path)  # tidy up the redirected telemetry temp file
	_restore_profile_file()
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
	# 5 rooms/floor → each floor has 3 ordinary door offers, enough for the door pity to
	# guarantee a Reprieve door (design/run-structure.md) so the Wellspring path is hit.
	_game.set("rooms_min", 5)
	_game.set("rooms_max", 5)
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
	var rooms_before_quit := int(RunState.run.get("rooms_cleared", 0))
	# The door plan is NOT in the checkpoint — it must regenerate identically from the
	# run seed when the resumed floor's first room loads (design/run-structure.md).
	var plan_before := RunState.door_plan.duplicate(true)
	_check(not (plan_before.get("offers", []) as Array).is_empty(), "floor 2 has a door plan before the quit")
	_check(echoes_before.size() >= 1, "picks exist before the quit (floor 1 echo beats)")
	_game.queue_free()
	await _settle(5)
	_boot_game()
	await _settle(5)
	_check(_scene_node() == null, "rebooted game waits at slot select")
	# The S2 slot-select screen: geometry net (spans the viewport) + the three plaques.
	var ss: Node = get_tree().get_first_node_in_group("slot_select")
	var svp := get_viewport().get_visible_rect().size
	_check(ss is Control and (ss as Control).size == svp,
		"slot select spans the viewport (%s == %s)" % [
			str((ss as Control).size) if ss is Control else "(none)", str(svp)])
	_check(ss != null and ss.call("plaque_count") == 3, "slot select shows three saga plaques")
	# Two-step delete state machine (no disk deletion): arming, then disarm-without-continue.
	ss.call("on_delete", 2)
	_check(int(ss.call("armed_slot")) == 2, "the ✕ arms its slot (no delete on the first press)")
	ss.call("on_plaque", 2)
	_check(int(ss.call("armed_slot")) == -1
			and get_tree().get_first_node_in_group("slot_select") != null,
		"clicking the armed plaque's own body disarms without continuing")
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
	_check(RunState.door_plan == plan_before, "the floor-2 door plan regenerates identically on resume")
	# Room-scaled tick (2026-07-10): the rooms-cleared counter rides the checkpoint
	# (it lives on the run dict), so the eventual day tick pays the WHOLE run's rooms.
	_check(int(RunState.run.get("rooms_cleared", -1)) == rooms_before_quit,
		"rooms-cleared counter survives the quit (%d)" % rooms_before_quit)


## Play one room to completion: clear it (or drive its Wellspring), take any echo
## offer, then walk out through a door (design/run-structure.md). On the final boss the
## run ends here (town swap in flight).
func _play_room() -> void:
	await _settle(12)
	if _scene_file() != "combat_room.tscn":
		return
	var room := _scene_node()
	var boss: bool = room.get("kind") == RunFlow.KIND_BOSS
	var well := get_tree().get_first_node_in_group("wellspring")
	if well != null:
		await _drive_reprieve(room, well)
	elif boss:
		await _clear_boss(room)
	else:
		await _clear_combat(room)
	# Statistics invariant (2026-07-07): the final boss's kill is counted in MEMORY (via
	# final_boss_killed) the instant it dies, but is NOT yet on disk — no checkpoint is
	# written after the last floor start, and the pedestal hasn't been entered. Quitting in
	# this window would discard the kill; the resume re-earns it exactly once. Prove disk
	# lags memory here (RunState is still in_run — the run finishes at the artifact, below).
	if boss and RunState.is_final_boss() and not _final_boss_disk_checked:
		_final_boss_disk_checked = true
		var mem_bk := int(SaveManager.state["story"]["counters"]["boss_kills"])
		var disk_bk := int((_read_slot_from_disk()["story"]["counters"] as Dictionary)["boss_kills"])
		_check(disk_bk < mem_bk,
			"final-boss kill in memory, not yet on disk (disk %d < mem %d)" % [disk_bk, mem_bk])
	if not RunState.in_run():
		return  # the final boss — run over, town swap deferred
	await _settle(8)
	var echo_panel: Node = get_tree().get_first_node_in_group("echo_offer")
	if boss and not _postboss_echo_tested:
		_postboss_echo_tested = true
		_check(echo_panel != null, "guaranteed post-boss echo offer fired")
	if echo_panel != null:
		# The O1 offer panel (2026-07-09): the marks bloom over the whole dimmed screen — the
		# geometry net (it spans the viewport) + one mark per offered echo (pool full → OFFER_SIZE).
		if not _echo_geom_checked:
			_echo_geom_checked = true
			var vp := get_viewport().get_visible_rect().size
			_check(echo_panel.get("size") == vp,
				"echo offer panel spans the viewport (%s vs %s)" % [echo_panel.get("size"), vp])
			_check(int(echo_panel.call("mark_count")) == EchoCore.OFFER_SIZE,
				"echo offer shows one mark per offered echo (%d)" % int(echo_panel.call("mark_count")))
		echo_panel.call("pick", 0)  # take the offered echo, like a player
		await _settle(6)
		# The RunHud echo shelf rebuilt on the pick — one tile per folded pick.
		if not _shelf_checked:
			_shelf_checked = true
			var hud: Node = room.get("_hud")
			var want := HudCore.fold_echoes(RunState.echoes, EchoCore.defs()).size()
			_check(hud != null and int(hud.call("echo_tile_count")) == want,
				"echo shelf tile count matches the folded pick count (%d)" % want)
	await _walk_out(room)


## A normal combat room. On the FIRST one, override the incoming door to a Dust cache so
## the clear pays an unconfounded cache (dust has no other combat source) — exercises
## game.gd's door-reward payment deterministically.
func _clear_combat(room: Node) -> void:
	if not _multiwave_checked:
		_multiwave_checked = true
		_check(int(room.call("wave_total")) >= 2,
			"combat room runs multiple waves (%d)" % int(room.call("wave_total")))
		# RunHud info chip carries the wave segment while the multi-wave room is uncleared.
		var hud: Node = room.get("_hud")
		_check(hud != null and "Wave" in str(hud.call("chip")),
			"info chip shows the Wave segment (%s)" % (str(hud.call("chip")) if hud != null else "no hud"))
		# Geometry regression net: the HUD must actually span the viewport — anchors set
		# in a Control's own _ready under a CanvasLayer get NO layout pass (size stays
		# 0,0 and every size-anchored element draws off-screen; caught live 2026-07-07).
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_check(hud is Control and (hud as Control).size == vp,
			"RunHud spans the viewport (%s == %s)" % [
				str((hud as Control).size) if hud is Control else "?", str(vp)])
		# Strata (design/dungeon-strata.md, 2026-07-10): the room applied its floor's
		# environment (per-instance, so the local Env sub-resource carries the floor's
		# background colour), and the number of spawned hazards equals the pure/seeded
		# plan recomputed here (deterministic in the run seed + room coords).
		if not _strata_checked:
			_strata_checked = true
			var fnum := int(room.get("floor_num"))
			var prof: Dictionary = DataLoader.load_domain("floors").get(str(fnum), {})
			var want_bg: Color = StrataCore.environment_of(prof)["background_color"]
			_check(room.call("environment_background") == want_bg,
				"combat room applied floor %d's environment background (%s)" % [fnum, want_bg])
			var planned: Array = room.call("planned_hazards")
			_check(get_tree().get_nodes_in_group("hazards").size() == planned.size(),
				"spawned hazard count matches the seeded plan (%d)" % planned.size())
			_check(int(room.call("hazard_count")) == planned.size(),
				"the room's hazard_count agrees with its plan")
	if not _dust_tested:
		_dust_tested = true
		var floor_now := int(RunState.run["floor"])
		RunState.pending_door = {"sigil": "dust", "peril": false}
		var dust_before := Ledger.get_amount("resonance-dust")
		await _kill_room(room)
		# Mirror game.gd._pay_cache exactly: dust/ore payouts round after the attunement
		# find-rate mult (matters now that cache bases can be fractional, 2026-07-10).
		var want: float = roundf(float(DoorCore.cache_reward("dust", floor_now, false)["amount"])
			* AttunementsCore.find_rate_mult(
				SaveManager.state["combat"].get("attunements", {}), AttunementsCore.defs()))
		_check(absf(Ledger.get_amount("resonance-dust") - (dust_before + want)) < 0.001,
			"dust door paid its cache on clear (+%.0f)" % want)
		# The kills dropped gold → the RunHud pickup strip is now visible (fades after ~3s).
		if not _pickup_checked:
			_pickup_checked = true
			var hud: Node = room.get("_hud")
			_check(hud != null and bool(hud.call("pickup_visible")),
				"RunHud pickup strip lit up on the run's resource drops")
		return
	await _kill_room(room)


## A boss room. Floor 1 = the data-driven Den-Warden (design/bosses/floor-1-boss.md):
## drive its phase machinery once, ending with it vulnerable in phase 2 so the original
## heal-valve wound+kill rides the same fight. The first later-floor boss room asserts
## the placeholder fallback once. On the FIRST boss room, wound the player to a known HP
## and assert the boss kill repairs 30% of the missing amount (the auto floor-boss valve).
func _clear_boss(room: Node) -> void:
	var player := _find_player()
	if not _den_warden_tested and int(room.get("floor_num")) == 1 and player != null:
		_den_warden_tested = true
		await _drive_den_warden(room, player)
	elif not _placeholder_boss_checked and int(room.get("floor_num")) == 2:
		_placeholder_boss_checked = true
		var hud2: Node = room.get("_hud")
		_check(str(room.get("boss_id")) == "boss-placeholder",
			"floor-2 boss room falls back to the placeholder boss (%s)" % str(room.get("boss_id")))
		_check(hud2 != null and str(hud2.call("boss_label")) == "FLOOR 2 — BOSS",
			"placeholder boss keeps the generic bar label (%s)"
			% (str(hud2.call("boss_label")) if hud2 != null else "no hud"))
	if player != null and not _boss_heal_tested:
		_boss_heal_tested = true
		var hud: Node = room.get("_hud")
		_check(hud != null and bool(hud.call("boss_bar_visible")),
			"RunHud boss bar visible during the boss fight")
		player.restore_health(60)  # deterministic: 40 missing of 100
		var want: int = 60 + DoorCore.heal_missing(60, player.max_health, DoorCore.BOSS_HEAL_PCT)
		await _kill_room(room)
		await _settle(12)
		_check(player.health == want, "boss kill healed 30%% of missing (60 -> %d, want %d)" % [player.health, want])
		_check(hud != null and not bool(hud.call("boss_bar_visible")),
			"RunHud boss bar gone after the boss dies")
		return
	await _kill_room(room)
	await _settle(12)


## Floor 1's boss room: assert the data-driven spawn (the def's name on the bar, a clean
## no-escort arena, dormant vent plates), then damage the boss across the 50% threshold
## and prove the reconfiguration beat — invulnerable, damage cleanly ignored, resolving
## on its own into phase 2. Ends with the boss VULNERABLE in phase 2; the caller's
## heal-valve wound + kill follows immediately (before the first burrow can fire).
func _drive_den_warden(room: Node, player: Player) -> void:
	await _settle(6)
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() == 1, "the Den-Warden fights alone — no escorts (%d enemies)" % enemies.size())
	if enemies.is_empty() or not (enemies[0] is EnemyBoss):
		_check(false, "floor-1 boss room spawned an EnemyBoss with a def")
		return
	var boss: EnemyBoss = enemies[0]
	_check(boss.has_def(), "the floor-1 boss runs on its data def")
	_check(str(room.get("boss_id")) == "den-warden",
		"floor-1 boss_id is den-warden (%s)" % str(room.get("boss_id")))
	var hud: Node = room.get("_hud")
	_check(hud != null and str(hud.call("boss_label")) == "The Den-Warden",
		"boss bar shows the def's name (%s)"
		% (str(hud.call("boss_label")) if hud != null else "no hud"))
	# Arena vents: real vent-plate hazards at the def's spots, DORMANT through phase 1.
	var vents := get_tree().get_nodes_in_group("hazards")
	var want_vents := (DataLoader.load_domain("bosses")["den-warden"]["arena_vents"] as Array).size()
	_check(vents.size() == want_vents, "the arena spawned the def's vent plates (%d)" % vents.size())
	var all_dormant := not vents.is_empty()
	for v in vents:
		if not bool(v.get("dormant")):
			all_dormant = false
	_check(all_dormant, "arena vents sit dormant in phase 1")
	# The phase drive below takes real seconds; heal to full so a stray boss hit can't
	# end the smoke (exact HP is re-pinned by the caller before the heal-valve assert).
	player.restore_health(player.max_health)
	# Damage to just ABOVE 50% — the boundary is AT 50%, so this must stay phase 1.
	var hp_above := int(ceilf(float(boss.max_hp) * 0.5)) + 1
	boss.take_damage(boss.current_hp() - hp_above)
	_check(boss.phase_index() == 0 and not boss.is_invulnerable(),
		"51%% HP: still phase 1 and vulnerable (hp %d)" % boss.current_hp())
	# Cross the threshold to ~49% -> the reconfiguration beat starts (invulnerable).
	boss.take_damage(7)
	_check(boss.is_invulnerable(), "the 50% crossing starts the reconfiguration beat (invulnerable)")
	var hp_locked := boss.current_hp()
	boss.take_damage(99)
	_check(boss.current_hp() == hp_locked, "damage during the reconfiguration beat is cleanly ignored")
	# The beat resolves on its own in bounded time (reconfigure_s), landing in phase 2.
	var guard := 0
	while boss.is_invulnerable() and guard < 40:
		guard += 1
		await _settle(6)
	_check(not boss.is_invulnerable(), "the reconfiguration beat ended on its own")
	_check(boss.phase_index() == 1, "the boss is in phase 2 after the beat (%d)" % boss.phase_index())


## A reprieve room (no wave). Wound the player, touch the Wellspring, assert 40% heal.
func _drive_reprieve(_room: Node, well: Node) -> void:
	var player := _find_player()
	if player != null and not _wellspring_tested:
		_wellspring_tested = true
		player.restore_health(60)  # deterministic: 40 missing of 100
		var want: int = 60 + DoorCore.heal_missing(60, player.max_health, DoorCore.WELLSPRING_HEAL_PCT)
		var wp: Vector3 = (well as Node3D).global_position
		(player as Node3D).global_position = Vector3(wp.x, 0.1, wp.z)  # walk into it (as with doors)
		await _settle(20)
		_check(player.health == want, "Wellspring healed 40%% of missing (60 -> %d, want %d)" % [player.health, want])


## Kill every enemy currently on the field (one wave's worth).
func _kill_wave() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(99999)


## Fully clear a (possibly multi-wave) combat/boss room: kill whatever is on the field,
## wait through each inter-wave beat + spawn telegraph, repeat until the room reports
## cleared. Watchdog-bounded so a stuck room fails loudly downstream, not by hanging.
func _kill_room(room: Node) -> void:
	var guard := 0
	# is_instance_valid guard: the death run's town swap can free the room while this
	# loop is mid-_settle — resuming into room.call() would then hit a freed instance.
	while is_instance_valid(room) and not bool(room.call("is_cleared")) and guard < 80:
		guard += 1
		if get_tree().get_nodes_in_group("enemies").is_empty():
			await _settle(10)  # mid inter-wave beat / spawn telegraph — wait for bodies
			continue
		_kill_wave()
		await _settle(6)


## Walk out through a door (or the plain boss exit). Checks the offer shape once, then
## picks a door — preferring a Reprieve door until the Wellspring is tested, otherwise
## a real fight (never Reprieve/Boss when a loot/echo door is on offer).
func _walk_out(_room: Node) -> void:
	await _settle(90)  # doors / the exit / the artifact open after the respawn_delay beat
	var player := _find_player()
	# Final chamber (2026-07-07): the codex artifact is the ONLY way out — walk into it
	# (Wellspring-style), which dissolves Tycho and ends the run victorious.
	var artifact := get_tree().get_first_node_in_group("codex_artifact")
	if artifact != null:
		if player != null:
			var ap: Vector3 = (artifact as Node3D).global_position
			(player as Node3D).global_position = Vector3(ap.x, 0.1, ap.z)
		await _settle(20)
		return
	var doors := get_tree().get_nodes_in_group("door_portal")
	if doors.is_empty():
		if player != null:
			(player as Node3D).global_position = Vector3(0, 0.1, -23)  # the plain boss exit
		await _settle(20)
		return
	if not _door_offer_checked:
		_door_offer_checked = true
		_check(doors.size() >= 1 and doors.size() <= 2, "door offer shows 1-2 doors (%d)" % doors.size())
		if doors.size() == 2:
			var s0 := str((doors[0].get_meta("door") as Dictionary)["sigil"])
			var s1 := str((doors[1].get_meta("door") as Dictionary)["sigil"])
			_check(s0 != s1, "the two doors show distinct sigils (%s / %s)" % [s0, s1])
	var chosen := _choose_door(doors)
	if player != null:
		var pos: Vector3 = (chosen as Node3D).global_position
		pos.y = 0.1
		(player as Node3D).global_position = pos
	await _settle(20)


func _choose_door(doors: Array) -> Node:
	if not _wellspring_tested:
		for d in doors:
			if str((d.get_meta("door") as Dictionary)["sigil"]) == DoorCore.SIGIL_REPRIEVE:
				return d
	for d in doors:
		var sig := str((d.get_meta("door") as Dictionary)["sigil"])
		if sig != DoorCore.SIGIL_REPRIEVE and sig != DoorCore.SIGIL_BOSS:
			return d
	return doors[0]


## Re-read the smoke slot straight off disk (bypassing SaveManager.state) — used to
## prove StoryState's counter writes are persisted, not just held in memory.
func _read_slot_from_disk() -> Dictionary:
	var f := FileAccess.open(SaveManager.slot_path(SMOKE_SLOT), FileAccess.READ)
	if f == null:
		_check(false, "could not re-read the slot file from disk")
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Put the human's REAL profile.json back exactly as the smoke found it: byte-identical
## bytes, or gone if it did not exist. Runs at the single exit point (ok AND fail path);
## asserts the restore so a failed write can never pass silently.
func _restore_profile_file() -> void:
	var path := SaveManager.profile_path()
	if _profile_existed:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			_check(false, "PROFILE RESTORE FAILED — could not open %s for write" % path)
			return
		f.store_buffer(_profile_bytes)
		f = null  # flush + close before the re-read below
		_check(FileAccess.get_file_as_bytes(path) == _profile_bytes,
			"the human's real profile.json restored BYTE-EXACTLY")
	else:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		_check(not FileAccess.file_exists(path),
			"profile.json removed again (it did not exist before the smoke)")


## Re-read the profile straight off disk (bypassing SaveManager.profile) — proves the settings
## write-on-close persisted (SET1). The profile is GLOBAL, so callers snapshot + restore it.
func _read_profile_from_disk() -> Dictionary:
	var f := FileAccess.open(SaveManager.profile_path(), FileAccess.READ)
	if f == null:
		_check(false, "could not re-read the profile file from disk")
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Parse the LAST line of the (redirected) telemetry JSONL file as a Dictionary, or
## {} if the file is missing/empty/unparseable. Used to prove each run/forfeit
## appends its own record (2026-07-10).
func _last_telemetry_line(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var lines := f.get_as_text().split("\n", false)
	if lines.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(lines[lines.size() - 1])
	return parsed if parsed is Dictionary else {}


## Advance a dialogue panel through every line of the given snippet id, then settle.
func _drive_panel(panel: DialoguePanel, id: String) -> void:
	var lines: int = ((DataLoader.load_domain("dialogue")[id]["scene"] as Dictionary)["lines"] as Array).size()
	for i in lines:
		panel.advance()
	await _settle(3)


## The snippet id a dialogue panel is currently playing ("none" if the panel is null).
func _panel_id(panel: DialoguePanel) -> String:
	if panel == null:
		return "none"
	return str((panel.get("_def") as Dictionary).get("id", ""))


## Drive two etching casts against controlled dummy enemies and assert concrete effects:
## Snare slows a nearby enemy (public slow_factor < 1), Shockwave force-staggers an ARMORED
## Brute (the only thing that bypasses stagger_time == 0). Each also proves the cooldown
## engaged (a second immediate cast is refused).
func _test_abilities_in_run(player: Player) -> void:
	var room := _scene_node()
	var ppos: Vector3 = (player as Node3D).global_position
	# Snare (Q): a dummy inside the field radius gets slowed.
	var dummy: EnemyDummy = load("res://scenes/combat/enemy_dummy.tscn").instantiate()
	room.add_child(dummy)
	dummy.target = player
	(dummy as Node3D).global_position = ppos + Vector3(1.2, 0, 0)
	await _settle(2)
	_check(dummy.slow_factor == 1.0, "enemy starts unsnared (slow_factor 1.0)")
	_check(player.call("try_cast", "q"), "Snare (Q) cast fired")
	await _settle(4)
	_check(dummy.slow_factor < 1.0, "Snare field slowed the nearby enemy (slow_factor %.2f)" % dummy.slow_factor)
	_check(not player.call("try_cast", "q"), "Snare on cooldown — a second immediate cast is refused")
	# Shockwave (R): force-stagger an ARMORED Brute (stagger_time 0 → only Shockwave does this).
	var brute: EnemyDummy = load("res://scenes/combat/enemy_dummy.tscn").instantiate()
	room.add_child(brute)
	brute.target = player
	(brute as Node3D).global_position = ppos + Vector3(2.0, 0, 0)
	await _settle(2)
	_check(brute.stagger_time == 0.0, "the Brute is armored (stagger_time 0)")
	_check(player.call("try_cast", "r"), "Shockwave (R) cast fired")
	await _settle(1)
	_check(brute.call("is_staggered"), "Shockwave force-staggered the armored Brute")
	_check(not player.call("try_cast", "r"), "Shockwave on cooldown — a second immediate cast is refused")

	# Strata hazard dual-use (design/dungeon-strata.md, 2026-07-10): a hazard damages
	# enemies too (hurts_enemies). Drive it by DIRECT call so the smoke never waits on a
	# multi-second cycle: drop a dummy far from the player, spawn a vent plate on it, and
	# call damage_area — the dummy must take damage, the player (10m off) must not.
	if not _dualuse_checked:
		_dualuse_checked = true
		var victim: EnemyDummy = load("res://scenes/combat/enemy_dummy.tscn").instantiate()
		room.add_child(victim)
		victim.target = player
		var vpos := ppos + Vector3(10.0, 0, 0)
		(victim as Node3D).global_position = vpos
		await _settle(2)
		var vhp_before := int(victim.call("current_hp"))
		var php_before := player.health
		var hz: Hazard = Hazard.new()
		room.add_child(hz)
		(hz as Node3D).global_position = vpos
		hz.configure(DataLoader.load_domain("hazards")["vent-plate"], 0)
		hz.target = player
		hz.damage_area(vpos, float(DataLoader.load_domain("hazards")["vent-plate"]["radius"]))
		await _settle(2)
		_check(int(victim.call("current_hp")) < vhp_before or not is_instance_valid(victim),
			"the vent plate damaged the enemy on it (dual-use)")
		_check(player.health == php_before, "the distant player took no hazard damage")
		if is_instance_valid(hz):
			hz.queue_free()
		if is_instance_valid(victim):
			victim.queue_free()

	await _test_heal_and_etch_echoes(player, room)


## Healing + etching-mod echoes (2026-07-10): apply via the REAL EchoCore path, then drive the
## real hooks. Heal-on-kill through the actual enemy.died → room._on_enemy_died path (amplified by
## Deep Repair's heal_received_mult); salvage through a real in-run ore pickup; the etching-mod
## handles moved on the live player and quick-channel folded onto the attunement cooldown mult.
func _test_heal_and_etch_echoes(player: Player, room: Node) -> void:
	if _scene_file() != "combat_room.tscn":
		return
	var defs := EchoCore.defs()
	# Etching mods: ability_damage_mult set; quick-channel folds onto the current cooldown mult.
	EchoCore.apply_to_player(player, defs["resonant-edge"])
	_check(absf(float(player.get("ability_damage_mult")) - 1.25) < 0.001,
		"resonant-edge set ability_damage_mult (%.3f)" % float(player.get("ability_damage_mult")))
	var cd_before := float(player.get("ability_cooldown_mult"))
	EchoCore.apply_to_player(player, defs["quick-channel"])
	_check(absf(float(player.get("ability_cooldown_mult")) - cd_before * 0.85) < 0.001,
		"quick-channel folded ability_cooldown_mult multiplicatively (%.3f)" % float(player.get("ability_cooldown_mult")))
	# Healing hooks.
	EchoCore.apply_to_player(player, defs["menders-rhythm"])
	EchoCore.apply_to_player(player, defs["deep-repair"])
	_check(float(player.get("heal_on_kill_pct")) > 0.0, "menders-rhythm set heal_on_kill_pct")
	_check(absf(float(player.get("heal_received_mult")) - 1.5) < 0.001, "deep-repair set heal_received_mult 1.5")
	# Kill an enemy through the real path (died → room._on_enemy_died heals % of missing, ×deep-repair).
	var kd: EnemyDummy = load("res://scenes/combat/enemy_dummy.tscn").instantiate()
	room.add_child(kd)
	kd.target = player
	(kd as Node3D).global_position = (player as Node3D).global_position + Vector3(3.0, 0, 0)
	kd.died.connect(Callable(room, "_on_enemy_died").bind(kd))
	await _settle(2)
	player.restore_health(50)
	var hp0 := player.health
	var kbase := DoorCore.heal_missing(hp0, player.max_health, float(player.get("heal_on_kill_pct")))
	var kmult := float(player.get("heal_received_mult"))
	var kwant := mini(player.max_health, hp0 + int(round(float(kbase) * kmult)))
	kd.take_damage(99999)  # kill → real _on_enemy_died heal-on-kill path
	await _settle(2)
	_check(player.health == kwant,
		"heal-on-kill fired and deep-repair amplified it (%d -> %d, want %d)" % [hp0, player.health, kwant])
	# Salvage: an in-run ore pickup heals % of missing (room subscribes to resource_changed).
	EchoCore.apply_to_player(player, defs["salvage"])
	player.restore_health(50)
	var shp := player.health
	var sbase := DoorCore.heal_missing(shp, player.max_health, float(player.get("heal_on_pickup_pct")))
	var swant := mini(player.max_health, shp + int(round(float(sbase) * kmult)))
	Ledger.add("resonance-ore", 1.0, "run-drop")  # a real in-run pickup fires resource_changed
	await _settle(2)
	_check(player.health == swant, "salvage healed on an ore pickup (%d -> %d, want %d)" % [shp, player.health, swant])


## Synthesize an ESC (ui_cancel) press through the viewport — drives the panel ESC-close pass.
func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)


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
