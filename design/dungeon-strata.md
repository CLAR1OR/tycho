# Dungeon Strata & Hazards — floor differentiation

> How the five floors of the one dungeon differ — mechanically (a **signature hazard** per floor) and visually (**environment profiles** on one shared geometry kit) — and the lore engine that makes the visual gradient part of the story. **Decision dated 2026-07-03** (human call, from the design-review discussion): this **revises IC-5's "no re-theme" reading**. The *bound* IC-5 protects stays fully in force: **one dungeon world, one geometry kit, no independent biome art lines, no age re-theming.** What changes: per-floor identity is now in scope, because in 3D it is data (materials, fog, light), not redrawn art.

---

## The idea in one paragraph

The dungeon is the nanobots' learning-space — a **constructed** environment. When the egg dissolved, the swarm scanned Tycho's world; the upper floors are its *imitation* of that world. The deeper Tycho descends, the older and less-disguised the construct gets: convincing cave → worked stone that's a little too regular → crystalline seams → clean impossible geometry → the void core where the codex artifact waits. **The imitation thins with depth.** The descent is a visual argument that this place is *made* — and made by something that learned our world from the outside. It foreshadows the nanobot reveal without a word of dialogue, rewards the game's core behavior (observation), and is retro-coherent: on a post-reveal replay the whole dungeon reads as "it was in front of me the entire time."

**Deniability rule (load-bearing):** floors 1–4 must read to a first-time player as *"magic gets stranger with depth."* The gradient whispers; only floor 5 is allowed to be unambiguous — and even that should only resolve fully in retrospect, after the (post-v1) reveal. If a playtester says "oh, it's a simulation" on floor 3, the gradient is too loud.

## What stays banned (the IC-5 bound)

- **No independent biome art lines.** Not five tilesets, not five prop sets, not five bespoke moods. One modular geometry kit, shared by all floors.
- **No age re-theming.** The dungeon never modernizes with the town (unchanged from the original decision — and now lore-reinforced: the construct predates the town's progress and doesn't care about it).
- Stratum identity comes from exactly three cheap things: an **environment profile** (data: palette/fog/light/emission), **one signature hazard**, and **2–4 unique props** per floor.

## The five strata

| Floor | Stratum (working name) | Look — and the tell | Signature hazard | Trial focus (in-fiction: what the swarm tests) |
| --- | --- | --- | --- | --- |
| 1 | **The Scanned Cave** | Natural rock, warm dark, utterly convincing — it's imitating the cave Tycho fell into. The tell (hindsight only): formations repeat a touch too evenly. | **Vent plates** — floor tiles that erupt on a visible charge-up cycle. | Timing & evasion — the swarm's first lesson is the dash. |
| 2 | **The Borrowed Hall** | Worked stone: arches, columns, ruin dressing. Imitating *built* things — but every arch is identical. A mason would vary; a copier doesn't. | **Watcher nodes** — fixed wall/pillar emitters that fire on clear line of sight (reuses the Archer LoS raycast + the cover system; murder-hole energy). | Cover & line of sight. |
| 3 | **The Resonant Stratum** | Crystalline seams glowing through the stone; a low hum. The medieval skin wearing thin. | **Burst crystals** — growths that detonate on damage or proximity, hurting *everyone* — usable as bombs against enemies. | Spacing & positioning. |
| 4 | **The Filed World** | Clean planes, floating masses, perfect repetition — unnatural, but a medieval mind attributes it to sorcery. | **Sweep beams** — rotating emitter lines with strict, learnable geometry. | Pathing under constraint. |
| 5 | **The Core** | Void, faint starfield, light that runs in traces like circuitry. The final-boss chamber — where the codex artifact assembles — is the deepest room of all. It was the bottom stratum all along. | **Drift fields** — currents in the void that push; the ground itself moves you. | Control under drift — composure. |

**Shared hazard pool** (any floor, sparse, from floor 2 on): **denial mist** — a drifting no-stand zone. (Keep the shared pool tiny; signature hazards carry floor identity.)

Each floor **introduces** its signature hazard and may sprinkle *earlier* floors' hazards sparsely — mechanical vocabulary accumulates on the way down, mirroring the difficulty curve.

## Hazard design rules

1. **Scripted, not simulated** (same philosophy as the arch puzzle): a hazard is geometry + a timer + a damage volume + a telegraph. No physics, no AI, no ambiguous states.
2. **Always telegraphed, always learnable.** Visible charge-up, readable cycle. Hazards serve pattern mastery, never gotchas.
3. **Dual-use by default: hazards damage enemies too.** Baiting the Brute into the beam is the intended play. (Exception only if a specific hazard breaks under it.)
4. **They compose with enemies, not replace them.** Density stays low in early rooms of a floor, higher in late rooms (data-tunable) — the hazard is the room's *modifier*, the enemies are its *content*.
5. **Never unwinnable.** Layout validation must guarantee hazards can't block the only path or make a room unclearable (PRD §10 dead-roll rule).
6. All damage/cycle/telegraph numbers are `# FEEL:` territory — placeholders until human-tuned.

## Data shapes (mirrored in `architecture-schemas.md` §9)

```jsonc
// data/floors/<n>.json — the stratum profile ("floor as data", sibling of "age as data")
// NOTE: this file EXISTS as of 2026-07-05, but only with the DOOR fields (door_weights +
// peril_chance — run-structure.md, pure DoorCore). The environment/props/hazards/
// music_layer fields below land with the strata build; adding them is purely additive.
{
  "id": 3, "name": "The Resonant Stratum",
  "environment": { "palette": "resonant", "fog_color": "#1a2438", "fog_density": 0.04,
                   "light_temp": 0.35, "emission": "crystal_teal" },
  "props": ["crystal-seam", "crystal-cluster", "humming-shard"],
  "hazards": { "signature": "burst-crystal", "pool": ["vent-plate", "denial-mist"],
               "density": { "early_rooms": 0.2, "late_rooms": 0.5 } },
  "music_layer": "dungeon_3"
}

// data/hazards/<id>.json
{
  "id": "burst-crystal", "name": "Burst Crystal",
  "kind": "burst",                    // vent | node | burst | beam | drift | mist
  "telegraph_s": 0.6, "cycle_s": 0.0, // cycle 0 = triggered, not periodic
  "damage": 20, "radius": 2.5,
  "hurts_enemies": true
}
```

## Readability guard (the one real risk)

Enemy telegraph and body colors are **fixed across all strata**; every floor palette is chosen *around* them, never over them. Each stratum gets a **human legibility pass** (can you read a Skirmisher's telegraph against the crystal glow?) — this is a budget line, not an afterthought. (It's why Hades' Asphodel can be lava-red while every tell stays bright.)

## Free lore this buys

- **Hazards become diegetic:** the runs are learning trials (IC-11), so each stratum is a *test chamber* — the swarm probing one capability per floor (see "trial focus" column). The apparatus isn't decoration; it's the exam.
- **Difficulty tiers:** the space *reconfiguring* — trial intensity raised for a host that keeps passing. Same strata, no new lore needed.
- **Contextual dialogue hooks** (candidates for the snippet pool):
  - Wren: "The deeper halls have straighter walls, you say. Nature doesn't file her corners — so who does?"
  - Sophia (stratum first-visit reports): "You said the third level *hums*? Rock doesn't hum, Tycho. Instruments hum."
  - Sophia, floor 4: "Identical, every arch? I couldn't draw two identical arches if I traced them. Whoever built that doesn't *draw* — it *repeats*."
  - Thomas, late: "A trial has a shape to it. And where there is a shape, there is a hand that shaped it." *(use at most one of these per act — the deniability rule applies to dialogue too)*

## Cost envelope (why this doesn't reopen the art risk)

Shared kit + **5 environment profiles** (pure data) + **5 signature hazards + 1 shared** (each: one small scene, a timer, a volume) + **2–4 props per floor** + **5 human legibility passes**. Rough estimate ~20–30% over strict single-theme — versus several-fold for true biomes, which stay banned.

## Open questions (resolve in playtest, not now)

- Do the strata land visually with placeholder assets, or does judging them need the asset-pipeline gate's output first?
- All hazard numbers (damage, cycle, telegraph, density curves) — tune in play.
- Is floor 5's void too loud too early? (Deniability tuning — it may need to be *quieter* than the concept art instinct wants.)
- Do some of the ~30 shared combat layouts need stratum-specific variants, or does the profile + hazard carry enough identity on identical geometry?
- Does hazard density scale with difficulty tier, or do tiers add hazard *behaviors* (faster cycles) instead?
