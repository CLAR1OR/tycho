extends Node3D
## Placeholder town hub (vertical slice, PRD §7.9 upgrade-hub model).
##
## One walkable square with two interactions: a BUILD PLOT (Linnea's Study — the one
## v1-slice building; walk in, press E to build/upgrade through its 3 levels) and the
## DUNGEON PORTAL (step in to start a run — signalled up to game.gd, which owns run
## flow). Vendors, dialogue, and the unlock cascade land in later slices; the plot
## deliberately ignores `unlocked_by` gating until the cascade exists.
##
## Town STATE is the save's town section (a plain data object, architecture-schemas
## §6): this scene reads/writes SaveManager.state["town"] via pure TownCore helpers.
## No TownState autoload yet — one town in v1 doesn't need it.

const BUILDING_ID := "linneas-study"

signal run_requested  # the player stepped into the dungeon portal

var _defs: Dictionary = {}
var _in_plot: bool = false

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _plot: Area3D = $BuildPlot
@onready var _plot_label: Label3D = $BuildPlot/Label
@onready var _building_mesh: MeshInstance3D = $BuildPlot/BuildingMesh
@onready var _portal: Area3D = $DungeonPortal
@onready var _day_label: Label = $HUD/DayInfo
@onready var _hint_label: Label = $HUD/Hint


func _ready() -> void:
	_rig.set_target(_player)
	_player.position = Vector3(0, 0, 8)
	_defs = DataLoader.load_domain("buildings")
	_portal.body_entered.connect(_on_portal_body_entered)
	_plot.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_plot = true)
	_plot.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_in_plot = false)
	var day := int(SaveManager.state["story"]["counters"].get("runs", 0)) + 1
	_day_label.text = "Home — Day %d" % day
	_hint_label.text = "WASD move - build at the plot (E) - step into the portal to descend"
	_refresh_plot()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _in_plot:
		_try_build()


func _on_portal_body_entered(body: Node3D) -> void:
	if body is Player:
		run_requested.emit()


# --- Build plot ------------------------------------------------------------------

func _try_build() -> void:
	if not _defs.has(BUILDING_ID):
		push_error("Town: missing building def \"%s\"" % BUILDING_ID)
		return
	var town: Dictionary = SaveManager.state["town"]
	var level := TownCore.building_level(town, BUILDING_ID)
	var cost := TownCore.next_level_cost(_defs[BUILDING_ID], level)
	if cost.is_empty():
		return  # maxed — the label already says so
	if not Ledger.try_spend_all(cost, "building-cost"):
		_flash_plot_label("Not enough gold")
		return
	SaveManager.state["town"] = TownCore.set_building(town, BUILDING_ID, level + 1)
	EventBus.building_built.emit(BUILDING_ID, level + 1)
	SaveManager.save_current()  # a built building must never be lost to a crash
	_refresh_plot()


func _refresh_plot() -> void:
	var level := TownCore.building_level(SaveManager.state["town"], BUILDING_ID)
	var def: Dictionary = _defs.get(BUILDING_ID, {})
	var display_name := str(def.get("name", BUILDING_ID))
	# The building visibly grows with its level (placeholder box — PRD: each level
	# changes the visual).
	_building_mesh.visible = level > 0
	if level > 0:
		# Box mesh is origin-centred: scale up per level and lift so it grows upward.
		_building_mesh.scale = Vector3(1.0, float(level), 1.0)
		_building_mesh.position = Vector3(0.0, 1.1 * float(level), 0.0)
	var cost := TownCore.next_level_cost(def, level)
	if cost.is_empty():
		_plot_label.text = "%s (max level)" % display_name
	else:
		var action := "build" if level == 0 else "upgrade to L%d" % (level + 1)
		_plot_label.text = "%s — E to %s (%s)" % [display_name, action, _cost_text(cost)]


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in cost:
		parts.append("%d %s" % [int(cost[id]), id])
	return ", ".join(parts)


func _flash_plot_label(msg: String) -> void:
	_plot_label.text = msg
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self) and _plot_label.text == msg:
		_refresh_plot()
