# Run Structure — door choice & the in-run healing economy

> **First implementation built 2026-07-05** (pure `DoorCore` + `data/floors/` + `data/resources/resonance-dust.json`; door portals, Wellspring, boss/echo valves in combat_room.gd + game.gd; the every-combat-room echo offer is retired — echoes now come from echo doors + one post-boss guarantee). All numbers below are the placeholders that shipped (in `data/floors/*.json` + `DoorCore` constants). **Deferred (designed here, not built):** Cartography **foresight**, the 2-3 **healing echoes** (need heal hooks the echo-mod system lacks), **3-door** offers, per-floor **heal caps**, first-encounter door **tooltips** (with the painterly pass). (**Recovery attunement is now BUILT** — 2026-07-10, with the Passive Attunements system: L1/2/3 = 4/7/10% of missing HP healed on room clear; see `design/etchings.md` implementation-status block.)

> The meso-loop's two missing specs, designed together because they are one system: **room branching** (what the PRD's "route choices" actually are) and **in-run healing** (how a 5-floor run survives HP persistence). **Drafted 2026-07-03.** The unifying idea: **damage costs you *choices*, not progress** — healing mostly enters the run through doors you pick *instead of* loot, so attrition pressure converts into the run's decision layer. All numbers are placeholders.

---

## Part 1 — Door choice (room branching)

### The flow

Clear a room → **two exit doors** open, each marked with a **sigil** previewing the *reward* of the room behind it → step through one; the choice is final (no backtracking — quick reads, release headspace, never a puzzle). Room *content* still comes from the shared layout pool + the floor's enemy mix; the door picks what the room **pays**.

- Sometimes only **one** door offers (weighted RNG said so) — no fake choices.
- The **last room of a floor always opens a single boss door** (distinct sigil; the room-count HUD means it's never a surprise).
- **Never two identical sigils** in one offer.

### The sigils (v1 reward set — deliberately small)

| Sigil | Room pays | Notes |
| --- | --- | --- |
| **Gold** | bonus gold on clear | The common filler. |
| **Ore** | Resonance Ore cache | Weapon economy. |
| **Dust** | Resonance Dust cache | Etchings/attunements economy — rarest sigil (matches "rare drops"). |
| **Echo** | an Echo pick (1 of 3) on clear | **The primary echo source** — see the cadence change below. |
| **Reprieve** | no combat — a breather room with a **Wellspring** (heal) | Uses the 3 budgeted reprieve layouts. The heal door. |
| **Boss** | floor boss (+ Knowledge Shards, floor heal) | Always alone at floor end. |

**Peril marks:** a door can additionally carry a peril mark — the room runs **elite modifiers** (the PRD §7.7 hook's first concrete use) and pays a **boosted reward**. This is the risk/reward lever, kept exactly this legible: scarier sigil, bigger number.

### Generation rules (pure, seeded, testable — extends `run_flow.gd`)

- Door offers are generated per floor from **data weights** (`door_weights` in the floor profile, `data/floors/<n>.json` — the strata doc's file gains a field, one system).
- **Pity rules** (PRD §10 RNG-protection, applied to doors): every floor guarantees ≥2 **Echo** doors and ≥1 **Reprieve** door among its offers; **Dust** appears at least once per run per N floors (tune). No sigil may be offered 3× consecutively.
- Peril frequency per floor is data (rises with depth and difficulty tier).

### Cartography's payoff (learning → run-visible)

The Cartography tech node ("maps as models — reveals dungeon layout/hints") gets its concrete effect here: **foresight** — after researching it, door sigils also show what lies *one room further ahead* (the offers behind each door). Reading the map before walking it: exactly the node's lesson, felt mid-run.

### Diegetic frame (deniability rule applies)

The learning-space *offers* trials — the sigils are etching-glyphs Tycho learns to read (first encounter of each gets a one-line tooltip; after that, icon only). The swarm pays the host in what it chases — which is, quietly, a reward schedule shaping varied behavior. Dialogue hook candidates (late-act, use sparingly): Sophia — "It pays you in whatever you're short of, have you noticed? That's not treasure, that's *provisioning*."

### The Echo cadence change (affects current code — deferred, but decided)

The current slice offers an Echo after **every** cleared combat room — fine at 1 floor × 3–4 rooms, but at full shape (30–50 combat rooms) that's triple Hades' boon rate and would exhaust the ~50 pool mid-run. **Decision:** echoes come from **Echo doors** (≥2/floor pity) **plus one guaranteed pick after every floor boss** (kill high → build beat). Target cadence ≈ **12–17 picks per full run**. The bible's "from time to time, the etchings glow" was always the intent; the every-room slice behavior is a placeholder to be retired when door choice is built.

---

## Part 2 — The in-run healing economy

### Philosophy

**Attrition is the run's long game** — HP persistence (2026-07-02) is deliberate tension, so: **no full heals anywhere, ever, mid-run.** All healing is a **percentage of *missing* HP** — it scales with need, can't overcap, and doesn't multiply against Vitality's +max-HP the way %-of-max would (anti-snowball). Damage taken always still costs *something*; what it costs is mostly **choices** (the Reprieve door you take instead of the Ore door; the Dust you spend on Recovery instead of an ability).

### The sources (complete list — legibility is the point)

| Source | What | When | Placeholder |
| --- | --- | --- | --- |
| **Wellspring** (Reprieve room) | a pool of dormant swarm-substrate; interact to heal | via the Reprieve door (≥1/floor offered) | **40% of missing HP** |
| **Floor-boss clear** | the swarm repairs its instrument after a passed exam | automatic, every boss kill | **30% of missing HP** |
| **Recovery attunement** | heal on room clear | persistent (Dust investment) | L1/2/3 = **4/7/10% of missing** per clear |
| **Healing Echoes** (2–3 in the ~50 pool) | e.g. *Mender's Rhythm* (small heal on kill), *Deep Repair* (+50% to all healing received), *Salvage* (heal on ore/dust pickup) | in-run picks | small; build choice |
| **Assist mode** | unchanged — stacking damage *resist*, not healing | opt-in | per IC-10 |

**Explicit non-goals (v1):** no random food/potion drops (keeps the source list legible), no mid-run shops, no health-for-currency trades, no full-heal rooms. Revisit only if playtest shows starvation pity is needed (PRD §10 already reserves pity rules).

### Why this holds up (the death-spiral guard)

A bad floor can't doom the run three floors later: the boss heal is a **guaranteed cadence** valve (every ~6–10 rooms), Reprieve doors are a **choosable** valve, Recovery/echoes are **investment** valves, and assist mode floors the whole thing for accessibility. But none of them erase mistakes — 30–40% of *missing* means arriving hurt still means leaving hurt.

### Diegetic frame

The runs are learning trials (IC-11); the space **maintains its instrument** between exams. The Wellspring is the same substrate the dungeon is made of, doing openly what it always does invisibly — one more quiet strata-consistent tell (a Wellspring on floor 4 looks *less* like water than the one on floor 1 did).

---

## Data shapes

```jsonc
// data/floors/<n>.json — gains door_weights (extends the §9 strata profile)
{ "id": 3, /* …strata fields… */
  "door_weights": { "gold": 3, "ore": 2, "dust": 1, "echo": 3, "reprieve": 2 },
  "peril_chance": 0.25 }

// healing + door constants live with run tuning (FEEL-adjacent, human-tuned):
// wellspring_heal_pct_missing, boss_heal_pct_missing, recovery_per_level[],
// echo doors per floor (pity), reprieve doors per floor (pity), echo_after_boss: true
```

## Balance watch-list

- **Heal stacking:** Recovery L3 + *Deep Repair* + every Reprieve door could nearly reset each floor — consider a per-floor healing cap or diminishing returns if playtest confirms.
- **Pity math vs. greed:** if Echo doors are strictly better than loot doors (they usually are in Hades too), the pity floor *is* the balance — loot doors must pay enough to tempt.
- **Dust starvation:** Dust is both the rarest sigil and a two-sink currency — watch it hardest (PRD §10 already flags the two-sink risk).
- **Peril reward curve:** boosted rewards must not make peril doors strictly correct for skilled players *and* strictly wrong for weak ones — peril scaling per tier helps.

## Open questions (resolve in playtest)

- Two doors or sometimes three? (Three adds choice richness but crowds room exits; start with two.)
- Does the post-boss guaranteed Echo + Echo doors hit the 12–17 pick target at real pace?
- Wellspring interaction: instant on touch, or a 2s channel (a breath, but interruptible-feeling)?
- Should peril doors exist on floor 1 at all, or unlock at tier/depth?
- Exact numbers: all of them.
