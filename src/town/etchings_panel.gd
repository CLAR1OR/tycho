extends Control
class_name EtchingsPanel
## Thomas's meditation screen — "The arms" (E1, human-picked 2026-07-08 via claude.ai/design,
## with two amendments: no bottom hint chip, and the Dust readout is a bare icon + big number,
## no box). Tycho's two arms drawn palm-up (EtchingsArms), four etched marks on them; hover
## lights a mark, click opens its skill menu on the right. Fullscreen, code-built, Slate-themed;
## pauses the game while open. Opened from the meditation spot once etchings are unlocked (B2).
##
## THE NO-SWAP RULE (the core directive): the screen shows the four marks and NOTHING else —
## no ability list, no Equip button, no empty sockets, no "slot" vocabulary. A site shows its
## slot's EQUIPPED ability, else the slot's STARTER (EtchingsArmsCore.displayed_ability); the
## fourth site is the innate dash. Bolt/Surge and the dormant four stay in data + EtchingsCore,
## just unreachable here — ability swapping arrives later as a story beat, not as waiting UI.
##
## AWAKEN framing: a dormant mark's action is "Awaken (n Dust)" (the old "Learn" label). Since
## there is no Equip button, awakening auto-equips the mark to its slot — learn() already does
## this for a fresh unlock into an empty slot, which is exactly the case here.
##
## Logic is EtchingsCore + EtchingsArmsCore (pure, tested); this is screens + wiring.
## learn()/equip()/close()/site_ability() are public so the headless smoke drives the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in SlateHud;
# the arm/sigil visuals in EtchingsArms/SigilIcon). ALL copy below is placeholder — HUMAN pen.
# =====================================================================================
const MARGIN := 20.0
const DOCK_W := 356.0
const DOCK_TOP := 104.0
## A site shows its slot's equipped ability, else this starter (placeholder mapping).
const STARTERS: Dictionary = {"rmb": "push", "q": "snare", "r": "shockwave"}
const SITE_KEY: Dictionary = {"rmb": "RMB", "q": "Q", "r": "R", "spc": "SPC"}
const SUBTITLE := "Tycho lays his arms open. The marks answer the resonance."
const MARK_DEEPENS := "THE MARK DEEPENS"
const DEEP_BLURB := "The resonance goes deeper."
const DORMANT_DESC := "The mark is there, under the skin. It has not answered yet."
const DASH_PRINCIPLE := "inertia"
const DASH_DESC := "The first mark. It was on him when he woke, and it goes deeper than the others do. It does not deepen here."

var _defs: Dictionary = {}
var _selected: String = ""

var _arms: EtchingsArms
var _title: Label
var _subtitle: Label
var _dock: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("etchings_panel")
	theme = SlateTheme.get_theme()


func open() -> void:
	_defs = EtchingsCore.defs()
	# Grant Push + auto-equip it the first time the screen opens after B2 (idempotent).
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var flags: Dictionary = SaveManager.state["story"]["flags"]
	SaveManager.state["combat"]["etchings"] = EtchingsCore.ensure_baseline(etchings, _defs, flags)
	SaveManager.save_current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A near-opaque backdrop over the whole screen (the frame bg of the mock).
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = TechChart.COL_FRAME_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# The arms (drawn + hit-tested).
	_arms = EtchingsArms.new()
	_arms.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_arms)
	_arms.setup(_defs, STARTERS, open_menu)
	# Header: title + subtitle (top-left).
	_title = Label.new()
	_title.text = "Thomas's Favorite Spot — Etchings"
	_title.theme_type_variation = &"TitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"DimLabel"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	# ESC closes the panel (the 2026-07-09 ESC-close pass replaces the Close button).
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under town.gd's $HUD CanvasLayer get no layout pass
	# (size stays 0,0) — sync to the viewport, like the Slate HUDs / tech panel do.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _title != null:
		_title.position = Vector2(MARGIN + 8.0, MARGIN)
	if _subtitle != null:
		_subtitle.position = Vector2(MARGIN + 9.0, MARGIN + 32.0)
	if _dock != null:
		_dock.position = Vector2(size.x - MARGIN - DOCK_W, DOCK_TOP)


# --- Public (menu buttons, arms callback, and the smoke driver all land here) ----------

## A site was clicked — select it and open its skill menu.
func open_menu(slot: String) -> void:
	_selected = slot
	if _arms != null:
		_arms.set_selected(slot)
	_build_menu()


## Awaken / deepen an etching, spending Resonance Dust. On a fresh unlock (awaken) it
## auto-equips to the empty matching slot — the no-swap screen has no separate Equip. No-op
## if dormant-by-code, maxed, or unaffordable. (Body unchanged from the list panel.)
func learn(id: String) -> void:
	if not _defs.has(id):
		push_error("EtchingsPanel: unknown etching \"%s\"" % id)
		return
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	if not EtchingsCore.can_learn(_defs[id], Ledger.get_amount("resonance-dust"), etchings):
		return
	var was_new := not EtchingsCore.is_unlocked(etchings, id)
	var cost := EtchingsCore.learn_cost(_defs[id], EtchingsCore.level_of(etchings, id))
	if not Ledger.try_spend("resonance-dust", float(cost), "etching"):
		return
	etchings = EtchingsCore.learn(etchings, id)
	# Auto-equip a fresh unlock into an empty slot of its kind (the awaken = equip step).
	var slot := str((_defs[id] as Dictionary).get("slot", ""))
	if was_new and str((etchings.get("slots", {}) as Dictionary).get(slot, "")) == "":
		etchings = EtchingsCore.equip(etchings, slot, id, _defs)
	SaveManager.state["combat"]["etchings"] = etchings
	SaveManager.save_current()
	if _arms != null:
		_arms.refresh()
	_build_menu()


## Equip `id` into `slot` — retained so the smoke can still exercise the equip path (the
## screen itself never shows an Equip button under the no-swap rule).
func equip(slot: String, id: String) -> void:
	SaveManager.state["combat"]["etchings"] = EtchingsCore.equip(
		SaveManager.state["combat"]["etchings"], slot, id, _defs)
	SaveManager.save_current()
	if _arms != null:
		_arms.refresh()
	_build_menu()


## The ability a site displays (equipped-else-starter; "dash" for the SPC site). Smoke/debug.
func site_ability(slot: String) -> String:
	if slot == "spc":
		return "dash"
	return EtchingsArmsCore.displayed_ability(slot, SaveManager.state["combat"]["etchings"], STARTERS)


# --- The skill menu (right-side dock) -------------------------------------------------

func _build_menu() -> void:
	if _dock != null:
		_dock.queue_free()
		_dock = null
	if _selected.is_empty():
		return
	var is_dash := _selected == "spc"
	var ability_id := site_ability(_selected)
	var def: Dictionary = _defs.get(ability_id, {})
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var level := 0 if is_dash else EtchingsCore.level_of(etchings, ability_id)

	_dock = PanelContainer.new()
	_dock.custom_minimum_size = Vector2(DOCK_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	_dock.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	# Head: sigil + name + key chip.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var sig := SigilIcon.new()
	sig.setup("dash" if is_dash else ability_id, SlateHud.COL_READY,
		SlateHud._with_fallback(SlateHud.FONT_NUM_FILE))
	sig.custom_minimum_size = Vector2(34, 34)
	head.add_child(sig)
	var name_l := Label.new()
	name_l.text = "Dash" if is_dash else str(def.get("name", ability_id))
	name_l.theme_type_variation = &"TitleLabel"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_l)
	var key_l := Label.new()
	key_l.text = str(SITE_KEY.get(_selected, ""))
	key_l.theme_type_variation = &"NumLabel"
	key_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(key_l)
	box.add_child(head)

	# Chips: principle (dust) + cooldown (dim). Dash shows only its principle.
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	var principle := DASH_PRINCIPLE if is_dash else str(def.get("principle", ""))
	chips.add_child(_chip(principle, SlateHud.COL_DUST))
	if not is_dash:
		chips.add_child(_chip("%ds cooldown" % int(def.get("cooldown_s", 0)), SlateHud.COL_KEY_TEXT))
	box.add_child(chips)

	# Description.
	var desc := DASH_DESC if is_dash else (DORMANT_DESC if level < 1 else str(def.get("desc", "")))
	if not desc.is_empty():
		box.add_child(_wrap(desc))

	# Level track (only for an awake, real etching — the dash and dormant marks show none).
	if not is_dash and level >= 1:
		var head_l := Label.new()
		head_l.text = MARK_DEEPENS
		head_l.theme_type_variation = &"DimLabel"
		box.add_child(head_l)
		var blurbs: Array = def.get("level_blurbs", [])
		for lvl in range(level, EtchingsCore.MAX_LEVEL + 1):
			box.add_child(_level_row(lvl, level, blurbs))

	# Action button.
	if not is_dash:
		var action := EtchingsArmsCore.menu_action(def, etchings)
		box.add_child(_action_node(ability_id, action))

	add_child(_dock)


func _level_row(lvl: int, current: int, blurbs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pip := Label.new()
	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blurb := str(blurbs[lvl - 1]) if lvl - 1 < blurbs.size() else "L%d" % lvl
	if lvl == current:                                       # now — gold pip
		pip.text = "●"
		pip.add_theme_color_override("font_color", SlateHud.COL_READY)
		txt.text = "L%d  %s" % [lvl, blurb]
	elif lvl == current + 1:                                 # next — hollow pip
		pip.text = "○"
		pip.add_theme_color_override("font_color", SlateHud.COL_SLATE_BORDER)
		txt.text = "L%d  %s" % [lvl, blurb]
	else:                                                    # deeper — dim italic
		pip.text = "○"
		pip.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)
		txt.text = "L%d  %s" % [lvl, DEEP_BLURB]
		txt.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)
	row.add_child(pip)
	row.add_child(txt)
	return row


## The awaken / deepen button, or the inert Mastered line.
func _action_node(id: String, action: Dictionary) -> Control:
	var kind := str(action["kind"])
	if kind == "mastered":
		var l := Label.new()
		l.text = "Mastered (L%d)" % EtchingsCore.MAX_LEVEL
		l.theme_type_variation = &"DimLabel"
		l.add_theme_color_override("font_color", SlateHud.COL_READY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var cost := int(action["cost"])
	var b := Button.new()
	if kind == "awaken":
		b.text = "Awaken  (%d Dust)" % cost
	else:
		b.text = "Deepen to L%d  (%d Dust)" % [int(action["to_level"]), cost]
	b.disabled = Ledger.get_amount("resonance-dust") < float(cost)
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(learn.bind(id))
	return b


func _chip(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"NumLabel"
	l.add_theme_color_override("font_color", col)
	return l


func _wrap(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
