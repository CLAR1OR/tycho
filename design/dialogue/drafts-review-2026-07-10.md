# Dialogue draft batch — human review (2026-07-10, the dialogue-volume chunk)

**ALL 60 pieces below are AGENT DRAFTS awaiting human curation.** The human's voice is canonical; edit freely — per the voice-guide workflow, your edits become the new calibration anchors. Everything was drafted against `voice-guides.md` (scientific-observing/no-BS register, banned constructions, tech-unlocked vocabulary, deniability list) and integrated into `data/dialogue/` in the same change. **No existing file was touched** (the E2 placeholder stays byte-identical).

**The floor-1 boss's name "The Den-Warden" is a PLACEHOLDER and appears in NO line** — every reference is descriptive ("the thing at the bottom of the first floor", "the burrower"), so the human rename orphans nothing. A unit lint now enforces this pool-wide (plus: no em dashes in spoken lines, no "Linnea" anywhere, conditions only from the engine vocabulary — `dialogue_core_test.gd::test_dialogue_data_sweep`).

**Batch totals: 60 files** — spine 14, arc 6, contextual 24, bark 16. Pool now 112 files (110 pieces; the a3/b3 twins are copies).

**New counter this chunk:** `max_floor >= N` (deepest floor EVER reached, max()'d at run end) — first consumers: `arc-tilly-depth`, the 5 Sophia stratum reports, `tilly-burrower-death`, `wren-bark-deep-stride`.

---

## Read this first — judgment calls + flags for the human

1. **E1 sets ONE flag (`e1`), not two.** The brief said E1 "sets `act1_complete` AND `e1`", but the shipped schema's `sets_flag` is a single string and the chunk's hard constraint forbade reshaping it. Everything in-game gates on `flag(e1)` (E3 barks, `arc-tilly-command`), exactly as specified. `act1_complete` is really a **save-meta** concern (the slot-screen badge reads meta without loading the slot, like `meta.runs`) — deferred WITH the badge, noted in `act1-story-beats.md`. When the badge lands, mirror e1 into meta the way meta.runs mirrors.
2. **The second bearer's UI label is now enforced in code.** `DialoguePanel` rendered speaker names as `who.capitalize()`, which would have printed "Linnea" — a hard Act-I violation. Added a pure `DialogueCore.display_name()` map: `linnea` → **"The Woman"** (unit-tested). If you prefer "the woman" lowercase or an empty label, it's one string in `dialogue_core.gd::DISPLAY_NAMES`. The emissary renders as "Emissary" (no map needed).
3. **`mara-blade-refined` gate is a PROXY.** "First weapon fully refined" is not expressible in the condition vocabulary (no weapon-level condition exists). Gated `flag(b1) + runs >= 12` and the line written so it reads as *refinement progress*, not a completed track. Options: accept the proxy, or add a `weapon(<id>) >= level` condition (mirrors `building()`) in a future chunk and re-gate.
4. **`tilly-burrower-death` can't detect the killer.** "Died TO the floor-1 boss" isn't expressible either; gated `deaths >= 2 + max_floor >= 1` and written so it works for any floor-1 death streak.
5. **C1 plays in town, not in the chamber.** The dissolve mechanic already delivers the pedestal in-run; the C1 cutscene is the scripted *retelling* (narration recaps the chamber, then Tycho debriefs Sophia). If you'd rather have the cutscene fire inside the final chamber, that's a scene-flow change, not a dialogue change.
6. **C2 gained a `flag(b3)` condition** beyond the skeleton's "C1 + next town visit": a rusher could otherwise hear Sophia muse about who writes the shards before B3 establishes there's knowledge in them at all. Same order-safety class as the D4 fix. Noted in the beats doc.
7. **C5 dreams are flag-chained** (`c4 → c5-3 → c5-4 → c5-5 → c5-6`, each also gated on its shard count) so the escalation can never skip or reorder even when shards outrun town visits. E2 (98) outranks dream 6 (65) on the max-shards visit — the artifact scene first, the last dream next visit. Intended.
8. **D2 vs `arc-mara-cannon` overlap.** D2 uses the human-approved anchor verbatim ("Dad made horseshoes his whole life. I made a cannon. Don't tell him."); the 07-04 arc beat `arc-mara-cannon` (same gate, `tech ren-gunpowder`) carries a paraphrase of the same pride ("I made a thing that talks back to armies. Don't you dare tell him."). Spine outranks arc, so D2 plays first and the arc beat follows on a later visit — it reads as her still glowing, but curate one if the echo bothers you.
9. **The emissary speech is deliberately rhetorical** ("The Emperor keeps what kneels."). The aphorism ban protects *our* characters from sounding like posters; an imperial herald delivering an ultimatum is allowed a slogan — it's characterization. Flagged in case you want him flatter. A minimal voice entry for him was added to `voice-guides.md` (additive).
10. **`tycho-bark-portal` has no surface.** Tycho is the player — there's no NPC talk spot or portal-step dialogue hook, so the bark loads and validates but can never play (same class as the pre-spot Thomas beats of 07-04). Wire a portal-step hook or cut it.
11. **Wren's hut notice NOT duplicated:** the beats doc allows exactly one Wren bark noticing Thomas's unchanging hut, and `wren-bark-hut` (2026-07-04) already is it. The new general Wren bark (`wren-bark-doors`) picks a different pattern and avoids the hut entirely (checked).
12. **Borderline-register lines kept, flag if too much:** Herzog's "War arrives first as paperwork." and "Winter is not impressed." (deadpan-declarative, matches his kept 07-04 register), Sophia's "Wartime turns out to be arithmetic with consequences.", Wren's "Roads always know." (his licensed hanging-conclusion tell), `mara-dust-sorting` (the dust visibly self-sorting is the loudest nanobot whisper in the pool — deniable as enchantment, but check it against the floor-3 "too loud" bar).
13. **Arc ordering follows the 07-04 convention** (priority + `once` + the 1-run arc cooldown, no arc-flag namespace): `arc-sophia-awe` (58) fires before `method` (55); `arc-tilly-depth`/`arc-mara-designs` (42) sit below their predecessors. The brief's "prior arc flag" gates for Tilly/Mara aren't expressible (their earlier arc beats set no flags — 07-04 decision); used the run-count/priority pattern those arcs already use.
14. **Smoke choreography updated** (the new spine changes which beat claims each town visit's one force-play slot): sim-2's return now plays C1 (was silent), Sophia's death-return talk queue is C2 → arc-sophia-awe (was arc-sophia-method), the market-sim return plays C4, the forfeit return c5-dream-3, the reload entry c5-dream-4. All asserted; 342 ok-checks green.

---

## Part 3 — spine scenes (14; all `[cutscene]` beats are force_play)

Priorities: below every already-shipped opener (a3 105/104, a4 100, E2 98, greeting 96, B5 95, B2 94, B3 92) so the authored order of play is: openers → C1 (91) → C4 (86) → C6 (82) → D1 (79) → D2 (78) → D3 (77) → D4 (76) → D5 (75) → C5 dreams (68–65) → E1 (99, gated on d5 so it always tops its visit). Chain flags enforce every hard ordering; priority only breaks same-visit ties.

| id | speakers | gate | sets | notes |
|---|---|---|---|---|
| `c1-first-clear` | tycho, sophia | `full_clears>=1` | `c1` | force. The artifact reveal retold in town (see flag #5). "They were dealt", the assembly begins. |
| `c2-sophia-question` | sophia, tycho | `flag(c1)` + `flag(b3)` | `c2` | talk. The question nobody asks; ends "Someone is checking our work." (flag #6 on the b3 gate). |
| `c4-first-dream` | tycho, linnea | `codex_shards>=2` | `c4` | force. Uses her approved anchor verbatim ("You can see me. Good. Don't talk. Look."). Hinges-outside captivity detail. She renders as "The Woman". |
| `c5-dream-3` | tycho, linnea | `codex_shards>=3` + `flag(c4)` | `c5-3` | force. She measures her cell. "Clearer this time. Whatever you did, do it again." |
| `c5-dream-4` | tycho, linnea | `codex_shards>=4` + `flag(c5-3)` | `c5-4` | force. "They count my candles. Not yours. I can work while you sleep." |
| `c5-dream-5` | tycho, linnea | `codex_shards>=5` + `flag(c5-4)` | `c5-5` | force. Approved anchor verbatim: "West gate. Weak hinge. Not yet. Wait for me." |
| `c5-dream-6` | tycho, linnea | `codex_shards>=6` + `flag(c5-5)` | `c5-6` | force. "Done waiting soon. You'll know the night." Gate value coupled to `CODEX_SHARDS_MAX` like E2. |
| `c6-age-turns` | sophia, herzog, tycho | `age>=2` | `c6` | force. The Library becomes the University on screen; Herzog: "The ledger hurt for it. It holds classes now. Good trade." |
| `d1-tilly-briefs` | tilly, herzog, tycho | `flag(c3)` + `tech_started(ren-gunpowder)` | `d1` | talk (her spine beat). The not-men armies match the dungeon creatures, point for point. |
| `d2-first-cannon` | mara, herzog | `tech(ren-gunpowder)` | `d2` | force. Mara's approved pride anchor VERBATIM (flag #8). Herzog: "Loud. Ugly. Ours. Build another." |
| `d3-the-emissary` | emissary, herzog | `flag(d1)` + `flag(d2)` | `d3` | force. First "Emperor" said aloud; the speech (flag #9); Herzog's canonical answer: "No." |
| `d4-dream-banner` | tycho | `flag(d3)` + `flag(c4)` | `d4` | force. The doc's gate fix honored. She mouths something; no Linnea line spoken (bandwidth fiction). |
| `d5-cliffhanger` | herzog, tilly, sophia, tycho | `flag(d4)` | `d5` | force. Tilly promoted ("Build me soldiers."), Sophia looks west ("armies, not just a sword" intent), end of v1. |
| `e1-town-drills` | tilly, herzog, tycho | `flag(d5)` | `e1` | force, priority 99. Changed posture + the standing invitation. Herzog: "Everything changed. Your errands became supply lines." `act1_complete`: see flag #1. |

Full text lives in the data files — every line was drafted fresh this pass; nothing existing was reused except the two approved Linnea anchors and Mara's approved D2 line (verbatim by design).

## Part 2 — arc beats (6; definitions now tabled in `act1-story-beats.md`)

| id | owner | gate | prio | intent + calls |
|---|---|---|---|---|
| `arc-sophia-awe` | sophia | `flag(b3)` + `runs>=4` | 58 | First sit-down with a pile of shards. "They don't repeat." / "It's enormous. Ask me again when I've slept." Fires before `method` (55). |
| `arc-sophia-telescope` | sophia | `tech(ren-telescope)` | 52 | Her OWN discovery, hands shaking (moon mountains — Galileo, and the sister of Tycho Brahe earns her astronomy beat). Dormant until the node is authored; closes the 07-04 stub (flag #1 there). |
| `arc-tilly-depth` | tilly | `max_floor>=3` + `runs>=6` | 42 | The tactics-class/cognitive-pulse beat; **the new counter's first consumer.** "Your monsters are teaching my recruits." |
| `arc-tilly-command` | tilly | `flag(e1)` | 60 | One clean order, no self-correction; Tycho names the growth, she shrugs it off. |
| `arc-mara-designs` | mara | `flag(b1)` + `runs>=14` | 42 | Mastery: her own three-draft design, not her father's work done over. |
| `arc-thomas-ages` | thomas | `age>=2` | 52 | "Who chose us? And what do they mean to make of the class?" His contemplative license, question payload. |

## Part 4 — contextual pool (24)

| id | owner | gate | notes |
|---|---|---|---|
| `sophia-burrower-kill` | sophia | `boss_kills>=1` | First-kill, turn-in flavored; "Beasts don't keep patterns that clean" (deniable hindsight tell). |
| `tilly-burrower-death` | tilly | `deaths>=2` + `max_floor>=1` | Tactics-eager debrief (flag #4 on the gate). |
| `sophia-first-floor-shard` | sophia | `boss_kills>=1` + `has(knowledge-shards)` | The floor-1 shard as "the first page of a primer" — seeds the curriculum idea. |
| `sophia-stratum-1..5` | sophia | `max_floor>=1..5` | Once each. Floor 3 opens on the strata doc's sample line VERBATIM ("Rock doesn't hum, Tycho. Instruments hum."). Floors 1–4 stay deniable (she reasons, never concludes); floor 5 is unsettled but concludes nothing ("I've stopped trying to fit it to anything I know"). |
| `herzog-arithmetic-ledger` | herzog | `tech(med-arithmetic-zero)` | "Zero"/exact figures licensed by the gate; "Nobody is punished. Everybody knows I know." |
| `herzog-masonry-masons` | herzog | `tech(med-masonry-arch)` | Does NOT reuse "Huh. It holds." — visiting masons ask to stay. |
| `thomas-printing-press` | thomas | `tech(ren-printing-press)` | Dormant forward ref (intentional). "Who decides which book it is?" |
| `herzog-market-open` | herzog | `building(market)>=1` | Posts IC-14 diegetically: "no trade in the humming stone, at any price." |
| `herzog-cathedral-founded` | herzog | `building(cathedral)>=1` | Flat civic read of a great work: "Good message. Cheap at the price. The price was not cheap." |
| `thomas-cathedral-vault` | thomas | `building(cathedral)>=3` | Purpose-lives-where question over the closed vault (deliberate rhyme with `arc-thomas-purpose`). |
| `sophia-library-open` | sophia | `building(library)>=1` | Backup copies "so the work doesn't die in my desk drawer" — care through method. |
| `sophia-observatory-open` | sophia | `building(observatory)>=1` | "The sky runs exact... That's my winter spoken for." |
| `mara-mill-gears` | mara | `building(mill)>=1` | Chose Mara over Herzog: gears as "one big machine wearing a stone coat" is her delight; "machine" is era-fine and not on the deniability list. |
| `tilly-walls-third` | tilly | `building(town-walls)>=3` | "That's the job now, trying to rob us and failing." |
| `herzog-gold-strongroom` | herzog | `resource(gold)>=1000` | Past-life fragment ("pay chests for kings"); avoids exact figures (gate ≠ arithmetic). |
| `mara-blade-refined` | mara | `flag(b1)` + `runs>=12` | PROXY GATE — flag #3. "It's been paying attention." |
| `herzog-three-clears` | herzog | `full_clears>=3` | Dry: the strait-swimmer who never shut up vs. Tycho who says nothing. |
| `thomas-gentle-way` | thomas | `dissolves>=5` | The dissolve as "seen off, like a guest" — door closing or hand on the shoulder? |
| `herzog-age-turned` | herzog | `age>=2` | "Ages change. Winter is not impressed." (flag #12). |
| `mara-dust-sorting` | mara | `has(resonance-dust)` | The dust sorts itself — loudest whisper in the pool, flag #12. |

## Part 4 — barks (16, all `once:false`)

**E3 post-climax set (gate `flag(e1)`, the town-at-drill texture):** `tilly-bark-drill-count` (cd2), `tilly-bark-shieldwall` (cd2 — "I mean it as a report. He's good."), `herzog-bark-requisition` (cd2), `herzog-bark-nightwatch` (cd2), `mara-bark-cannon-swab` (cd2 — talks to the cannon), `mara-bark-cannon-shot` (cd2 — "landing where Tilly points"), `wren-bark-west-birds` (cd3 — reading an army in the sky), `wren-bark-west-carts` (cd3 — "That's not trade, that's leaving."), `sophia-bark-wartime-method` (cd2), `sophia-bark-wartime-books` (cd2 — the two books that must not explain each other).

**General:** `wren-bark-doors` (cd3, none — a NEW pattern, hut deliberately avoided per flag #11), `wren-bark-deep-stride` (cd3, `max_floor>=4` — "Legs remember. They're honest that way."), `herzog-bark-mountain-pass` (cd2, none — past-life vein), `mara-bark-nails` (cd2, none), `sophia-bark-postdeath` (cd2, `deaths>=1` — "soup for accuracy", her approved post-death anchor's register), `tycho-bark-portal` (cd2, none — NO SURFACE YET, flag #10).

---

## Verification done (this pass)

- All 60 files load through the real `DataLoader` schema (loud validation), filenames == ids, gates AND-only from the implemented vocabulary.
- New pool-wide lint (unit): no em dashes in any spoken line, "Linnea" appears in no text, the placeholder boss name appears in no text, all condition keys/counters known. 270 unit cases green.
- Smoke green end-to-end with the new choreography (342 ok-checks): C1/C2/C4/C5-3/C5-4 exercised in order, awe-before-method arc order, max_floor recorded/persisted/round-tripped, twin suppression and E2 unaffected.
- Vocabulary table respected per gate (pre-Clock: bells/watches/sundown/"grey hour"; pre-Arithmetic: tallies only; "powder" only behind `ren-gunpowder`; Wren + Linnea exempt as licensed).

## Not verified (needs the human)

- **Voice.** Every line above is a draft. Curation priority: the D3 emissary speech (#9), the C5 Linnea transmissions (her voice is the newest and thinnest-calibrated), E1's Herzog close (#12 class), `mara-dust-sorting` loudness (#12), the D2/arc-mara-cannon echo (#8).
- The C5/D4 dream pacing at real shard pace (~1 per full clear) — plays fine in the smoke's compressed timeline; judge the drip in play.
