extends RefCounted
class_name UnlocksCore
## Pure unlock-cascade logic (PRD §7.1): town systems come online one at a time as
## the story sets flags — never all open from minute 0. SYSTEMS maps a system id to
## the story flag that opens it; is_unlocked reads state.story.flags. No engine
## state, no autoloads — unit-testable headless.
##
## Mapping (act1-story-beats.md Phase B — the cascade beats):
##   weapons  <- b1  (Mara and the ore → the forge)
##   etchings <- b2  (Thomas; the etchings SYSTEM is not built in v1 — the mapping
##                    is defined but dormant, gating nothing yet)
##   tech     <- b3  (Sophia cracks the shards → the research desk)
##   building <- b4  (Herzog opens the ledger → the build plots)
##
## The NPC talk spots and the dungeon portal are NEVER gated (talking is how the
## beats fire, and the dungeon is always the way forward).

const SYSTEMS := {
	"weapons": "b1",
	"etchings": "b2",
	"tech": "b3",
	"building": "b4",
}


## Is `system` unlocked in this save? Reads state.story.flags. An unknown system id
## is a typo — LOUD error + false, never silently open a facility.
static func is_unlocked(state: Dictionary, system: String) -> bool:
	if not SYSTEMS.has(system):
		push_error("UnlocksCore: unknown system \"%s\"" % system)
		return false
	var flags: Dictionary = (state.get("story", {}) as Dictionary).get("flags", {})
	return bool(flags.get(str(SYSTEMS[system]), false))
