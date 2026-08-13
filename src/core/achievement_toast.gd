extends EmberHud
class_name AchievementToast
## The achievement unlock banner (architecture-schemas.md §5). **Migrated to Ember
## 2026-08-13** (Tier A of design/ui-hud.md § "Migrating to Ember") — it was a
## gold-bordered Slate panel; it is now the echo-medallion grammar instead: a gold ring
## carrying the monogram, tracked caps over the name beside it, all of it on one hairline
## and floating on the world with nothing behind it.
##
## Why the medallion and not a smaller panel: the toast plays over BOTH town and combat,
## so it is the one piece of UI most likely to be seen against a bright, busy frame. Under
## Slate a panel solved that by covering the frame up. Under Ember the shadowed text and
## the ring do it, and the reward reads as the same kind of object as an echo pickup —
## which is what it is.
##
## Owned by the Achievements autoload on its OWN CanvasLayer, so it works in town AND
## in-run and survives every scene swap. PROCESS_MODE_ALWAYS: unlocks can land while a
## panel owns the pause (building_built fires from the paused build panel) and the toast
## must still play. enqueue() is the only way in (the Achievements autoload calls it).
##
## RESTYLE ONLY — enqueue / showing / current_name / queued / shown_total, the queue
## semantics, and the slide/hold/fade lifecycle are byte-identical.
##
## HUMAN: everything under "Style" is a PLACEHOLDER — colours, sizes, timings. Dial like
## FEEL numbers (no combat feel rides this, so no `# FEEL:` tag).

# =====================================================================================
# Style — placeholders (sizes / timings). Palette + fonts are shared (see EmberHud).
# =====================================================================================
## The medallion's centre, below the top edge. Deliberately LOW: this toast is the one
## piece of UI that plays in every scene, so it has to clear both of the things that own
## the top band elsewhere — the run HUD's boss bar (top-centre, ends ~63) and the town
## HUD's resource strip (top-right, ends ~75, and it reaches past the middle now that
## seven readouts sit there with no panel padding). The first probe render had it drawn
## through the town strip. HUMAN: placeholder — the clearance is the constraint, the
## exact value is yours.
const TOP_MARGIN := 96.0
const MEDAL_R := 21.0       # the monogram ring
const MEDAL_RING_W := 1.6
const TEXT_GAP := 15.0      # ring edge -> the text block
const CAPTION_LIFT := 10.0  # caption centre, above the block's centre
const NAME_DROP := 10.0     # name centre, below the block's centre
const RULE_DROP := 22.0     # the hairline under it all, below the medallion's centre
const RULE_PAD := 14.0      # how far the rule runs past the content, each side
const SLIDE_S := 0.25       # slide/fade in
const HOLD_S := 3.0         # fully shown
const FADE_S := 0.6         # fade out
const SLIDE_PX := 24.0      # slide-in travel
const FS_CAPTION := 10      # the small "ACHIEVEMENT" caption (ui med, tracked)
const FS_NAME := 17         # the achievement name (display)
const FS_ICON := 15         # the monogram (display)
const CAPTION := "ACHIEVEMENT"  # HUMAN: placeholder copy

var _queue: Array[Dictionary] = []   # [{name, icon}] waiting their turn
var _current: Dictionary = {}        # the toast on screen ({} = none)
var _t := 0.0                        # seconds into the current toast's life
var _shown_total := 0                # cumulative count (smoke getter)


func _ready() -> void:
	super._ready()  # EmberHud: anchors + mouse_filter IGNORE + the four fonts
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("achievement_toast")


## Queue one unlock banner. Toasts play strictly one at a time, in enqueue order.
func enqueue(display_name: String, icon: String) -> void:
	_queue.append({"name": display_name, "icon": icon})


# --- Smoke/test getters ----------------------------------------------------------------

func showing() -> bool:
	return not _current.is_empty()


func current_name() -> String:
	return str(_current.get("name", ""))


func queued() -> int:
	return _queue.size()


func shown_total() -> int:
	return _shown_total


# --- Animation ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_sync_viewport_size()  # EmberHud: the CanvasLayer-under-_ready layout quirk
	if _current.is_empty():
		if _queue.is_empty():
			return
		_current = _queue.pop_front()
		_shown_total += 1
		_t = 0.0
	_t += delta
	if _t >= SLIDE_S + HOLD_S + FADE_S:
		_current = {}
	queue_redraw()


## The current toast's alpha from its life phase (slide-in ramp, hold, fade-out).
func _alpha() -> float:
	if _t < SLIDE_S:
		return _t / SLIDE_S
	if _t < SLIDE_S + HOLD_S:
		return 1.0
	return maxf(0.0, 1.0 - (_t - SLIDE_S - HOLD_S) / FADE_S)


func _draw() -> void:
	if _current.is_empty() or size.x < 1.0:
		return
	var a := _alpha()
	var slide := (1.0 - minf(_t / SLIDE_S, 1.0)) * -SLIDE_PX
	var cy := TOP_MARGIN + slide
	# Measure first: the whole thing is centred as one block, and there is no panel to
	# anchor to, so the widths have to be known before anything is drawn.
	var name_text := current_name()
	var cap_w := _text_tracked_w(CAPTION, FS_CAPTION, _font_ui_med)
	var name_w := _text_w(name_text, FS_NAME, _font_display)
	var text_w := maxf(cap_w, name_w)
	var total := MEDAL_R * 2.0 + TEXT_GAP + text_w
	var left := (size.x - total) * 0.5
	var medal := Vector2(left + MEDAL_R, cy)
	# The medallion: the echo-rail grammar — a gold ring with the monogram inside.
	_ring(medal, MEDAL_R, MEDAL_RING_W, Color(COL_ACCENT, a))
	_text_centred(medal.x, medal.y, str(_current.get("icon", "?")),
		Color(COL_ACCENT, a), FS_ICON, _font_display)
	var tx := left + MEDAL_R * 2.0 + TEXT_GAP
	_text_tracked(Vector2(tx, cy - CAPTION_LIFT), CAPTION, Color(COL_INK_DIM, a),
		FS_CAPTION, _font_ui_med)
	# The name carries the shadow: it is the biggest text with nothing behind it, and the
	# toast can land over anything (a lit forge, a hazard flash).
	_text_shadowed(Vector2(tx, cy + NAME_DROP), name_text, Color(COL_INK, a),
		FS_NAME, _font_display)
	_hairline(left - RULE_PAD, left + total + RULE_PAD, cy + RULE_DROP,
		Color(COL_HAIR, COL_HAIR.a * a))
