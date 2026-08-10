extends EmberHud
class_name RunHud
## The in-run HUD ("Ember" design — built 2026-08-10 from the human-picked reference
## anchors in assets_src/anchors/). Replaces the Slate HUD that shipped 2026-07-07.
## Spec: design/ui-hud.md § "In-run HUD — Ember"; dial board: design/feel-tuning.md.
##
## What changed from Slate, and why: Slate stated every element in an opaque rounded
## panel. Ember draws NO panels — the HUD floats on the world, held together by hairlines,
## thin rings and negative space, with gold reserved for state. Over a dark 2.5D field
## that reads better because it never fights the scene for contrast.
##
## Layout (see the reference anchor):
##   bottom-left    echo rail, medallions growing UPWARD from the HP baseline
##   bottom-centre  the thin HP bar with its gold centre diamond, hint prose above it
##   bottom-right   the ability dial: three rings + a smaller dash ring, cooldown arcs
##   top-right      bare resource readouts, then the room block (header + objective rows)
##   top-centre     the boss bar (boss rooms only)
##
## One screen-filling Control (mouse_filter IGNORE) on combat_room's $HUD CanvasLayer. It
## draws everything itself in _draw and polls the player/boss each frame — combat_room +
## game.gd push room/hint/wave/HP/boss state in through the setters. The public API is
## unchanged from the Slate version except for `set_wave_progress` (the live kill count
## the objective row needs), so combat_room's wiring is untouched apart from that feed.
##
## Pure string/fold/threshold logic lives in HudCore (src/combat/hud_core.gd); this node
## owns only pixels. The shared Ember vocabulary — palette, fonts, hairline/ring/arc/
## diamond/glyph primitives — lives in EmberHud (src/core/ember_hud.gd).
##
## HUMAN: EVERYTHING under "Style" (here + the shared style in ember_hud.gd) is a
## PLACEHOLDER — colours, sizes, positions, timings, and every glyph silhouette. Dial them
## like FEEL numbers. Sized against the project's 1280x720 base viewport (the reference
## anchors are 1536x1024, so nothing was copied pixel-for-pixel; proportions were carried
## across and the numbers re-judged for 16:9).

# =====================================================================================
# Run-specific style — placeholders (sizes / colours / timings). Dial freely.
# (The shared palette + fonts + primitives + glyphs live in EmberHud.)
# =====================================================================================
# Echo rail — bottom-left, growing UP toward the top of the screen (human-specified).
const ECHO_D := 38.0
const ECHO_GAP := 11.0
const ECHO_RING_W := 1.5
const ECHO_BADGE_R := 8.0
# HP bar — bottom-centre. Fills OUTWARD from the centre diamond in both directions.
const HP_W := 460.0
const HP_H := 5.0
const HP_BOTTOM := 52.0          # bar centre, distance from the bottom edge
const HP_DIAMOND := 6.5
const HP_FILL_INSET := 5.0       # where the fill starts, clear of the diamond
const COL_HP := Color(200.0/255, 48.0/255, 40.0/255)               # #c83028
const COL_HP_LOW := Color(236.0/255, 76.0/255, 62.0/255)           # #ec4c3e
## The reference anchor shows NO number on the bar. Tycho needs one (you are constantly
## judging "does the next hit kill me"), so it fades in on any HP change and leaves again.
## Set HP_NUM_HOLD_S to 0.0 to follow the anchor exactly; raise it far to keep it always on.
const HP_NUM_HOLD_S := 1.5
const HP_NUM_FADE_S := 0.6
const HP_NUM_DROP := 18.0        # number's centre, below the bar's centre
# Ability dial — bottom-right, stacked upward: RMB / Q / R, then the smaller dash ring.
const SLOT_D := 56.0
const DASH_D := 40.0
## Must clear BOTH the key label under each ring and the cooldown arc of its neighbour,
## which is drawn SLOT_ARC_PAD beyond the ring — so the usable gap is this minus 2*pad.
const SLOT_GAP := 26.0
const SLOT_RING_W := 2.0
const SLOT_ARC_W := 3.0
const SLOT_ARC_PAD := 5.0        # cooldown arc radius, beyond the ring
const GLYPH_SCALE := 0.52        # ability glyph size as a fraction of its ring diameter
const ABIL_BOTTOM := 58.0        # the dash ring's centre, distance from the bottom edge
const KEY_DROP := 9.0            # key label's centre, below the ring's edge
# Room block — top-right: the bare resource readouts, then header + objective rows.
const BLOCK_W := 300.0
const RES_TOP := 14.0            # resource row centre, below MARGIN
const RES_GLYPH := 19.0
const RES_GAP := 12.0            # glyph -> its number
const RES_SPACING := 30.0        # between resource groups
const HEAD_GAP := 36.0           # resource row -> header
const HEAD_RULE_DROP := 13.0     # header centre -> its hairline
const ROW_FIRST := 22.0          # hairline -> first objective row
const ROW_GAP := 28.0            # between objective rows
const ROW_VALUE_DROP := 21.0     # objective label -> its counter line
const BULLET_HALF := 4.5
const BULLET_GAP := 13.0         # bullet centre -> label
const HEAD_TRACKING := 1.8
# Boss bar — top-centre, same mirrored grammar as the HP bar.
const BOSS_W := 420.0
const BOSS_H := 7.0
const BOSS_DIAMOND := 7.0
const BOSS_NAME_TOP := 9.0       # name centre, below MARGIN
const BOSS_BAR_TOP := 34.0       # bar centre, below MARGIN
const BOSS_TRACKING := 2.6
const COL_BOSS := Color(155.0/255, 79.0/255, 192.0/255)            # #9b4fc0
const COL_BOSS_LABEL := Color(230.0/255, 213.0/255, 242.0/255)     # #e6d5f2
# Contextual hint — bottom-centre, bare prose above the HP bar (no chip, no panel).
const HINT_LIFT := 30.0          # hint centre, above the HP bar's centre
# Vignette (low HP) — the one Slate element Ember keeps, because it is combat information.
const VIGNETTE_DEPTH := 90.0
const VIGNETTE_STEPS := 24
const VIGNETTE_ALPHA := 0.30

## Which Ledger ids show in the top-right readout, in order, with their glyph + colour.
## A resource only appears once it has a nonzero amount — an empty run shows an empty
## corner, and the row grows as the run pays out (the anchor shows three, not a fixed set).
const RES_IDS: Array[String] = ["gold", "resonance-ore", "resonance-dust", "knowledge-shards"]
const RES_GLYPH_ID := {
	"gold": "gold", "resonance-ore": "ore", "resonance-dust": "dust", "knowledge-shards": "shards",
}
const RES_COLOR := {
	"gold": COL_GOLD, "resonance-ore": COL_ORE, "resonance-dust": COL_DUST,
	"knowledge-shards": COL_SHARDS,
}
## Ability id -> glyph id. Slate spelled these as Cinzel monograms (P / B / Sn / Sh / Su);
## Ember draws the mark instead, which is the whole point of the reference language.
const ABILITY_GLYPH := {
	"push": "push", "bolt": "bolt", "snare": "snare", "shockwave": "shockwave", "surge": "surge",
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
var _kills: int = 0        # kills in the CURRENT wave (combat_room pushes them)
var _wave_total: int = 0   # enemies in the CURRENT wave

var _hp: int = 0
var _max_hp: int = 1
var _hint: String = ""
var _echoes: Array = []   # HudCore.fold_echoes output

var _res_amounts: Dictionary = {}   # id -> current amount, for the top-right readout
var _hp_num_alpha: float = 0.0
var _hp_num_hold: float = 0.0


func _ready() -> void:
	super._ready()  # EmberHud: anchors + mouse_filter + the three fonts
	add_to_group("run_hud")
	# Seed from the Ledger so a checkpoint resume shows real values immediately, then
	# track changes live.
	for id: String in RES_IDS:
		_res_amounts[id] = Ledger.get_amount(id)
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


## The live objective counter: kills so far in the current wave, out of its size.
## Pushed by combat_room on each spawn batch and each kill (Ember's objective row).
func set_wave_progress(kills: int, total: int) -> void:
	_kills = kills
	_wave_total = total
	queue_redraw()


func mark_cleared() -> void:
	_cleared = true
	queue_redraw()


func set_hint(text: String) -> void:
	_hint = text
	queue_redraw()


func set_hp(hp: int, max_hp: int) -> void:
	# Any actual change wakes the number; a no-op push (the per-frame poll) leaves it alone.
	if hp != _hp or max_hp != _max_hp:
		_hp_num_alpha = 1.0
		_hp_num_hold = HP_NUM_HOLD_S
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


## Rebuild the echo rail from the run's picks (called on room spawn + after each pick).
func refresh_echoes() -> void:
	_echoes = HudCore.fold_echoes(RunState.echoes, EchoCore.defs())
	queue_redraw()


# --- Smoke/test getters --------------------------------------------------------------

## The room block's header line (floor / room / peril / wave). Still called `chip()` —
## Slate drew it as a top-left chip, Ember draws it as the room block's heading.
func chip() -> String:
	return HudCore.chip_text(_floor, _room, _rooms, _kind, _peril, _wave_idx, _wave_count, _cleared)


func task_rows() -> Array:
	return HudCore.task_rows(_kind, _cleared, _kills, _wave_total, _boss_name)


func echo_tile_count() -> int:
	return _echoes.size()


## True when the top-right readout has at least one resource to show.
func pickup_visible() -> bool:
	for id: String in RES_IDS:
		if float(_res_amounts.get(id, 0.0)) > 0.0:
			return true
	return false


func boss_bar_visible() -> bool:
	return is_instance_valid(_boss) and _boss.current_hp() > 0


## The bar's label: the boss def's name when set, else the generic floor label.
func boss_label() -> String:
	return _boss_name if not _boss_name.is_empty() else "FLOOR %d — BOSS" % _floor


# --- Resource readout ----------------------------------------------------------------

func _on_resource_changed(id: String, _old: float, new_amount: float, _reason: String) -> void:
	if not RES_IDS.has(id):
		return
	_res_amounts[id] = new_amount


func _process(delta: float) -> void:
	_sync_viewport_size()  # EmberHud: the CanvasLayer-under-_ready layout quirk
	# Fade the HP number out after its hold window.
	if _hp_num_alpha > 0.0:
		if _hp_num_hold > 0.0:
			_hp_num_hold -= delta
		elif HP_NUM_FADE_S > 0.0:
			_hp_num_alpha = maxf(0.0, _hp_num_alpha - delta / HP_NUM_FADE_S)
		else:
			_hp_num_alpha = 0.0
	queue_redraw()  # ability cooldowns + boss bar animate every frame


# =====================================================================================
# Draw
# =====================================================================================

func _draw() -> void:
	if HudCore.is_low_hp(_hp, _max_hp):
		_draw_vignette()
	_draw_resources()
	_draw_room_block()
	_draw_boss_bar()
	_draw_echo_rail()
	_draw_hp()
	_draw_abilities()
	_draw_hint()


# --- Resource readout (top-right, bare glyph + big number, no box) --------------------

func _draw_resources() -> void:
	var y := MARGIN + RES_TOP
	var segs: Array = []  # [{id, text, w}]
	var total := 0.0
	for id: String in RES_IDS:
		var amt := int(_res_amounts.get(id, 0.0))
		if amt <= 0:
			continue
		var t := str(amt)
		var w := RES_GLYPH + RES_GAP + _text_w(t, FS_BIG, _font_num)
		segs.append({"id": id, "text": t, "w": w})
		total += w + RES_SPACING
	if segs.is_empty():
		return
	total -= RES_SPACING
	var x := size.x - MARGIN - total
	for seg: Dictionary in segs:
		var gid := str(RES_GLYPH_ID[str(seg["id"])])
		_glyph(Vector2(x + RES_GLYPH * 0.5, y), RES_GLYPH, gid, RES_COLOR[str(seg["id"])])
		_text_at(Vector2(x + RES_GLYPH + RES_GAP, y), str(seg["text"]), COL_INK, FS_BIG, _font_num)
		x += float(seg["w"]) + RES_SPACING


# --- Room block (top-right): header + objective rows ----------------------------------

func _draw_room_block() -> void:
	var left := size.x - MARGIN - BLOCK_W
	var right := size.x - MARGIN
	var head_y := MARGIN + RES_TOP + HEAD_GAP
	# Header: the room state, tracked and dim, with the peril mark kept red.
	_text_tracked(Vector2(left, head_y), chip(), COL_INK_DIM, FS_HEAD, _font_num,
		HEAD_TRACKING, "⚠", COL_DANGER)
	var rule_y := head_y + HEAD_RULE_DROP
	_hairline(left, right, rule_y)
	# Objective rows: a gold diamond bullet, the label, and its counter beneath.
	var y := rule_y + ROW_FIRST
	for row: Dictionary in task_rows():
		var done := bool(row.get("done", false))
		var label_col := COL_INK_FAINT if done else COL_INK
		_diamond(Vector2(left + BULLET_HALF, y), BULLET_HALF,
			COL_INK_FAINT if done else COL_ACCENT)
		_text_at(Vector2(left + BULLET_HALF * 2.0 + BULLET_GAP, y), str(row.get("label", "")),
			label_col, FS_LABEL, _font_body)
		var want := int(row.get("want", 0))
		if want > 0:
			var have := int(row.get("have", 0))
			var col := COL_ACCENT if have >= want else COL_INK
			_text_at(Vector2(left + BULLET_HALF * 2.0 + BULLET_GAP, y + ROW_VALUE_DROP),
				"%d / %d" % [have, want], col, FS_VALUE, _font_num)
			y += ROW_VALUE_DROP
		y += ROW_GAP


# --- Echo rail (bottom-left, growing upward) ------------------------------------------

func _draw_echo_rail() -> void:
	var cx := MARGIN + ECHO_D * 0.5
	# The lowest medallion's bottom lines up with the HP bar's bottom edge.
	var base_y := size.y - HP_BOTTOM + HP_H * 0.5 - ECHO_D * 0.5
	for i in _echoes.size():
		var cy := base_y - float(i) * (ECHO_D + ECHO_GAP)
		if cy - ECHO_D * 0.5 < MARGIN:
			break  # ran out of screen; the rail simply stops (no wrap — one clean column)
		var centre := Vector2(cx, cy)
		_ring(centre, ECHO_D * 0.5, ECHO_RING_W, COL_RING)
		var tile: Dictionary = _echoes[i]
		_text_centred(cx, cy, str(tile.get("monogram", "?")), COL_INK, FS_MONO, _font_display)
		var count := int(tile.get("count", 1))
		if count > 1:
			var badge := centre + Vector2(ECHO_D * 0.34, -ECHO_D * 0.34)
			_disc(badge, ECHO_BADGE_R, COL_ACCENT)
			_text_centred(badge.x, badge.y, str(count), COL_ON_ACCENT, FS_KEY, _font_num)


# --- HP bar (bottom-centre, filling outward from the diamond) -------------------------

func _draw_hp() -> void:
	var low := HudCore.is_low_hp(_hp, _max_hp)
	var cx := size.x * 0.5
	var cy := size.y - HP_BOTTOM
	var half := HP_W * 0.5
	var top := cy - HP_H * 0.5
	draw_rect(Rect2(cx - half, top, HP_W, HP_H), COL_TRACK)
	var frac := clampf(float(_hp) / float(maxi(1, _max_hp)), 0.0, 1.0)
	var reach := half - HP_FILL_INSET
	var run := reach * frac
	if run > 0.0:
		var fill := COL_HP_LOW if low else COL_HP
		draw_rect(Rect2(cx - HP_FILL_INSET - run, top, run, HP_H), fill)
		draw_rect(Rect2(cx + HP_FILL_INSET, top, run, HP_H), fill)
	_diamond(Vector2(cx, cy), HP_DIAMOND, COL_DANGER if low else COL_ACCENT)
	if _hp_num_alpha > 0.0:
		_text_centred(cx, cy + HP_NUM_DROP, "%d / %d" % [_hp, _max_hp],
			Color(COL_INK, _hp_num_alpha), FS_VALUE, _font_num, true)


# --- Ability dial (bottom-right, stacked upward) --------------------------------------

func _draw_abilities() -> void:
	var info := _player.ability_slot_info() if is_instance_valid(_player) else {}
	var cx := size.x - MARGIN - SLOT_D * 0.5
	# Bottom-up: the dash pip sits nearest the corner, the three cast slots climb above it.
	var cy := size.y - ABIL_BOTTOM
	var dash: Dictionary = info.get("dash", {})
	_draw_ability(Vector2(cx, cy), DASH_D, "dash", "SPC",
		float(dash.get("cd_left", 0.0)), float(dash.get("cd_total", 0.0)), true)
	cy -= DASH_D * 0.5 + SLOT_GAP + SLOT_D * 0.5
	for i in SLOT_KEYS.size():
		var slot: String = SLOT_KEYS[SLOT_KEYS.size() - 1 - i]  # R, Q, RMB (bottom to top)
		var d: Dictionary = info.get(slot, {})
		var id := str(d.get("id", ""))
		var has := not id.is_empty()
		_draw_ability(Vector2(cx, cy), SLOT_D, str(ABILITY_GLYPH.get(id, "")),
			str(SLOT_KEY_LABEL[slot]), float(d.get("cd_left", 0.0)),
			float(d.get("cd_total", 0.0)), has)
		cy -= SLOT_D + SLOT_GAP


func _draw_ability(centre: Vector2, diameter: float, glyph_id: String, key: String,
		cd_left: float, cd_total: float, equipped: bool) -> void:
	var r := diameter * 0.5
	var on_cd := cd_left > 0.01
	var ready_now := equipped and not on_cd
	# Ready is the ONLY thing gold on a slot; everything else is the idle ring.
	_ring(centre, r, SLOT_RING_W, COL_ACCENT if ready_now else COL_RING)
	if equipped and not glyph_id.is_empty():
		_glyph(centre, diameter * GLYPH_SCALE, glyph_id, COL_INK if ready_now else COL_INK_FAINT)
	if on_cd and cd_total > 0.0:
		# The arc GROWS back as the cooldown recovers — a full ring means ready. Drawn at
		# full accent, not a soft one: "can I cast yet" is the dial's whole job.
		_arc_sweep(centre, r + SLOT_ARC_PAD, SLOT_ARC_W,
			1.0 - clampf(cd_left / cd_total, 0.0, 1.0), COL_ACCENT)
	_text_centred(centre.x, centre.y + r + KEY_DROP, key, COL_INK_DIM, FS_KEY, _font_num)


# --- Boss bar (top-centre) ------------------------------------------------------------

func _draw_boss_bar() -> void:
	if not boss_bar_visible():
		return
	var cx := size.x * 0.5
	var label := boss_label()
	var lw := _text_tracked_w(label, FS_VALUE, _font_display, BOSS_TRACKING)
	_text_tracked(Vector2(cx - lw * 0.5, MARGIN + BOSS_NAME_TOP), label, COL_BOSS_LABEL,
		FS_VALUE, _font_display, BOSS_TRACKING)
	var cy := MARGIN + BOSS_BAR_TOP
	var half := BOSS_W * 0.5
	var top := cy - BOSS_H * 0.5
	draw_rect(Rect2(cx - half, top, BOSS_W, BOSS_H), COL_TRACK)
	var frac := clampf(float(_boss.current_hp()) / float(maxi(1, _boss_max)), 0.0, 1.0)
	var reach := half - HP_FILL_INSET
	var run := reach * frac
	if run > 0.0:
		draw_rect(Rect2(cx - HP_FILL_INSET - run, top, run, BOSS_H), COL_BOSS)
		draw_rect(Rect2(cx + HP_FILL_INSET, top, run, BOSS_H), COL_BOSS)
	_diamond(Vector2(cx, cy), BOSS_DIAMOND, COL_BOSS_LABEL)


# --- Contextual hint (bottom-centre, bare prose) --------------------------------------

func _draw_hint() -> void:
	if _hint.is_empty():
		return
	_text_centred(size.x * 0.5, size.y - HP_BOTTOM - HINT_LIFT, _hint, COL_INK,
		FS_LABEL, _font_body, true)


# --- Vignette (low HP) ----------------------------------------------------------------

func _draw_vignette() -> void:
	var band := VIGNETTE_DEPTH / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var t := float(i) / float(VIGNETTE_STEPS)
		var inset := t * VIGNETTE_DEPTH
		var col := Color(COL_HP, (1.0 - t) * VIGNETTE_ALPHA)
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			col, false, band + 1.0)
