extends PanelContainer
class_name TechPanel
## Sophia's research screen (PRD §7.8) — placeholder UI, code-built like the echo
## and tuning panels. Pauses the game while open.
##
## Flow: LIST (pick/see nodes; turn in Knowledge Shards) → NODE (progress + invest
## Knowledge) → READ (the authored explanation) → the node's puzzle, dispatched on
## `puzzle.kind` (architecture-schemas.md §4): "quiz" → the built-in QUIZ screen;
## "interactive" → PUZZLE embeds the bespoke scene from PUZZLES and waits for its
## `solved` signal → AHA (the reveal) → done: TechState.complete (TechCore.complete +
## `tech_researched` on the EventBus) + save.
##
## Shard economy (2026-07-06): investing spends KNOWLEDGE ONLY. Knowledge Shards are
## turned in for Knowledge with the desk's "turn in shards" action (TechState). A wrong
## quiz answer LOCKS the quiz (LOCKED screen) until one run passes — the interactive
## arch puzzle is exempt (its staged failures are the teaching).
##
## Logic stays in TechCore (pure, tested); tech-section writes route through the
## TechState autoload (set_active / invest / turn_in_shards / lock_quiz / complete); this
## class is screens and wiring. All flow methods (select_node / invest_all /
## turn_in_shards / begin_read / begin_quiz / answer / begin_puzzle / finish) are public
## so the headless smoke can drive the real path.

enum Screen { LIST, NODE, READ, QUIZ, LOCKED, PUZZLE, AHA }

## Bespoke interactive puzzles, keyed by the node's `puzzle.scene`. Contract:
## a Control with `setup(data: Dictionary)` and a `solved` signal.
const PUZZLES: Dictionary = {
	"puzzle_arch": preload("res://src/learning/puzzle_arch.gd"),
}

# Fullscreen page with side gutters so reading lines stay a comfortable width.
const GUTTER_X := 240
const GUTTER_Y := 24

var _defs: Dictionary = {}
var _screen: int = Screen.LIST
var _node_id: String = ""
var _quiz_index: int = 0
var _rows: VBoxContainer
var _puzzle: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tech_panel")
	theme = SlateTheme.get_theme()


func open() -> void:
	_defs = DataLoader.load_domain("tech")
	# Fullscreen (a centered box overflowed the window once real explanation text
	# was in it). The whole page scrolls, so no screen can ever bleed off-view.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GUTTER_X)
	margin.add_theme_constant_override("margin_right", GUTTER_X)
	margin.add_theme_constant_override("margin_top", GUTTER_Y)
	margin.add_theme_constant_override("margin_bottom", GUTTER_Y)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_show_list()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


# --- Flow (public — buttons and the smoke driver both land here) -----------------

func select_node(id: String) -> void:
	_node_id = id
	# Selecting makes it the ACTIVE node — the one Sophia auto-solves over runs.
	TechState.set_active(id)
	_show_node()


## Pour the Ledger's Knowledge (+ Knowledge Shards, converted as needed) into the
## selected node, up to its remaining cost. The invest transaction (+ its Ledger
## spends) lives on TechState now; the readout re-reads state below.
func invest_all() -> void:
	TechState.invest(_defs[_node_id], _node_id)
	_show_node()


func begin_read() -> void:
	_show_read()


func begin_quiz() -> void:
	if TechCore.is_quiz_locked(SaveManager.state["tech"], _node_id):
		_show_locked()
		return
	_quiz_index = 0
	_show_quiz()


## Turn in ALL held Knowledge Shards for Knowledge at the desk (TechState owns the
## transaction). Public so the smoke can drive it; refreshes the current screen.
func turn_in_shards() -> void:
	TechState.turn_in_shards()
	SaveManager.save_current()
	if _screen == Screen.NODE:
		_show_node()
	else:
		_show_list()


## True while the quiz-locked screen is up (a wrong answer this run). Smoke/debug hook.
func on_locked_screen() -> bool:
	return _screen == Screen.LOCKED


## Embed the node's bespoke interactive puzzle and wait for it to be solved.
func begin_puzzle() -> void:
	_screen = Screen.PUZZLE
	_clear()
	var def: Dictionary = _defs[_node_id]
	var puzzle: Dictionary = def["puzzle"]
	var scene_id := str(puzzle.get("scene", ""))
	if not PUZZLES.has(scene_id):
		push_error("TechPanel: unknown puzzle scene \"%s\" on %s" % [scene_id, _node_id])
		_show_read()
		return
	_title(str(def["name"]))
	_puzzle = (PUZZLES[scene_id] as GDScript).new()
	_puzzle.call("setup", puzzle.get("data", {}))
	_puzzle.connect("solved", _show_aha)
	_rows.add_child(_puzzle)
	_button("Step away (keeps progress)", close)


## The live puzzle Control (smoke driver + debugging).
func puzzle_node() -> Control:
	return _puzzle


## Answer the current quiz question with option `index` (in DATA order — the UI
## shuffles display order but binds original indices). A WRONG answer locks the quiz
## for one run (2026-07-06); Sophia still auto-solves eventually, so this delays,
## never hard-gates (IC-10). No-op while already locked (the locked screen has no
## answer buttons; this guards a stray driver call).
func answer(index: int) -> void:
	if _screen == Screen.LOCKED:
		return
	var q := _current_question()
	if index == int(q.get("correct", 0)):
		_quiz_index += 1
		if _quiz_index >= _questions().size():
			_show_aha()
		else:
			_show_quiz()
	else:
		TechState.lock_quiz(_node_id)
		SaveManager.save_current()
		_show_locked()


## The aha has been read: the node completes for real.
func finish() -> void:
	TechState.complete(_node_id)  # TechCore.complete + tech_researched, in one place
	SaveManager.save_current()
	_node_id = ""
	_show_list()


# --- Screens ---------------------------------------------------------------------

func _show_list() -> void:
	_screen = Screen.LIST
	_clear()
	_title("Sophia's Desk — Research")
	var tech: Dictionary = SaveManager.state["tech"]
	_label("You carry: %d Knowledge, %d Knowledge Shards (worth %d each)" % [
		int(Ledger.get_amount("knowledge")), int(Ledger.get_amount("knowledge-shards")),
		int(TechCore.SHARD_KNOWLEDGE_VALUE)])
	_turn_in_button()
	for id in TechCore.available(_defs, tech):
		var def: Dictionary = _defs[id]
		var b := Button.new()
		b.text = "%s   [%s, %d Knowledge]   %.0f/%d" % [
			str(def["name"]), str(def["tier"]), int(def["cost_knowledge"]),
			TechCore.progress(tech, id), int(def["cost_knowledge"])]
		b.pressed.connect(select_node.bind(id))
		_rows.add_child(b)
	for id: String in tech.get("researched", []):
		if _defs.has(id):
			var done := Label.new()
			done.text = "✓ %s — researched" % str(_defs[id]["name"])
			done.theme_type_variation = &"DimLabel"
			_rows.add_child(done)
	_button("Close", close)


func _show_node() -> void:
	_screen = Screen.NODE
	_clear()
	var def: Dictionary = _defs[_node_id]
	var tech: Dictionary = SaveManager.state["tech"]
	_title(str(def["name"]))
	_label("%s node — Age %d%s" % [str(def["tier"]).capitalize(), int(def["age"]),
		"  🧠 thinking tool" if bool(def.get("thinking_tool", false)) else ""])
	_label("Progress: %.0f / %d Knowledge" % [TechCore.progress(tech, _node_id), int(def["cost_knowledge"])])
	_label("You carry: %d Knowledge, %d Shards" % [
		int(Ledger.get_amount("knowledge")), int(Ledger.get_amount("knowledge-shards"))])
	_turn_in_button()
	if TechCore.is_ready(def, tech):
		_label("It's ready. Sophia lays out what the shards revealed —")
		_button("Read & solve", begin_read)
	else:
		_button("Invest everything you carry", invest_all)
	_button("Back", _show_list)
	_button("Close", close)


func _show_read() -> void:
	_screen = Screen.READ
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title(str(def["name"]))
	_reading(str(def.get("explanation", "(no explanation authored yet)")))
	if str((def["puzzle"] as Dictionary).get("kind", "quiz")) == "interactive":
		_button("To the gateway — build it", begin_puzzle)
	else:
		_button("I have it — ask me", begin_quiz)
	_button("Close (keeps progress)", close)


func _show_quiz(feedback: String = "") -> void:
	_screen = Screen.QUIZ
	_clear()
	var q := _current_question()
	_title("Question %d of %d" % [_quiz_index + 1, _questions().size()])
	_reading(str(q.get("q", "?")))
	if not feedback.is_empty():
		var fb := Label.new()
		fb.text = feedback
		fb.modulate = Color(1.0, 0.6, 0.5)
		_rows.add_child(fb)
	# Shuffle the display order; each button still answers with its DATA index.
	var options: Array = q.get("options", [])
	var order := range(options.size())
	order.shuffle()
	for i: int in order:
		var b := Button.new()
		b.text = str(options[i])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(answer.bind(i))
		_rows.add_child(b)


## The quiz is locked (a wrong answer this run). No answer buttons — a run has to pass
## before Sophia will hear the answer again. Diegetic line in the plain register.
func _show_locked() -> void:
	_screen = Screen.LOCKED
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title(str(def["name"]))
	_reading("Sophia: That's not it. Go make a run and clear your head. Ask me again when you're back.")
	_button("Back", _show_list)
	_button("Close (keeps progress)", close)


func _show_aha() -> void:
	_screen = Screen.AHA
	_clear()
	var def: Dictionary = _defs[_node_id]
	_title("✦ " + str(def["name"]))
	_reading(str(def.get("aha", "")))
	var unlocks: Array = def.get("unlocks", [])
	if not unlocks.is_empty():
		var names := PackedStringArray()
		for u: Dictionary in unlocks:
			names.append("%s %s" % [str(u.get("type", "")), str(u.get("id", ""))])
		_label("Unlocked: " + ", ".join(names))
	_button("Finish", finish)


# --- UI helpers -------------------------------------------------------------------

func _clear() -> void:
	for child in _rows.get_children():
		child.queue_free()


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.theme_type_variation = &"TitleLabel"
	_rows.add_child(l)


func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


## Long-form text (explanations and ahas are essays, by design). The PAGE scrolls,
## so this is just a wrapping label at reading width.
func _reading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(l)


## The "turn in shards" action (2026-07-06): bring Sophia the Knowledge Shards you
## found and she extracts what they teach — all held shards → Knowledge at 5 apiece.
## Disabled at 0 shards. Shown on both the list and node screens.
func _turn_in_button() -> void:
	var shards := int(Ledger.get_amount("knowledge-shards"))
	var b := Button.new()
	b.text = "Turn in %d Knowledge Shards → %d Knowledge" % [
		shards, shards * int(TechCore.SHARD_KNOWLEDGE_VALUE)]
	b.disabled = shards <= 0
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(turn_in_shards)
	_rows.add_child(b)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	_rows.add_child(b)


func _questions() -> Array:
	return (_defs[_node_id]["puzzle"] as Dictionary).get("data", {}).get("questions", [])


func _current_question() -> Dictionary:
	var qs := _questions()
	return qs[_quiz_index] if _quiz_index < qs.size() else {}
