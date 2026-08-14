extends Control
class_name EtchingsPanel
## Thomas's meditation screen — "The arms" (E1, human-picked 2026-07-08 via claude.ai/design,
## with two amendments: no bottom hint chip, and the Dust readout is a bare icon + big number,
## no box). Tycho's two arms drawn palm-up (EtchingsArms), four etched marks on them; hover
## lights a mark, click opens its skill menu on the right. Fullscreen, code-built,
## EMBER-themed (migrated 2026-08-14, Tier B); pauses the game while open. Opened from the
## meditation spot once etchings are unlocked (B2).
##
## The Ember migration is a RESTYLE — every public method, the no-swap rule, the transactions
## and all copy are byte-identical, and the smoke drives it unchanged. What moved: the
## backdrop ColorRect is gone (EtchingsArms draws the shared scrim); the right dock's panel
## is transparent, bounded by a VERTICAL hairline on its inner edge, which is the anchor's
## own hero/dock divider; the level track's "●/○" text pips became real drawn diamonds; and
## Awaken/Deepen is the screen's one `EmberAction`.
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
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts live in EmberHud;
# the arm/sigil visuals in EtchingsArms/SigilIcon). ALL copy below is placeholder — HUMAN pen.
# =====================================================================================
const DOCK_W := 382.0   # +26 over Slate's 356: the dock's new hairline divider costs that
const DOCK_TOP := 104.0
const FS_DOCK_NAME := EmberHud.FS_HERO   # the dock's ability name (display, under title size)
## A site shows its slot's equipped ability, else this starter (placeholder mapping).
const STARTERS: Dictionary = {"rmb": "push", "q": "snare", "r": "shockwave"}
const SITE_KEY: Dictionary = {"rmb": "RMB", "q": "Q", "r": "R", "spc": "SPC"}
const SUBTITLE := "Tycho lays his arms open. The marks answer the resonance."
const MARK_DEEPENS := "THE MARK DEEPENS"
const DEEP_BLURB := "The resonance goes deeper."
const DORMANT_DESC := "The mark is there, under the skin. It has not answered yet."
const DASH_PRINCIPLE := "inertia"
const DASH_DESC := "The first mark. It was on him when he woke, and it goes deeper than the others do. It does not deepen here."
## The two-page tab row (E1 = the marks; the second page = Passive Attunements). Placeholder copy.
const TAB_MARKS := "THE MARKS"
const TAB_BODY := "THE BODY"
const TAB_TOP := 70.0
const TAB_GAP := 18.0

var _defs: Dictionary = {}
var _selected: String = ""
var _page: String = "marks"  # "marks" (the E1 arms) or "body" (attunements)

var _arms: EtchingsArms
var _title: Label
var _subtitle: Label
var _dock: PanelContainer
var _attn_page: AttunementsPage
var _tab_marks: Button
var _tab_body: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("etchings_panel")
	theme = EmberTheme.get_theme()


func open() -> void:
	_defs = EtchingsCore.defs()
	# Grant Push + auto-equip it the first time the screen opens after B2 (idempotent).
	var etchings: Dictionary = SaveManager.state["combat"]["etchings"]
	var flags: Dictionary = SaveManager.state["story"]["flags"]
	SaveManager.state["combat"]["etchings"] = EtchingsCore.ensure_baseline(etchings, _defs, flags)
	SaveManager.save_current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The arms (drawn + hit-tested). They draw the scrim as their first act, so this screen
	# no longer carries a backdrop ColorRect of its own — one scrim dial, in EmberHud.
	_arms = EtchingsArms.new()
	_arms.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_arms)
	_arms.setup(_defs, STARTERS, open_menu)
	# The attunements page (bible, PRD §7.4) — hidden behind the arms until the tab swaps.
	# Built once; it reads the save + Ledger on each refresh. It is added HERE, before the
	# header, because it lays down its own scrim (the arms are hidden on its tab, so their
	# scrim goes with them) — added after the header, that scrim dimmed the screen's own
	# title and subtitle. Caught by the menu probe, invisible to every test.
	_attn_page = AttunementsPage.new()
	_attn_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_attn_page)
	_attn_page.setup(AttunementsCore.defs(), deepen_attunement)
	_attn_page.visible = false
	# Header: title + subtitle (top-left).
	_title = Label.new()
	_title.text = "Thomas's Favorite Spot — Etchings"
	_title.theme_type_variation = &"EmberTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"EmberDim"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	# The tab row (added LAST so the tabs sit above the pages). Two quiet mono-caps chips.
	_tab_marks = _make_tab(TAB_MARKS, "marks")
	_tab_body = _make_tab(TAB_BODY, "body")
	add_child(_tab_marks)
	add_child(_tab_body)
	_apply_page()
	get_tree().paused = true


func _make_tab(text: String, page: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.theme_type_variation = &"EmberHead"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sfx.play("ui-click")
		switch_page(page))
	return b


## Swap between the marks page (E1) and the attunements page. Public for the smoke.
func switch_page(page: String) -> void:
	if page != "marks" and page != "body":
		return
	_page = page
	_apply_page()


func _apply_page() -> void:
	var marks := _page == "marks"
	if _arms != null:
		_arms.visible = marks
	if _dock != null:
		_dock.visible = marks
	if _attn_page != null:
		_attn_page.visible = not marks
		if not marks:
			_attn_page.refresh()
	# Selected tab = gold; the other dim. (Gold as state — which page you are on.)
	if _tab_marks != null:
		_tab_marks.add_theme_color_override("font_color",
			EmberHud.COL_ACCENT if marks else EmberHud.COL_INK_DIM)
	if _tab_body != null:
		_tab_body.add_theme_color_override("font_color",
			EmberHud.COL_ACCENT if not marks else EmberHud.COL_INK_DIM)


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
	# Bands from EmberMenuCore, so this header sits exactly where every other Ember screen's
	# header sits. A band's y is the line's CENTRE; a Label positions by its top-left.
	var bands := EmberMenuCore.catalogue(size)
	var left: float = (bands["title"] as Rect2).position.x
	if _title != null:
		_title.position = EmberMenuCore.label_pos(bands["title"], _title.size.y)
	if _subtitle != null:
		_subtitle.position = EmberMenuCore.label_pos(bands["subtitle"], _subtitle.size.y)
	if _dock != null:
		_dock.position = Vector2(size.x - EmberMenuCore.PAD_PX - DOCK_W, DOCK_TOP)
	if _tab_marks != null:
		_tab_marks.position = Vector2(left, TAB_TOP)
	if _tab_body != null:
		_tab_body.position = Vector2(left + _tab_marks.size.x + TAB_GAP, TAB_TOP)



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


## Deepen a Passive Attunement (bible, PRD §7.4), spending Resonance Dust — the SAME sink as
## the abilities. No-op if maxed or unaffordable. Persists + refreshes the attunements page.
func deepen_attunement(id: String) -> void:
	var adefs := AttunementsCore.defs()
	if not adefs.has(id):
		push_error("EtchingsPanel: unknown attunement \"%s\"" % id)
		return
	var attn: Dictionary = SaveManager.state["combat"].get("attunements", {})
	if not AttunementsCore.can_deepen(adefs[id], Ledger.get_amount("resonance-dust"), attn):
		return
	var cost := AttunementsCore.next_cost(adefs[id], AttunementsCore.level(attn, id))
	if not Ledger.try_spend("resonance-dust", float(cost), "attunement"):
		return
	SaveManager.state["combat"]["attunements"] = AttunementsCore.deepen(attn, id)
	SaveManager.save_current()
	if _attn_page != null:
		_attn_page.refresh()


## The current level of an attunement (0 = un-owned). Smoke/debug.
func attunement_level(id: String) -> int:
	return AttunementsCore.level(SaveManager.state["combat"].get("attunements", {}), id)


## True when the attunements ("body") page is showing. Smoke/debug.
func show_attunements() -> bool:
	return _page == "body"


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

	_dock = PanelContainer.new()   # transparent under EmberTheme — it groups and pads only
	_dock.custom_minimum_size = Vector2(DOCK_W, 0)
	# The dock's inner edge carries a vertical hairline — the anchor's hero/dock divider, and
	# Ember's replacement for the panel border that used to box this column in.
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	_dock.add_child(split)
	split.add_child(VSeparator.new())
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	split.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	# Head: sigil + name + key chip.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var sig := SigilIcon.new()
	sig.setup("dash" if is_dash else ability_id, EmberHud.COL_ACCENT,
		EmberHud._with_fallback(EmberHud.FONT_NUM_FILE))
	sig.custom_minimum_size = Vector2(34, 34)
	head.add_child(sig)
	var name_l := Label.new()
	name_l.text = "Dash" if is_dash else str(def.get("name", ability_id))
	name_l.theme_type_variation = &"EmberTitle"
	# The dock is 356 px wide; the full title size would wrap every two-word ability name.
	name_l.add_theme_font_size_override("font_size", FS_DOCK_NAME)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_l)
	var key_l := Label.new()
	key_l.text = str(SITE_KEY.get(_selected, ""))
	key_l.theme_type_variation = &"EmberNum"
	key_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(key_l)
	box.add_child(head)

	# Chips: principle (dust) + cooldown (dim). Dash shows only its principle.
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	var principle := DASH_PRINCIPLE if is_dash else str(def.get("principle", ""))
	chips.add_child(_chip(principle, EmberHud.COL_DUST))
	if not is_dash:
		chips.add_child(_chip("%ds cooldown" % int(def.get("cooldown_s", 0)), EmberHud.COL_INK_DIM))
	box.add_child(chips)

	# Description.
	var desc := DASH_DESC if is_dash else (DORMANT_DESC if level < 1 else str(def.get("desc", "")))
	if not desc.is_empty():
		box.add_child(_wrap(desc))

	# Level track (only for an awake, real etching — the dash and dormant marks show none).
	if not is_dash and level >= 1:
		var head_l := Label.new()
		head_l.text = MARK_DEEPENS
		head_l.theme_type_variation = &"EmberHead"
		box.add_child(head_l)
		var blurbs: Array = def.get("level_blurbs", [])
		for lvl in range(level, EtchingsCore.MAX_LEVEL + 1):
			box.add_child(_level_row(lvl, level, blurbs))

	# Action button.
	if not is_dash:
		var action := EtchingsArmsCore.menu_action(def, etchings)
		box.add_child(_action_node(ability_id, action))

	add_child(_dock)


## One rung of the deepen ladder: a drawn pip, then the level's blurb. The pip used to be a
## literal "●"/"○" character in whatever font the row inherited; it is now the same drawn
## diamond the forge, the survey and the attunements page show, in the same three states.
func _level_row(lvl: int, current: int, blurbs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark := EmberPips.new()
	var txt := Label.new()
	txt.theme_type_variation = &"EmberProse"
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blurb := str(blurbs[lvl - 1]) if lvl - 1 < blurbs.size() else "L%d" % lvl
	var state := "rest"
	if lvl <= current:
		state = "filled"
	elif lvl == current + 1:
		state = "next"
	if lvl <= current + 1:                                   # now, and the step you can buy
		txt.text = "L%d  %s" % [lvl, blurb]
	else:                                                    # deeper — dim, unnamed
		txt.text = "L%d  %s" % [lvl, DEEP_BLURB]
		txt.add_theme_color_override("font_color", EmberHud.COL_INK_DIM)
	row.add_child(mark)
	row.add_child(txt)
	mark.set_states([state] as Array[String])
	return row


## The awaken / deepen button, or the inert Mastered line.
func _action_node(id: String, action: Dictionary) -> Control:
	var kind := str(action["kind"])
	if kind == "mastered":
		var l := Label.new()
		l.text = "Mastered (L%d)" % EtchingsCore.MAX_LEVEL
		l.theme_type_variation = &"EmberDim"
		l.add_theme_color_override("font_color", EmberHud.COL_ACCENT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var cost := int(action["cost"])
	var b := Button.new()
	b.theme_type_variation = &"EmberAction"   # the dock's one gold control
	if kind == "awaken":
		b.text = "Awaken  (%d Dust)" % cost
	else:
		b.text = "Deepen to L%d  (%d Dust)" % [int(action["to_level"]), cost]
	b.disabled = Ledger.get_amount("resonance-dust") < float(cost)
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(learn.bind(id))
	return b


## A meta word under the head (the principle, the cooldown). Not a chip any more — Ember has
## no chips; the colour alone carries which kind of fact it is.
func _chip(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"EmberHead"
	l.add_theme_color_override("font_color", col)
	return l


func _wrap(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"EmberProse"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
