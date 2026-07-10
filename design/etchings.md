# Etchings — the 9 active abilities (+ dash)

> **Implementation status (2026-07-07 — first slice built).** The system is playable: all 9 abilities ship as data (`data/etchings/*.json`), a pure `EtchingsCore` + the `EtchingsPanel` (opened from Thomas's meditation spot, gated on B2) handle learn/level/equip with Resonance Dust, and the player casts RMB/Q/R with per-slot cooldowns. **Built (castable at L1/L2): Push, Bolt, Snare, Shockwave, Surge.** **Dormant (data ships, shown in the panel as unlearnable): Afterstrike, Ward, Lodestone, Sentinel** — implementation status is CODE (`EtchingsCore.IMPLEMENTED`), not data. **Deferred:** all L3 riders (data only), all weapon synergies (data only), and etching-mod Echoes. (**Passive Attunements are now BUILT** — see the block below.) Every number below is a placeholder living in each def's `behavior` dict + level `_mult`s (dial board: `design/feel-tuning.md`).

> **Passive Attunements — implementation status (2026-07-10 — built).** The bible's second Thomas's-Hut layer (PRD §7.4) is live: the seven passives are the persistent BASELINE a run starts from, and echoes build on top. **All 7 ship as data** (`data/attunements/<id>.json`: vitality / recovery / quickening / resonance-flow / focus / resilience / attunement; `ATTUNEMENTS_SPEC` in DataLoader, filename==id, loud validation). **Data shape:** `id/name/desc` (placeholder copy) + `costs_dust: [L1,L2,L3]` + a `levels` array of 3 entries with **ABSOLUTE/replace semantics** (level N states its TOTAL effect, like building levels — not stacking deltas). Each level entry carries a `kind` so the panel renders all 7 uniformly:
> - **stat** — echo-shape `{stat, add, mult}` mods reusing EchoCore's EXACT stat handles (vitality→`max_health`, quickening→`dash_cooldown`, focus→`attack_damage`+`attack_damage_finisher`). Applied through the SAME `EchoCore.apply_to_player({"mods": …})` path as weapons/echoes — no second stat engine.
> - **heal_on_clear** — Recovery: pct of MISSING HP healed on room clear (4/7/10 per `run-structure.md`).
> - **find_rate** — Attunement: Dust/Ore find multiplier (kept tame — inherently bounded at 3 levels, the PRD §10 compounding risk).
> - **damage_reduction** — Resilience: flat HP off each hit (floored at 1 — no immunity).
> - **ability_cooldown** — Resonance Flow: ability cast-cooldown multiplier (EchoCore has no ability-cd handle, so it rides a player var).
>
> **Application order (PRD §7.4):** base feel exports → weapon → **attunements** → echoes, in `combat_room._ready`. Non-stat kinds set hooks: `player.flat_damage_reduction` / `player.ability_cooldown_mult`, the room's `_find_mult` (per-kill ore chance) + `_recovery_pct` (heals on the once-per-clear site, combat+boss, atop the boss valve); find-rate ALSO multiplies the Dust/Ore door-cache amounts in `game.gd._pay_cache` (DoorCore's pure math untouched). **Pure `AttunementsCore`** (`src/learning/attunements_core.gd`, static, unit-tested) owns level/next_cost/can_deepen/deepen (return-new-dict, capped at 3) + the five folded read helpers. **Save:** `combat.attunements` (flat `{id: level}`) — already in defaults; purchases spend `Ledger.try_spend("resonance-dust", n, "attunement")`. **UI:** a SECOND page on the etchings panel — the E1 "arms" page stays the default; a mono-caps `THE MARKS · THE BODY` tab row swaps to `AttunementsPage` (a 7-row Slate sheet: name / desc / 3-pip track / effect line / `Deepen (n Dust)` button, inert `Mastered` at L3; a mote-cluster Dust readout). **Cost curve:** [8,12,16] each (rebalanced 2026-07-10) → 252 Dust to max all 7, near the full ability kit's ≈270 so the shared-Dust two-sink tension is real. **Deferred (document-don't-build):** the attunement TREE/prereqs (flat list for now), an in-run "attuned baseline" HUD readout, attunement-mod echoes, per-attunement L3 riders. **Every number (`costs_dust` + effect values) + all page copy/layout is a PLACEHOLDER** — dial like FEEL numbers (`data/attunements/*.json`; `design/feel-tuning.md`).

> **Panel presentation — "The arms" (E1, human decision 2026-07-08).** The etchings PANEL was rebuilt (`EtchingsPanel`, from a scrolling list into Tycho's two arms with four etched marks — spec: `design/ui-hud.md` → "Etchings panel — The arms (E1)"). The panel now shows only **the four marks a run actually uses** — each slot's equipped-else-STARTER ability (`STARTERS = {rmb: push, q: snare, r: shockwave}`, placeholder) plus the innate dash — with an **awaken / deepen / mastered** framing (dormant → `Awaken (n Dust)`, same unlock mechanic; awakening auto-equips, since the screen has no Equip button). This is the deliberate **no-swap rule:** ability swapping and the Equip/loadout UI are hidden until a later story beat — the other 5 etchings stay in data + `EtchingsCore` but don't appear in this screen. **The 9-ability design itself is unchanged** (everything below still stands); only how the panel PRESENTS it changed. Two optional data fields were added for the menu copy — `desc` + `level_blurbs` (authored in push/snare/shockwave, placeholder text).

> The design for Tycho's "magic" loadout: the **9 unlockable abilities** (3 per slot: RMB / Q / R), the fixed dash, upgrade levels, weapon synergies, and the data shape. **Drafted 2026-07-03** — fills the bible's empty etchings table (the last undesigned core combat system). All numbers are placeholders; ability *feel* is `# FEEL:` territory (human-tuned like everything else in combat). Budget contract: 9 abilities × 3 levels × ~1 weapon-synergy variant each (`content-budget.md`); system contract: PRD §7.3; vendor: Thomas's Hut (Resonance Dust, shared with attunements).

---

## Design rules

1. **Slot grammar.** Each slot has one job, so a loadout always covers three roles:
   - **RMB — Strike.** Quick tactical hit, short cooldown (~4–6 s). The "second attack."
   - **Q — Field.** Control/utility, medium cooldown (~10–14 s). Shapes the room.
   - **R — Surge.** The big moment, long cooldown (~30–45 s). Spent, not spammed.
   - **Space — Dash.** Fixed, always available since A1. NOT one of the 9 (see below).
2. **Cooldowns, no mana.** No resource bar — cooldown pips only (PRD §9 already lists them). Keeps the HUD lean and the reflexive loop pure.
3. **Mouse-aimed, like everything else.** Abilities fire toward the cursor/facing, consistent with the attack scheme. No target-lock.
4. **Relative to the FEEL baseline.** Ability damage/knockback are expressed relative to the player's feel-tuned exports where sensible (same philosophy as weapon mods — tuning the baseline tunes the arsenal).
5. **One real principle each.** Every ability is a nanobot operation wearing a physics name (the `principle` field) — deniable as magic pre-reveal, obvious as engineering post-reveal. Same deniability rule as the dungeon strata.
6. **They compose with what exists.** Knockback into dual-use hazards (`dungeon-strata.md`), stagger rules (`stagger_time`, armored = 0), the commit-token crowd cap, cover/line-of-sight — abilities are designed against these systems, not beside them.

## The dash (Space — fixed)

The etchings' "first word": granted in A1, never swapped, never bought. Upgrades come only from the **Quickening** attunement (+charges / shorter CD) and **dash-mod Echoes** — the dash itself stays out of the 9 so the one universal defensive verb is never a build decision.

## The nine

### RMB — Strikes

| | Push | Bolt | Afterstrike |
| --- | --- | --- | --- |
| **Principle** | Impulse — momentum transfer | Directed energy | Stored work — the swarm replays |
| **What it does** | A flat-palm cone of force: modest damage, heavy knockback. Enemies slammed into walls/obstacles take bonus damage + brief stagger; shoving them into hazards is intended play. | A fast dart of etching-light at the cursor — the melee kits' ranged answer. Staggers squishies (cancels telegraphs at range). | A spectral copy of your **last landed melee hit** re-strikes the same spot after ~0.5 s at a % of its damage. Rewards landing finishers. |
| **L2** | Wider cone, +slam damage | +damage, −cooldown | +replay % |
| **L3 rider** | Shoved enemies knock down whatever they hit (bowling) | Pierces the first enemy | The replay is a small AoE pulse |
| **Weapon synergy** | **Sword:** a Push placed mid-combo doesn't reset the sequence, and the following finisher gains bonus damage | **Bow:** Bolt marks its target (~4 s); arrows hit marked targets for +damage | **Daggers:** replays twice at a lower % |

**Push is the free one** — granted at B2 during Thomas's meditation scene (the system's tutorial ability; the other eight cost Dust).

### Q — Fields

| | Snare | Ward | Lodestone |
| --- | --- | --- | --- |
| **Principle** | Viscosity — the air thickens | Rapid assembly — matter from "dust" | Attraction |
| **What it does** | A ground field (~3 m): enemies inside are heavily slowed; squishies briefly rooted on cast. Armored enemies (stagger 0) are slowed but never rooted. | Raises a chest-high barrier arc (~4 m) for ~5 s on collision layer 4 — it **blocks movement, arrows, and line of sight** (cover on demand: Archers and watcher nodes lose you behind it). | Plants a point that drags nearby enemies toward it over ~1.5 s (armored dragged less), grouping them for finishers, Shockwave, or a waiting hazard. |
| **L2** | +radius, +duration | Wider arc, +duration | +radius, +pull strength |
| **L3 rider** | Enemies *leaving* the field are staggered | Enemies touching it take pulse damage + a shove | Detonates when it expires (light AoE) |
| **Weapon synergy** | **Bow:** +ranged damage vs snared enemies | **Sword:** fighting adjacent to your own Ward grants flat frontal damage reduction (braced) | **Daggers:** +attack speed against enemies near the lodestone |

### R — Surges

| | Shockwave | Surge | Sentinel |
| --- | --- | --- | --- |
| **Principle** | Pressure wave | Overdrive — the swarm redlines the host | **Self-assembly** |
| **What it does** | A radial blast from Tycho: big close damage falling off with range, massive knockback — and it briefly staggers **even armored enemies** (the only thing that does). The panic button; spectacular with hazards. | ~5 s: +move speed, +attack speed, dash cooldown halved, immune to knockback. Etchings blaze; ghost trail runs. | The nanobots **assemble a small floating construct** (~8 s) that darts at enemies and fires stinging bolts. |
| **L2** | +damage, +radius | +duration, +potency | +duration, +damage |
| **L3 rider** | Leaves a brief Snare-like slow field | Kills during Surge extend it (+1 s each) | The construct taunts — nearby enemies engage *it* |
| **Weapon synergy** | **Sword:** your next 3 swings after the blast use the finisher arc | **Daggers:** +1 dash charge for the duration | **Bow:** the construct volleys in sync with every arrow you loose |

**Sentinel is the Act-II summon seed.** The summons schema (`architecture-schemas.md` §8) hangs off `source_etching` — that etching is Sentinel. In v1 it's just a short-lived construct; the strategy layer grows real summons out of this node (the climax's "summons unlock" seed points here). Its data carries `summon_seed: true` so nobody redesigns it into a shape summons can't extend. It is also the loudest rational-fiction whisper in the kit: the player watches the "magic" *build a machine* — the same thing the dungeon's deeper strata quietly are.

## Unlocks & costs (placeholders — tune with the Dust economy)

- **B2** (Thomas, first Resonance Dust): screen unlocks, **Push granted free**.
- Unlock costs by slot (rebalanced 2026-07-10 against `tools/economy_sim.gd`): RMB **6** Dust, Q **8**, R **12** (Push stays free). Levels per slot: RMB [6, 10], Q [8, 12], R [12, 18] (L2 = unlock cost, L3 ≈ 1.67×).
- Full 9-ability kit ≈ **270** Dust (the 5 implemented ≈ 150); the 7 attunements ≈ **252** ([8, 12, 16] each) — the same pool (deliberate tension, PRD §7.3/§7.4 risk). Sim result at these numbers: first paid unlock ~run 2, ability kit maxed ~run 13, both Dust sinks complete ~run 25 (`design/economy-sim.md`).

## Echo integration (unblocks the "etching mods" category)

The Echo pool's etching-mod category can now be authored against real handles:
- Generic stat handles: `ability_damage_mult`, `ability_cooldown_mult`, per-slot variants (`rmb_*`, `q_*`, `r_*`).
- **BUILT 2026-07-10 (echo-pool expansion 8→~25):** the two generic handles are LIVE as plain `Player` fields, reached by EchoCore's existing `{stat,add,mult}` math (no engine change). `ability_damage_mult` (default 1.0) is folded into cast damage at the single choke point `player._ability_damage(scale)` (used by Push/Bolt/Shockwave); `ability_cooldown_mult` is the SAME field the Resonance-Flow attunement sets at spawn, so echo mults **fold multiplicatively on top** (attunements apply first, echoes after — verified). Shipped etching-mod echoes: `resonant-edge` (+25% ability damage), `quick-channel` (−15% cooldowns, stackable), `overcharge` (+60% damage / +40% cooldowns drawback), `focusing-lens` (+10% damage, stackable), + the synergy `arc-resonance` (requires resonant-edge + quick-channel). Per-slot variants (`rmb_*` etc.) + ability-specific hooks below remain deferred.
- Ability-specific echo hooks (examples): "Push resets on kill", "Snare also weakens (enemies take +damage)", "Ward duration doubled", "Shockwave twice, half power". Synergy echoes can require a specific equipped ability (the `requires[]` mechanism already supports this shape).

## Rational-fiction integrity & dialogue hooks

Pre-reveal these read as a warrior-mystic's arts; post-reveal each is an obvious engineering verb (impulse, directed energy, replay, viscosity, fabrication, attraction, pressure, overdrive, self-assembly). Thomas teaches the categories as a philosophy of *restraint* — candidates for his arc pool:
- On Strikes: "The shove is honest. It only ever does what your hand meant."
- On Wards: "You didn't raise a wall, boy. You *asked*, and something built one. Sit with that."
- On Sentinel: "It makes a servant from nothing and unmakes it after. Whatever grants this — it knows how to make things that *end*. Remember that kindness."

## Balance risks (watch in playtest)

- **Ward vs ranged pressure:** cover-on-demand could trivialize Archers/watcher nodes — tune duration vs cooldown so it's a beat, not a stance.
- **Lodestone → Shockwave** is the obvious dominant combo — it *should* feel great (that's the synergy high), but numbers must keep positioning relevant.
- **Surge + assist mode + Vitality/Resilience** stacking (extends PRD §10's trivialize-check).
- **Rotation homogenization:** if every room opens RMB+Q+R, builds stop mattering. R's cooldown should exceed a typical room so it stays a *choice*; Q/RMB stagger by design.
- **Afterstrike math** rides on finisher damage — cap the replay % so finisher buffs don't compound past intent.

## Data shape (mirrored in `architecture-schemas.md` §10)

```jsonc
// data/etchings/<id>.json
{ "id": "push", "name": "Push", "slot": "rmb",         // rmb | q | r
  "principle": "impulse",                                // rational-fiction tag; dialogue hooks read it
  "cooldown_s": 5.0,
  "granted_by": "b2",                                    // beat id, or null = bought at Thomas's Hut
  "cost_unlock_dust": 0, "cost_levels_dust": [3, 5],
  "levels": [ { }, { "damage_mult": 1.3 }, { "rider": "bowling" } ],
  "weapon_synergy": { "weapon": "sword", "effect": "combo_continues_bonus_finisher" },
  "summon_seed": false }
```

Save already carries `combat.etchings {slots: {rmb,q,r}, unlocked: {id: level}}` (schema §1) — no save change needed.

## Open questions (resolve in playtest)

- Is 9 the right count for v1 build variety (PRD §13 already asks this)? If cut, cut one per slot — the grammar survives.
- Do R cooldowns (30–45 s) feel *earned* or *absent* at real room pace?
- Sentinel vs the commit-token crowd cap: does its taunt consume attacker tokens or bypass them? (Decide when built — affects crowd readability.)
- Do ability VFX need the asset pipeline, or do primitive-mesh placeholders read well enough for feel-tuning (placeholder-first says try it)?
- Exact Dust curve once drop rates exist — the two-sink balance is unmeasurable until then.
