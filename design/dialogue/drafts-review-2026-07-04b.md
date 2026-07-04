# Dialogue draft batch (cascade beats) — human review

Drafted 2026-07-04 against `design/voice-guides.md`, `design/act1-story-beats.md` (Phase B), and the shipped `data/dialogue/` schema, as part of the **unlock-cascade pass** (PRD §7.1). **These two spine beats + one contextual retouch ARE integrated** (the cascade needs them to fire) — unlike batch 1's draft-first flow, these landed in `data/dialogue/` in the same change, because they're load-bearing for the town-gating. **They are still drafts for voice — the human owns curation; edits become new calibration anchors.**

**Batch:** 1 new spine cutscene (+ its fallback twin, a copy) + 1 new spine talk + 1 retouch of a shipped contextual.

---

## Read this first — decisions and flags

### The B3 fallback twin (the design call the pass had to make)
`act1-story-beats.md` open question #1: *"Does B3's 3rd-boss-kill gate the tree too late? Fallback: OR runs >= 6 — exception to the no-OR rule, or just a second copy of the beat."* The pass chose the **second copy**:
- **`b3-sophia-shards`** — gate `boss_kills >= 3`.
- **`b3-sophia-shards-alt`** — **byte-identical scene**, gate `runs >= 6`.
- Both `sets_flag: "b3"`, both `force_play`, both `source: spine`.

**The twin-suppression problem and its fix.** Two force-play beats both eligible would BOTH play on successive town visits (different ids, both `once` but neither seen until played). The condition vocabulary is **AND-only with no negation**, so you can't write `{flag: b3}`-absent in data. Rather than add negation, the pass added a **tiny general rule to `DialogueCore.eligible`: a snippet whose `sets_flag` flag is already set is inert.** Once either twin plays and sets `b3`, the other is suppressed. This is not b3-specific — it protects any future beat that shares a `sets_flag` with a twin. Unit-tested (`dialogue_core_test.gd` → `test_sets_flag_suppression`, `test_twin_forced_plays_exactly_once`).

If the human prefers ONE beat with a single gate (drop the fallback), delete `b3-sophia-shards-alt.json` — nothing else changes; the suppression rule stays harmless.

### The B4 gate number
`b4-herzog-ledger` gates on `gold >= 40` = **the cheapest L1 building cost** (Sophia's Study, `data/buildings/sophias-study.json`; Quarry is 50, Town Walls 60). If building costs are re-tuned, revisit this number so B4 can't gate a facility the player can't yet afford anyway.

### The `herzog-ledger-open` retouch
That shipped contextual (gold ≥ 50) narrated Herzog *opening* the ledger — which, post-cascade, B4 already did. Two minimal edits:
1. **Re-gated** `+ {flag: b4}` so it can only fire AFTER the spine beat (spine outranks contextual anyway, but the flag makes ordering explicit and stops it standing in for B4 on an old save).
2. **First line retouched:** "I've opened the ledger" → "The ledger's open and the prices are set" (it's no longer the moment of opening; it's Herzog remarking on the coin). No other line changed.

### Voice / house-style checks (all pass by inspection)
- **Zero em dashes in any spoken line** across all three files (the b3 twins' narration lines `who: ""` also carry none).
- **Sophia (b3):** precision, excitement-as-appetite not volume, no ornament. "deliberate, it's ordered, and it's teaching" carries the beats-doc INTENT ("structured, deliberate") without quoting it. Vocabulary is **pre-Arithmetic-safe** (b3 can fire before the Arithmetic node): "three nights" is a small tally, no "zero"/exact figures; deniability words avoided (no *data/information/system/signal*). "appetite" is the one flavor reach — flag if it reads too writerly.
- **Herzog (b4):** short declaratives, **zero rhetorical questions**, ledger register ("The ledger doesn't argue terms. It only adds."), one flat close ("Go pick a plot."). Tycho gets the only question.

### Not verified (needs the human)
- **Voice.** Every line is a draft; the human owns the final read. Prime curation candidates: Sophia's "appetite" beat (b3, does the last narration line over-reach?) and whether the two B3 twins should stay identical or diverge slightly in flavor (they needn't be byte-identical — only the flag + force_play must match for the suppression to hold).

---

## Snippet table

Owner = `speakers[0]`. Gate = all conditions (AND).

| id | owner | source | kind | gate | sets | lines (verbatim, spoken only) | judgment calls |
|---|---|---|---|---|---|---|---|
| b3-sophia-shards | sophia | spine | cutscene (force_play) | boss_kills ≥ 3 | b3 | S: "They aren't stones with scratches on them. They're written. Every one says something, and the somethings fit. Start one and the next one carries it further." / T: "Written by who?" / S: "I don't know yet. But nobody cuts this into rock by accident. It's deliberate, it's ordered, and it's teaching. Keep bringing them up and I can start to read it properly. All of it." | Two narration captions frame it (`who: ""`). Beats-doc intent ("structured, deliberate") carried, not quoted. Pre-Arithmetic vocab. |
| b3-sophia-shards-alt | sophia | spine | cutscene (force_play) | runs ≥ 6 | b3 | *(identical scene to `b3-sophia-shards`)* | The fallback copy (open-question #1). Suppression rule keeps only one from playing. Delete this file to drop the fallback. |
| b4-herzog-ledger | herzog | spine | talk | gold ≥ 40 (cheapest L1 building) | b4 | H: "You've hauled up enough coin that I can't call it luck anymore. So I've opened the ledger. Proper books." / H: "Bring gold and stone and tell me what you want raised. The town raises it. A study, a quarry, a wall. Whatever the coin covers." / T: "That's it? No terms?" / H: "The ledger doesn't argue terms. It only adds. Go pick a plot." | Priority 88 < A4's 100, so once A4 is eligible (runs≥2) it still fires first; here A4 is usually ineligible when B4's gold gate is first met. No rhetorical questions (Herzog's ban). |
| herzog-ledger-open | herzog | contextual | talk | gold ≥ 50 **+ flag(b4)** | — | *(retouched)* H line 1: "You're carrying more coin than the town saw all last winter. The ledger's open and the prices are set. If you want walls, wells, or workshops, the town will build what you can pay for." / *(line 2 unchanged)* | Was `gold ≥ 50` only, narrated opening the ledger. Now post-B4 flavor. Only line 1 changed. |

---

## Verification done
- All new/edited files parse as valid JSON and validate against the loader `dialogue` spec.
- Zero em dashes in any spoken line.
- Gate conditions use only the shipped vocabulary (`counter`+`gte`, `resource`+`gte`, `flag`). No OR (the fallback is a second copy, per the resolved open question).
- gdUnit core suite (88 cases) + the end-to-end smoke (88 ok-checks, now driving the full cascade) green. Editor pass clean.
