# Boss #1 — Floor 1, The Scanned Cave

> **Drafted 2026-07-10; DIRECTION A — THE DEN-WARDEN — PICKED BY THE HUMAN same day.** This doc does two jobs: §1–2 set the **boss grammar shared by all five bosses** (so bosses 2–5 inherit it), §3 records the three directions considered (B's hazard integration is folded into A; C is parked as a floor-4 examiner candidate). Open-question leans adopted at the pick: **no escorts** (boss #1 teaches the duel), **single 50% phase threshold**, name placeholder **"The Den-Warden"** (human renames with the dialogue pass), no dedicated reconfiguration sting in v1 (boss track carries it). Per the content budget, bosses are the most expensive single items in v1 — design + arena + feel + tells — and feel numbers are human territory throughout.

---

## 1. What a boss is in this game (constraints from locked decisions)

- **One boss per floor, floor 5 = final boss** (content-budget). Boss room = a single staged fight, no waves, clean arena (no random hazard scatter — the boss OWNS the room; `dungeon-strata.md` slice decision).
- **The fiction (IC-11 + the strata lore engine):** the runs are learning trials; each stratum probes one capability. The boss is that floor's **examiner** — the final, concentrated test of the floor's lesson. Bosses are imitations like everything else in the learning-space, and they follow the same gradient: floor 1's examiner is the most convincing imitation of a living thing; by floor 5 the examiner no longer bothers to pretend. **The deniability rule binds bosses hardest of all** — a first-time player on floor 1 must read "monster," not "test proctor."
- **What already exists and stays:** the boss bar (RunHud), boss bounty (gold + 1 Knowledge Shard + 1 Ore), the post-boss ~30% missing-HP heal valve, the guaranteed post-boss echo pick, the boss music track, `EventBus.boss_killed` → the B3 unlock cascade. The boss slots into all of it unchanged.
- **Floor 1 reality check:** the player may arrive on their FIRST run — sword + dash only, no etchings, no attunements, possibly zero echoes. Boss #1 must be honest with exactly that kit, and it carries the extra job of teaching what a boss *is* here: read the tell, dash on the beat, hit the opening.

## 2. Boss grammar (applies to all five — bosses 2–5 inherit this section)

1. **Compose from the proven telegraph vocabulary; invent arrangements, not kinds.** The game already has readable tells the player has practiced on trash: the Slammer's growing ground circle, the Charger's line telegraph, the Archer's projectile, and six hazard behaviours (vent/node/burst/beam/drift/mist). A boss uses these shapes at boss scale and in *sequences*. New mechanic kinds are a per-boss exception that must earn its cost, never the default. (This is the budget lever that makes 5 bosses affordable.)
2. **Tell discipline:** fixed telegraph colours, same as enemies and hazards (the strata readability guard). Boss tells run slightly LONGER than trash tells — a boss is a harder test, not a faster gotcha. All timings are `# FEEL:` placeholder exports, human-dialed.
3. **Phase structure:** phases switch at HP thresholds; the transition is a short invulnerable **reconfiguration beat** (diegetic: the examiner adjusting the test — reads as the monster enraging/molting on early floors). Boss #1 gets **2 phases** (the simplest possible statement of the grammar); later bosses may take 3. Each phase = a small attack loop (2–3 moves) with ONE new element over the previous phase.
4. **The floor's signature hazard is the boss's phase-2 weapon.** The floor taught a hazard for 6–10 rooms; the exam uses it. (Floor 1: vent plates erupt under the boss's command; floor 4: the arena grows sweep beams; etc.) This converges floor lesson and boss fight into one statement, and it's nearly free — the Hazard class already runs these behaviours.
5. **No add-spam.** Escorts (if any) are sparse, from the floor's own enemy mix, and never spawn during a tell the player is currently dodging. Boss #1: zero adds in phase 1; phase 2 at most one pair, once (open question below).
6. **Never unwinnable, always leavable:** the fight must be honest for the floor's minimum kit; death costs nothing (locked). The quit-gate rules apply as in any room.
7. **Dialogue hooks per boss** (contextual pool, `act1-story-beats.md`): first-kill reaction, death-to-this-boss reaction (per boss), Sophia getting the shard from THIS floor. Drafted through `voice-guides.md` like all dialogue; not part of the boss build chunk.

## 3. Boss #1 — three directions (HUMAN: pick one, or blend)

The trial focus of The Scanned Cave is **timing & evasion — the dash is the swarm's first lesson.** All three directions test exactly that; they differ in fiction, silhouette, and how loudly they whisper the secret.

### Direction A — The Den-Warden (the convincing beast) ← RECOMMENDED
The floor imitates the cave Tycho fell into; its examiner imitates the thing that would rule such a cave — a great burrowing beast (placeholder primitive now; salamander/mole silhouette when the asset pipeline lands). The most convincing imitation on the most convincing floor.
- **Phase 1 (100→50%):** a 3-move loop, all known shapes — a **lunge** (Charger line telegraph, boss-length), a **swipe** (short melee arc, the dummy's strike grammar, bigger), a **circling retreat** (repositioning beat = the player's punish window).
- **Phase 2 (≤50%):** reconfiguration beat, then it **burrows** — the body vanishes, chained ground circles (Slammer telegraph ×2–3) track the player, and it **erupts** under the last one — and from here on, the arena's **vent plates** (floor hazard, rule 4) fire in sequence with its loop. Same lesson as the whole floor — watch the ground, dash on the beat — at exam intensity.
- **The hindsight tell** (deniability-safe): its roar is the SAME roar every time, its loop never varies. A beast would vary; a copy doesn't. First playthrough: "a monster with patterns" (i.e., a video-game boss — perfectly deniable). Post-reveal: "it was a recording."
- **Cost: lowest.** Every telegraph exists; burrow = hide mesh + move a marker; vents ride the Hazard class.

### Direction B — The Loose Stone (the cave itself fights)
No creature — the examiner is the floor's *terrain* animated: a rolling mass of imitation rock. Rockfall volleys (circle telegraphs raining in patterns), boulder sweeps (line telegraphs wall-to-wall), vent eruptions escalating from move to phase. Phase 2 splits it into 2–3 chunks that reassemble.
- Reads as "earth magic" — deniable. Purest expression of "the dungeon is the test," and almost the whole fight rides the hazard engine (very scriptable).
- **Risks:** a rock pile is a weak first-boss silhouette (bosses 2–5 will struggle to top "the level attacks you" if it's spent on floor 1), and a no-face boss gives the dialogue pool little to react to. Cost: low-mid.

### Direction C — The First Echo (the swarm's sketch of you)
A dark humanoid silhouette wielding player-shaped moves: a dash (Charger logic), a sword arc, a Push-like shove. Phase 2 runs the same loop faster and adds vent punctuation. Fiction: the swarm learns by copying, and its first crude sketch of Tycho himself proctors the first exam.
- The doppelgänger is a legitimate medieval trope, so it's *technically* deniable, and it's the strongest foreshadowing of the three. Cost: low (a fixed kit that resembles the player's — no input recording).
- **Risks:** "a copy of ME on floor 1" pushes the gradient's loudest idea to its quietest floor — if any playtester says "it's studying me" on floor 1, the deniability rule is broken. This concept is better spent deeper (a floor-4 examiner, where the filed world already whispers) — parked as a candidate there.

**Recommendation: A**, with B's hazard-integration already folded in (the phase-2 vents ARE the Loose Stone's best idea). It protects the deniability rule where it's most fragile, gives the first boss a classic monster-den silhouette (the player's mental model of "boss" needs no help), spends the least budget, and leaves C's doppelgänger for a floor that can afford its loudness.

## 4. Direction-independent pieces (buildable after the pick, one chunk)

- **A real `boss_core.gd` + `enemy_boss.gd`:** pure phase machine (HP thresholds → phase index, loop position, reconfiguration timing — unit-testable) driving a scene that composes the existing telegraph/FX vocabulary. Replaces the stats-pumped dummy. All numbers `# FEEL:` exports (human dials — new values, no existing ones touched).
- **Arena:** the existing boss room + the floor's prop dressing at the edges; direction A adds a nest/bones prop note for the human's prop pass. Vent-plate positions for phase 2 = data on the floor's boss entry, not code.
- **Boss identity as data:** `data/bosses/<id>.json` (name for the boss bar, floor, phase thresholds, loop definitions referencing telegraph kinds + numbers) — same content-is-data rule as everything else; the schema lands with the build chunk in `architecture-schemas.md`.
- Unchanged: bounty, heal valve, echo pick, music, `boss_killed` cascade.

## 5. Open questions (settle at direction pick or first playtest)

- Escorts in phase 2: none, or one Skirmisher pair once at 25%? (Lean: none — boss #1 teaches the duel; escorts are a later-boss escalation.)
- Boss name shown on the bar (placeholder register: "The Den-Warden"): human names it with the dialogue pass.
- Does the reconfiguration beat want its own SFX/music sting, or is the boss track enough for v1?
- Phase thresholds 50% (single transition) vs 60/30 (two) for boss #1 — lean single; save density for later floors.
