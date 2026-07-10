extends SlateHud
class_name RunHud
## The in-run HUD ("Slate" design — human-approved 2026-07-07 via claude.ai/design,
## the "C" direction: an echo shelf over the HP bar with a clean top row). Replaces the
## old debug-style stacked text Labels. Spec + deferred work: design/ui-hud.md.
##
## One screen-filling Control (mouse_filter IGNORE) on combat_room's $HUD CanvasLayer.
## It draws everything itself in _draw (rounded panels via a StyleBoxFlat, text via the
## three project fonts under assets/fonts/) and polls the player/boss each frame —
## combat_room + game.gd push the room/hint/wave/HP state in through the setters. Pure
## string/fold/threshold logic lives in HudCore (src/combat/hud_core.gd); this node
## owns only pixels.
##
## Extends SlateHud (src/core/slate_hud.gd), which owns the SHARED style: the Slate
## palette + pickup colours, the three project fonts, the shared font sizes (FS_CHIP /
## FS_BODY / FS_HINT / FS_SMALL) + MARGIN, and the draw plumbing (_panel / _text_in /
## _text_w / _with_fallback / _sync_viewport_size). Dial shared style there; the
## run-specific placeholders below are the HP/echo/slot/boss/vignette/pickup pieces.
##
## HUMAN: EVERYTHING under "Style" (here + the shared style in slate_hud.gd) is a
## PLACEHOLDER — colours, sizes, fonts, and the pickup timings. Dial them like FEEL
## numbers (design/ui-hud.md).

# =====================================================================================
# Run-specific style — placeholders (sizes / colours / timings). Dial freely.
# (The shared palette + fonts + FS_CHIP/BODY/HINT/SMALL + MARGIN live in SlateHud.)
# =====================================================================================
# HP bar
const HP_W := 340.0
const HP_H := 26.0
const COL_HP_FILL := Color(201.0/255, 58.0/255, 44.0/255)          # #c93a2c
const COL_HP_LOW_BORDER := Color(179.0/255, 48.0/255, 42.0/255)    # #b3302a
const COL_HP_LOW_NUM := Color(255.0/255, 179.0/255, 168.0/255)     # #ffb3a8
# Echo shelf
const ECHO_TILE := 32.0
const ECHO_GAP := 6.0
const ECHO_PER_ROW := 8
const ECHO_RADIUS := 6
# Ability slots
const SLOT := 66.0
const DASH_PIP := 46.0
const SLOT_GAP := 8.0
const SLOT_RADIUS := 12
# Boss bar
const BOSS_W := 520.0
const BOSS_H := 18.0
const COL_BOSS_FILL := Color(155.0/255, 79.0/255, 192.0/255)       # #9b4fc0
const COL_BOSS_LABEL := Color(230.0/255, 213.0/255, 242.0/255)     # #e6d5f2
# Vignette (low-HP screen edge)
const VIGNETTE_DEPTH := 90.0
const VIGNETTE_STEPS := 24
const VIGNETTE_ALPHA := 0.30
const COL_VIGNETTE := Color(201.0/255, 58.0/255, 44.0/255)
# Fonts + the FS_CHIP/BODY/HINT/SMALL sizes + MARGIN are shared — see SlateHud. These
# are the run-specific display sizes (DISPLAY = Cinzel monograms/labels; NUM = HP digits).
const FS_TILE := 13      # echo tile monograms (display)
const FS_SLOT := 20      # ability slot monograms (display)
const FS_HP := 14        # HP numerals (num)
const FS_BOSS := 13      # boss label (display)
# Pickup strip timing
const PICKUP_HOLD_S := 3.0
const PICKUP_FADE_S := 0.8

## Which Ledger ids show in the fading pickup strip, and their short labels.
const PICKUP_IDS: Array[String] = ["gold", "resonance-ore", "resonance-dust", "knowledge-shards"]
const PICKUP_LABEL := {
	"gold": "gold", "resonance-ore": "ore", "resonance-dust": "dust", "knowledge-shards": "shards",
}
const PICKUP_COLOR := {
	"gold": COL_GOLD, "resonance-ore": COL_ORE, "resonance-dust": COL_DUST, "knowledge-shards": COL_SHARDS,
}
## Fixed ability-name monograms for the three slots (disambiguates Snare/Shockwave/Surge).
const ABILITY_MONOGRAM := {
	"push": "P", "bolt": "B", "snare": "Sn", "shockwave": "Sh", "surge": "Su",
}
const SLOT_KEYS: Array[String] = ["rmb", "q", "r"]
const SLOT_KEY_LABEL := {"rmb": "RMB", "q": "Q", "r": "R"}

# =====================================================================================
# State (pushed in by combat_room / game.gd, or polled)
# =====================================================================================
var _player: Player = null
var _boss: EnemyDummy = null
var _boss_max: int = 1
var _boss_name: String = ""  # data-driven bosses label the bar with the def's name

var _floor: int = 1
var _room: int = 1
var _rooms: int = 1
var _kind: String = HudCore.KIND_COMBAT
var _peril: bool = false
var _wave_idx: int = 0
var _wave_count: int = 0
var _cleared: bool = false

var _hp: int = 0
var _max_hp: int = 1
var _hint: String = ""
var _echoes: Array = []   # HudCore.fold_echoes output

var _pickup_amounts: Dictionary = {}   # id -> amount at the last pickup
var _pickup_alpha: float = 0.0
var _pickup_hold_t: float = 0.0


func _ready() -> void:
	super._ready()  # SlateHud: anchors + mouse_filter + the three fonts
	add_to_group("run_hud")
	# In-run pickups feed the fading strip; the town economy readout stays on game.gd's HUD.
	EventBus.resource_changed.connect(_on_resource_changed)


# --- Setup / setters (combat_room + game.gd push state in) ---------------------------

func setup(player: Player, boss: EnemyDummy = null) -> void:
	_player = player
	set_boss(boss)


func configure_room(floor_num: int, room: int, rooms: int, kind: String, peril: bool) -> void:
	_floor = floor_num
	_room = room
	_rooms = rooms
	_kind = kind
	_peril = peril
	queue_redraw()


func set_wave(idx: int, count: int) -> void:
	_wave_idx = idx
	_wave_count = count
	queue_redraw()


func mark_cleared() -> void:
	_cleared = true
	queue_redraw()


func set_hint(text: String) -> void:
	_hint = text
	queue_redraw()


func set_hp(hp: int, max_hp: int) -> void:
	_hp = hp
	_max_hp = max_hp
	queue_redraw()


func set_boss(boss: EnemyDummy) -> void:
	_boss = boss
	if boss != null:
		_boss_max = maxi(1, int(boss.max_hp))
	queue_redraw()


## Data-driven bosses (data/bosses/) put the def's name on the bar; placeholder
## bosses never call this, so they keep the generic floor label unchanged.
func set_boss_name(boss_name: String) -> void:
	_boss_name = boss_name
	queue_redraw()


## Rebuild the echo shelf from the run's picks (called on room spawn + after each pick).
func refresh_echoes() -> void:
	_echoes = HudCore.fold_echoes(RunState.echoes, EchoCore.defs())
	queue_redraw()


# --- Smoke/test getters --------------------------------------------------------------

func chip() -> String:
	return HudCore.chip_text(_floor, _room, _rooms, _kind, _peril, _wave_idx, _wave_count, _cleared)


func echo_tile_count() -> int:
	return _echoes.size()


func pickup_visible() -> bool:
	return _pickup_alpha > 0.0


func boss_bar_visible() -> bool:
	return is_instance_valid(_boss) and _boss.current_hp() > 0


## The bar's label: the boss def's name when set, else the generic floor label.
func boss_label() -> String:
	return _boss_name if not _boss_name.is_empty() else "FLOOR %d — BOSS" % _floor


# --- Pickup strip --------------------------------------------------------------------

func _on_resource_changed(id: String, _old: float, new_amount: float, _reason: String) -> void:
	if not RunState.in_run() or not PICKUP_IDS.has(id):
		return
	_pickup_amounts[id] = new_amount
	_pickup_alpha = 1.0
	_pickup_hold_t = PICKUP_HOLD_S


func _process(delta: float) -> void:
	_sync_viewport_size()  # SlateHud: the CanvasLayer-under-_ready layout quirk
	# Fade the pickup strip after its hold window.
	if _pickup_alpha > 0.0:
		if _pickup_hold_t > 0.0:
			_pickup_hold_t -= delta
		else:
			_pickup_alpha = maxf(0.0, _pickup_alpha - delta / PICKUP_FADE_S)
	queue_redraw()  # ability cooldowns + boss bar animate every frame


# =====================================================================================
# Draw
# =====================================================================================

func _draw() -> void:
	if HudCore.is_low_hp(_hp, _max_hp):
		_draw_vignette()
	_draw_chip()
	_draw_pickups()
	_draw_boss_bar()
	_draw_hp_and_echoes()
	_draw_ability_slots()
	_draw_hint()


# --- Info chip (top-left) ------------------------------------------------------------

func _draw_chip() -> void:
	var s := chip()
	var pad := Vector2(10, 5)
	var w := _text_w(s, FS_CHIP, _font_num) + pad.x * 2.0
	var h := _font_num.get_height(FS_CHIP) + pad.y * 2.0
	var rect := Rect2(MARGIN, MARGIN, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	_text_in(Rect2(rect.position.x + pad.x, rect.position.y, w - pad.x * 2.0, h),
		s, COL_TEXT, FS_CHIP, _font_num, HORIZONTAL_ALIGNMENT_LEFT)


# --- Pickup strip (top-right, fading) ------------------------------------------------

func _draw_pickups() -> void:
	if _pickup_alpha <= 0.0:
		return
	var segs: Array = []  # [{text, color, w}]
	for id: String in PICKUP_IDS:
		var amt := int(_pickup_amounts.get(id, 0))
		if amt <= 0:
			continue
		var t := "%d %s" % [amt, str(PICKUP_LABEL[id])]
		segs.append({"text": t, "color": PICKUP_COLOR[id], "w": _text_w(t, FS_BODY, _font_num)})
	if segs.is_empty():
		return
	var gap := 18.0
	var pad := Vector2(12, 6)
	var content_w := 0.0
	for seg: Dictionary in segs:
		content_w += float(seg["w"]) + gap
	content_w -= gap
	var w := content_w + pad.x * 2.0
	var h := _font_num.get_height(FS_BODY) + pad.y * 2.0
	var rect := Rect2(size.x - MARGIN - w, MARGIN, w, h)
	_panel(rect, Color(COL_SLATE_BG, COL_SLATE_BG.a * _pickup_alpha),
		Color(COL_SLATE_BORDER, COL_SLATE_BORDER.a * _pickup_alpha), 2, 8)
	var x := rect.position.x + pad.x
	for seg: Dictionary in segs:
		var c: Color = seg["color"]
		_text_in(Rect2(x, rect.position.y, float(seg["w"]), h), str(seg["text"]),
			Color(c, c.a * _pickup_alpha), FS_BODY, _font_num, HORIZONTAL_ALIGNMENT_LEFT)
		x += float(seg["w"]) + gap


# --- HP bar + echo shelf (bottom-left) -----------------------------------------------

func _draw_hp_and_echoes() -> void:
	var low := HudCore.is_low_hp(_hp, _max_hp)
	var bar := Rect2(MARGIN, size.y - MARGIN - HP_H, HP_W, HP_H)
	var border := COL_HP_LOW_BORDER if low else COL_SLATE_BORDER
	_panel(bar, COL_SLATE_BG, border, 3, 8)
	# Fill (clamped fraction), inset inside the border.
	var frac := clampf(float(_hp) / float(maxi(1, _max_hp)), 0.0, 1.0)
	if frac > 0.0:
		var inset := 3.0
		var fill := Rect2(bar.position.x + inset, bar.position.y + inset,
			(bar.size.x - inset * 2.0) * frac, bar.size.y - inset * 2.0)
		draw_rect(fill, COL_HP_FILL)
	var num := "%d / %d" % [_hp, _max_hp]
	_text_in(Rect2(bar.position + Vector2(1, 1), bar.size), num, Color(0, 0, 0, 0.6),
		FS_HP, _font_num)  # shadow
	_text_in(bar, num, COL_HP_LOW_NUM if low else Color.WHITE, FS_HP, _font_num)
	# Echo shelf directly above the HP bar (row 0 nearest the bar, wrapping upward).
	for i in _echoes.size():
		var row := i / ECHO_PER_ROW
		var col := i % ECHO_PER_ROW
		var tx := MARGIN + float(col) * (ECHO_TILE + ECHO_GAP)
		var ty := bar.position.y - ECHO_GAP - ECHO_TILE - float(row) * (ECHO_TILE + ECHO_GAP)
		_draw_echo_tile(Rect2(tx, ty, ECHO_TILE, ECHO_TILE), _echoes[i])


func _draw_echo_tile(rect: Rect2, tile: Dictionary) -> void:
	_panel(rect, COL_SLATE_BG, COL_SLATE_BORDER, 2, ECHO_RADIUS)
	_text_in(rect, str(tile.get("monogram", "?")), COL_TEXT, FS_TILE, _font_display)
	var count := int(tile.get("count", 1))
	if count > 1:
		# Small gold stack badge, top-right corner.
		var bs := 14.0
		var b := Rect2(rect.position.x + rect.size.x - bs + 3.0, rect.position.y - 3.0, bs, bs)
		_panel(b, COL_READY, COL_READY, 0, 4)
		_text_in(b, str(count), COL_BADGE_TEXT, FS_SMALL, _font_num)


# --- Ability slots (bottom-right) ----------------------------------------------------

func _draw_ability_slots() -> void:
	var info := _player.ability_slot_info() if is_instance_valid(_player) else {}
	# Lay out right-to-left: dash pip | R | Q | RMB, anchored to the bottom-right.
	var y := size.y - MARGIN - SLOT
	var x := size.x - MARGIN - DASH_PIP
	# Dash pip (smaller, vertically centred against the big slots).
	var dash: Dictionary = info.get("dash", {"cd_left": 0.0, "cd_total": 0.0})
	_draw_slot(Rect2(x, y + (SLOT - DASH_PIP) * 0.5, DASH_PIP, DASH_PIP),
		"–", "SPC", float(dash.get("cd_left", 0.0)), true, FS_TILE)
	x -= SLOT_GAP + SLOT
	for i in SLOT_KEYS.size():
		var slot: String = SLOT_KEYS[SLOT_KEYS.size() - 1 - i]  # R, Q, RMB (right to left)
		var d: Dictionary = info.get(slot, {})
		var id := str(d.get("id", ""))
		var face := "–"
		var has := not id.is_empty()
		if has:
			face = str(ABILITY_MONOGRAM.get(id, HudCore.monogram(str(d.get("name", id)))))
		_draw_slot(Rect2(x, y, SLOT, SLOT), face, str(SLOT_KEY_LABEL[slot]),
			float(d.get("cd_left", 0.0)), has, FS_SLOT)
		x -= SLOT_GAP + SLOT


func _draw_slot(rect: Rect2, face: String, key: String, cd_left: float, ready_glow: bool, fs: int) -> void:
	var on_cd := cd_left > 0.01
	var border := COL_SLATE_BORDER
	if ready_glow and not on_cd:
		border = COL_READY
	_panel(rect, COL_SLATE_BG, border, 3, SLOT_RADIUS)
	var face_col := COL_TEXT if ready_glow else COL_KEY_TEXT
	_text_in(rect, face, face_col, fs, _font_display)
	if on_cd:
		# Darken the whole face + overlay the remaining seconds (v1 — no pie wedge).
		draw_rect(rect, Color(0, 0, 0, 0.55))
		_text_in(rect, "%.1f" % cd_left, Color.WHITE, FS_BODY, _font_num)
	# Key badge under the slot.
	_text_in(Rect2(rect.position.x, rect.position.y + rect.size.y + 2.0,
		rect.size.x, _font_num.get_height(FS_SMALL)), key, COL_KEY_TEXT, FS_SMALL, _font_num)


# --- Boss bar (top-center) -----------------------------------------------------------

func _draw_boss_bar() -> void:
	if not boss_bar_visible():
		return
	var label := boss_label()
	var lh := _font_display.get_height(FS_BOSS)
	var cx := size.x * 0.5
	_text_in(Rect2(cx - BOSS_W * 0.5, MARGIN, BOSS_W, lh), label, COL_BOSS_LABEL,
		FS_BOSS, _font_display)
	var bar := Rect2(cx - BOSS_W * 0.5, MARGIN + lh + 4.0, BOSS_W, BOSS_H)
	_panel(bar, COL_SLATE_BG, COL_SLATE_BORDER, 3, 6)
	var frac := clampf(float(_boss.current_hp()) / float(maxi(1, _boss_max)), 0.0, 1.0)
	if frac > 0.0:
		var inset := 3.0
		draw_rect(Rect2(bar.position.x + inset, bar.position.y + inset,
			(bar.size.x - inset * 2.0) * frac, bar.size.y - inset * 2.0), COL_BOSS_FILL)


# --- Contextual hint (bottom-center) -------------------------------------------------

func _draw_hint() -> void:
	if _hint.is_empty():
		return
	var pad := Vector2(14, 6)
	var w := _text_w(_hint, FS_HINT, _font_body) + pad.x * 2.0
	var h := _font_body.get_height(FS_HINT) + pad.y * 2.0
	# Sit above the ability slots' key-badge line.
	var rect := Rect2((size.x - w) * 0.5, size.y - MARGIN - SLOT - h - 24.0, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	_text_in(Rect2(rect.position.x + pad.x, rect.position.y, w - pad.x * 2.0, h),
		_hint, COL_TEXT, FS_HINT, _font_body, HORIZONTAL_ALIGNMENT_LEFT)


# --- Vignette (low HP) ---------------------------------------------------------------

func _draw_vignette() -> void:
	var band := VIGNETTE_DEPTH / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var t := float(i) / float(VIGNETTE_STEPS)
		var inset := t * VIGNETTE_DEPTH
		var col := Color(COL_VIGNETTE, (1.0 - t) * VIGNETTE_ALPHA)
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			col, false, band + 1.0)
