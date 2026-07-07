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

# Door-choice coverage flags — each mechanic is exercised once, then skipped (below).
var _door_offer_checked: bool = false
var _dust_tested: bool = false
var _wellspring_tested: bool = false
var _boss_heal_tested: bool = false
var _postboss_echo_tested: bool = false
var _multiwave_checked: bool = false  # a real combat room ran >1 wave (2026-07-06)
var _final_boss_disk_checked: bool = false  # the statistics invariant window (2026-07-07)


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
	_check(_door_offer_checked, "a door offer with 1-2 distinct sigils was shown")
	_check(_dust_tested, "a paying door granted its cache on clear (reason door-reward)")
	_check(_wellspring_tested, "a reprieve door's Wellspring healed 40% of missing")
	_check(_boss_heal_tested, "a boss kill healed 30% of missing")
	_check(_postboss_echo_tested, "the guaranteed post-boss echo offer fired")
	await _settle(30)
	_check(_scene_file() == "town.tscn", "victory returns to town (got %s)" % _scene_file())
	_check(SaveManager.state["checkpoint"] == null, "run over — checkpoint cleared")
	var c: Dictionary = SaveManager.state["story"]["counters"]
	_check(int(c["runs"]) == runs_before + 1, "runs counter ticked (%d)" % int(c["runs"]))
	_check(int(c["boss_kills"]) >= 1, "boss kill counted (%d)" % int(c["boss_kills"]))
	_check(int(c["full_clears"]) == 1, "full clear counted")
	# The full clear ended by walking into the codex artifact — Tycho DISSOLVED (a full-clear
	# return), which is a separate counter from a combat death (2026-07-07).
	_check(int(c["dissolves"]) == 1, "dissolve counted at the codex artifact")
	_check(int(c["deaths"]) == 0, "the full-clear dissolve is NOT a combat death")
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
	_check(int(disk_c["dissolves"]) == 1, "disk: dissolves counter persisted")
	_check(int(on_disk["codex"]["shards"]) == 1, "disk: codex shard persisted")
	_check(int(on_disk["meta"]["runs"]) == runs_before + 1, "disk: meta.runs mirror persisted")

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

	# --- Build in town ---------------------------------------------------------------
	# The wave gold (>= 40) buys Sophia's Study L1; a later day tick must produce.
	var gold_before_build := Ledger.get_amount("gold")
	_scene_node().call("_try_build", "sophias-study")
	var lvl: int = TownCore.building_level(SaveManager.state["town"], "sophias-study")
	_check(lvl == 1, "build plot built the study (level %d)" % lvl)
	_check(Ledger.get_amount("gold") < gold_before_build, "build spent gold")

	# --- Desk still locked; B3 (+ the Food day tick) fire on the NEXT town entry ------
	# B3 (Sophia cracks the shards) is eligible (run 1's 3 boss kills tripped its gate)
	# but A3 outranked it on the last return. It force-plays only once A3 has set its
	# flag (suppressing the a3 twins) — on the next town entry. Prove the desk is still
	# shut, build the Farm, fill the granary, then drive a simulated run to bring B3 and
	# the Food-upkeep day tick (design/food-upkeep.md) in together.
	_check(not UnlocksCore.is_unlocked(SaveManager.state, "tech"), "research desk locked before B3")
	Ledger.add("gold", 40.0, "smoke-grant")
	_scene_node().call("_try_build", "farm")
	_check(TownCore.building_level(SaveManager.state["town"], "farm") == 1, "farm built (ungated)")
	var cheats: CheatPanel = get_tree().get_first_node_in_group("cheat_panel")
	_check(cheats != null, "cheat panel available")
	# Buildings now: study + farm (2) → upkeep 2 + 2 = 4; farm L1 makes 3 food; a fat
	# granary covers it → well-fed.
	Ledger.add("food", 50.0, "smoke-grant")
	var food_before := Ledger.get_amount("food")
	var built_count := (SaveManager.state["town"]["buildings"] as Array).size()

	cheats.simulate_run(true)  # sim #1 — trips B3 and runs the Food day tick
	await _settle(10)
	# food = prior stock + farm harvest (3) - upkeep (2 base + 1/building).
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
	_scene_node().call("_try_build", "quarry")
	_check(TownCore.building_level(SaveManager.state["town"], "quarry") == 0,
		"quarry blocked before masonry is researched")
	var panel: TechPanel = _scene_node().call("open_tech_panel")
	await _settle(3)

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
	# Nothing force-plays on this return: A3 is set (both a3 twins suppressed), b3 is set
	# (both b3 twins suppressed), and B5 still needs masonry — so the town swap is silent.
	cheats.simulate_run(true)
	await _settle(10)
	_check(get_tree().get_first_node_in_group("dialogue_panel") == null,
		"the quiz-clear return is silent (no eligible force-play)")
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
	Ledger.add("resonance-dust", 100.0, "smoke-grant")
	var dust_before := Ledger.get_amount("resonance-dust")
	etch.learn("snare")       # Q, unlock 4 — auto-equips to the empty Q slot
	etch.learn("shockwave")   # R, unlock 6 — auto-equips to the empty R slot
	etch.equip("q", "snare")  # idempotent (already auto-equipped) — exercises the equip API
	etch.equip("r", "shockwave")
	etchings = SaveManager.state["combat"]["etchings"]
	_check(EtchingsCore.level_of(etchings, "snare") == 1 and str(etchings["slots"]["q"]) == "snare",
		"Snare learned + equipped to Q")
	_check(EtchingsCore.level_of(etchings, "shockwave") == 1 and str(etchings["slots"]["r"]) == "shockwave",
		"Shockwave learned + equipped to R")
	_check(absf((dust_before - Ledger.get_amount("resonance-dust")) - 10.0) < 0.001,
		"learning Snare(4) + Shockwave(6) spent 10 Dust via the Ledger (reason etching)")
	var edefs := EtchingsCore.defs()
	_check(not EtchingsCore.can_learn(edefs["sentinel"], 999.0, etchings),
		"Sentinel is dormant — not learnable even with Dust")
	etch.learn("sentinel")
	_check(not EtchingsCore.is_unlocked(SaveManager.state["combat"]["etchings"], "sentinel"),
		"learning a dormant etching is a no-op")
	_check((_read_slot_from_disk()["combat"]["etchings"]["unlocked"] as Dictionary).has("shockwave"),
		"disk: the learned etching kit persisted")
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
		await _test_abilities_in_run(player)

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
	_check(Ledger.get_amount("stone") >= 2.0, "quarry produced stone on the day tick")

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

	# Sophia is now a town NPC (talkable from day 0, ungated). After B3 she has arc content.
	_check(_scene_node().has_node("NpcSophia"), "Sophia exists as a town NPC")
	var sdlg: DialoguePanel = _scene_node().call("talk_to", "sophia")
	_check(sdlg != null, "Sophia is talkable and offers her arc beat (b3 set)")
	if sdlg != null:
		await _drive_panel(sdlg, "arc-sophia-method")

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
	# via a sim so E2's town-entry force-play fires. E2 (codex_shards>=6) is the only eligible
	# force-play: a3/b3 twins are flag-suppressed and B5 is seen.
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

	# --- Forfeit Run — "like it never happened" (ESC menu, design 2026-07-07) ----------
	# Start a real run, let its first room pay out and clear it, then forfeit: the whole
	# slot rolls back to the portal-entry snapshot (resources, counters, checkpoint), on
	# disk and in memory.
	pause = get_tree().get_first_node_in_group("pause_menu")
	_check(pause != null, "pause menu available for the forfeit test")
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
	_game.call("choose_slot", SMOKE_SLOT)
	await _settle(10)
	_check(_scene_file() == "town.tscn", "re-choosing the slot loads town (got %s)" % _scene_file())
	_check(int(SaveManager.state["story"]["counters"]["runs"]) == runs_saved,
		"counters survived the Save & Quit round-trip (%d)" % int(SaveManager.state["story"]["counters"]["runs"]))

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
		echo_panel.call("pick", 0)  # take the offered echo, like a player
		await _settle(6)
	await _walk_out(room)


## A normal combat room. On the FIRST one, override the incoming door to a Dust cache so
## the clear pays an unconfounded cache (dust has no other combat source) — exercises
## game.gd's door-reward payment deterministically.
func _clear_combat(room: Node) -> void:
	if not _multiwave_checked:
		_multiwave_checked = true
		_check(int(room.call("wave_total")) >= 2,
			"combat room runs multiple waves (%d)" % int(room.call("wave_total")))
	if not _dust_tested:
		_dust_tested = true
		var floor_now := int(RunState.run["floor"])
		RunState.pending_door = {"sigil": "dust", "peril": false}
		var dust_before := Ledger.get_amount("resonance-dust")
		await _kill_room(room)
		var want: float = float(DoorCore.cache_reward("dust", floor_now, false)["amount"])
		_check(absf(Ledger.get_amount("resonance-dust") - (dust_before + want)) < 0.001,
			"dust door paid its cache on clear (+%.0f)" % want)
		return
	await _kill_room(room)


## A boss room. On the FIRST one, wound the player to a known HP and assert the boss
## kill repairs 30% of the missing amount (the auto floor-boss valve).
func _clear_boss(room: Node) -> void:
	var player := _find_player()
	if player != null and not _boss_heal_tested:
		_boss_heal_tested = true
		player.restore_health(60)  # deterministic: 40 missing of 100
		var want: int = 60 + DoorCore.heal_missing(60, player.max_health, DoorCore.BOSS_HEAL_PCT)
		await _kill_room(room)
		await _settle(12)
		_check(player.health == want, "boss kill healed 30%% of missing (60 -> %d, want %d)" % [player.health, want])
		return
	await _kill_room(room)
	await _settle(12)


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
