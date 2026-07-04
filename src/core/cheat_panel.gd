extends PanelContainer
class_name CheatPanel
## Playtest cheat panel (debug tooling, like the F1 TuningPanel). **F2 toggles it**;
## while open the game is paused. Exists so the human can playtest puzzles, story
## progression, and town/tech pacing WITHOUT grinding the dungeon: grant resources,
## simulate finished runs, insta-research tech, and (in-run) clear the wave or heal.
##
## Design rule: cheats go through the REAL paths — Ledger mutations carry a "cheat"
## reason, and a simulated run is just the same EventBus signals a real run emits
## (boss_killed → run_ended), so counters, the day tick, codex shards, auto-solve,
## and every future subscriber (achievements, story gates) behave identically.
##
## Code-built, spawned once by game.gd into the HUD layer (survives scene swaps).
## Public methods (grant / simulate_run / research / …) let the smoke drive it.

const PANEL_WIDTH := 380.0
const FONT_SIZE := 13

## A simulated victory pays what a real slice clear's boss pays (combat_room.gd).
const SIM_BOSS_GOLD := 25.0
const SIM_BOSS_SHARDS := 1.0
const SIM_BOSS_ORE := 2.0

var _game: Node = null
var _rows: VBoxContainer = null


func setup(game: Node) -> void:
	_game = game
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("cheat_panel")
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -PANEL_WIDTH
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cheat_panel"):
		# No slot loaded yet (slot-select screen) → nothing to cheat on.
		if not visible and SaveManager.state.is_empty():
			return
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_rebuild()
	else:
		get_viewport().gui_release_focus()


func _close() -> void:
	if visible:
		_toggle()


# --- Cheats (public — buttons and the smoke both land here) ------------------------

func grant(id: String, amount: float) -> void:
	Ledger.add(id, amount, "cheat")


func grant_codex_shard() -> void:
	StoryState.grant_codex_shard()  # same codex bump + codex_shard_added the win path uses
	_rebuild_if_open()


## A finished run without playing it: emit exactly what a real run emits, plus the
## boss loot a real clear would have dropped. Town-only (a live run would go stale).
func simulate_run(victory: bool) -> void:
	if RunState.in_run():
		return
	if victory:
		grant("gold", SIM_BOSS_GOLD)
		grant("knowledge-shards", SIM_BOSS_SHARDS)
		grant("resonance-ore", SIM_BOSS_ORE)
		EventBus.boss_killed.emit("cheat-sim", 1)
	else:
		EventBus.death.emit("cheat-sim")
	EventBus.run_ended.emit(victory, 1, {})
	_rebuild_if_open()


func simulate_runs(count: int, victory: bool = true) -> void:
	for i in count:
		simulate_run(victory)


## Raw-set a story flag (b1..b5) in the save. Rationale: the unlock cascade (PRD
## §7.1) gates the forge/desk/plots behind story beats, so an OLD dev save from
## before the cascade lands locked out of its own facilities. This is the no-grind
## escape hatch — poke the flag and walk back in. Bypasses the beat deliberately
## (it's a debug tool); the real path is replaying the beat.
func set_story_flag(flag: String) -> void:
	if SaveManager.state.is_empty():
		return
	StoryState.set_flag(flag)  # route the raw poke through the story owner
	SaveManager.save_current()
	_rebuild_if_open()


## Instantly research a node — the real completion path (TechCore + the event), so
## unlocks, age advance, and the town plots all react as if it were earned.
func research(id: String) -> void:
	SaveManager.state["tech"] = TechCore.complete(SaveManager.state["tech"], id)
	EventBus.tech_researched.emit(id)
	SaveManager.save_current()
	_rebuild_if_open()


## In-run: kill everything standing in the current room via the real damage path
## (drops, clear signal, and the echo beat all follow). Closes the panel first so
## the normal post-clear flow isn't running under our pause.
func slaughter_wave() -> void:
	if not RunState.in_run():
		return
	_close()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(99999)


func full_heal() -> void:
	var player := _find_player()
	if player != null:
		player.heal(99999)


# --- UI -----------------------------------------------------------------------------

func _rebuild_if_open() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_header("⚑ CHEATS — playtest tools (F2 closes)")

	_header("Resources")
	var resources := DataLoader.load_domain("resources")
	var ids := resources.keys()
	ids.sort()
	for id: String in ids:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s (%d)" % [str(resources[id]["name"]), int(Ledger.get_amount(id))]
		name_label.add_theme_font_size_override("font_size", FONT_SIZE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		for amount: float in [10.0, 100.0]:
			var b := Button.new()
			b.text = "+%d" % int(amount)
			b.add_theme_font_size_override("font_size", FONT_SIZE)
			b.pressed.connect(func() -> void:
				grant(id, amount)
				_rebuild())
			row.add_child(b)
		_rows.add_child(row)
	_action("+1 codex shard (%d held)" % int(SaveManager.state["codex"]["shards"]),
		grant_codex_shard)

	_header("Progression")
	if RunState.in_run():
		_note("(finish or abandon the run to simulate runs)")
	else:
		_action("Simulate 1 victorious run (day ticks, counters, codex)",
			simulate_run.bind(true))
		_action("Simulate 5 victorious runs", simulate_runs.bind(5, true))
		_action("Simulate 1 death run", simulate_run.bind(false))
	var counters: Dictionary = SaveManager.state["story"]["counters"]
	_note("runs %d · clears %d · deaths %d · boss kills %d" % [int(counters["runs"]),
		int(counters["full_clears"]), int(counters["deaths"]), int(counters["boss_kills"])])

	_header("Set story flag (raw)")
	_note("Reopens cascade-gated facilities on an old save (b1 forge · b3 desk · b4 build)")
	var flags: Dictionary = SaveManager.state["story"]["flags"]
	var flag_row := HBoxContainer.new()
	flag_row.add_theme_constant_override("separation", 4)
	for flag: String in ["b1", "b2", "b3", "b4", "b5"]:
		var b := Button.new()
		b.text = "%s%s" % [flag, " ✓" if bool(flags.get(flag, false)) else ""]
		b.add_theme_font_size_override("font_size", FONT_SIZE)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(set_story_flag.bind(flag))
		flag_row.add_child(b)
	_rows.add_child(flag_row)

	_header("Tech — instant research")
	var defs := DataLoader.load_domain("tech")
	var available := TechCore.available(defs, SaveManager.state["tech"])
	if available.is_empty():
		_note("(nothing left to research)")
	for id: String in available:
		_action("⚡ %s" % str(defs[id]["name"]), research.bind(id))

	if RunState.in_run():
		_header("In run")
		_action("Slaughter the wave", slaughter_wave)
		_action("Full heal", full_heal)


func _header(text: String) -> void:
	var l := Label.new()
	l.text = "\n" + text
	l.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	l.modulate = Color(1.0, 0.85, 0.4)
	_rows.add_child(l)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.modulate = Color(1, 1, 1, 0.6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


func _action(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(action)
	_rows.add_child(b)


func _find_player() -> Player:
	if _game == null:
		return null
	var world := _game.get_node_or_null("World")
	if world == null:
		return null
	for child in world.get_children():
		var p := child.get_node_or_null("Player")
		if p is Player and not child.is_queued_for_deletion():
			return p
	return null
