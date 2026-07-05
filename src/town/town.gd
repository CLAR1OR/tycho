extends Node3D
## Placeholder town hub (vertical slice, PRD §7.9 upgrade-hub model).
##
## Interactions (all placeholder-boxy, E to use):
## - BUILD PLOTS — any Area3D child with `metadata/building_id`. Walk in, press E
##   to build/upgrade through the building's 3 levels. Plots gated by tech
##   (`unlocked_by` via TownCore.is_unlocked) show as locked until researched.
## - SOPHIA'S DESK — opens the research screen (TechPanel: invest Knowledge/Shards
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
@onready var _desk: Area3D = $SophiasDesk
@onready var _forge: Area3D = $MarasForge
@onready var _portal: Area3D = $DungeonPortal
@onready var _day_label: Label = $HUD/DayInfo
@onready var _food_label: Label = $HUD/FoodStatus
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
	# Food upkeep (design/food-upkeep.md): the Well-Fed indicator only means something
	# once a day has ticked (day 1 = no tick yet); reads the last tick's stored status.
	if day > 1:
		var fed := bool(SaveManager.state["town"].get("well_fed", false))
		_food_label.text = "Well-Fed (+25% production)" if fed else "Short on food (no bonus)"
	else:
		_food_label.text = ""
	_hint_label.text = "WASD move - E interact (plots, desk, forge, people) - the portal starts a run"
	_refresh_facilities()
	# Spine/cutscene beats can force-play on a town visit — max 1 (spec): this runs
	# once per town instance, so one visit = at most one forced scene. Deferred a
	# frame so the scene (and any save/swap in flight) settles first.
	call_deferred("_check_force_play")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# Facilities re-check their story-flag gate on every press — a beat could have
	# fired mid-visit (a talk sets a flag) and opened the door since you walked in.
	if _in_desk:
		if open_tech_panel() == null:
			_flash_facility(_desk, "Sophia: not yet.")
	elif _in_forge:
		if open_forge_panel() == null:
			_flash_facility(_forge, "Mara: not yet.")
	elif _in_npc != null:
		talk_to(str(_in_npc.get_meta("npc_id")))
	elif _in_plot != null:
		_try_build(str(_in_plot.get_meta("building_id")))


func _on_portal_body_entered(body: Node3D) -> void:
	if body is Player:
		run_requested.emit()


## Public (game flow + smoke driver): open Sophia's research screen, or null if the
## tech system hasn't been unlocked yet (B3 — Sophia cracks the shards).
func open_tech_panel() -> TechPanel:
	if not UnlocksCore.is_unlocked(SaveManager.state, "tech"):
		return null
	var panel := TechPanel.new()
	$HUD.add_child(panel)
	panel.open()
	return panel


## Public (game flow + smoke driver): open Mara's Forge, or null if the weapons
## system hasn't been unlocked yet (B1 — Mara and the ore).
func open_forge_panel() -> ForgePanel:
	if not UnlocksCore.is_unlocked(SaveManager.state, "weapons"):
		return null
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
		SaveManager.save_current()
		# A cascade beat (b1/b3/b4) may have just set its flag — reopen the facility
		# it gates without waiting for the next town visit.
		_refresh_facilities())
	return panel


# --- Build plots ------------------------------------------------------------------

func _try_build(building_id: String) -> void:
	if not _building_defs.has(building_id):
		push_error("Town: missing building def \"%s\"" % building_id)
		return
	# The build plots stay shut until Herzog opens the ledger (B4, PRD §7.1). The
	# label already says so; a press just flashes the hint.
	if not UnlocksCore.is_unlocked(SaveManager.state, "building"):
		_flash_plot_label(_plot_for(building_id), "Herzog: not yet.")
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


## Re-label the three story-gated facilities (forge, desk, and every plot) against
## the current unlock flags. Called on entry and after any beat that sets a flag.
func _refresh_facilities() -> void:
	_refresh_facility(_forge, "weapons", "Mara's Forge", "E for weapons",
		"Mara hasn't offered her services")
	_refresh_facility(_desk, "tech", "Sophia's Desk", "E to research",
		"Sophia hasn't cracked the shards")
	_refresh_plots()


func _refresh_facility(area: Area3D, system: String, display_name: String,
		open_hint: String, locked_reason: String) -> void:
	var label := area.get_node("Label") as Label3D
	if UnlocksCore.is_unlocked(SaveManager.state, system):
		label.text = "%s — %s" % [display_name, open_hint]
		label.modulate = Color.WHITE
	else:
		label.text = "%s — locked (%s)" % [display_name, locked_reason]
		label.modulate = Color(1, 1, 1, 0.5)


## Brief acknowledgment flash when a locked facility is pressed (the permanent label
## carries the diegetic reason; this just confirms the press registered).
func _flash_facility(area: Area3D, msg: String) -> void:
	var label := area.get_node("Label") as Label3D
	label.text = msg
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self) and is_instance_valid(area):
		_refresh_facilities()


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
	# The whole build system is gated on B4 (Herzog opens the ledger) — that gate
	# reads first, before any per-building tech gate.
	if not UnlocksCore.is_unlocked(SaveManager.state, "building"):
		label.text = "%s — locked (Herzog hasn't opened the ledger)" % display_name
		label.modulate = Color(1, 1, 1, 0.5)
		return
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
