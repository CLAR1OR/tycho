extends PanelContainer
class_name EchoOfferPanel
## In-run Echo offer UI (PRD §7.5): the etchings glow, the game pauses, three cards
## appear — click one or press 1/2/3. Built entirely in code (placeholder UI, like
## the tuning panel); combat_room spawns it on its HUD layer after a clear.
##
## The panel unpauses BEFORE reporting the pick, so whatever the callback does
## (apply stats, open the exit) runs in a live tree. pick() is public so the
## headless smoke driver can choose programmatically.

const CARD_WIDTH := 220.0

var _ids: Array[String] = []
var _on_pick: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the tree is paused
	add_to_group("echo_offer")


## Show the offer and pause the game. `on_pick` is called with the chosen echo id.
func present(offer_ids: Array[String], on_pick: Callable) -> void:
	_ids = offer_ids
	_on_pick = on_pick
	var defs := EchoCore.defs()

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Your etchings glow — choose an Echo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	rows.add_child(cards)
	for i in _ids.size():
		var def: Dictionary = defs.get(_ids[i], {"name": _ids[i], "desc": ""})
		var card := Button.new()
		card.custom_minimum_size = Vector2(CARD_WIDTH, 96)
		card.text = "[%d]  %s\n%s" % [i + 1, str(def.get("name", "?")), str(def.get("desc", ""))]
		card.clip_text = false
		card.pressed.connect(pick.bind(i))
		cards.add_child(card)

	var hint := Label.new()
	hint.text = "click a card or press 1 / 2 / 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	rows.add_child(hint)

	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	get_tree().paused = true
	Sfx.play("echo-open")
	# Recenter once the container has computed its real size — a freshly built
	# Control has no rect yet (the tuning-panel layout lesson).
	await get_tree().process_frame
	if is_inside_tree():
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)


## Choose card `index` (0-based). Public: buttons, number keys, and the smoke
## driver all end up here.
func pick(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	var id := _ids[index]
	var cb := _on_pick
	Sfx.play("echo-pick")
	get_tree().paused = false
	queue_free()
	if cb.is_valid():
		cb.call(id)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_3:
			get_viewport().set_input_as_handled()
			pick(int(key - KEY_1))
