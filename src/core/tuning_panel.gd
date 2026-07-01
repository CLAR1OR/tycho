extends PanelContainer
class_name TuningPanel
## Runtime FEEL-tuning panel for the Phase 0 combat-feel gate (debug tooling).
##
## F1 toggles it; while open the game is PAUSED (freeze mid-fight, drag sliders,
## F1 again to resume and feel the change). Every slider writes straight into the
## live objects — player/camera/room @exports, and the static CombatFX / EnemyDummy
## knobs — so nothing here persists: when a value feels right, hit **Copy changed**
## and paste the clipboard into the matching script/scene (the dial board
## design/feel-tuning.md maps every name to its home).
##
## Built entirely in code (no .tscn) and spawned by feel_room.gd. Throwaway with
## the rest of the sandbox.

const PANEL_WIDTH := 440.0
const NAME_COL_WIDTH := 195.0
const FONT_SIZE := 13

var _entries: Array[Dictionary] = []
var _rows_box: VBoxContainer = null


## Wire up the live objects and build the UI. Call once, right after add_child.
func setup(player: Player, rig: CameraRig, room: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must run while the tree is paused
	visible = false
	# NOT set_anchors_preset: that recomputes offsets to preserve the current
	# (tiny) rect, crushing the panel to min size. This one zeroes the offsets.
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -PANEL_WIDTH

	_define_entries(player, rig, room)
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tuning_panel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if not visible:
		get_viewport().gui_release_focus()  # don't leave Space/arrows driving a slider


# --- The dial list ------------------------------------------------------------
# One dictionary per slider: where it lives, how to read/write it, slider range.
# `sec` groups rows under a header and tells you which file the value belongs to.

func _define_entries(p: Player, rig: CameraRig, room: Node3D) -> void:
	var E := func(sec: String, label: String, getv: Callable, setv: Callable,
			lo: float, hi: float, step: float, as_int: bool = false) -> void:
		_entries.append({
			"section": sec, "label": label, "get": getv, "set": setv,
			"min": lo, "max": hi, "step": step, "int": as_int,
		})

	var sp := "Player — player.gd"
	E.call(sp, "move_speed", func() -> float: return p.move_speed,
			func(v: float) -> void: p.move_speed = v, 3.0, 14.0, 0.1)
	E.call(sp, "dash_speed", func() -> float: return p.dash_speed,
			func(v: float) -> void: p.dash_speed = v, 10.0, 40.0, 0.5)
	E.call(sp, "dash_cooldown", func() -> float: return p.dash_cooldown,
			func(v: float) -> void: p.dash_cooldown = v, 0.1, 2.5, 0.05)
	E.call(sp, "dash_iframes", func() -> float: return p.dash_iframes,
			func(v: float) -> void: p.dash_iframes = v, 0.05, 0.6, 0.01)
	E.call(sp, "attack_windup", func() -> float: return p.attack_windup,
			func(v: float) -> void: p.attack_windup = v, 0.0, 0.3, 0.01)
	E.call(sp, "attack_active", func() -> float: return p.attack_active,
			func(v: float) -> void: p.attack_active = v, 0.04, 0.3, 0.01)
	E.call(sp, "attack_recover", func() -> float: return p.attack_recover,
			func(v: float) -> void: p.attack_recover = v, 0.02, 0.6, 0.01)
	E.call(sp, "attack_recover_finisher", func() -> float: return p.attack_recover_finisher,
			func(v: float) -> void: p.attack_recover_finisher = v, 0.1, 1.2, 0.05)
	E.call(sp, "attack_damage", func() -> float: return float(p.attack_damage),
			func(v: float) -> void: p.attack_damage = int(v), 5.0, 60.0, 1.0, true)
	E.call(sp, "attack_damage_finisher", func() -> float: return float(p.attack_damage_finisher),
			func(v: float) -> void: p.attack_damage_finisher = int(v), 10.0, 120.0, 5.0, true)
	E.call(sp, "attack_move_mult", func() -> float: return p.attack_move_mult,
			func(v: float) -> void: p.attack_move_mult = v, 0.0, 1.0, 0.05)
	E.call(sp, "combo_continue_window", func() -> float: return p.combo_continue_window,
			func(v: float) -> void: p.combo_continue_window = v, 0.1, 1.0, 0.05)
	E.call(sp, "hit_grace", func() -> float: return p.hit_grace,
			func(v: float) -> void: p.hit_grace = v, 0.0, 1.0, 0.05)

	var sl := "Aim assist — player.gd"
	E.call(sl, "lunge_speed", func() -> float: return p.lunge_speed,
			func(v: float) -> void: p.lunge_speed = v, 0.0, 20.0, 0.5)
	E.call(sl, "lunge_range", func() -> float: return p.lunge_range,
			func(v: float) -> void: p.lunge_range = v, 0.0, 8.0, 0.25)
	E.call(sl, "lunge_cone_deg", func() -> float: return p.lunge_cone_deg,
			func(v: float) -> void: p.lunge_cone_deg = v, 20.0, 180.0, 5.0)
	E.call(sl, "lunge_stop", func() -> float: return p.lunge_stop,
			func(v: float) -> void: p.lunge_stop = v, 0.5, 3.0, 0.1)
	E.call(sl, "lunge_whiff_mult", func() -> float: return p.lunge_whiff_mult,
			func(v: float) -> void: p.lunge_whiff_mult = v, 0.0, 1.0, 0.05)

	var sh := "Hitstop — fx.gd"
	E.call(sh, "hitstop_scale", func() -> float: return CombatFX.hitstop_scale,
			func(v: float) -> void: CombatFX.hitstop_scale = v, 0.0, 0.3, 0.01)
	E.call(sh, "hitstop_light", func() -> float: return CombatFX.hitstop_light,
			func(v: float) -> void: CombatFX.hitstop_light = v, 0.0, 0.15, 0.005)
	E.call(sh, "hitstop_finisher", func() -> float: return CombatFX.hitstop_finisher,
			func(v: float) -> void: CombatFX.hitstop_finisher = v, 0.0, 0.3, 0.005)
	E.call(sh, "hitstop_kill", func() -> float: return CombatFX.hitstop_kill,
			func(v: float) -> void: CombatFX.hitstop_kill = v, 0.0, 0.35, 0.005)

	var sc := "Camera — camera_rig.gd"
	E.call(sc, "follow_lerp", func() -> float: return rig.follow_lerp,
			func(v: float) -> void: rig.follow_lerp = v, 2.0, 20.0, 0.5)
	E.call(sc, "cam_height (offset.y)", func() -> float: return rig.cam_offset.y,
			func(v: float) -> void: rig.cam_offset.y = v, 8.0, 25.0, 0.5)
	E.call(sc, "cam_pullback (offset.z)", func() -> float: return rig.cam_offset.z,
			func(v: float) -> void: rig.cam_offset.z = v, 3.0, 16.0, 0.5)
	E.call(sc, "cam_pitch", func() -> float: return rig.cam_pitch,
			func(v: float) -> void: rig.cam_pitch = v, -80.0, -35.0, 1.0)
	E.call(sc, "shake_decay", func() -> float: return rig.shake_decay,
			func(v: float) -> void: rig.shake_decay = v, 2.0, 14.0, 0.5)
	E.call(sc, "shake_on_hit", func() -> float: return room.shake_on_hit,
			func(v: float) -> void: room.shake_on_hit = v, 0.0, 1.0, 0.05)

	var sr := "Wave — feel_room.gd"
	E.call(sr, "enemy_count (next wave)", func() -> float: return float(room.enemy_count),
			func(v: float) -> void: room.enemy_count = int(v), 1.0, 12.0, 1.0, true)
	E.call(sr, "respawn_delay", func() -> float: return room.respawn_delay,
			func(v: float) -> void: room.respawn_delay = v, 0.0, 3.0, 0.1)
	E.call(sr, "spawn_radius", func() -> float: return room.spawn_radius,
			func(v: float) -> void: room.spawn_radius = v, 8.0, 26.0, 0.5)

	var se := "Crowd — enemy_dummy.gd (all enemies)"
	E.call(se, "max_attackers", func() -> float: return float(EnemyDummy.max_attackers),
			func(v: float) -> void: EnemyDummy.max_attackers = int(v), 1.0, 5.0, 1.0, true)
	E.call(se, "circle_speed_mult", func() -> float: return EnemyDummy.circle_speed_mult,
			func(v: float) -> void: EnemyDummy.circle_speed_mult = v, 0.3, 1.2, 0.05)
	E.call(se, "separation_force", func() -> float: return EnemyDummy.separation_force,
			func(v: float) -> void: EnemyDummy.separation_force = v, 0.0, 15.0, 0.5)
	E.call(se, "close_timeout", func() -> float: return EnemyDummy.close_timeout,
			func(v: float) -> void: EnemyDummy.close_timeout = v, 0.5, 3.0, 0.1)


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var title := Label.new()
	title.text = "FEEL TUNING — game paused. F1 to close & feel it."
	title.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	outer.add_child(title)

	var note := Label.new()
	note.text = "Live only — use Copy changed, then paste into the scripts to keep."
	note.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	note.modulate = Color(1, 1, 1, 0.6)
	outer.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	var last_section := ""
	for entry in _entries:
		if entry["section"] != last_section:
			last_section = entry["section"]
			_add_section_header(last_section)
		_add_row(entry)

	var buttons := HBoxContainer.new()
	outer.add_child(buttons)
	var reset_btn := Button.new()
	reset_btn.text = "Reset all"
	reset_btn.pressed.connect(_reset_all)
	buttons.add_child(reset_btn)
	var copy_btn := Button.new()
	copy_btn.text = "Copy changed"
	copy_btn.pressed.connect(_copy_changed)
	buttons.add_child(copy_btn)


func _add_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", FONT_SIZE)
	header.modulate = Color(0.75, 0.9, 1.0)
	_rows_box.add_child(header)


func _add_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	_rows_box.add_child(row)

	var name_label := Label.new()
	name_label.text = entry["label"]
	name_label.custom_minimum_size.x = NAME_COL_WIDTH
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = entry["min"]
	slider.max_value = entry["max"]
	slider.step = entry["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52.0
	value_label.add_theme_font_size_override("font_size", FONT_SIZE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var initial: float = entry["get"].call()
	entry["initial"] = initial
	entry["slider"] = slider
	entry["value_label"] = value_label
	slider.set_value_no_signal(initial)
	value_label.text = _fmt(entry, initial)
	slider.value_changed.connect(func(v: float) -> void:
		entry["set"].call(v)
		value_label.text = _fmt(entry, v))


func _fmt(entry: Dictionary, v: float) -> String:
	return str(int(v)) if entry["int"] else "%.2f" % v


func _reset_all() -> void:
	for entry in _entries:
		(entry["slider"] as HSlider).value = entry["initial"]  # fires value_changed → applies


func _copy_changed() -> void:
	var lines := PackedStringArray()
	for entry in _entries:
		var v: float = (entry["slider"] as HSlider).value
		if not is_equal_approx(v, entry["initial"]):
			lines.append("%s  →  %s = %s" % [entry["section"], entry["label"], _fmt(entry, v)])
	var text := "(no changes)" if lines.is_empty() else "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print("[TuningPanel] copied:\n", text)
