extends Node
## Renders a SPECIMEN menu screen built from the Ember menu vocabulary to PNGs, so the
## language can be judged before any real screen migrates onto it. The menu companion to
## render_hud.gd (which does the same job for the in-run HUD).
##
## Why a specimen rather than a migrated screen: the vocabulary (EmberHud's menu
## primitives + EmberMenuCore's layout) is about to be applied to fifteen screens. If it
## is wrong — columns too tight, rows too loud, the gold spent in the wrong places — that
## is fifteen rewrites. One fake screen that exercises every primitive at once costs an
## hour and is judgeable against assets_src/anchors/weapon-menu-reference.png directly.
##
## The specimen's content is deliberately FAKE (a weapon menu that matches the anchor, so
## the two can be laid side by side). It is a ruler, not a screen.
##
## SINCE TIER B (2026-08-14) the probe also renders the REAL migrated screens — the forge,
## the etchings arms, the attunements page, a build page (built AND tech-locked), the survey
## and the market. That is the half a specimen cannot do: the specimen proves the vocabulary
## is coherent, the real screens prove each one actually reaches for it. Every defect Tier A
## shipped was of the second kind (a collision, an invisible badge) and no test would have
## caught any of them.
##
## Needs a real GPU context (it reads the viewport texture back), so NOT --headless:
##   godot --path . tools/render_menu.tscn
## Output: user://menu_render_<state>.png (paths echoed to stdout, with the OS path).
##
## SAFETY: it seeds `SaveManager.state` from `SaveData.default_slot()` in memory (the rule
## render_compare.gd set) and points `current_slot` at the throwaway slot 99, because
## EtchingsPanel.open() legitimately persists its baseline grant. Slot 99 is deleted on the
## way out. It never touches slots 0-3 or profile.json.

## Render at the project's BASE viewport, never at whatever size the window manager hands
## the probe window — the constants are judged against these numbers.
const SHOT_SIZE := Vector2i(1280, 720)
## The fake world behind the scrim: a mid-tone field with a couple of bright patches, so
## the scrim's dim can be judged (Ember menus sit ON the world, they do not replace it).
const BG := Color(0.20, 0.19, 0.16)
const PATCHES: Array[Rect2] = [
	Rect2(120, 80, 420, 300),
	Rect2(760, 380, 460, 280),
]
const PATCH_COL := Color(0.42, 0.45, 0.36)

var _screen: Specimen
var _sv: SubViewport


func _ready() -> void:
	_sv = SubViewport.new()
	_sv.size = SHOT_SIZE
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(SHOT_SIZE)
	_sv.add_child(bg)
	for r: Rect2 in PATCHES:
		var p := ColorRect.new()
		p.color = PATCH_COL
		p.position = r.position
		p.size = r.size
		_sv.add_child(p)
	var layer := CanvasLayer.new()
	_sv.add_child(layer)
	_screen = Specimen.new()
	layer.add_child(_screen)
	_run()


## The throwaway save slot, exactly as the smoke uses it (design/godot-conventions.md).
const SLOT := 99


func _run() -> void:
	await _shot("catalogue", "catalogue")
	await _shot("column", "column")
	await _shot_pause()
	_seed_state()
	_screen.hide()   # the remaining shots are real screens, not the specimen
	await _shot_forge()
	await _shot_etchings()
	await _shot_build()
	await _shot_survey()
	await _shot_market()
	await _shot_tech()
	await _shot_settings()
	await _shot_achievements()
	await _shot_slot_select()
	await _shot_dialogue()
	_screen.show()
	SaveManager.delete_slot(SLOT)
	print("render_menu: done")
	get_tree().quit()


# =====================================================================================
# The real Tier B screens
# =====================================================================================

## A town far enough along that every state on these pages has something to show: a couple
## of buildings up, a market to trade at, and enough of each resource that the affordable
## and the unaffordable both appear. In memory only — never `create_slot`.
func _seed_state() -> void:
	SaveManager.state = SaveData.default_slot("menu-probe", "")
	SaveManager.current_slot = SLOT
	var town: Dictionary = SaveManager.state["town"]
	for pair: Array in [["farm", 1], ["quarry", 2], ["market", 1]]:
		town = TownCore.set_building(town, str(pair[0]), int(pair[1]))
	SaveManager.state["town"] = town
	SaveManager.state["town"]["well_fed"] = true   # the Well-Fed footnote is a real state
	for pair: Array in [["gold", 128.0], ["stone", 64.0], ["food", 30.0],
			["knowledge", 12.0], ["knowledge-shards", 4.0], ["resonance-ore", 35.0],
			["resonance-dust", 26.0]]:
		Ledger.add(str(pair[0]), float(pair[1]), "menu-probe")


## Add `panel` to the probe's viewport and undo the pause its open() sets. Every migrated
## panel pauses the tree while it is up, which in a probe would stop the very _process that
## syncs its size to the viewport — so the shot would be of a zero-sized screen.
func _stage(panel: Control) -> void:
	_sv.add_child(panel)
	get_tree().paused = false


func _unstage(panel: Control) -> void:
	panel.queue_free()
	get_tree().paused = false


func _shot_forge() -> void:
	var p := ForgePanel.new()
	_stage(p)
	p.open()
	p.select_weapon("sword")
	await _shot_node("forge")
	_unstage(p)


## Two shots off one screen: the arms page with a mark selected (so the dock is populated),
## then the same panel tabbed to the attunements ledger.
func _shot_etchings() -> void:
	var p := EtchingsPanel.new()
	_stage(p)
	p.open()
	p.open_menu("rmb")
	await _shot_node("etchings")
	p.switch_page("body")
	await _shot_node("attunements")
	_unstage(p)


## Two shots off the build page: a BUILT building (pips, the BUILT stamp, a live gold
## action) and a TECH-LOCKED one (no action at all, just the research line) — the two
## halves of the page that can disagree about where the dock's content ends.
func _shot_build() -> void:
	var p := BuildPanel.new()
	_stage(p)
	p.open("farm")   # built, not tech-locked -> the gold Raise action actually renders
	await _shot_node("build")
	_unstage(p)
	var locked := BuildPanel.new()
	_stage(locked)
	locked.open("library")   # gated on an unauthored tech — the dormant forward ref
	await _shot_node("build-locked")
	_unstage(locked)


func _shot_survey() -> void:
	var p := SurveyPanel.new()
	_stage(p)
	p.open()
	await _shot_node("survey")
	_unstage(p)


func _shot_market() -> void:
	var p := MarketPanel.new()
	_stage(p)
	p.open()
	await _shot_node("market")
	_unstage(p)


# =====================================================================================
# The real Tier C screens
# =====================================================================================

## Two shots off the research screen: the constellation with a node selected (so the dock
## is populated), then the reading page — which is the only place in the game the player
## actually READS, and therefore the only place the prose font has to carry a whole screen.
func _shot_tech() -> void:
	var p := TechPanel.new()
	_stage(p)
	p.open()
	var ids: Array = DataLoader.load_domain("tech").keys()
	ids.sort()   # deterministic: the probe must render the same node every run
	if not ids.is_empty():
		p.select_node(str(ids[0]))
	await _shot_node("tech")
	if not ids.is_empty():
		p.begin_read()
		await _shot_node("tech-read")
	_unstage(p)


func _shot_settings() -> void:
	var p := SettingsPanel.new()
	_stage(p)
	p.open()
	await _shot_node("settings")
	_unstage(p)   # NOT close() — close() would persist the profile


func _shot_achievements() -> void:
	var p := AchievementsPanel.new()
	_stage(p)
	p.open()
	await _shot_node("achievements")
	_unstage(p)


## The title screen. Its plaques read the REAL slot files, and this probe's user:// is a
## throwaway, so all three render EMPTY — which is the state worth seeing anyway, since the
## empty plaque's dashed frame is the mark Tier C added. The occupied plaque is exercised by
## the smoke. The probe deliberately does NOT write a save to dress this shot: slots 1-3 are
## the human's, and a tool that writes them is one bad `--path` away from eating a saga.
func _shot_slot_select() -> void:
	var p := SlotSelect.new()
	_stage(p)
	await _shot_node("slot-select")
	_unstage(p)


## The talk box — the one Ember surface that stays see-through, because you have to be able
## to see who is speaking. The shot is over the probe's bright patches on purpose: the check
## is whether the box's own ground carries the line where the world behind it is lightest.
func _shot_dialogue() -> void:
	var p := DialoguePanel.new()
	_stage(p)
	p.play({"scene": {"kind": "talk", "lines": [
		{"who": "sophia", "text": "The shards are a record of something that already happened. Read them and you are reading the past, not the stone."},
	]}})
	get_tree().paused = false
	await _shot_node("dialogue")
	_unstage(p)


## The REAL pause menu — the first screen on EmberTheme, and the only Control-TREE screen
## in either probe. It is here because a theme is exactly the kind of thing that looks
## right in source and wrong on screen: every colour, font and stylebox arrives indirectly.
##
## Driven without open(), which would pause the tree (the probe needs its own _process to
## keep running) and play a sound. `_rebuild()` is called directly instead.
func _shot_pause() -> void:
	_screen.hide()
	var menu := PauseMenu.new()
	menu.setup(_StubGame.new())
	_sv.add_child(menu)
	menu.visible = true
	menu.size = Vector2(SHOT_SIZE)
	menu.call("_rebuild")
	await _shot_node("pause")
	menu.queue_free()
	_screen.show()


## The pause menu asks its game for two things while rebuilding. Neither exists in a probe.
class _StubGame extends Node:
	func on_slot_select() -> bool:
		return false

	func current_scene() -> Node:
		return null  # no gate scene -> can_quit_now() is true, so nothing renders disabled


func _shot(label: String, mode: String) -> void:
	_screen.mode = mode
	_screen.size = Vector2(SHOT_SIZE)
	_screen.queue_redraw()
	await _shot_node(label)


func _shot_node(label: String) -> void:
	# Two frames: one to lay out and redraw, one to be sure it reached the framebuffer.
	# (A Control TREE needs the extra one more than a _draw does — containers only settle
	# their children's rects on the layout pass.)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	var path := "user://menu_render_%s.png" % label
	img.save_png(path)
	print("render_menu: wrote %s -> %s" % [path, ProjectSettings.globalize_path(path)])


# =====================================================================================
# The specimen screen — every menu primitive exercised once
# =====================================================================================
class Specimen extends EmberHud:
	## `catalogue` = the four-column grammar (forge / etchings / build / market / tech).
	## `column`    = the centred single-column grammar (settings / achievements).
	var mode: String = "catalogue"

	# Fake content, shaped like the anchor's.
	const RAIL := ["sword", "shield", "heart", "boot", "star"]
	const RAIL_ACTIVE := 0
	const ROWS := [
		{"name": "Bear-Crown Hammer", "glyph": "anvil", "level": 2, "max": 4, "state": "selected"},
		{"name": "Twin Blades", "glyph": "sword", "level": 1, "max": 4, "state": "idle"},
		{"name": "Stone Cleaver", "glyph": "stone", "level": 1, "max": 4, "state": "hover"},
		{"name": "Wildwood Bow", "glyph": "leaf", "level": 1, "max": 4, "state": "idle"},
		{"name": "Chain Flail", "glyph": "lock", "level": 0, "max": 4, "state": "disabled"},
	]
	const STATS := [
		{"glyph": "star", "label": "Base Damage", "from": 38.0, "to": 44.0, "unit": ""},
		{"glyph": "sword", "label": "Heavy Swing", "from": 120.0, "to": 130.0, "unit": "%"},
		{"glyph": "shockwave", "label": "Stagger Chance", "from": 15.0, "to": 20.0, "unit": "%"},
		{"glyph": "boot", "label": "Attack Speed", "from": 0.8, "to": 0.8, "unit": "x"},
	]
	const COSTS := {"gold": 80, "resonance-ore": 20, "leaf": 5}
	const HAVE := {"gold": 128, "resonance-ore": 35, "leaf": 3}
	const RES := [
		{"glyph": "gold", "amount": 128, "col": COL_GOLD},
		{"glyph": "dust", "amount": 35, "col": COL_DUST},
		{"glyph": "leaf", "amount": 12, "col": Color(164.0/255, 217.0/255, 122.0/255)},
		{"glyph": "shards", "amount": 4, "col": COL_SHARDS},
	]
	## Settings-shaped rows for the single-column state.
	const COLUMN_SECTIONS := [
		{"head": "SOUND", "rows": [["Music", "70"], ["Sound", "85"], ["Interface", "60"]]},
		{"head": "DISPLAY", "rows": [["Window", "WINDOWED"]]},
		{"head": "ASSIST", "rows": [["Reinforcement Protocol", "—"]]},
	]

	# Specimen-only geometry. The REAL dials that matter live in EmberHud + EmberMenuCore;
	# these are just how this fake screen arranges its fake content.
	const RAIL_R := 19.0
	const RAIL_GAP := 50.0
	const ROW_H := 58.0
	const ROW_GAP := 9.0
	const ROW_PAD := 14.0
	const STAT_GAP := 34.0
	const COST_GAP := 26.0
	const ACTION_H := 44.0

	func _ready() -> void:
		super._ready()
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		_scrim()
		if mode == "column":
			_draw_column_screen()
		else:
			_draw_catalogue_screen()

	# --- The four-column catalogue ----------------------------------------------------

	func _draw_catalogue_screen() -> void:
		var l := EmberMenuCore.catalogue(size)
		_draw_header(l, "Weapons", "Choose a weapon to equip and upgrade.")
		_draw_rail(l["rail"])
		_draw_list(l["list"])
		_draw_hero(l["hero"])
		_draw_dock(l["dock"])
		_draw_footer(l["footer"], "Equip")

	func _draw_header(l: Dictionary, title: String, subtitle: String) -> void:
		var band: Rect2 = l["title"]
		var x := band.position.x
		var w := _text_at(Vector2(x, band.position.y), title, COL_INK, FS_TITLE, _font_display)
		# The anchor brackets its title with flourishes; at 16:9 there is no room to the
		# left of the margin, so the specimen carries one to the right only. HUMAN: judge.
		_flourish(Vector2(x + w + 66.0, band.position.y + 2.0), 56.0)
		var sub: Rect2 = l["subtitle"]
		_text_at(Vector2(x, sub.position.y), subtitle, COL_INK_DIM, FS_SUB, _font_body)
		_draw_resources(l["resources"])

	## Bare glyph + number, laid out right-to-left from the screen edge — the same readout
	## the run HUD carries, in the same corner, so town and run agree.
	func _draw_resources(band: Rect2) -> void:
		var x := band.end.x
		var y := band.position.y
		for i in range(RES.size() - 1, -1, -1):
			var r: Dictionary = RES[i]
			var text := str(r["amount"])
			var tw := _text_w(text, FS_BIG, _font_num)
			_text_at(Vector2(x - tw, y), text, COL_INK, FS_BIG, _font_num)
			x -= tw + 12.0
			_glyph(Vector2(x - 9.0, y), 19.0, str(r["glyph"]), r["col"])
			x -= 18.0 + 30.0

	func _draw_rail(rail: Rect2) -> void:
		if rail.size.x <= 0.0:
			return
		var cx := rail.position.x + rail.size.x * 0.5
		var y := rail.position.y + RAIL_R + 6.0
		for i in RAIL.size():
			var active := i == RAIL_ACTIVE
			var col := COL_ACCENT if active else COL_INK_DIM
			_ring(Vector2(cx, y), RAIL_R, 1.4, COL_ACCENT if active else COL_RING)
			_glyph(Vector2(cx, y), RAIL_R * 1.05, str(RAIL[i]), col)
			y += RAIL_GAP
		_v_rule(rail.end.x + 12.0, rail.position.y, rail.position.y + RAIL_GAP * RAIL.size())

	func _draw_list(list: Rect2) -> void:
		var y := list.position.y
		y = _section(list.position.x, list.end.x, y, "WEAPON LIST")
		var col := Rect2(list.position.x, y, list.size.x, list.end.y - y)
		var rects := EmberMenuCore.stack(col, ROWS.size(), ROW_H, ROW_GAP)
		for i in ROWS.size():
			_draw_list_row(rects[i], ROWS[i])

	func _draw_list_row(rect: Rect2, row: Dictionary) -> void:
		var state := str(row["state"])
		var locked := state == "disabled"
		_row_box(rect, state)
		var ink := COL_DISABLED if locked else COL_INK
		var gx := rect.position.x + ROW_PAD + 13.0
		var cy := rect.position.y + rect.size.y * 0.5
		_glyph(Vector2(gx, cy), 26.0, str(row["glyph"]), COL_INK_DIM if locked else COL_ACCENT)
		var tx := gx + 13.0 + ROW_PAD
		var name_w := rect.end.x - ROW_PAD - 56.0 - tx
		_text_at(Vector2(tx, cy - 9.0), _elide(str(row["name"]), name_w, FS_ROW, _font_ui),
			ink, FS_ROW, _font_ui)
		if locked:
			_text_at(Vector2(tx, cy + 11.0), "Defeat the Den-Warden", COL_DISABLED,
				FS_ROW_SM, _font_ui)
			return
		var lvl := int(row["level"])
		_text_right(rect.end.x - ROW_PAD, cy - 9.0, "Lv. %d" % lvl,
			COL_ACCENT if lvl > 1 else COL_INK_DIM, FS_ROW_SM, _font_num)
		var states := EmberMenuCore.pip_states(lvl, int(row["max"]))
		var track_w := float(states.size() - 1) * 13.0
		_pips(Vector2(tx + track_w * 0.5 + 2.0, cy + 12.0), states)

	func _draw_hero(hero: Rect2) -> void:
		var cx := hero.position.x + hero.size.x * 0.5
		var cy := hero.position.y + hero.size.y * 0.34
		# The stage: the item drawn large. A real screen puts its silhouette here; the
		# specimen draws the glyph at stage scale so the negative space is judgeable.
		_ring(Vector2(cx, cy), 96.0, 1.0, COL_HAIR)
		_glyph(Vector2(cx, cy), 132.0, "anvil", COL_INK_DIM)
		var name_y := hero.position.y + hero.size.y * 0.60
		_text_centred(cx, name_y, "Bear-Crown Hammer", COL_INK, FS_HERO, _font_display)
		var meta := "HAMMER  ·  EQUIPPED  ·  FLAT L2"
		_text_centred(cx, name_y + 28.0, meta, COL_INK_DIM, FS_ROW_SM, _font_ui)
		_hairline(hero.position.x + 40.0, hero.end.x - 40.0, name_y + 48.0)
		var desc := "A massive hammer once wielded by the protectors of the wilds."
		_text_centred(cx, name_y + 74.0,
			_elide(desc, hero.size.x, FS_SUB, _font_body), COL_INK_DIM, FS_SUB, _font_body)

	func _draw_dock(dock: Rect2) -> void:
		var x := dock.position.x
		var right := dock.end.x
		var y := dock.position.y

		y = _section(x, right, y, "WEAPON LEVEL")
		var lvl_w := _text_at(Vector2(x, y + 8.0), "Lv. 2", COL_INK, FS_HERO, _font_num)
		var states := EmberMenuCore.pip_states(2, 4)
		# Laid out from the measured text width, not a guessed offset — the first render
		# had the pips sitting on top of the numeral.
		_pips(Vector2(x + lvl_w + 20.0 + float(states.size() - 1) * 13.0 * 0.5, y + 10.0),
			states)
		y += 46.0

		y = _section(x, right, y, "NEXT LEVEL — Lv. 3")
		for s: Dictionary in STATS:
			_draw_stat_row(x, right, y, s)
			y += STAT_GAP
		y += 8.0

		y = _section(x, right, y, "UPGRADE COST")
		var cost := EmberMenuCore.cost_rows(COSTS, HAVE)
		var cx := x
		for r: Dictionary in cost["rows"]:
			cx += _draw_cost(cx, y, r) + COST_GAP
		y += 34.0

		# The action. Dashed gold = the one thing this screen is for; the same frame goes
		# dim the moment it is unaffordable (it is here — the specimen is 2 leaf short).
		var affordable := bool(cost["affordable"])
		var btn := Rect2(x, y, right - x, ACTION_H)
		_dashed_rect(btn, COL_ACCENT if affordable else COL_DISABLED)
		_text_centred(btn.position.x + btn.size.x * 0.5, btn.position.y + btn.size.y * 0.5,
			"Upgrade", COL_ACCENT if affordable else COL_DISABLED, FS_ROW, _font_ui_med)

	func _draw_stat_row(x: float, right: float, y: float, s: Dictionary) -> void:
		_glyph(Vector2(x + 8.0, y), 17.0, str(s["glyph"]), COL_INK_DIM)
		_text_at(Vector2(x + 26.0, y), str(s["label"]), COL_INK, FS_ROW_SM, _font_ui)
		var d := EmberMenuCore.stat_delta(float(s["from"]), float(s["to"]), str(s["unit"]))
		if not bool(d["changed"]):
			_text_right(right, y, str(d["from"]), COL_INK_DIM, FS_ROW_SM, _font_num)
			return
		# `38 › 44` — the new value is the only gold thing in the row.
		var to_w := _text_right(right, y, str(d["to"]), COL_ACCENT, FS_ROW_SM, _font_num)
		var arrow_x := right - to_w - 14.0
		_text_right(arrow_x, y, "›", COL_INK_DIM, FS_ROW_SM, _font_ui)
		_text_right(arrow_x - 12.0, y, str(d["from"]), COL_INK_DIM, FS_ROW_SM, _font_num)

	## One `80 / 128` group: glyph, then have/need with the have in red when short.
	## Returns its width so the caller can lay the next one beside it.
	func _draw_cost(x: float, y: float, r: Dictionary) -> float:
		var ok := bool(r["ok"])
		_glyph(Vector2(x + 8.0, y), 16.0, _cost_glyph(str(r["id"])), COL_INK_DIM)
		var text := "%d / %d" % [int(r["need"]), int(r["have"])]
		var w := _text_at(Vector2(x + 22.0, y), text, COL_INK if ok else COL_DANGER,
			FS_ROW_SM, _font_num)
		return 22.0 + w

	func _cost_glyph(id: String) -> String:
		match id:
			"resonance-ore": return "ore"
			"resonance-dust": return "dust"
			"knowledge-shards": return "shards"
			"food": return "leaf"
			_: return id

	func _draw_footer(band: Rect2, action: String = "") -> void:
		_hairline(band.position.x, band.end.x, band.position.y - 20.0)
		_prompt(Vector2(band.position.x, band.position.y), "E", "Back")
		if action.is_empty():
			return
		var w := _prompt_w("F", action)
		_prompt(Vector2(band.end.x - w, band.position.y), "F", action)

	# --- The centred single column ----------------------------------------------------

	func _draw_column_screen() -> void:
		var l := EmberMenuCore.column(size)
		var band: Rect2 = l["title"]
		var col: Rect2 = l["column"]
		# A read-down page centres its title rather than hanging it off the left margin.
		_text_centred(size.x * 0.5, band.position.y, "Settings", COL_INK, FS_TITLE, _font_display)
		_flourish(Vector2(size.x * 0.5, band.position.y + 30.0), 150.0)
		_text_centred(size.x * 0.5, l["subtitle"].position.y + 18.0,
			"Set once. Kept for you, not the saga.", COL_INK_DIM, FS_SUB, _font_body)
		var y := col.position.y + 26.0
		for section: Dictionary in COLUMN_SECTIONS:
			y = _section(col.position.x, col.end.x, y, str(section["head"]))
			for row: Array in section["rows"]:
				_text_at(Vector2(col.position.x, y), str(row[0]), COL_INK, FS_ROW, _font_ui)
				_text_right(col.end.x, y, str(row[1]), COL_INK_DIM, FS_ROW, _font_num)
				y += 34.0
			y += 20.0
		_draw_footer(l["footer"])
