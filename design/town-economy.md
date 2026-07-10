# Town Economy — buildings, age-banded levels, sinks

> **Designed 2026-07-10, converged in chat with the human.** Supersedes the bible's original 13-building / flat-3-level table (bible, PRD, content-budget, schemas synced in the same change). This doc owns the town-economy design: the building roster, the level model, the Market/Cathedral sinks, and the Act-II fold-forward. **All numbers are placeholders** — the human dials them like `# FEEL:` values.
>
> **Implementation status (BUILT 2026-07-10, same day as the design):** the v1 scope of this doc is in code and data. **Data:** all 5 new building files (`data/buildings/library|observatory|mill|market|cathedral.json` — Library carries the 4-level University opener), the Farm-L3/Quarry-L2 in-band gates, and the caravan table (`data/town/caravan-deals.json`, 5 deals, loaded via `DataLoader.load_caravan_deals()` — the same one-file exception as the SFX map). **Core:** `TownCore.is_level_unlocked` (shared gate helper; unauthored tech ids = dormant forward refs, unknown gate TYPES lock loudly), `display_name` (rename/band openers), the tick's `multiplier` fold (produce → multipliers → scale → upkeep/Well-Fed) + Market auto-sell (stable return keys `food_sold`/`gold_from_sale`; keep-buffer = `MARKET_KEEP_BUFFER_DAYS` 2 × nominal upkeep), `capability_value` (generic; the Cathedral's `shard_value_add` rides it via `TechCore.shard_turn_in_value(shards, bonus)` in `TechState.turn_in_shards`). **Scene:** `MarketPanel` (exchange + caravan, Slate; deal rotation pure in `MarketCore` — `deals[day mod n]`, L3 second slot hash-offset, one accept/day via `town.market_deal_done_day`, save-backed) opens from the Market BuildPanel's **Trade** button or `town.open_market_panel()` — a deliberate choice over a second town site (one plot = one press); 5 new build plots in `town.tscn`; build/survey panels show `Requires <tech>` for gated levels (`BuildPanelCore.action` kind `"locked"`), multiplier/market/great-work yield lines, and `TownCore.display_name` everywhere; `game.gd` realizes the auto-sell on the Ledger (reason `market-sale`); the overnight toast gained a placeholder "+N gold in trade" segment. All numbers/copy PLACEHOLDERS (see `feel-tuning.md` § Town economy).
>
> **Deferred:** the Observatory's `puzzle-hint` capability ships as data with NO consumer (hints currently cycle freely in the puzzle UI) and its next-tech preview is unbuilt; the Cathedral completion ACHIEVEMENT waits on the achievements system; exchange + caravan are not in the economy sim (policy note in `economy-sim.md`); new-building silhouettes fall back to monograms (placeholder-first).
>
> **Merged-after note (2026-07-10):** this doc was designed against the PRE-rebalance sim report; the same-day rebalance + room-scaled tick landed on main first (`design/economy-sim.md` is regenerated, `design/history.md` has both bullets). The stale figures are corrected inline below; the design itself is unaffected — the structural problem (no gold sink once buildings max) survives the rebalance, only smaller.

---

## The model in three rules

1. **Buildings persist for the whole game — nothing retires.** Ages don't swap the roster; they unlock new **level bands**: **Age I = L1–3**, each later age adds **+2 levels** → cap **L11** in the Future age (Age I keeps 3 levels as the exception — it's the fully-played v1 age and grandfathers all built data verbatim).
2. **A band belongs to its age.** The first level of each band is **gated by a tech of that age** (per-level `unlocked_by`), and band costs are paid in Gold + that age's **Material** resource. (Per the bible's pacing rule the Material stays Stone through the Renaissance; Iron/Steel arrive with the Industrial complexity spike.)
3. **Band openers transform; band closers bump.** The first level of a band changes the building qualitatively — new visual, possibly a new name, sometimes a new function or output (Library→University, Quarry→Mine). The second level is the stat bump. Ten flat "+1/day" increments is the failure mode; five transformations with a bump after each is history happening.

Why this shape (what it buys structurally):

- **Gold saturation can't recur.** The economy sim's headline red flag (gold piles up with no sink once buildings max — 94k idle by run 40 pre-rebalance, still ~22.8k after the 2026-07-10 rebalance; `economy-sim.md`) is answered three ways: the Market's repeatable exchange, the Cathedral's huge staged costs, and every later age reopening ~2 levels × 9 buildings of sinks.
- **The evolving Material role gets its job automatically.** "What does Iron/Steel buy?" — the next band of every building you already own. Each age's Material is that age's construction currency, exactly as Stone is now.
- **Act II comes for free.** A city is a building-level vector over the same defs. Liberated towns start low and climb the same ladders — no second system (see fold-forward below).

**Exceptions to the ladder:** **Thomas's Hut** never changes (lore, IC-14 — 1 model, no ladder). The **Cathedral** is the per-age Great Work with its own 3-stage build (below). **Mara's Forge** is a shop whose levels are tech-gated (Metallurgy → L2, per the bible); its full ladder is detailed when the shop is made buildable.

## The roster — 9 buildable + 2 shops

| Building | Unlocked by | Age-I function | Transforms into |
| --- | --- | --- | --- |
| **Farm** | start | Food/day → the Well-Fed upkeep loop (`food-upkeep.md`); **L3 gated by Three-Field Rotation** (the node's felt payoff) | stays the Farm, re-skinned per age |
| **Quarry** | Masonry & the Arch | Stone/day (+ small Resonance Ore chance); **L2 gated by The Wheel & Axle** (ox-carts) | **Mine** (Industrial) — output flips to the age's Material (iron → steel) |
| **Sophia's Study** | start | base Knowledge/day + the shard turn-in desk | stays Sophia's, re-skinned per age |
| **Library** | Writing & Parchment | **+% Knowledge** (the first `multiplier` building — different math than the Study's flat rate) | **University** (Renaissance — Printing Press gates the L4 opener; the C6 age-turn showpiece) |
| **Observatory** | Empirical Observation | **+Knowledge/day AND one free hint** on the active tech puzzle + a preview of what the next tech unlocks; **L3 gated by Optics & Lenses** | Telescope gates its Renaissance band |
| **Mill** | Watermill | **+% Farm & Quarry output** (second multiplier); **L3 gated by Mechanical Clock** (timed works) | re-themes toward powered machinery (see open questions — Energy role) |
| **Market** | Arithmetic & Zero | the economy hinge: auto-sells Food surplus, Gold→Stone/Food exchange, one rotating caravan deal per day (spec below) | **Bank** (later age, TBD) |
| **Town Walls** | Masonry & the Arch | capability/flavor (`walls-1..3`); **the literal Act-II seed** | **Fortifications** — a real defense stat in Act II |
| **Cathedral — the Great Work** | Masonry & the Arch (the node's pitch literally promises it: "why an arch can hold up a cathedral") | 3 huge staged levels: scaffolding → structure → finished. The prestige gold+stone sink; one big themed bonus + an achievement on completion | one **Great Work per age** (a new monument each age — data slots, flavor TBD) |
| *Mara's Forge* (shop) | start | weapon upgrades (Resonance Ore); **L2 via Metallurgy** = cheaper/stronger | shop ladder detailed later |
| *Thomas's Hut* (shop) | start | etchings + attunements (Resonance Dust) | **never changes** (lore, IC-14 — 1 model) |

## Cuts (2026-07-10, human decision)

- **Timber + the Woodcutter's Lodge** — one Material per age; **Stone IS the medieval material**. The Material role is now **Stone → Iron → Steel → Oil/composites → Nanomaterial**. (This also resolves the doc-vs-code drift flagged 2026-07-10 — Timber never existed in `data/`.)
- **The Cart** — its "production boost" duplicated the Mill. The Wheel & Axle now gates **Quarry L2** instead (every tech still lights something up).
- **University as a separate building** — it's what the **Library becomes** when Printing Press opens its Renaissance band. The age-turn moment gets stronger: a building you raised with your own gold visibly transforms.
- **No Cartwright / run-loot building** — town buildings never touch run rewards or combat power (human call; keeps the civilian/combat separation absolute, IC-14).

## The tech payoff rule

**Every tech node lights something up in town** — a new building or a level. The Age-I mapping (bible tech table is synced to this):

| Tech | Town payoff |
| --- | --- |
| Empirical Observation | Observatory |
| Writing & Parchment | Library |
| Arithmetic & Zero | Market |
| Masonry & the Arch | Quarry + Town Walls + the Cathedral may begin |
| Three-Field Rotation | Farm L3 |
| The Wheel & Axle | Quarry L2 (ox-carts) |
| Watermill | Mill |
| Mechanical Clock | Mill L3 (timed works) |
| Metallurgy | Forge L2 |
| Optics & Lenses | Observatory L3; bridge to Telescope |
| Cartography | *(the exception — its payoff is in-run door foresight, `run-structure.md`)* |
| **Printing Press** (Ren) | **Library → University** (the L4 band opener) |
| **Telescope** (Ren) | Observatory's Renaissance band |

## Market — v1 spec (all numbers placeholders)

The missing gold economy. Three functions, deliberately simple; **the Market never trades Resonance** (Ore/Dust stay outside the civilian economy, IC-14).

1. **Auto-sell surplus Food** on the day tick: everything above a keep-buffer (placeholder: 2× current upkeep) sells at **1 gold / Food**. (Completes the loop `food-upkeep.md` pointed at.)
2. **Exchange (the repeatable soft sink):** buy at unfavorable rates — **5 gold → 1 Stone**, **2 gold → 1 Food**. Deliberately worse than producing it; late-game gold finally has somewhere to go, and it gives Stone a gold-priced escape valve. (Pre-rebalance Stone was the sim's hard bottleneck; the room-scaled tick relieved it — Walls L3 now gets bought in-sample — but the valve stays useful whenever the human dials Stone tight again.)
3. **Caravan deal:** one rotating offer per day tick from a small data table (e.g. "20 Stone for 70 gold", "sell 10 Food at double") — a tiny reason to glance at the Market daily. Civilian resources only.

Levels: L2 better rates, L3 a second deal slot (placeholders).

## Cathedral — the Great Work (all numbers placeholders)

- **Stage costs meant to bite:** 400g + 60 Stone → 900g + 150 Stone → 2,000g + 300 Stone. Sized against the PRE-rebalance sim's 94k-gold-by-run-40 curve — post-rebalance the curve is ~22.8k by run 40, so these likely land near the right bite already; the human dials. *(Sim rerun with the build, 2026-07-10: stage 1 lands at run ~29; stages 2–3 stay out of reach in-sample — Stone, not gold, bites, because Quarry L2+ waits on the unauthored Wheel & Axle. Expected under "the tech payoff rule"; recheck when the gate techs are authored.)*
- Each stage is a visible construction state (scaffolding → structure → finished) — the didactic payoff is real: cathedrals were multi-generation civic projects.
- **Completion bonus (placeholder):** shard turn-in value +1 (`SHARD_KNOWLEDGE_VALUE` 5→6) + an achievement. Prestige first; the bonus is themed, not build-defining.
- Later ages raise a **new** Great Work (data slots; flavor per age TBD) — and in Act II every liberated city can raise its own.

## Schema deltas (`architecture-schemas.md` §6 — synced)

- `levels[]` is **age-banded**, not fixed-3: arrays grow as later ages are authored (v1 ships Age-I bands + the Library L4 opener; later bands are absent until authored — the loader takes the array as-is).
- Any level may carry an optional **`unlocked_by`** (same typed shape as the building-level one) and an optional **`rename`** (band openers: Library L4 → "University"). Levels keep **REPLACE/absolute semantics** — a band opener that changes output simply states the new `produce` resource.
- `category` gains **`great-work`**.
- Existing 4 building files stay valid verbatim; implementation adds the two in-band tech gates (Farm L3, Quarry L2).

## v1 authoring scope

9 buildable × Age-I band (L1–3, costs Gold + Stone) + the 2 shops + the **Library→University L4 opener** (so C6's age turn has its showpiece) + the Cathedral's 3 stages. Later bands land with their ages, post-v1. Net new data over today: **5 new building files** (Library, Observatory, Mill, Market, Cathedral) + 2 gate fields + the Market/caravan logic + the Cathedral bonus hook.

## Act II fold-forward (designed-for, not built — IC-13)

- **City = a building-level vector** over the same defs; young cities climb the same ladders. Town development in the strategy layer is this exact system, instantiated N times.
- **Walls → Fortifications** (defense stat), **Market → trade routes/logistics hooks**, **Farm/upkeep → army & city provisioning** (`food-upkeep.md`), **Cathedral → per-city Great Work** (prestige/morale lever).
- **Military buildings** (summoning circle, barracks) arrive as *new* category entries born in their age — mirroring how the Energy/Military resource roles are born, not retrofitted.

## Open questions (playtest / next design pass)

- **Mill vs the Energy role at Industrial:** does the Mill become the power building, or does a new born-Industrial Power Plant own the Energy resource (leaning: new building, symmetric with the resource role being born)?
- Caravan-deal table shapes + whether deals should ever be strictly good (a "check the Market" habit vs. a solved optimization).
- Cathedral bonus — is +1 shard value too build-relevant for a prestige monument?
- Is 2 levels per building per age enough cadence, or does an age ever feel empty? (Fix = a 3-level band for one or two buildings, NOT new buildings.)
- Observatory hints vs. Sophia auto-solve — two hint systems touching the same puzzles; make sure they read as one.
- Dust two-sink saturation (`economy-sim.md`) is a *combat*-economy problem — explicitly NOT addressed here (IC-14 separation). The 2026-07-10 rebalance already pushed both-sinks-complete from run ~9 to ~25; watch it again as etchings 6–9 land.
