extends Node3D
## Placeholder town hub (vertical slice, PRD §7.9 upgrade-hub model).
##
## Interactions (all placeholder-boxy, E to use):
## - BUILD PLOTS — any Area3D child with `metadata/building_id`. Walk in, press E
##   to build/upgrade through the building's 3 levels. Plots gated by tech
##   (`unlocked_by` via TownCore.is_unlocked) show as locked until researched.
## - LINNEA'S DESK — opens the research screen (TechPanel: invest Knowledge/Shards
##   → read → quiz → aha → unlock).
## - NPCS — any Area3D child with `metadata/npc_id`. E to talk: DialogueCore picks
##   their single best eligible snippet (PRD §7.12). Spine beats with force_play
##   auto-play on town entry, max 1 per visit (spec).
## - DUNGEON PORTAL — step in to start a run (signalled up to game.gd).
##
## Town STATE is the save's town section (architecture-schemas §6), read/written
## via pure TownCore helpers. No TownState autoload yet — one town doesn't need it.

signal run_requested  # the player stepped into the dungeon portal

var _building_defs: Dictionary = {}
var _tech_defs: Dictionary = {}
var _dialogue_defs: Dictionary = {}
var _plots: Array[Area3D] = []      # every Area3D with metadata/building_id
var _in_plot: Area3D = null         # the plot the player is standing in (or null)
var _in_npc: Area3D = null          # the NPC the player is standing at (or null)
var _in_desk: bool = false
var _in_forge: bool = false

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _desk: Area3D = $LinneasDesk
@onready var _forge: Area3D = $MarasForge
@onready var _portal: Area3D = $DungeonPortal
@onready var _day_label: Label = $HUD/DayInfo
@onready var _hint_label: Label = $HUD/Hint


func _ready() -> void:
	_rig.set_target(_player)
	_player.position = Vector3(0, 0, 8)
	_building_defs = DataLoader.load_domain("buildings")
	_tech_defs = DataLoader.load_domain("tech")
	_dialogue_defs = DataLoader.load_domain("dialogue")
	_portal.body_entered.connect(_on_portal_body_entered)
	for child in get_children():
		if child is Area3D and child.has_meta("building_id"):
			var plot := child as Area3D
			_plots.append(plot)
			plot.body_entered.connect(func(body: Node3D) -> void:
				if body is Player:
					_in_plot = plot)
			plot.body_exited.connect(func(body: Node3D) -> void:
				if body is Player and _in_plot == plot:
					_in_plot = null)
		if child is Area3D and child.has_meta("npc_id"):
			var npc := child as Area3D
			npc.body_entered.connect(func(body: Node3D) -> void:
				if body is Player:
					_in_npc = npc)
			npc.body_exited.connect(func(body: Node3D) -> void:
				if body is Player and _in_npc == npc:
					_in_npc = null)
	_desk.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_desk = true)
	_desk.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_desk = false)
	_forge.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_forge = true)
	_forge.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_forge = false)
	# A finished research can unlock plots while we stand here — refresh live.
	EventBus.tech_researched.connect(func(_tech_id: String) -> void: _refresh_plots())
	var day := int(SaveManager.state["story"]["counters"].get("runs", 0)) + 1
	_day_label.text = "Home — Day %d" % day
	_hint_label.text = "WASD move - E interact (plots, desk, forge, people) - the portal starts a run"
	_refresh_plots()
	# Spine/cutscene beats can force-play on a town visit — max 1 (spec): this runs
	# once per town instance, so one visit = at most one forced scene. Deferred a
	# frame so the scene (and any save/swap in flight) settles first.
	call_deferred("_check_force_play")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _in_desk:
		open_tech_panel()
	elif _in_forge:
		open_forge_panel()
	elif _in_npc != null:
		talk_to(str(_in_npc.get_meta("npc_id")))
	elif _in_plot != null:
		_try_build(str(_in_plot.get_meta("building_id")))


func _on_portal_body_entered(body: Node3D) -> void:
	if body is Player:
		run_requested.emit()


## Public (game flow + smoke driver): open Linnea's research screen.
func open_tech_panel() -> TechPanel:
	var panel := TechPanel.new()
	$HUD.add_child(panel)
	panel.open()
	return panel


## Public (game flow + smoke driver): open Mara's Forge.
func open_forge_panel() -> ForgePanel:
	var panel := ForgePanel.new()
	$HUD.add_child(panel)
	panel.open()
	return panel


# --- Dialogue (PRD §7.12) -----------------------------------------------------------

## Public (interact + smoke driver): the character offers their single best
## eligible snippet; nothing eligible = a shrug, not a panel.
func talk_to(npc_id: String) -> DialoguePanel:
	var snippet_id := DialogueCore.select(_dialogue_defs, SaveManager.state, npc_id)
	if snippet_id.is_empty():
		return null
	return _play_snippet(_dialogue_defs[snippet_id], true)


func _check_force_play() -> void:
	var snippet_id := DialogueCore.select_forced(_dialogue_defs, SaveManager.state)
	if not snippet_id.is_empty():
		_play_snippet(_dialogue_defs[snippet_id], false)


func _play_snippet(def: Dictionary, count_talk: bool) -> DialoguePanel:
	var panel := DialoguePanel.new()
	$HUD.add_child(panel)
	panel.play(def)
	panel.finished.connect(func() -> void:
		SaveManager.state["story"] = DialogueCore.mark_shown(
			SaveManager.state["story"], def, count_talk)
		SaveManager.save_current())
	return panel


# --- Build plots ------------------------------------------------------------------

func _try_build(building_id: String) -> void:
	if not _building_defs.has(building_id):
		push_error("Town: missing building def \"%s\"" % building_id)
		return
	var def: Dictionary = _building_defs[building_id]
	if not TownCore.is_unlocked(def, SaveManager.state["tech"]["researched"]):
		return  # the label already says what research it needs
	var town: Dictionary = SaveManager.state["town"]
	var level := TownCore.building_level(town, building_id)
	var cost := TownCore.next_level_cost(def, level)
	if cost.is_empty():
		return  # maxed — the label already says so
	if not Ledger.try_spend_all(cost, "building-cost"):
		_flash_plot_label(_plot_for(building_id), "Not enough resources")
		return
	SaveManager.state["town"] = TownCore.set_building(town, building_id, level + 1)
	EventBus.building_built.emit(building_id, level + 1)
	SaveManager.save_current()  # a built building must never be lost to a crash
	_refresh_plots()


func _refresh_plots() -> void:
	for plot in _plots:
		_refresh_plot(plot)


func _refresh_plot(plot: Area3D) -> void:
	var building_id := str(plot.get_meta("building_id"))
	var def: Dictionary = _building_defs.get(building_id, {})
	var display_name := str(def.get("name", building_id))
	var label := plot.get_node("Label") as Label3D
	var mesh := plot.get_node("BuildingMesh") as MeshInstance3D
	var level := TownCore.building_level(SaveManager.state["town"], building_id)
	# The building visibly grows with its level (placeholder box — PRD: each level
	# changes the visual).
	mesh.visible = level > 0
	if level > 0:
		# Box mesh is origin-centred: scale up per level and lift so it grows upward.
		mesh.scale = Vector3(1.0, float(level), 1.0)
		mesh.position = Vector3(0.0, 1.1 * float(level), 0.0)
	if not TownCore.is_unlocked(def, SaveManager.state["tech"]["researched"]):
		label.text = "%s — locked (research: %s)" % [display_name, _gate_name(def)]
		label.modulate = Color(1, 1, 1, 0.5)
		return
	label.modulate = Color.WHITE
	var cost := TownCore.next_level_cost(def, level)
	if cost.is_empty():
		label.text = "%s (max level)" % display_name
	else:
		var action := "build" if level == 0 else "upgrade to L%d" % (level + 1)
		label.text = "%s — E to %s (%s)" % [display_name, action, _cost_text(cost)]


func _gate_name(def: Dictionary) -> String:
	var gate: Dictionary = def.get("unlocked_by") if def.get("unlocked_by") != null else {}
	var tech_id := str(gate.get("id", "?"))
	return str((_tech_defs.get(tech_id, {}) as Dictionary).get("name", tech_id))


func _plot_for(building_id: String) -> Area3D:
	for plot in _plots:
		if str(plot.get_meta("building_id")) == building_id:
			return plot
	return null


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in cost:
		parts.append("%d %s" % [int(cost[id]), id])
	return ", ".join(parts)


func _flash_plot_label(plot: Area3D, msg: String) -> void:
	if plot == null:
		return
	var label := plot.get_node("Label") as Label3D
	label.text = msg
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self) and is_instance_valid(plot) and label.text == msg:
		_refresh_plot(plot)
