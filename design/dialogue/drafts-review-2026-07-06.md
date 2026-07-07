# Dialogue review — 2026-07-06 (human opening scripts + voice recalibration)

The human wrote the game's opening dialogues (first-death spine + first-meeting beats) and set the register: **"scientific observing, no-BS type of talking. no poetic / wise stuff. maybe thomas can get some, but that's about it."** This pass integrated those scripts verbatim, added the missing NPCs/UI, and ran a conformance pass over the existing batch against the sharpened register. **The human's scripts are now the top calibration anchors** in `voice-guides.md` and outrank all prior samples.

---

## 1. Human scripts integrated (CANONICAL — typo fixes only)

| id | source | speakers | gate | sets | notes |
|---|---|---|---|---|---|
| `a3-first-death` | spine, **force_play** cutscene | tycho, sophia | `deaths>=1` | `a3` | Scripts 1+2 as one cutscene. Stage directions became telegram narration lines (`who:""`): "He finds Sophia at her workbench…" / "They walk to the portal." / "Sophia steps toward the portal. It does not let her through." / "They walk back." Priority **105** (above B5's 95) so it takes the one force-play slot on the death-return visit. |
| `a-mara-meets` | spine | mara, tycho | `flag(a3)` | — | Script 3. Priority **96** (above `b1-mara-ore`'s 90) so the greeting precedes the ore beat when both are eligible. |
| `b2-thomas-meditation` | spine | thomas, tycho | `flag(a3)` | **`b2`** | Script 4. Sets `b2` → unlocks the etchings system (UnlocksCore `etchings<-b2`) and Thomas's meditation spot. Priority 94. |
| `b4-herzog-ledger` | spine | herzog, tycho | `resource(gold)>=40` | `b4` | **Reworked** to Script 5 (same id/gate/flag). Was 4 lines, now 3. |

### Typo fixes to the human scripts (only these; no phrasing changes)
The three normalizations the brief named were applied to the raw text; as delivered here the scripts read:
- **"chick in" → "check in"** (A3: "Let me check in with my sister…").
- **"ecounter" → "encounter"** (a-mara-meets: "I had an encounter with a magical artefact…").
- **"ressources" → "resources"** (b4: "Something that gives gold and resources…").
No other spelling changes. **Grammar/phrasing left verbatim** per instruction — e.g. "This goes against my every theory I had about how the world actually works", "as far as I remember", and the several lines the human left without a terminal period (A3 lines 5/8/16; a-mara-meets line 6) are preserved exactly. No em dashes added anywhere.

### Voice-guide tensions in the human text (human overrides — flagged, not changed)
- **A3 Tycho: "All other data points also point in the direction of this being reality."** — `data` is on the voice-guide's *deniability* banned-words list (pre-reveal, everyone but Wren/Linnea). The human's scientific-observing register uses it deliberately. Kept verbatim; `voice-guides.md` §deniability now records the exception (Tycho's dry-empirical register may reach for "data points").
- **A3 Sophia: "maybe it runs on divine energy after all? On magic?"** — `energy` (physics sense) is likewise on the deniability list; here it's the in-world *divine energy / magic* framing, not physics, so it stays deniable. Kept verbatim.

---

## 2. Conformance pass over the existing batch (register: scientific-observing, no poetic/wise)

The 2026-07-04 batch was already drafted against the banned-aphorism rule, so **most lines were already conformant.** Only the clearest poetic/inspirational-shaped lines were rewritten; Thomas keeps his limited contemplative license (untouched). Every change below is a **proposal for the human's curation** — revert freely.

### Rewritten (2 files, 3 lines)
| id | before → after |
|---|---|
| `wren-bark-roads` | "Same three hills, every time. **As if the roads are remembering something the hills already forgot.**" → "Same three hills, every time. **Nobody laid them out to. They just do.**" (drops the mystical personification; keeps Wren's hanging-observation tell) |
| `b5-the-first-wall` (narration) | "The wall goes up over a week **—** grey stone…" → "…over a week**,** grey stone…" (removes an em dash in a caption) |
| `b5-the-first-wall` (narration) | "…a stone ring where the wooden one stood. **It is a small wall. It is a beginning.**" → "…**It is a small wall, and it is the first the town has ever raised from stone.**" (drops the inspirational-post button; stays observational) |

### Reviewed and KEPT (borderline, flagged for the human)
- **`arc-sophia-method`** — "if I only read, I learn what the shard knows. If I guess first, I find out what I know… only the second one is mine." Mirrored shape, but it *is* the empirical method (predict → check error) stated concretely, which is exactly the target register. Kept; flag if the mirror reads too precious.
- **`arc-thomas-*`** — all kept (Thomas's contemplative license). Watch `arc-thomas-woman`'s "Love at that distance is a strange crop, boy" if you want him plainer.
- **`b3-sophia-shards` / `-alt`** narration — "There is something new in her face, and it isn't fear. It's appetite." Literary caption, kept (narration, not spoken).
- **`wren-bark-monomyth` / `-hut`** — Wren's licensed funny-strange takes; the monomyth "turning the pages" and the hut's "Not the hut. The forgetting." are his signature. Kept; de-poeticize if you want him drier.
- **`herzog-bark-wall`** — "I've stopped being surprised by what a wall does to a man." Slightly proverb-ish but matches his approved dry-general register. Kept.

Everything else in `data/dialogue/` was reviewed line-by-line and judged already conformant (Tilly earnest/report, Mara task-in-line banter, Herzog flat declaratives, Sophia precise, the a4/b1/c3/herzog-ledger spine).

---

## 3. New systems this pass added (context for curation)

- **Sophia is now a town NPC** (`NpcSophia`, near her desk; talkable from day 0, before the tech tree). Her arc beats (arc-sophia-*) previously had **no talk spot** — the desk opens the research panel, not dialogue — so they were unreachable. They fire now.
- **`!` / `!!` dialogue indicators** — a floating Label3D over any NPC with **new, unseen** content: `!!` for a spine (main-story) beat, `!` for arc/contextual. Barks and already-seen content never light it. Pure `DialogueCore.indicator_for`, rendered by `town.gd`, refreshed on entry and after each dialogue closes.
- **Meditation spot** — Thomas's favorite spot (Area3D + prop near Thomas), gated on the etchings system (B2). The etchings/attunement **menu is not built in v1** (document-don't-build); unlocked, it's a one-line diegetic beat ("Tycho listens to the resonance. Nothing answers yet.").

---

## 4. Open design edges (human decision — noted, NOT solved)

1. **Win-first-run edge.** `a3-first-death` gates on `deaths>=1`, and the Mara greeting (a3), Thomas/B2 (a3 → etchings), etc. chain off `a3`. **A player who never dies on their first run never trips the gate**, so the first-death cutscene and everything downstream (including the etchings unlock via B2) stall. A fallback gate (e.g. an OR on `runs>=N`, or firing A3 after A2 regardless) is a human call — same class as the B3 `boss_kills>=3 OR runs>=6` fallback. Recorded in `act1-story-beats.md` (A3 note).
2. **B2 gate divergence.** The skeleton's B2 gate was "first Resonance Dust + visited Thomas once". The human's script 4 gates on `flag(a3)` and Thomas simply offering it, so **B2 now depends on the first-death cutscene**, not on dust. Intended per the human's direction; noted in the beats doc.
3. **Greeting-after-ore edge.** If a player gets Resonance Ore and talks to Mara *before* ever dying, `b1-mara-ore` plays first and `a-mara-meets` (the introduction) plays later, slightly out of narrative order. Minor; priority can't fix it without a flag-chain. Left as-is.

---

## 5. Tech-node Sophia hints retouched (arch puzzle — 2026-07-06)

The masonry tech rewrite (encyclopedic explanation/aha; see `design/tech-nodes/medieval-masonry-the-arch.md` §4/§6) is body text, not dialogue. But the arch puzzle's Sophia HINTS and its intro line **are** dialogue (`data/tech/med-masonry-arch.json` → `puzzle.data`), and the originals carried **em dashes**, which the sharpened register bans. Retouched to Sophia's plain, precise register (she may still reason out loud and ask a guiding question; only the em dashes and the mild personification were the problem). Proposals for the human's curation — revert freely.

| line | before → after |
|---|---|
| intro | "…Herzog wants STONE. Raise a gateway that can carry the new wall. Try the obvious thing first **—** then load it and see." → "…Herzog wants stone. Raise a gateway that can carry the new wall. Try the obvious thing first**,** then load it and see." (em dash → comma; drops the shout-caps STONE) |
| hint 1 | "A flat stone over a gap snaps along its *underside* **—** that's where it's being pulled apart, and **stone hates being pulled**. Can you arrange the stones so they're only ever *pushed*?" → "A flat stone over a gap snaps along its underside**. That's** where it's being pulled apart, and **stone is weak when it's pulled**. **Try arranging** the stones so they're only ever pushed together." |
| hint 2 | "Wedges. If each stone is a wedge leaning on the next, the weight presses them together instead of bending any one of them. **But a ring isn't a ring until it's closed.**" → "**Use wedges.** If each stone is a wedge leaning on the next, the load presses them together instead of bending any one of them. **A ring isn't a ring until it's closed, though.**" |
| hint 3 | "Set the top wedge **—** the keystone **—** *last*; that locks it. Then mind the feet: a finished arch shoves outward. Plant something heavy on each side to take the shove." → "Set the top wedge, the keystone, last**. That** locks the ring. Then mind the feet**.** A finished arch shoves outward, so plant something heavy on each side to take the shove." |

The optional Wren "aha" tag in the .md (§6) was also de-em-dashed and pointed toward Wren's plainer register (it is not shipped in `data/`; authoring reference only).

---

## 6. A3 opening-scene twin — win-first-run fix (2026-07-07)

The human decided the opening scene must fire after the FIRST run regardless of death (resolves the "win-first-run edge" flagged in `act1-story-beats.md`). Built as a twin of `a3-first-death` using the same shared-flag suppression as the B3 pair. `a3-first-death` is UNCHANGED and canonical.

| id | source | speakers | gate | priority | sets | notes |
|---|---|---|---|---|---|---|
| `a3-first-return` (NEW) | spine, **force_play** cutscene | tycho, sophia | `runs>=1` | **104** | `a3` | The generic opener: Tycho steps back out of the portal (a win, no death) and takes Sophia to it. Death variant (`a3-first-death`, 105) wins the slot after a death; the generic fills the no-death case. Either sets `a3` → the other is inert forever. |

**Lines — HUMAN CURATION FLAGGED (overwrite the placeholders).** `a3-first-return` reuses the human's own `a3-first-death` lines wherever the scene is identical (finding Sophia, the walk to the portal, the portal refusing her, the closing). Those are **HUMAN-VERBATIM** — do not touch. The lines that had to differ (there was no death) are **ORCHESTRATOR PLACEHOLDER** and want the human's pen:

- **Placeholder (new for the no-death open):** line 1 narration ("Tycho steps out of the portal, back into the evening air."); line 2 Tycho ("Back out. Same field, same sky. The passage holds in both directions, then."); line 3 Tycho ("Let me check in with my sister…").
- **Placeholder (adapted from the human's `a3-first-death` line, death clause removed):** line 5 Tycho's "Sophia! Sorry to interrupt…" (drops "was slain by monsters, woke up here again"; ends on the etchings); line 12 Tycho's "Sure will do…" (drops the "artefact will resurrect me" clause — no death has happened yet).
- **Human-verbatim (copied byte-exact from `a3-first-death`):** the "He finds Sophia at her workbench…" narration; Sophia's "What are you talking about?…"; "They walk to the portal."; Tycho's "So here was the object…"; Sophia's "This goes against my every theory…"; "Sophia steps toward the portal. It does not let her through."; Sophia's "I cannot go through…"; "They walk back."; Sophia's "This is something huge…"; Tycho's "Did not have anything else in mind."
