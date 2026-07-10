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

var _scene: Node = null       # the live town or combat room
var _session_t: float = 0.0   # unsaved playtime (flushed into meta.playtime_s on save)
# Portal-entry slot snapshot for a Forfeit rollback (design 2026-07-07). Captured at
# _start_run BEFORE any run mutation or checkpoint write; Forfeit restores it wholesale.
var _run_snapshot: Dictionary = {}
# The last day tick's result, handed to the town's overnight toast on the run-end return
# (design/ui-hud.md). Set in _on_run_ended, consumed + cleared in _goto_town — a Forfeit
# reaches town WITHOUT setting it, so it never toasts (Forfeit ticks no day).
var _last_day_tick: Dictionary = {}
# Run telemetry (2026-07-10, diagnostics tooling — NOT the save system; see
# Telemetry.append's header). Stamped in _start_run alongside _run_snapshot, read in
# _on_run_ended / forfeit_run to build a record: elapsed wall time and the resource
# deltas the run earned (current Ledger vs. the snapshot taken at portal entry).
var _run_start_ms: int = 0

@onready var _world: Node = $World


func _ready() -> void:
	# The has-<resource> pickup flags + all story counters ride StoryState (an autoload,
	# so it subscribes before this scene); the town economy readout is now the TownHud's
	# resource strip, so game.gd holds no HUD readout of its own.
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.tech_researched.connect(_on_tech_researched)
	# Apply the profile's window mode once at boot (SaveManager loaded the profile as an
	# autoload; headless-guarded inside). Volumes already rode Music._ready. (SET1, 2026-07-09.)
	SettingsPanel.apply_window_mode(SaveManager.profile)
	# Playtest cheat panel (F2) — lives on the HUD layer so it survives scene swaps.
	var cheats := CheatPanel.new()
	cheats.setup(self)
	$HUD.add_child(cheats)
	# ESC pause menu (Resume / Forfeit / Save & Quit) — also HUD-layer, survives swaps.
	var pause := PauseMenu.new()
	pause.setup(self)
	$HUD.add_child(pause)
	_show_slot_select()


## Boot screen: pick/create a slot. Nothing is loaded until the player chooses.
func _show_slot_select() -> void:
	Music.play("title")
	var select := SlotSelect.new()
	select.slot_count = SLOT_COUNT
	select.slot_chosen.connect(func(slot: int) -> void:
		select.queue_free()
		choose_slot(slot))
	# The title screen's quiet "settings" corner opens the settings page (no return target —
	# the slot select stays up behind the backdrop; the panel owns + drops the pause). SET1.
	select.settings_requested.connect(func() -> void: open_settings())
	$HUD.add_child(select)


## Load (or create) a slot and enter the game: town, or — if the slot carries a
## mid-run checkpoint — straight back into the run at floor start.
func choose_slot(slot: int) -> void:
	if not SaveManager.load_slot(slot):
		SaveManager.create_slot(slot, DEFAULT_SLOT_NAME)
	var checkpoint: Variant = SaveManager.state.get("checkpoint")
	if checkpoint is Dictionary and not (checkpoint as Dictionary).is_empty():
		RunState.resume_from(checkpoint)
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
	# Fire the overnight production toast if a day just ticked (a run ended into town).
	# _last_day_tick is empty on a fresh boot / resume / Forfeit return, so those are silent.
	town.show_day_toast(_last_day_tick)
	_last_day_tick = {}
	_save()


func _start_run() -> void:
	# The rollback point for a Forfeit: the full slot state at portal entry, before ANY run
	# mutation or checkpoint write (design 2026-07-07). Nothing has touched a counter yet
	# (start_run only emits run_started, which no state-owner mutates on). Capture the LIVE
	# Ledger explicitly — state["ledger"] only syncs on save, so it can lag the real amounts.
	_run_snapshot = SaveManager.state.duplicate(true)
	_run_snapshot["ledger"] = Ledger.to_dict()
	_run_start_ms = Time.get_ticks_msec()
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
		int(RunState.run["rooms_this_floor"]), RunState.room_kind(), RunState.pending_door,
		_floor_profile(int(RunState.run["floor"])))  # the stratum profile (env/props/hazards)
	_swap(room)
	room.cleared.connect(_on_room_cleared.bind(room))
	room.exit_entered.connect(func() -> void: call_deferred("_next_room"))
	room.player_died.connect(func() -> void: RunState.player_died())
	# Final chamber: walking into the codex artifact dissolves Tycho and ends the run.
	room.artifact_entered.connect(func() -> void: call_deferred("_finish_at_artifact"))


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
	var boss_id: String = room.boss_id if was_boss else ""
	# The door that led INTO this room decides what it PAYS (design/run-structure.md).
	# Captured before RunState.room_cleared advances / a new door is picked.
	var incoming: Dictionary = RunState.pending_door.duplicate()
	var cleared_floor := int(RunState.run["floor"])
	if RunState.is_final_boss():
		# The final chamber (design 2026-07-07): count the kill, run the boss valve (heal +
		# the guaranteed post-boss echo), then raise the codex artifact as the ONLY way out.
		# Walking into it dissolves Tycho and ends the run — run_ended is DEFERRED to that
		# entry (RunState.finish_at_artifact via room.artifact_entered), not fired here.
		RunState.final_boss_killed(boss_id)
		room.apply_missing_heal(DoorCore.BOSS_HEAL_PCT)
		_offer_echo(room, func() -> void: _open_artifact(room))
		return
	if not RunState.room_cleared(boss_id):
		return  # defensive: only the final boss ends the run, handled above
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
	var resource := str(reward["resource"])
	var amount := float(reward["amount"])
	# Attunement find-rate lifts Dust/Ore caches only (gold/echo/reprieve unaffected). Applied
	# HERE at the payout — DoorCore's pure math is never touched (PRD §10: bounded at 3 levels).
	if resource == "resonance-dust" or resource == "resonance-ore":
		var attn: Dictionary = SaveManager.state["combat"].get("attunements", {})
		amount = roundf(amount * AttunementsCore.find_rate_mult(attn, AttunementsCore.defs()))
	Ledger.add(resource, amount, "door-reward")


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
		RunState.pick_echo(id), on_done)  # the room's RunHud refreshes its echo shelf on pick


## Open the next room's doors; walking into one records the chosen door on RunState so
## the next room spawns from it (reprieve/peril) and pays from it on clear.
func _present_doors(room: Node, offer: Array) -> void:
	if offer.is_empty():
		room.open_exit()  # no offer (shouldn't happen off the boss path) — plain exit
		return
	room.present_doors(offer, func(door: Dictionary) -> void:
		RunState.pending_door = door.duplicate())


## Raise the codex artifact pedestal in the final chamber (design 2026-07-07). The label
## shows the CURRENT shard count / max; the run's own shard is granted on run_ended (the
## dissolve), so it isn't reflected here yet.
func _open_artifact(room: Node) -> void:
	room.open_artifact(int(SaveManager.state["codex"]["shards"]), StoryCore.CODEX_SHARDS_MAX)


## The player walked into the codex artifact — end the run victorious (deferred out of the
## body_entered physics callback). run_ended then rides the normal _on_run_ended tail.
func _finish_at_artifact() -> void:
	RunState.finish_at_artifact()


func _on_run_ended(victory: bool, floor_reached: int, stats: Dictionary) -> void:
	# The counters + the full-clear codex shard rode StoryState, and Sophia's tech
	# auto-solve rode TechState (both fired already — they subscribed first as
	# autoloads). game.gd handles only the scene-flow tail.
	# Telemetry (2026-07-10): a diagnostics record of the just-finished run, BEFORE the
	# day tick below adds town production into the Ledger — resource_deltas should read
	# what the RUN earned, not the town's overnight tick on top of it.
	Telemetry.append(TelemetryCore.build_record(
		RunState.run_number, SaveManager.current_slot,
		TelemetryCore.OUTCOME_VICTORY if victory else TelemetryCore.OUTCOME_DEATH,
		floor_reached, int(stats.get("room", 0)), _run_elapsed_s(),
		RunState.echoes, _run_resource_deltas()))
	SaveManager.state["checkpoint"] = null  # the run is over — nothing to resume
	# The day tick: 1 day = 1 run, win OR die (locked decision, PRD §6.2). The tick
	# also runs the Food upkeep pass (design/food-upkeep.md): production comes in, the
	# town eats, and covered → Well-Fed → +25% to all other production (already folded
	# into `produced`). Spend Food AFTER adding production so the stock math matches
	# the core's "harvest first" rule.
	# Room-scaled magnitude (human decision 2026-07-10): the tick scales with the run's
	# cleared rooms. The fallback 10 = one nominal day, protecting any emitter that
	# doesn't set rooms_cleared (the cheat panel's simulate_run sets it explicitly).
	Sfx.play("day-chime")
	var tick_scale := TownCore.run_tick_scale(int(stats.get("rooms_cleared", 10)))
	var tick := TownCore.tick(
		SaveManager.state["town"], DataLoader.load_domain("buildings"),
		Ledger.get_amount("food"), tick_scale)
	var produced: Dictionary = tick["produced"]
	for id: String in produced:
		Ledger.add(id, float(produced[id]), "town-tick")
	Ledger.try_spend("food", float(tick["food_consumed"]), "upkeep")
	# Market auto-sell (town-economy.md, 2026-07-10): the pure tick computed the
	# surplus sale; realize it on the Ledger AFTER upkeep, same order as the core.
	if float(tick.get("food_sold", 0.0)) > 0.0:
		Ledger.try_spend("food", float(tick["food_sold"]), "market-sale")
		Ledger.add("gold", float(tick["gold_from_sale"]), "market-sale")
	SaveManager.state["town"]["well_fed"] = bool(tick["well_fed"])
	_last_day_tick = tick  # the town's overnight toast reads this on the return (_goto_town)
	call_deferred("_goto_town")


func _on_tech_researched(tech_id: String) -> void:
	# The first researched tech of an age turns the town's page to it (schemas §3).
	var defs := DataLoader.load_domain("tech")
	var node_age := int((defs.get(tech_id, {}) as Dictionary).get("age", 1))
	if node_age > int(SaveManager.state["town"]["age"]):
		SaveManager.state["town"]["age"] = node_age
		SaveManager.state["meta"]["age"] = node_age
		EventBus.age_advanced.emit(node_age)


# --- ESC pause menu (design 2026-07-07) ---------------------------------------------
# The PauseMenu (HUD layer) calls into these. The Hades quit-gate lives on the room
# (combat_room.can_menu_quit); the menu asks the current scene directly.

## The live scene (town or combat room), or null at the slot-select screen. The PauseMenu
## reads it to route its gate check (town / no method → allowed; a room → can_menu_quit).
func current_scene() -> Node:
	return _scene


## True when we are at the boot/quit slot-select screen (no scene loaded) — the menu is inert.
func on_slot_select() -> bool:
	return _scene == null


## Open the settings page (SET1, 2026-07-09) onto the HUD layer. `return_to` (the pause menu, from
## its Settings button) is reshown when the page closes; the title-screen entry passes null (the
## slot select stays up behind the backdrop). Returns the panel so the smoke can drive it.
func open_settings(return_to: Control = null) -> SettingsPanel:
	var panel := SettingsPanel.new()
	$HUD.add_child(panel)
	panel.open()
	if return_to != null:
		panel.closed.connect(func() -> void:
			if is_instance_valid(return_to) and return_to.has_method("reshow"):
				return_to.call("reshow"))
	return panel


## Forfeit the current run — "like it never happened" (design 2026-07-07). Roll the whole
## slot back to the portal-entry snapshot: abort RunState (emits nothing → no day tick, no
## counters, echoes gone), restore the snapshot to memory AND to the live Ledger (the only
## thing save_current re-collects), force the checkpoint null, then save — overwriting the
## floor-checkpoint writes the run left on disk. Finally return to town the normal deferred
## way. The in-session RunState.run_number may skip a value after this — cosmetic, in memory.
func forfeit_run() -> void:
	if not RunState.in_run():
		return
	# Telemetry (2026-07-10): capture BEFORE the rollback below, while RunState.run /
	# .echoes and the live Ledger still reflect the run that's being thrown away.
	Telemetry.append(TelemetryCore.build_record(
		RunState.run_number, SaveManager.current_slot, TelemetryCore.OUTCOME_FORFEIT,
		RunFlow.floor_reached(RunState.run), int(RunState.run.get("room", 0)), _run_elapsed_s(),
		RunState.echoes, _run_resource_deltas()))
	RunState.abort_run()                                  # (a) no run_ended/death/counters
	SaveManager.state = _run_snapshot.duplicate(true)     # (b) restore portal-entry state
	# _collect_from_systems() re-collects ONLY the Ledger on save — reset it to the snapshot
	# so the run's resource gains don't leak back in through save_current below.
	Ledger.reset(SaveManager.state["ledger"])
	SaveManager.state["checkpoint"] = null                # (c) belt-and-suspenders (snapshot predates it)
	SaveManager.save_current()                            # (d) overwrite the run's on-disk checkpoints
	call_deferred("_goto_town")                           # (e) town music rides the normal path (no toast: no day ticked)


## Save & Quit from the ESC menu → back to the slot-select screen. In a run: NO disk write
## (the floor-start checkpoint already on disk IS the save; writing run counters here would
## break the no-mid-run-write statistics invariant — the resume must re-earn post-checkpoint
## progress). In town: a real save. Both then tear down to slot select.
func save_and_quit() -> void:
	if RunState.in_run():
		# INVARIANT (statistics, design 2026-07-07): do NOT touch disk mid-run. Just drop the
		# in-memory run; choose_slot reloads the floor-start checkpoint from disk on return.
		RunState.abort_run()
	else:
		_save()
	_return_to_slot_select()


## Tear down the current scene and go back to the slot-select page (reused by Save & Quit).
## choose_slot() works again afterward — it reloads from disk (resume checkpoint or town).
func _return_to_slot_select() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_show_slot_select()


# --- Telemetry (2026-07-10) -----------------------------------------------------------

func _run_elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _run_start_ms) / 1000.0


## What the run earned: current Ledger vs. the portal-entry snapshot (_run_snapshot,
## captured in _start_run). Covers every resource id touched on either side.
func _run_resource_deltas() -> Dictionary:
	var before: Dictionary = _run_snapshot.get("ledger", {})
	var now := Ledger.to_dict()
	var ids := {}
	for id: String in before:
		ids[id] = true
	for id: String in now:
		ids[id] = true
	var deltas := {}
	for id: String in ids:
		var d := float(now.get(id, 0.0)) - float(before.get(id, 0.0))
		if d != 0.0:
			deltas[id] = d
	return deltas


# --- Save / HUD ---------------------------------------------------------------------

func _save() -> void:
	SaveManager.state["meta"]["playtime_s"] = float(SaveManager.state["meta"]["playtime_s"]) + _session_t
	_session_t = 0.0
	SaveManager.save_current()
