extends Control
class_name MarketPanel
## The Market's trade page (design/town-economy.md, 2026-07-10): the Gold→Stone/Food
## exchange (the repeatable soft sink — deliberately worse than producing it) and the
## day's rotating caravan deal(s). Opened from the Market's BuildPanel row (the
## "Trade" button) or town.gd's open_market_panel() — a deliberate choice over a
## second town interaction site: the Market plot already opens its ledger page, and
## one plot = one press stays true (documented in town-economy.md). Fullscreen,
## code-built, Slate-themed; pauses while open; NO Close button — ESC closes (the
## panel-wide ESC-close pass).
##
## Transactions (all Ledger, civilian resources only — the Market never trades
## Resonance, IC-14): exchange buys 1 Stone / 1 Food per press at the built level's
## data rates (reason "market-exchange"); a caravan deal swaps its give for its get
## once per day (reason "caravan"; town.market_deal_done_day remembers).
## Logic is MarketCore + TownCore (pure, tested); this is the screen + wiring.
## open()/close()/buy_stone()/buy_food()/accept_deal()/deal_id() are public so the
## headless smoke drives the real path.

# =====================================================================================
# Style / copy — placeholders. Dial like FEEL numbers (shared palette/fonts in
# SlateHud). ALL copy below is PLACEHOLDER, Herzog's register (short declaratives,
# no aphorisms, no em dashes) — the human dials it.
# =====================================================================================
const MARGIN := 20.0
const SHEET_W := 560.0
const SHEET_TOP := 120.0
const FS_CARRY := 28
const FS_CARRY_LABEL := 11
const TITLE := "The Market"
const SUBTITLE := "Coin moves. Herzog counts it twice."
const EXCHANGE_HEADER := "EXCHANGE"
const CARAVAN_HEADER := "TODAY'S CARAVAN"
const BUY_STONE_FMT := "Buy 1 stone (%d gold)"
const BUY_FOOD_FMT := "Buy 1 food (%d gold)"
const DEAL_TRADE_FMT := "give %s, take %s"
const ACCEPT := "Accept"
const DEAL_DONE := "Done for today. The caravan moves on."
const NO_DEALS := "No caravan today."
## The resources the carry readout shows (the civilian set the Market trades).
const CARRY_IDS: Array[String] = ["gold", "stone", "food"]

var _defs: Dictionary = {}
var _deals: Dictionary = {}

var _title: Label
var _subtitle: Label
var _sheet: PanelContainer
var _font_num: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("market_panel")
	theme = SlateTheme.get_theme()
	_font_num = SlateHud._with_fallback(SlateHud.FONT_NUM_FILE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func open() -> void:
	_defs = DataLoader.load_domain("buildings")
	_deals = DataLoader.load_caravan_deals()
	_title = Label.new()
	_title.text = TITLE
	_title.theme_type_variation = &"TitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"DimLabel"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	_build_sheet()
	queue_redraw()
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# CanvasLayer-under-_ready geometry quirk — sync to the viewport like every panel.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	if _title != null:
		_title.position = Vector2(MARGIN + 8.0, MARGIN)
	if _subtitle != null:
		_subtitle.position = Vector2(MARGIN + 9.0, MARGIN + 32.0)
	if _sheet != null:
		_sheet.position = Vector2((size.x - _sheet.size.x) * 0.5, SHEET_TOP)


# --- Public (buttons + the smoke driver land here) ---------------------------------

## Today's day number — 1 day = 1 run (the same read as town.gd's day chip).
func day() -> int:
	return int(SaveManager.state["story"]["counters"].get("runs", 0)) + 1


## The Market's current-level rates ({} if somehow unbuilt — the panel then shows nothing).
func rates() -> Dictionary:
	return MarketCore.caps(_defs.get("market", {}),
		TownCore.building_level(SaveManager.state["town"], "market"))


## The deal id on offer in `slot` today ("" when none — table empty or slot beyond
## the built level's deal_slots).
func deal_id(slot: int) -> String:
	if slot >= int(rates().get("deal_slots", 0)):
		return ""
	return MarketCore.deal_id_for_slot(_deals, day(), slot)


## Exchange: 1 Stone for the built level's buy_stone_gold. False when unaffordable.
func buy_stone() -> bool:
	return _exchange("stone", int(rates().get("buy_stone_gold", 0)))


## Exchange: 1 Food for the built level's buy_food_gold. False when unaffordable.
func buy_food() -> bool:
	return _exchange("food", int(rates().get("buy_food_gold", 0)))


## Accept the deal in `slot` — pay its give, receive its get, mark today done (one
## accept per day across all slots). False when done today / no deal / unaffordable.
func accept_deal(slot: int) -> bool:
	var town: Dictionary = SaveManager.state["town"]
	if not MarketCore.can_accept_deal(town, day()):
		return false
	var id := deal_id(slot)
	if id.is_empty() or not _deals.has(id):
		return false
	var deal: Dictionary = _deals[id]
	if not Ledger.try_spend_all(deal.get("give", {}), "caravan"):
		return false
	var got: Dictionary = deal.get("get", {})
	for res: String in got:
		Ledger.add(res, float(got[res]), "caravan")
	SaveManager.state["town"] = MarketCore.mark_deal_done(town, day())
	SaveManager.save_current()  # an accepted deal must never replay after a crash
	_refresh()
	return true


func _exchange(resource: String, price_gold: int) -> bool:
	if price_gold <= 0:
		return false  # unbuilt / malformed rates — never a free trade
	if not Ledger.try_spend("gold", float(price_gold), "market-exchange"):
		return false
	Ledger.add(resource, 1.0, "market-exchange")
	_refresh()
	return true


func _refresh() -> void:
	_build_sheet()
	queue_redraw()


# --- The sheet (exchange buttons + the caravan rows) --------------------------------

func _build_sheet() -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
	_sheet = PanelContainer.new()
	_sheet.custom_minimum_size = Vector2(SHEET_W, 0)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	_sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var r := rates()
	box.add_child(_header(EXCHANGE_HEADER))
	box.add_child(_exchange_button(BUY_STONE_FMT % int(r.get("buy_stone_gold", 0)),
		int(r.get("buy_stone_gold", 0)), buy_stone))
	box.add_child(_exchange_button(BUY_FOOD_FMT % int(r.get("buy_food_gold", 0)),
		int(r.get("buy_food_gold", 0)), buy_food))
	box.add_child(HSeparator.new())
	box.add_child(_header(CARAVAN_HEADER))
	var slots := int(r.get("deal_slots", 0))
	var any := false
	for slot in slots:
		var id := deal_id(slot)
		if id.is_empty():
			continue
		any = true
		box.add_child(_deal_row(slot, _deals[id]))
	if not any:
		var l := Label.new()
		l.text = NO_DEALS
		l.theme_type_variation = &"DimLabel"
		box.add_child(l)
	elif not MarketCore.can_accept_deal(SaveManager.state["town"], day()):
		var done := Label.new()
		done.text = DEAL_DONE
		done.theme_type_variation = &"DimLabel"
		box.add_child(done)
	add_child(_sheet)


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"NumLabel"
	l.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)
	return l


func _exchange_button(text: String, price_gold: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = price_gold <= 0 or not Ledger.can_afford({"gold": price_gold})
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(func() -> void: action.call())
	return b


func _deal_row(slot: int, deal: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	var pitch := Label.new()
	pitch.text = str(deal.get("text", ""))
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(pitch)
	var terms := Label.new()
	terms.text = DEAL_TRADE_FMT % [_cost_text(deal.get("give", {})), _cost_text(deal.get("get", {}))]
	terms.theme_type_variation = &"NumLabel"
	terms.add_theme_color_override("font_color", SlateHud.COL_KEY_TEXT)
	mid.add_child(terms)
	hb.add_child(mid)
	var b := Button.new()
	b.text = ACCEPT
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not MarketCore.can_accept_deal(SaveManager.state["town"], day()) \
		or not Ledger.can_afford(deal.get("give", {}))
	b.pressed.connect(func() -> void: Sfx.play("ui-click"))
	b.pressed.connect(func() -> void: accept_deal(slot))
	hb.add_child(b)
	return hb


func _cost_text(cost: Dictionary) -> String:
	# Matches town.gd's _cost_text format byte-for-byte ("%d %s", ", "-joined).
	var parts := PackedStringArray()
	for id: String in cost:
		parts.append("%d %s" % [int(cost[id]), id])
	return ", ".join(parts)


# --- Draw (bg + the carry readout, the survey's pattern) -----------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), TechChart.COL_FRAME_BG)
	var right := size.x - MARGIN
	var y := MARGIN + 6.0
	for id in CARRY_IDS:
		var num := str(int(Ledger.get_amount(id)))
		var nw := _font_num.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY).x
		var by := y + _font_num.get_ascent(FS_CARRY)
		draw_string(_font_num, Vector2(right - nw, by), num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY, BuildPanel.res_color(id))
		var lw := _font_num.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY_LABEL).x
		draw_string(_font_num, Vector2(right - nw - 10.0 - lw, by), id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_CARRY_LABEL, SlateHud.COL_KEY_TEXT)
		y += FS_CARRY + 10.0
