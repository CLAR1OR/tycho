extends EmberHud
class_name MarketPanel
## The Market's trade page (design/town-economy.md, 2026-07-10): the Gold→Stone/Food
## exchange (the repeatable soft sink — deliberately worse than producing it) and the
## day's rotating caravan deal(s). Opened from the Market's BuildPanel row (the
## "Trade" button) or town.gd's open_market_panel() — a deliberate choice over a
## second town interaction site: the Market plot already opens its ledger page, and
## one plot = one press stays true (documented in town-economy.md). Fullscreen,
## code-built, EMBER (migrated 2026-08-14, Tier B); pauses while open; NO Close button —
## ESC closes (the panel-wide ESC-close pass).
##
## The Ember migration is a RESTYLE — every transaction, every public method and all copy are
## byte-identical, and the smoke drives it unchanged. What moved: the sheet's panel is
## transparent with real hairlines between its sections, the section heads are tracked caps
## rather than mono, the carry stack became `_resource_readout`, and Accept is the caravan
## row's `EmberAction` — the exchange buttons stay plain frames, because buying a stone is a
## thing you can do all day and the day's one deal is not.
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
# EmberHud). ALL copy below is PLACEHOLDER, Herzog's register (short declaratives,
# no aphorisms, no em dashes) — the human dials it.
# =====================================================================================
const SHEET_W := 560.0
const SHEET_TOP := 120.0
const RES_Y := 40.0   # the shared carry readout's row, level with the title band
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


func _ready() -> void:
	super._ready()  # EmberHud: full-rect anchors + the five shared fonts
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("market_panel")
	theme = EmberTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func open() -> void:
	_defs = DataLoader.load_domain("buildings")
	_deals = DataLoader.load_caravan_deals()
	_title = Label.new()
	_title.text = TITLE
	_title.theme_type_variation = &"EmberTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"EmberDim"
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
	# Bands from EmberMenuCore, so this header sits where every Ember screen's header sits.
	var bands := EmberMenuCore.catalogue(size)
	if _title != null:
		_title.position = EmberMenuCore.label_pos(bands["title"], _title.size.y)
	if _subtitle != null:
		_subtitle.position = EmberMenuCore.label_pos(bands["subtitle"], _subtitle.size.y)
	if _sheet != null:
		var col: Rect2 = EmberMenuCore.column(size, _sheet.size.x)["column"]
		_sheet.position = Vector2(col.position.x, SHEET_TOP)


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
	_sheet = PanelContainer.new()   # transparent under EmberTheme — it groups and pads only
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
	# Side by side, each shrunk to its own text. Stacked full-width they filled the sheet,
	# and a 480 px transparent frame with centred text reads as a field to type in rather
	# than a button to press — the one place Ember's frame-over-nothing needs its width
	# reined in by hand.
	var buys := HBoxContainer.new()
	buys.add_theme_constant_override("separation", 12)
	buys.add_child(_exchange_button(BUY_STONE_FMT % int(r.get("buy_stone_gold", 0)),
		int(r.get("buy_stone_gold", 0)), buy_stone))
	buys.add_child(_exchange_button(BUY_FOOD_FMT % int(r.get("buy_food_gold", 0)),
		int(r.get("buy_food_gold", 0)), buy_food))
	box.add_child(buys)
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
		l.theme_type_variation = &"EmberDim"
		box.add_child(l)
	elif not MarketCore.can_accept_deal(SaveManager.state["town"], day()):
		var done := Label.new()
		done.text = DEAL_DONE
		done.theme_type_variation = &"EmberDim"
		box.add_child(done)
	add_child(_sheet)


## A section head — tracked caps over the rows it names. The drawn equivalent is
## `EmberHud._section`; in a Control tree the head is a Label and the rule is an HSeparator.
func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"EmberHead"
	return l


func _exchange_button(text: String, price_gold: int, action: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	pitch.theme_type_variation = &"EmberProse"   # the caravan's pitch is voice, not a label
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(pitch)
	var terms := Label.new()
	terms.text = DEAL_TRADE_FMT % [_cost_text(deal.get("give", {})), _cost_text(deal.get("get", {}))]
	terms.theme_type_variation = &"EmberNum"
	terms.add_theme_color_override("font_color", EmberHud.COL_INK_DIM)
	mid.add_child(terms)
	hb.add_child(mid)
	var b := Button.new()
	# The caravan is once a day and then gone — that is the one thing on this page worth
	# marking gold. The two exchange buttons stay plain frames on purpose.
	b.theme_type_variation = &"EmberAction"
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


# --- Draw (the scrim + the shared carry readout) --------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim()  # the ground every Ember menu sits on
	_resource_readout(size.x - EmberMenuCore.PAD_PX, RES_Y, CARRY_IDS)
