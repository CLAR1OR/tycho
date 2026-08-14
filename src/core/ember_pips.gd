extends EmberHud
class_name EmberPips
## A level track as a packable Control — `EmberHud._pips` (gold diamonds) wrapped so a
## Control-tree screen can drop it into an HBox beside a name or a cost.
##
## Why it exists: the pip track is the single most-repeated mark in the game's menus (weapon
## refine levels, building levels, attunement depth, mark depth), and before the Tier B
## migration FOUR screens each drew their own. The forge built five `Panel` nodes with
## StyleBoxFlat borders; the etchings, attunements and survey pages each printed literal
## "●"/"○" glyphs in whatever font the row happened to inherit — so the same idea rendered
## at three different sizes with three different fill rules, and "what does hollow mean"
## had three answers. One node, one rule (EmberMenuCore.pip_states), one look.
##
## HUMAN: PIP_HALF / PIP_GAP / PAD are placeholders — dial like FEEL numbers.
## Dial board: design/feel-tuning.md § Ember Tier B.

const PIP_HALF := 4.5    # diamond half-diagonal
const PIP_GAP := 13.0    # centre to centre
const PAD := Vector2(2.0, 6.0)   # breathing room around the track, so a row doesn't clip it

var _states: Array[String] = []


func _ready() -> void:
	super._ready()
	# EmberHud's _ready presets a full-rect HUD overlay; a pip track is an inline element
	# sized by its own content, so undo the anchors and let custom_minimum_size drive it.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Point the track at a level. `max_level` 0 draws nothing (a building with no authored
## levels yet, or a track that does not apply to this row).
func setup(level: int, max_level: int) -> void:
	set_states(EmberMenuCore.pip_states(level, max_level))


## Set the states directly. For a track this is `EmberMenuCore.pip_states` output; for the
## SINGLE pip that marks one row of a ladder (a build page's level rows, the etchings'
## deepen rungs) the caller names the state outright — `["filled"]` / `["next"]` / `["rest"]`
## — because "which of the three is this row" is a fact those screens already know, and
## reverse-engineering it into a (level, max) pair produced a real bug: a row whose track
## was 0-long drew NO pip at all, so its text lost the rail every other row hung on.
func set_states(states: Array[String]) -> void:
	_states = states
	var n := _states.size()
	var w := 0.0 if n == 0 else float(n - 1) * PIP_GAP + PIP_HALF * 2.0
	custom_minimum_size = Vector2(w + PAD.x * 2.0, PIP_HALF * 2.0 + PAD.y * 2.0)
	queue_redraw()


func _draw() -> void:
	if _states.is_empty():
		return
	_pips(Vector2(size.x * 0.5, size.y * 0.5), _states, PIP_HALF, PIP_GAP)
