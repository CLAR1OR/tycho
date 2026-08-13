extends Control
class_name PauseMenu
## ESC pause menu (design 2026-07-07; made FULLSCREEN 2026-07-07; **migrated to Ember
## 2026-08-13**, Tier A of design/ui-hud.md § "Migrating to Ember"). Spawned once by
## game.gd on the HUD layer (survives scene swaps),
## PROCESS_MODE_ALWAYS, hidden by default. ESC (ui_cancel) toggles it; while open the tree
## is paused. Guards: inert at the slot-select screen; ignores ESC while another panel
## already owns the pause (dialogue / echo offer / F1 / F2 / tech / forge / etchings) —
## only our OWN open state may unpause.
##
## Offers Resume, Forfeit Run (in-run only), and Save & Quit. Forfeit and in-run Save & Quit
## obey the Hades quit-gate: leaving a room is allowed only after clearing it or while still
## untouched (combat_room.can_menu_quit()). Forfeit rolls the slot back to portal entry
## ("like it never happened", game.gd.forfeit_run). In-run Save & Quit writes NOTHING to
## disk — the floor-start checkpoint already on disk IS the save (the no-mid-run-write
## statistics invariant; see game.gd.forfeit_run / save_and_quit).
##
## Code-built like the other panels. Public methods (open / close / forfeit / save_and_quit
## / can_quit_now) let the headless smoke drive it; gated actions no-op with a visible reason.
##
## Fullscreen: a scrim over the whole screen with a centred column. It lives on game.gd's
## `$HUD` CanvasLayer, where anchors set in _ready get NO layout pass (the RunHud geometry
## quirk) — so `size` is synced to the viewport on open and each frame while visible.
##
## THIS IS THE FIRST SCREEN ON `EmberTheme`, and it is a Control TREE rather than a `_draw`
## on purpose: the content is a stack of real Buttons that need hover, focus, disabled and
## click, and containers already do that correctly. Everything visual now comes from the
## theme — the diff for the migration was deleting overrides, not adding them. Two notes:
##   - The backdrop reads `EmberHud.COL_SCRIM` rather than carrying its own copy, so every
##     Ember screen dims the world by the same amount from one dial.
##   - Only **Resume** wears `EmberAction` (the gold-framed primary). Gold means state, so
##     making all five buttons gold would say nothing. The rest rest on the hairline.
##
## RESTYLE ONLY — open/close/forfeit/save_and_quit/can_quit_now/open_settings/
## open_achievements/reshow, every guard, the ESC semantics and all copy are unchanged.

const PANEL_WIDTH := 320.0
## Shown when the Hades gate refuses a mid-run quit (HUMAN: placeholder copy — dial freely).
const GATE_REASON := "Finish the fight first (or leave before taking a hit)."
## Gap between the title and the button column (HUMAN: placeholder — dial).
const TITLE_GAP := 18

var _game: Node = null
var _rows: VBoxContainer = null
var _status_label: Label = null


func setup(game: Node) -> void:
	_game = game
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	theme = EmberTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks so they don't fall through to the game
	var backdrop := ColorRect.new()
	backdrop.color = EmberHud.COL_SCRIM  # one scrim dial for every Ember screen
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	_rows.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(_rows)


func _process(_delta: float) -> void:
	# CanvasLayer-under-_ready layout quirk: keep the fullscreen rect synced to the viewport
	# while shown (also covers window resizes). Cheap; only runs while visible.
	if visible:
		var vp := get_viewport_rect().size
		if size != vp:
			size = vp


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _game == null or bool(_game.call("on_slot_select")):
		return  # nothing to pause at the slot-select screen
	if visible:
		close()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return  # another panel owns the pause — don't hijack ESC to open over it
	open()
	get_viewport().set_input_as_handled()


# --- Open / close (public — buttons, ESC, and the smoke land here) ------------------

## Open the menu and pause the tree.
func open() -> void:
	if visible:
		return
	visible = true
	size = get_viewport_rect().size  # sync now (the quirk); _process keeps it in step
	get_tree().paused = true
	_rebuild()
	Sfx.play("ui-click")


## Close the menu and unpause.
func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	get_viewport().gui_release_focus()


## The Settings button (SET1, 2026-07-09): hide the menu WITHOUT unpausing (the pause stays ours),
## then open the settings page over us via game.gd, asking to be reshown when it closes. Public so
## the smoke drives the same path the button uses.
func open_settings() -> void:
	visible = false
	_game.call("open_settings", self)


## The Achievements button (schemas §5, 2026-07-11): same pattern as Settings — hide without
## unpausing, open the achievements page over us, reshow when it closes. Public for the smoke.
func open_achievements() -> void:
	visible = false
	_game.call("open_achievements", self)


## Reappear after the settings page closed over us: the pause is still ours, so DON'T touch it (and
## no Sfx — this is not a fresh open). Just show, resync the fullscreen rect, and rebuild.
func reshow() -> void:
	visible = true
	size = get_viewport_rect().size
	_rebuild()


# --- Actions (public — gated actions no-op with a visible reason) --------------------

## True when leaving the current scene is allowed: town (or any scene without the gate) is
## always fine; in a run the room's Hades rule decides (cleared, or untouched this room).
func can_quit_now() -> bool:
	var scene: Node = _game.call("current_scene")
	if scene == null or not scene.has_method("can_menu_quit"):
		return true
	return bool(scene.call("can_menu_quit"))


## Forfeit the run — roll the slot back to portal entry (game.gd.forfeit_run). No-op with a
## visible reason if not in a run or if the Hades gate refuses.
func forfeit() -> void:
	if not RunState.in_run():
		_set_status("No run to forfeit.")
		return
	if not can_quit_now():
		_set_status(GATE_REASON)
		return
	close()
	_game.call("forfeit_run")


## Save & Quit to the slot-select screen (game.gd.save_and_quit). In a run the Hades gate
## applies and NO disk write happens (the checkpoint is the save). In town: a real save.
func save_and_quit() -> void:
	if RunState.in_run() and not can_quit_now():
		_set_status(GATE_REASON)
		return
	close()
	_game.call("save_and_quit")


# --- UI ------------------------------------------------------------------------------

func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"EmberTitle"
	_rows.add_child(title)

	_status_label = Label.new()
	_status_label.theme_type_variation = &"EmberDim"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_status_label)

	# Breathing room between the title block and the buttons — Ember has no panel edge to
	# separate them, so the negative space has to.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, TITLE_GAP)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(spacer)

	var in_run := RunState.in_run()
	var allowed := can_quit_now()
	_set_status(_status_line(in_run, allowed))

	# Resume is the primary action — the one gold thing on the screen.
	_button("Resume", close, false, true)
	_button("Settings", open_settings, false)
	# HUMAN: placeholder placement — move the entry if the menu should stay leaner.
	_button("Achievements", open_achievements, false)
	if in_run:
		# Forfeit is offered only in a run (there is nothing to abandon in town).
		_button("Forfeit Run (abandon it, keep nothing)", forfeit, not allowed)
		_button("Quit (run saved at floor start)", save_and_quit, not allowed)
	else:
		_button("Save & Quit", save_and_quit, false)


func _status_line(in_run: bool, allowed: bool) -> String:
	if not in_run:
		return "In town. Save and quit whenever you like."
	if allowed:
		return "In a run. Forfeit abandons it; Quit resumes at this floor's start."
	return GATE_REASON


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _button(text: String, action: Callable, disabled: bool, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.theme_type_variation = &"EmberAction" if primary else &"Button"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(action)
	_rows.add_child(b)
	return b
