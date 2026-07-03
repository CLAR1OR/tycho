# Act I — Story-Beat Skeleton

> The ordered spine from "Tycho finds the artefact" to "the emperor gets a face," what gates each beat, the four character arcs, and the dialogue-selection rules. This doc doubles as the **dialogue system spec** — the condition vocabulary at the bottom is what the engine must implement. Drafted 2026-06-12. Beats are skeleton-level: scene intent + gate, not scripts. Scripts get authored per-beat later (human voice, agent drafts, human curation).
>
> **Implementation status (2026-07-03):** the selection system below is BUILT — full condition vocabulary + priority/once/cooldown/force-play rules in pure `src/dialogue/dialogue_core.gd` (tested), playback in `dialogue_panel.gd`, NPC talk spots + 1-forced-per-visit in `town.gd`, content as `data/dialogue/*.json`. First authored snippets: A4, B1, B5 (force-play cutscene), C3, one Herzog contextual, one Wren bark — agent drafts, awaiting human curation. Deferred: banner icons, painterly stills, `talked_to` location conditions.

**Decisions baked in (from 2026-06-12 scope answers):** mixed gating (milestones + tech + run-counters); the mysterious woman arrives **mid-act** — the early game stays purely local; full arcs for **Linnea, Tilly, Mara, Old Thomas**; Wren + Herzog are flavor tracks.

---

## The spine (~22 scenes — Phase E added 2026-07-03)

Phases overlap in play — gates, not a strict sequence. `[cutscene]` = painterly stills + narration.

### Phase A — The artefact (first session)
| # | Beat | Gate |
| --- | --- | --- |
| A1 | **The cave.** Tycho falls, finds the egg, etchings flow in, the portal rises. [cutscene] | new game |
| A2 | **First run (tutorial).** Sword + dash only. Tuned so most players die on floor 1–2. | after A1 |
| A3 | **First death → the town learns.** Wake at home; Linnea has *seen* the etchings glow while he was "gone." First shards handed over. Establishes: death is survivable, Linnea analyzes, the town is home base. | first death |
| A4 | **Herzog hears about it.** Mayor's flat pragmatism: "Can you fetch things from in there? Then fetch useful ones." Frames runs as *for the town*. | run count ≥ 2 |

### Phase B — Systems come online (the unlock cascade)
| # | Beat | Gate |
| --- | --- | --- |
| B1 | **Mara and the ore.** First Resonance Ore → forge scene → **weapons system unlocks**. | first Resonance Ore in inventory |
| B2 | **Thomas and the meditation.** Tycho mentions the etchings itch; Thomas teaches stillness → **etchings/abilities screen unlocks**. | first Resonance Dust + visited Thomas once |
| B3 | **Linnea cracks the shards.** "There's *knowledge* in them — structured, deliberate." → **tech tree unlocks**. [cutscene] | 3rd boss kill (any floors, cumulative) |
| B4 | **Herzog opens the ledger.** Gold threshold → **town building unlocks**. | gold ≥ first building cost |
| B5 | **The first stone wall.** Masonry researched → palisade comes down, wall goes up. Herzog: "Huh. It holds." (per the masonry node) | tech `med-masonry-arch` |

### Phase C — Momentum (the town transforms)
| # | Beat | Gate |
| --- | --- | --- |
| C1 | **First full clear.** Final boss falls; the **codex artifact** is revealed in the chamber — first shard slots in, the assembly begins. [cutscene] | first full clear |
| C2 | **The question nobody asks.** Linnea, quietly: shards teach *real things that check out* — who writes knowledge into stone, and why is it *true*? First rational-fiction itch at the artefact's nature. | C1 + next town visit |
| C3 | **Tilly's reports begin.** Refugees on the roads. Burned villages, far west. Armies that "weren't men." Background rumble, escalating snippet series. | C1 + run count ≥ 12 |
| C4 | **The first dream.** Mid-act arrival, per decision: a woman at a desk by candlelight, etchings like his, working at something urgent. She *notices him noticing her*. Cuts off. [cutscene] | codex shards ≥ 2 |
| C5 | **Dreams escalate with the artifact.** Each new shard = stronger dream-link: glimpses of her captivity, her *deliberateness* — she is not flailing, she is executing a plan. (Snippet series, 1 per shard.) | each codex shard after C4 |
| C6 | **The age turns.** Printing Press or Telescope researched → Renaissance begins visually; town skin advances. Linnea's Study → toward University. [cutscene] | first Renaissance tech |

### Phase D — The climax (the emperor gets a face)
| # | Beat | Gate |
| --- | --- | --- |
| D1 | **Tilly connects the dots.** The "not-men" armies match Tycho's dungeon creatures. Someone out there *summons*. Tilly briefs Herzog; the town starts taking the west seriously. | C3 done + Gunpowder research **started** |
| D2 | **Gunpowder.** Researched → cannon on the new wall. The town can now imagine *war*. | tech `ren-gunpowder` |
| D3 | **The emissary.** A rider under a black-and-gold banner. Ultimatum: submit to **the Emperor** — first time the name is said aloud. Herzog refuses, flatly. Stakes go local → world. [cutscene] | D1 + D2 |
| D4 | **The dream-glimpse.** That night: the woman, clearer than ever — and behind her, *his* banner. The emperor's power has a source, and it is *her*. She mouths something. Cut to black. [cutscene] | D3 **+ C4** |
| D5 | **Cliffhanger close.** Tilly promoted to organize defense; Linnea looks west; "armies, not just a sword." **End of v1.** | D4 |

> **Gate fix (2026-07-03):** D4 now also requires `flag(c4)`. Without it, D4 was reachable via D3 → D1 → C3 → C1 with only **one** full clear, while C4 (the *first* dream) needs `codex_shards >= 2` — so a steady researcher could hit "the woman, clearer than ever" having never dreamt of her at all, and the reveal of her as the emperor's source would land with zero setup. The dream escalation (C4 → C5 → D4) must be unskippable.

### Phase E — after the climax (the v1 endgame state — added 2026-07-03)

The cliffhanger is the *finish line*, not a wall: the player can keep running, researching, and completing the codex. Phase E makes that post-climax state **designed** instead of a dangle — the game must never feel like it silently ran out.

| # | Beat | Gate |
| --- | --- | --- |
| E1 | **A town that drills.** Force-plays once on the next town return after D5: the town has *changed posture* — Tilly runs guard drills by the wall, Herzog requisitions, the cannon is manned. Sets `act1_complete` (save meta → "Act I complete" badge on the slot screen). Ends on the standing invitation: the portal still glows; the shards still teach; the west will take time to arrive. | D5 + next town visit |
| E2 | **The artifact waits.** The final shard slots in — the artifact assembles fully, turns once, hums… and *stops*. It is complete, and it is **waiting**. Linnea: "It's finished. And it's — listening? For what?" Thomas (if seen after): "A finished question is still a question." Explicit, honest, in-fiction "not yet" — solving it is Act II+'s door (per IC-6: v1's payoff is the grown mystery). Written **order-safe**: no emperor references unless `d5` is set (it can fire pre-climax for a completionist rusher). [cutscene] | codex shards = max (all slots filled) |
| E3 | *(a state, not a scene)* **One more run.** What remains playable and *acknowledged*: difficulty tiers (the space reconfigures — strata lore already covers this), unfinished tech nodes, arc beats not yet fired, and a small **post-climax bark set (~10)** so the town talks about drills/watch-rotas/the west instead of being frozen pre-war. | after E1 |

**Order note:** E2 is gated only on shard count, so E1/E2 can occur in either order — both scripts must stand alone (E2 references no war unless flagged; E1 references no artifact state).

---

## Character arcs (~7 beats each, interleaved by gates)

Arc beats use the same gate vocabulary; they fire between spine beats by priority (see selection rules).

**Linnea — the method.** Awe at the shards → builds a *method* (recording, prediction, error) → frustration when shards outpace her → her own discovery, not shard-fed (the telescope, her hands shaking) → quiet dread of C2's question → climax: "whoever sends this knowledge — the emperor got *power* from his. Why did we get *school*?" (seeds the artefact-intent mystery). Also carries: auto-solve hints, tech-unlock reactions (her contextual snippets are the largest single pool).

**Tilly — competence.** Eager, overconfident → embarrassing failure on patrol → learns from Tycho that patterns beat bravado (dungeon talk as tactics class — the cognitive pulse, in-fiction) → drills the guard → her reports are taken seriously (D1 is *her* spine beat) → promoted at D5. Ends as the strategy layer's human hook.

**Mara — the maker.** Ore curiosity → first resonance weapon sings and she can't explain why → craftsman's crisis ("my father knew iron; what do *I* know?") → she starts *testing*, Linnea-style, forge as lab → mastery: daggers/bow as her own designs, not her father's → pride beat at the cannon (D2): "we made the wall's teeth."

**Old Thomas — the question.** Philosophy exchanges that quietly aim at the reveal: on whether a thing's *purpose* lives in it or in its maker → on miracles (a miracle is a message — what is the messenger?) → on Tycho's deaths ("you return. Either heaven is leaky, or something *keeps* you — and keeping is a choice someone made") → on the woman (love and duty across distance) → final: "whatever holds you, holds *her*. Things made by the same hand are kin." Foreshadows nanobots/aliens without ever saying it. His unchanged hut: never explained in v1, one Wren bark allowed to *notice* it.

**Flavor tracks (no arc payoff in v1):** **Wren** — escalating ahead-of-his-time takes (wonder, monomyth, the hut, "maps of stories"); strictly diegetic per the locked decision. **Herzog** — dry civic reactions per building/age milestone; his D3 refusal is his peak moment, written in the spine.

---

## Dialogue selection system (the spec)

Hades-style high volume. Every snippet/scene is data with:

```
id, speakers[], source (spine | arc | contextual | bark),
conditions[]        — ALL must hold (see vocabulary)
priority            — spine > arc > contextual > bark; ties broken by author-set weight
once                — default true for spine/arc/contextual; barks repeatable
cooldown_runs       — min runs between repeats (barks) / between two scenes of the same arc (default 1 — never two arc beats of the same character back-to-back)
```

**On each town visit:** build the eligible set per character → each character offers their single highest-priority eligible item → spine/cutscene beats can force-play (banner icon over the speaker, Hades-style). One forced scene max per visit; the rest waits — never dump three story scenes after one run.

**Condition vocabulary (what the engine must support):**
- flags: `flag(<beat-id>)` set on scene completion — gates chains (D4 needs D3)
- counters: `runs >= N`, `deaths >= N`, `boss_kills >= N` (cumulative), `full_clears >= N`, `codex_shards >= N`
- tech: `tech(<node-id>)` researched; `tech_started(<node-id>)`; `age >= N`
- economy: `resource(<id>) >= N`, `building(<id>) >= level`
- inventory events: `has(<resource-id>)` first-time pickup triggers
- visit/locale: `talked_to(<char>) >= N`, current location
- composite: AND of the above (no OR needed in v1 — write two snippets instead)

This vocabulary is the contract for `architecture-schemas.md` (dialogue schema + the event bus that updates counters/flags).

## Open questions (resolve in playtest, not now)
- Does B3's "3rd boss kill" gate the tree too late if a player rushes floor depth? Fallback gate: `OR runs >= 6` — exception to the no-OR rule, or just a second copy of the beat with the alternate gate.
- C4's `codex_shards >= 2` means two full clears before the woman appears — confirm that lands mid-act at real play pace (~run 15–20).
- Whether D5 plays as one scene or a short playable epilogue walk through the changed town (cost: one scripted sequence — decide after the climax is drafted).
