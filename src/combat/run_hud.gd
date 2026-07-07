extends Control
class_name RunHud
## The in-run HUD ("Slate" design — human-approved 2026-07-07 via claude.ai/design,
## the "C" direction: an echo shelf over the HP bar with a clean top row). Replaces the
## old debug-style stacked text Labels. Spec + deferred work: design/ui-hud.md.
##
## One screen-filling Control (mouse_filter IGNORE) on combat_room's $HUD CanvasLayer.
## It draws everything itself in _draw (rounded panels via a StyleBoxFlat, text via the
## fallback font) and polls the player/boss each frame — combat_room + game.gd push the
## room/hint/wave/HP state in through the setters. Pure string/fold/threshold logic lives
## in HudCore (src/combat/hud_core.gd); this node owns only pixels.
##
## HUMAN: EVERYTHING under "Style" is a PLACEHOLDER — colours, sizes, and the pickup
## timings are yours to dial (design/ui-hud.md). Dial them like FEEL numbers.

# =====================================================================================
# Style — placeholders (colours / sizes / timings). Dial freely.
# =====================================================================================
# Palette (Color(r/255,...) so the values are const-foldable — the hex is in the comment)
const COL_SLATE_BG := Color(23.0/255, 22.0/255, 28.0/255)          # #17161c panel body
const COL_SLATE_BORDER := Color(74.0/255, 71.0/255, 86.0/255)      # #4a4756
const COL_CHIP_BG := Color(23.0/255, 22.0/255, 28.0/255, 0.78)     # #17161c @ 0.78
const COL_CHIP_BORDER := Color(58.0/255, 56.0/255, 68.0/255)       # #3a3844
const COL_TEXT := Color(201.0/255, 197.0/255, 214.0/255)           # #c9c5d6
const COL_READY := Color(255.0/255, 230.0/255, 128.0/255)          # #ffe680 gold ready/badge
const COL_BADGE_TEXT := Color(30.0/255, 28.0/255, 24.0/255)        # dark text on the gold badge
const COL_KEY_TEXT := Color(150.0/255, 146.0/255, 162.0/255)       # dim key-badge label
const COL_PERIL := Color(255.0/255, 92.0/255, 92.0/255)            # #ff5c5c (glyph lives in chip text)
# Pickup colours (per resource id)
const COL_GOLD := Color(255.0/255, 230.0/255, 128.0/255)           # #ffe680
const COL_ORE := Color(176.0/255, 164.0/255, 224.0/255)            # #b0a4e0
const COL_DUST := Color(128.0/255, 230.0/255, 255.0/255)           # #80e6ff
const COL_SHARDS := Color(208.0/255, 143.0/255, 255.0/255)         # #d08fff
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
# Fonts
const FS_CHIP := 14
const FS_BODY := 15
const FS_SMALL := 11
const FS_SLOT := 22
const FS_HP := 15
# Layout margin from screen edges
const MARGIN := 14.0
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

var _font: Font
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	add_to_group("run_hud")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
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


# --- Pickup strip --------------------------------------------------------------------

func _on_resource_changed(id: String, _old: float, new_amount: float, _reason: String) -> void:
	if not RunState.in_run() or not PICKUP_IDS.has(id):
		return
	_pickup_amounts[id] = new_amount
	_pickup_alpha = 1.0
	_pickup_hold_t = PICKUP_HOLD_S


func _process(delta: float) -> void:
	# Godot quirk: anchors set in our own _ready never get a layout pass under a
	# CanvasLayer (size stays 0,0 and everything anchored to size.x/size.y draws
	# off-screen). Sync to the viewport explicitly; also covers window resizes.
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
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


func _panel(rect: Rect2, bg: Color, border: Color, border_w: int, radius: int) -> void:
	_sb.bg_color = bg
	_sb.border_color = border
	_sb.set_border_width_all(border_w)
	_sb.set_corner_radius_all(radius)
	draw_style_box(_sb, rect)


func _text(pos: Vector2, s: String, col: Color, fs: int) -> void:
	# pos = top-left; draw_string wants a baseline, so drop by the ascent.
	draw_string(_font, Vector2(pos.x, pos.y + _font.get_ascent(fs)),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_w(s: String, fs: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


# --- Info chip (top-left) ------------------------------------------------------------

func _draw_chip() -> void:
	var s := chip()
	var pad := Vector2(10, 6)
	var w := _text_w(s, FS_CHIP) + pad.x * 2.0
	var h := float(FS_CHIP) + pad.y * 2.0
	var rect := Rect2(MARGIN, MARGIN, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	_text(rect.position + pad, s, COL_TEXT, FS_CHIP)


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
		segs.append({"text": t, "color": PICKUP_COLOR[id], "w": _text_w(t, FS_BODY)})
	if segs.is_empty():
		return
	var gap := 18.0
	var pad := Vector2(12, 7)
	var content_w := 0.0
	for seg: Dictionary in segs:
		content_w += float(seg["w"]) + gap
	content_w -= gap
	var w := content_w + pad.x * 2.0
	var h := float(FS_BODY) + pad.y * 2.0
	var rect := Rect2(size.x - MARGIN - w, MARGIN, w, h)
	_panel(rect, Color(COL_SLATE_BG, COL_SLATE_BG.a * _pickup_alpha),
		Color(COL_SLATE_BORDER, COL_SLATE_BORDER.a * _pickup_alpha), 2, 8)
	var x := rect.position.x + pad.x
	for seg: Dictionary in segs:
		var c: Color = seg["color"]
		_text(Vector2(x, rect.position.y + pad.y), str(seg["text"]),
			Color(c, c.a * _pickup_alpha), FS_BODY)
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
	var nw := _text_w(num, FS_HP)
	var npos := Vector2(bar.position.x + (bar.size.x - nw) * 0.5,
		bar.position.y + (bar.size.y - FS_HP) * 0.5)
	_text(npos + Vector2(1, 1), num, Color(0, 0, 0, 0.6), FS_HP)  # shadow
	_text(npos, num, COL_HP_LOW_NUM if low else Color.WHITE, FS_HP)
	# Echo shelf directly above the HP bar (row 0 nearest the bar, wrapping upward).
	for i in _echoes.size():
		var row := i / ECHO_PER_ROW
		var col := i % ECHO_PER_ROW
		var tx := MARGIN + float(col) * (ECHO_TILE + ECHO_GAP)
		var ty := bar.position.y - ECHO_GAP - ECHO_TILE - float(row) * (ECHO_TILE + ECHO_GAP)
		_draw_echo_tile(Rect2(tx, ty, ECHO_TILE, ECHO_TILE), _echoes[i])


func _draw_echo_tile(rect: Rect2, tile: Dictionary) -> void:
	_panel(rect, COL_SLATE_BG, COL_SLATE_BORDER, 2, ECHO_RADIUS)
	var mono := str(tile.get("monogram", "?"))
	var mw := _text_w(mono, FS_SMALL)
	_text(Vector2(rect.position.x + (rect.size.x - mw) * 0.5,
		rect.position.y + (rect.size.y - FS_SMALL) * 0.5), mono, COL_TEXT, FS_SMALL)
	var count := int(tile.get("count", 1))
	if count > 1:
		# Small gold stack badge, top-right corner.
		var bs := 14.0
		var b := Rect2(rect.position.x + rect.size.x - bs + 3.0, rect.position.y - 3.0, bs, bs)
		_panel(b, COL_READY, COL_READY, 0, 4)
		var ct := str(count)
		var cw := _text_w(ct, FS_SMALL)
		_text(Vector2(b.position.x + (bs - cw) * 0.5, b.position.y + (bs - FS_SMALL) * 0.5),
			ct, COL_BADGE_TEXT, FS_SMALL)


# --- Ability slots (bottom-right) ----------------------------------------------------

func _draw_ability_slots() -> void:
	var info := _player.ability_slot_info() if is_instance_valid(_player) else {}
	# Lay out right-to-left: dash pip | R | Q | RMB, anchored to the bottom-right.
	var y := size.y - MARGIN - SLOT
	var x := size.x - MARGIN - DASH_PIP
	# Dash pip (smaller, vertically centred against the big slots).
	var dash: Dictionary = info.get("dash", {"cd_left": 0.0, "cd_total": 0.0})
	_draw_slot(Rect2(x, y + (SLOT - DASH_PIP) * 0.5, DASH_PIP, DASH_PIP),
		"–", "SPC", float(dash.get("cd_left", 0.0)), true, FS_SMALL)
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
	var fw := _text_w(face, fs)
	_text(Vector2(rect.position.x + (rect.size.x - fw) * 0.5,
		rect.position.y + (rect.size.y - fs) * 0.5 - 4.0), face, face_col, fs)
	if on_cd:
		# Darken the whole face + overlay the remaining seconds (v1 — no pie wedge).
		draw_rect(rect, Color(0, 0, 0, 0.55))
		var cd := "%.1f" % cd_left
		var cw := _text_w(cd, FS_BODY)
		_text(Vector2(rect.position.x + (rect.size.x - cw) * 0.5,
			rect.position.y + (rect.size.y - FS_BODY) * 0.5), cd, Color.WHITE, FS_BODY)
	# Key badge under the slot.
	var kw := _text_w(key, FS_SMALL)
	_text(Vector2(rect.position.x + (rect.size.x - kw) * 0.5, rect.position.y + rect.size.y + 2.0),
		key, COL_KEY_TEXT, FS_SMALL)


# --- Boss bar (top-center) -----------------------------------------------------------

func _draw_boss_bar() -> void:
	if not boss_bar_visible():
		return
	var label := "FLOOR %d — BOSS" % _floor
	var lw := _text_w(label, FS_SMALL)
	var cx := size.x * 0.5
	_text(Vector2(cx - lw * 0.5, MARGIN), label, COL_BOSS_LABEL, FS_SMALL)
	var bar := Rect2(cx - BOSS_W * 0.5, MARGIN + FS_SMALL + 6.0, BOSS_W, BOSS_H)
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
	var pad := Vector2(14, 7)
	var w := _text_w(_hint, FS_BODY) + pad.x * 2.0
	var h := float(FS_BODY) + pad.y * 2.0
	# Sit above the ability slots' key-badge line.
	var rect := Rect2((size.x - w) * 0.5, size.y - MARGIN - SLOT - h - 24.0, w, h)
	_panel(rect, COL_CHIP_BG, COL_CHIP_BORDER, 1, 8)
	_text(rect.position + pad, _hint, COL_TEXT, FS_BODY)


# --- Vignette (low HP) ---------------------------------------------------------------

func _draw_vignette() -> void:
	var band := VIGNETTE_DEPTH / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var t := float(i) / float(VIGNETTE_STEPS)
		var inset := t * VIGNETTE_DEPTH
		var col := Color(COL_VIGNETTE, (1.0 - t) * VIGNETTE_ALPHA)
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			col, false, band + 1.0)
