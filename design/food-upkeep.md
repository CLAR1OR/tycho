# Food & Upkeep — the Well-Fed mechanic

> Fixes the dead resource: Food's stated purpose ("soft cap on town size / morale") referenced a population system the lean upgrade-hub town doesn't have — so Food had no sink and no effect. **Drafted 2026-07-03.** The fix gives Food one legible job in v1 **and** establishes the *upkeep mechanism* the strategy layer will reuse for armies and cities (the actual prepare-for). Numbers are placeholders.

---

## The mechanic (v1 — deliberately one rule)

On each **day tick** (1 day = 1 run):

1. The town **consumes Food**: `upkeep = base + 1 per built building` (placeholder — scales gently with town size, no population micro).
2. If the stock covers upkeep → the town is **Well-Fed** for that tick: **+25%** (placeholder) to *all other* day-tick production — Timber, Stone, Gold, and **Knowledge**.
3. If the stock falls short → the town simply **isn't** Well-Fed. **No penalty, no spiral, no starvation state** — you lose the bonus, nothing more. (Mirrors the no-death-penalty philosophy: the economy deals in bonuses, not punishments.)
4. Surplus beyond upkeep just accumulates; the **Market** sells surplus for Gold (already designed).

UI: one small **Well-Fed indicator** on the day-tick summary / town HUD (a full or empty granary icon) — the whole mechanic must be readable at a glance.

## Why this is on-theme (the rational-fiction dividend)

Well-Fed boosting *Knowledge* teaches a true thing: **agricultural surplus is the precondition of scholarship** — calories fund specialists; the plow pays for the scribe. This is real economic history delivered as a game rule, and it retroactively gives the **Three-Field Rotation** tech node (Farm boost) a *felt* payoff: better rotation → reliable surplus → the town thinks faster. Dialogue hooks: Herzog on granaries ("An army marches on its stomach. So does a library."), Linnea on who fed the monks who copied the books.

## The Act II fold-forward (the real prepare-for)

The mechanism — a **consume-then-status** pass in the day tick — is exactly what the strategy layer needs, at bigger scale:

- **Armies:** human troops (Tilly's guard, garrisons) consume **provisions on the march** — historically *the* constraint of war. Summons stay artefact-powered (IC-14: the combat/artefact economy never touches the civilian one) — food logistics apply to *people*, which keeps human armies and summon armies strategically different (a real decision, not flavor).
- **Cities:** each liberated town runs the same upkeep rule with its own Farm; fed/unfed becomes the per-city morale lever.
- **Architecture:** one new town-tick effect kind, **`upkeep`** (consumes a resource, grants a status that other effects read) — extends `produce | knowledge | multiplier | capability` (schemas §6). v1 implements it once for one town; Act II instantiates it N times. No rewrite.

## Numbers (placeholders — tune with the economy)

| Knob | Placeholder |
| --- | --- |
| Farm output L1/2/3 | 3 / 5 / 8 Food per day |
| Upkeep | 2 base + 1 per built building |
| Well-Fed bonus | +25% to all other day-tick production |
| Market surplus sale | existing Market rules |

## Open questions (playtest)

- Is a binary Well-Fed/not too coarse, or exactly right for the lean model? (Tiers of fed-ness are the first thing NOT to add.)
- Should Well-Fed also touch anything in-run (e.g. start-of-run bonus)? Current answer: **no** — the civilian/combat separation (IC-14) stays clean.
- Does upkeep-per-building make late-town Farm upgrades feel mandatory? (If so, flatten the curve.)
- Granary as a later building (stores more / smooths bad ticks)? Post-v1 candidate, not budgeted.
