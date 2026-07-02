extends PanelContainer
class_name TechPanel
## Linnea's research screen (PRD §7.8) — placeholder UI, code-built like the echo
## and tuning panels. Pauses the game while open.
##
## Flow: LIST (pick/see nodes) → NODE (progress + invest Knowledge/Shards) →
## READ (the authored explanation) → QUIZ (the interim puzzle; the bespoke
## interactive puzzles replace this per-node later) → AHA (the reveal) → done:
## TechCore.complete + `tech_researched` on the EventBus + save.
##
## Logic stays in TechCore (pure, tested); this class is screens and wiring.
## All flow methods (select_node / invest_all / begin_read / begin_quiz / answer /
## finish) are public so the headless smoke can drive the real path.

enum Screen { LIST, NODE, READ, QUIZ, AHA }

const PANEL_WIDTH := 660.0
const PANEL_HEIGHT := 500.0

var _defs: Dictionary = {}
var _screen: int = Screen.LIST
var _node_id: String = ""
var _quiz_index: int = 0
var _rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tech_panel")


func open() -> void:
	_defs = DataLoader.load_domain("tech")
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	margin.add_child(_rows)
	_show_list()
	get_tree().paused = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await get_tree().process_frame
	if is_inside_tree():
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func close() -> void:
	get_tree().paused = false
	queue_free()


# --- Flow (public — buttons and the smoke driver both land here) -----------------

func select_node(id: String) -> void:
	_node_id = id
	# Selecting makes it the ACTIVE node — the one Linnea auto-solves over runs.
	SaveManager.state["tech"]["active"] = id
	_show_node()


## Pour the Ledger's Knowledge (+ Knowledge Shards, converted as needed) into the
## selected node, up to its remaining cost.
func invest_all() -> void:
	var def: Dictionary = _defs[_node_id]
	var tech: Dictionary = SaveManager.state["tech"]
	var missing := float(def["cost_knowledge"]) - TechCore.progress(tech, _node_id)
	var conv := TechCore.shards_needed(missing, Ledger.get_amount("knowledge"), Ledger.get_amount("knowledge-shards"))
	if int(conv["shards_used"]) > 0 and Ledger.try_spend("knowledge-shards", float(conv["shards_used"]), "research"):
		Ledger.add("knowledge", float(conv["knowledge_from_shards"]), "shard-conversion")
	var result := TechCore.invest(tech, def, minf(Ledger.get_amount("knowledge"), missing))
	if float(result["accepted"]) > 0.0 and Ledger.try_spend("knowledge", float(result["accepted"]), "research"):
		SaveManager.state["tech"] = result["tech"]
	_show_node()


func begin_read() -> void:
	_show_read()


func begin_quiz() -> void:
	_quiz_index = 0
	_show_quiz()


## Answer the current quiz question with option `index` (in DATA order — the UI
## shuffles display order but binds original indices). Wrong answers just retry:
## reward thinking, never hard-gate (IC-10).
func answer(index: int) -> void:
	var q := _current_question()
	if index == int(q.get("correct", 0)):
		_quiz_index += 1
		if _quiz_index >= _questions().size():
			_show_aha()
		else:
			_show_quiz()
	else:
		_show_quiz("Not quite — read the failure, think it through, try again.")


## The aha has been read: the node completes for real.
func finish() -> void:
	SaveManager.state["tech"] = TechCore.complete(SaveManager.state["tech"], _node_id)
	EventBus.tech_researched.emit(_node_id)
	SaveManager.save_current()
	_node_id = ""
	_show_list()


# --- Screens ---------------------------------------------------------------------

func _show_list() -> void:
	_screen = Screen.LIST
	_clear()
	_title("Linnea's Desk — Research")
	var tech: Dictionary = SaveManager.state["tech"]
	_label("You carry: %d Knowledge, %d Knowledge Shards (worth %d each)" % [
		int(Ledger.get_amount("knowledge")), int(Ledger.get_amount("knowledge-shards")),
		int(TechCore.SHARD_KNOWLEDGE_VALUE)])
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
			done.modulate = Color(1, 1, 1, 0.55)
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
	if TechCore.is_ready(def, tech):
		_label("It's ready. Linnea lays out what the shards revealed —")
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
	l.add_theme_font_size_override("font_size", 20)
	_rows.add_child(l)


func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(l)


## Long-form text in a scroll area (explanations and ahas are essays, by design).
func _reading(text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 64.0, 240.0)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_WIDTH - 96.0, 0.0)
	scroll.add_child(l)
	_rows.add_child(scroll)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	_rows.add_child(b)


func _questions() -> Array:
	return (_defs[_node_id]["puzzle"] as Dictionary).get("data", {}).get("questions", [])


func _current_question() -> Dictionary:
	var qs := _questions()
	return qs[_quiz_index] if _quiz_index < qs.size() else {}
