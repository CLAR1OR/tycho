extends EmberHud
class_name EchoOfferPanel
## In-run Echo offer UI — "The etchings answer" (O1, human-picked 2026-07-09 via
## claude.ai/design, "Echo Offer" group). No panel, no cards: when the offer fires (the
## game is already paused) the whole screen dims and three resonance marks bloom over the
## dimmed battlefield. Each mark carries the echo's Cinzel monogram (the exact glyph it
## will wear on the RunHud echo rail — HudCore.monogram, reused), a key badge, the name in
## Cinzel, and the effect lines. Hover wakes the ring; click or number key picks.
##
## **Migrated to Ember 2026-08-13** (Tier A of design/ui-hud.md § "Migrating to Ember").
## This screen was ALREADY the language before the language had a name — O1 was picked as
## "no panel, no cards" nine months before Ember was named, so the migration is mostly
## deleting the three Slate leftovers: the chip-styled key badge and held badge became a
## thin ring and a gold disc (the run HUD's stack-badge grammar), the letter-spaced sub
## dropped its bespoke FontVariation for the shared `_text_tracked`, and the effect lines
## moved from mono to the UI voice (they are phrases, not readouts).
##
## Drawn entirely in `_draw` (the panel IS the screen); hover/click hit-test in `_gui_input`.
## The pure display rules live in EchoOfferCore; this owns only pixels + hit-testing.
##
## FROZEN: the panel unpauses BEFORE reporting the pick, so whatever the callback does
## (apply stats, open the exit) runs in a live tree. present()/pick()/mark_count() are
## public so the headless smoke driver can choose programmatically. The mock's gold
## pick-flash and fly-to-rail animation are DEFERRED — pick() stays synchronous.
##
## HUMAN: everything under "Style / copy" is a PLACEHOLDER — dial like FEEL numbers (no
## combat feel, so no `# FEEL:` tag). The shared palette + fonts live in EmberHud.

# =====================================================================================
# Style / copy — placeholders. (Palette + fonts + primitives are shared — see EmberHud.)
# =====================================================================================
## Deliberately LIGHTER than EmberHud.COL_SCRIM: a menu can afford to bury the world, but
## this offer fires mid-run and you are still reading the battlefield you will drop back
## into. HUMAN: this is the one dial that decides whether the offer feels like a pause or
## like a screen.
const DIMMER := Color(8.0/255, 7.0/255, 12.0/255, 0.62)
const COL_DRAWBACK := Color(201.0/255, 129.0/255, 129.0/255)     # #c98181 soft red (softer than COL_DANGER)
const COL_MONO_HOVER := Color(191.0/255, 242.0/255, 255.0/255)   # #bff2ff woken monogram
const TITLE := "Your etchings glow."          # placeholder copy
const SUB := "CHOOSE AN ECHO"                 # placeholder copy (tracked caps sub)
const WOVEN_FMT := "woven from %s"            # placeholder copy — wraps the resolved parents
# Header
const HEADER_TOP_FRAC := 0.13
const FS_OFFER_TITLE := 21    # title (body / Garamond — the game speaking, not a label)
const FS_OFFER_SUB := 11      # tracked caps sub (ui med)
const SUB_TRACKING := 3.0
const SUB_DY := 24.0
# Marks (a shallow arc; ring radius, the middle lifted when the count is odd)
const RING_R := 75.0
const ARC_BASE_FRAC := 0.52   # ring-centre y as a fraction of size.y
const ARC_LIFT := 38.0        # the middle mark rides higher (odd counts, >= 3)
const RING_W := 2.0
const RING_IDLE_ALPHA := 0.45
const MONO_IDLE_ALPHA := 0.85
const FS_OFFER_MONO := 46     # monogram (display / Cinzel)
const FS_NAME := 21     # echo name (display / Cinzel)
const FS_FX := 13       # effect lines (ui)
const FS_PARENTS := 10  # synergy parents line (ui med, tracked)
const FS_OFFER_KEY := 11      # key badge digit (num)
const FS_HELD := 10     # held ×n badge (num)
const NAME_DY := 26.0   # name centre, below the ring's edge
const LINE_GAP := 22.0
const FX_GAP := 18.0
# Key badge: a thin ring at the mark's top, the footer-prompt grammar.
const KEY_R := 11.0
# Held ×n badge: a gold disc, the run HUD's echo-rail stack badge, same corner.
const HELD_R := 9.0
# Glow / halo (layered fills + arcs, like the S2 title glow / E1 mark halo)
const GLOW_A_IDLE := 0.10
const GLOW_A_HOVER := 0.16
const GLOW_LAYERS := 5
const HALO_A := 0.14
const HALO_W := 6.0
const HALO_STEP := 5.0
const HALO_RINGS := 3
# Synergy weave (a faint outer second ring)
const WEAVE_GAP := 5.0
const WEAVE_W := 3.0
const WEAVE_ALPHA := 0.30
# Hit-test box around a mark (ring + the name/effects below it)
const HIT_W := 220.0
const HIT_TOP := 18.0
const HIT_BOT := 104.0

var _ids: Array[String] = []
var _on_pick: Callable
var _defs: Dictionary = {}
var _hovered: int = -1


func _ready() -> void:
	super._ready()  # EmberHud: anchors + the four fonts (mouse_filter is overridden below)
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the tree is paused
	add_to_group("echo_offer")
	mouse_filter = Control.MOUSE_FILTER_STOP  # the whole screen catches hover + clicks


## Show the offer and pause the game. `on_pick` is called with the chosen echo id.
func present(offer_ids: Array[String], on_pick: Callable) -> void:
	_ids = offer_ids
	_on_pick = on_pick
	_defs = EchoCore.defs()
	_sync_viewport_size()  # the marks draw off size — set it now, before the first frame
	get_tree().paused = true
	Sfx.play("echo-open")
	queue_redraw()


## Choose mark `index` (0-based). Public: the mouse, number keys, and the smoke driver all
## land here. FROZEN semantics: unpause BEFORE reporting the pick, synchronously.
func pick(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	var id := _ids[index]
	var cb := _on_pick
	Sfx.play("echo-pick")
	get_tree().paused = false
	queue_free()
	if cb.is_valid():
		cb.call(id)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_3:
			get_viewport().set_input_as_handled()
			pick(int(key - KEY_1))  # keys map 1..n; pick() guards a key past the count


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _mark_at((event as InputEventMouseMotion).position)
		if hit != _hovered:
			_hovered = hit
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := _mark_at((event as InputEventMouseButton).position)
		if i >= 0:
			pick(i)


func _process(_delta: float) -> void:
	# Anchors set in a Control's own _ready under a CanvasLayer get no layout pass (size
	# stays 0,0) — sync to the viewport, like every other Ember surface.
	var before := size
	_sync_viewport_size()
	if size != before:
		queue_redraw()


# --- Debug (the headless smoke reads this) -------------------------------------------

func mark_count() -> int:
	return _ids.size()


# --- Layout / hit-test ---------------------------------------------------------------

## The ring centre of mark `i` — a shallow arc: outer marks lower, the exact-middle mark
## lifted when the count is odd (and >= 3). 1-2-mark offers centre gracefully.
func _center(i: int) -> Vector2:
	var n := _ids.size()
	var cy := size.y * ARC_BASE_FRAC
	if n >= 3 and n % 2 == 1 and i == n / 2:
		cy -= ARC_LIFT
	return Vector2(size.x * float(i + 1) / float(n + 1), cy)


func _mark_at(pos: Vector2) -> int:
	for i in _ids.size():
		var c := _center(i)
		var rect := Rect2(c.x - HIT_W * 0.5, c.y - RING_R - HIT_TOP, HIT_W, RING_R + HIT_TOP + HIT_BOT)
		if rect.has_point(pos):
			return i
	return -1


# --- Draw ----------------------------------------------------------------------------

func _draw() -> void:
	if size.x < 1.0:
		return
	_scrim(DIMMER)  # the dim over the battlefield — lighter than a menu's, on purpose
	_draw_header()
	for i in _ids.size():
		_draw_mark(i)


func _draw_header() -> void:
	var cx := size.x * 0.5
	var top := size.y * HEADER_TOP_FRAC
	_text_centred(cx, top, TITLE, COL_INK_DIM, FS_OFFER_TITLE, _font_body)
	var w := _text_tracked_w(SUB, FS_OFFER_SUB, _font_ui_med, SUB_TRACKING)
	_text_tracked(Vector2(cx - w * 0.5, top + SUB_DY), SUB, COL_INK_FAINT, FS_OFFER_SUB,
		_font_ui_med, SUB_TRACKING)


func _draw_mark(i: int) -> void:
	var id := _ids[i]
	var def: Dictionary = _defs.get(id, {"name": id, "desc": ""})
	var c := _center(i)
	var hovered := i == _hovered
	var synergy := EchoOfferCore.is_synergy(def)
	# Radial inner glow, then the ring (a faint outer weave first when it's a synergy).
	_inner_glow(c, hovered)
	if synergy:
		_ring(c, RING_R + WEAVE_GAP, WEAVE_W, Color(COL_DUST, WEAVE_ALPHA))
	_ring(c, RING_R, RING_W, COL_DUST if hovered else Color(COL_DUST, RING_IDLE_ALPHA))
	if hovered:
		_halo(c)
	# Monogram — the exact glyph the pick will wear on the rail.
	var mono := HudCore.monogram(str(def.get("name", id)))
	var mcol := COL_MONO_HOVER if hovered else Color(COL_DUST, MONO_IDLE_ALPHA)
	_text_centred(c.x, c.y, mono, mcol, FS_OFFER_MONO, _font_display)
	# Key badge (top of the ring) — a thin ring with the digit, the footer-prompt grammar.
	# Drawn at INK weight, not the usual faint ring: the O1 rebuild deleted the "press
	# 1 / 2 / 3" hint line on the grounds that these badges carry the affordance, so they
	# are the only thing telling you the keys work. The first probe render had them at
	# COL_RING over the mark's own glow, where they all but vanished.
	var key_c := c + Vector2(0.0, -RING_R)
	_ring(key_c, KEY_R, 1.4, COL_INK_DIM)
	_text_centred(key_c.x, key_c.y, str(i + 1), COL_INK, FS_OFFER_KEY, _font_num)
	# Held ×n badge (upper-right, stackables only) — a gold disc with dark text, the same
	# badge the echo rail wears, in the same corner of the same medallion.
	var held := EchoOfferCore.held_count(id, RunState.echoes)
	if held > 0:
		var held_c := c + Vector2(RING_R * 0.62, -RING_R * 0.62)
		_disc(held_c, HELD_R, COL_ACCENT)
		_text_centred(held_c.x, held_c.y, "×%d" % held, COL_ON_ACCENT, FS_HELD, _font_num)
	# Name, then (synergy) the parents line, then the effect lines.
	var y := c.y + RING_R + NAME_DY
	_text_centred(c.x, y, str(def.get("name", id)), COL_INK, FS_NAME, _font_display, true)
	y += LINE_GAP
	if synergy:
		var parents := WOVEN_FMT % EchoOfferCore.parents_line(def, _defs)
		var pw := _text_tracked_w(parents, FS_PARENTS, _font_ui_med)
		_text_tracked(Vector2(c.x - pw * 0.5, y), parents, COL_INK_FAINT, FS_PARENTS, _font_ui_med)
		y += FX_GAP
	for fx: Dictionary in EchoOfferCore.effect_lines(str(def.get("desc", ""))):
		var col := COL_DRAWBACK if bool(fx["drawback"]) else COL_INK_DIM
		_text_centred(c.x, y, str(fx["text"]), col, FS_FX, _font_ui, true)
		y += FX_GAP


# --- draw helpers --------------------------------------------------------------------

func _inner_glow(center: Vector2, hovered: bool) -> void:
	var a := GLOW_A_HOVER if hovered else GLOW_A_IDLE
	for i in GLOW_LAYERS:
		var t := float(i) / float(GLOW_LAYERS)
		draw_circle(center, RING_R * (1.0 - t * 0.35), Color(COL_DUST, a * (1.0 - t)))


func _halo(center: Vector2) -> void:
	for i in HALO_RINGS:
		var r := RING_R + HALO_STEP * float(i + 1)
		_ring(center, r, HALO_W, Color(COL_DUST, HALO_A / float(i + 1)))
