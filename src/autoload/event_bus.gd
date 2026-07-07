extends Node
## EventBus — the spine of the architecture (PRD §7.0, architecture-schemas.md §5).
##
## The ONLY cross-domain channel. Every meaningful state change is emitted here as a
## typed, past-tense signal; achievements, dialogue gating, stats, town tick, and the
## future strategy pillar all *subscribe*. Systems never call each other for
## bookkeeping — they emit. (Signals down / calls up stay fine WITHIN a scene tree;
## this bus is for crossing domain boundaries.)
##
## Rules (godot-conventions.md):
## - Thin: the bus holds NO state and NO logic. It routes.
## - Adding a signal is fine; adding a getter/setter here is architecture rot.
## - No `get_node("/root/...")` reaching into another pillar — subscribe instead.

# Most signals are emitted by systems that don't exist yet (Skeleton milestone
# builds the socket before the appliances) — that's expected, not dead code.
@warning_ignore_start("unused_signal")

# --- Run lifecycle (roguelite pillar) ---
signal run_started(run_number: int)
signal run_ended(victory: bool, floor_reached: int, stats: Dictionary)
signal death(source_id: String)                      # player died in-run (no penalty, per locked design)
signal dissolved()                                   # player walked into the codex artifact on a full clear (final chamber) — Tycho dissolves + respawns in town (2026-07-07); ticks `dissolves`, NOT `deaths`
signal boss_killed(boss_id: String, floor: int)

# --- Economy ---
signal resource_changed(id: String, old_amount: float, new_amount: float, reason: String)

# --- Learning / tech ---
signal tech_researched(tech_id: String)
signal age_advanced(age: int)

# --- Town ---
signal building_built(building_id: String, level: int)

# --- Story / codex ---
signal dialogue_seen(dialogue_id: String)
signal codex_shard_added(total: int)

# --- Meta ---
signal achievement_unlocked(achievement_id: String)
signal save_loaded(slot: int)                        # a slot was loaded; systems re-read their state

@warning_ignore_restore("unused_signal")
