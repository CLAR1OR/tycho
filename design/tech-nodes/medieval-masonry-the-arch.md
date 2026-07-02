# Tech Node — Masonry & the Arch

> **First authored node (the Content gate).** Authored end-to-end to validate the explanation → puzzle → "aha" format. Playtest for *delight vs. homework* before authoring the rest of the tree. Template: `_TEMPLATE.md`.

## 1. Metadata
| Field | Value |
| --- | --- |
| id | `med-masonry-arch` |
| name | Masonry & the Arch |
| age | I Medieval |
| tier | KEY |
| cost | 40 Knowledge (illustrative — tune later) |
| prerequisites | `med-arithmetic-zero` (Arithmetic & Zero) |
| unlocks | **Quarry** (Stone resource) + **Town Walls** (the strategy-layer seed) |
| supersedes / retires | — (Timber/Stone retire later, at the Industrial age) |
| status | drafted — awaiting playtest. **In-game since 2026-07-02** (`data/tech/med-masonry-arch.json`); the **§5 interactive puzzle is BUILT** (same day, replacing the interim quiz): pure `src/learning/arch_puzzle_core.gd` (the §9 scripted state machine) + clickable diagram `src/learning/puzzle_arch.gd`. Placeholder visuals; click-to-place stands in for drag-and-drop; hints cycle freely (the 1-per-run limit and the pointed profile's mechanical payoff are deferred — pointed is visual-only). This .md remains the authoring source. |

## 2. One-line pitch
Learn *why* an arch can hold up a cathedral when a flat stone can't span a doorway — and unlock stone construction (Quarry + the first Town Wall).

## 3. Framing / trigger
Available once Arithmetic & Zero is researched (the tree is open by then — Linnea unlocked it after the third boss). The motivation is concrete and pulls toward the strategy seed:

- **Herzog (mayor):** "The palisade's half-rot and a hard winter from falling over. Wood won't hold what's coming. We need *stone*." *(He doesn't yet know what's coming. The player will.)*
- **Linnea:** "Stone's easy — you just stack it. The trouble is the *gateway*. Lay a stone flat across the opening and it cracks under its own roof. There's a trick to it, and I think the shards have the shape of it. Let me show you."

Tycho-the-observer hook (optional flavor): Tycho recalls the cave he fell into — a natural rock span overhead that *didn't* fall. "Why does the cave hold up its own ceiling, when our doorway lintel won't?"

## 4. Explanation (read before the puzzle)
*Shown when the node is ready to research.*

You already know stone in your bones: stack it and it only packs tighter — push *down* on a pile and it grips harder. So why does the same stone that holds up a whole wall **snap** the moment you lay it flat across a doorway and pile a roof on top?

Because stone keeps two very different promises. Squeeze it and it is almost unbreakable — its strength in **compression** is enormous. *Pull* it apart and it is feeble — its strength in **tension** is perhaps a tenth as much. A flat stone beam — a *lintel* — over a gap bends under load, and bending stretches its underside. The bottom fibers go into tension, and that is exactly where stone gives up and cracks.

The **arch** is the trick that erases the tension. Curve the span into a ring of wedge-shaped stones — *voussoirs* — and now every stone is driven hard against its neighbors. Nothing bends. The weight runs *through* the stones as pure squeeze, following an invisible path — the **thrust line** — down to the ground. Stone asked to do only the one thing stone is good at.

The last stone you set is the **keystone**, the wedge at the very top. Until it drops home the ring is unfinished, and a half-built arch would simply fall — so masons hold it up on a temporary wooden frame, the *centering*, until the keystone locks the ring. Seat it, and the arch becomes self-supporting. Pull the frame away. It stands.

There is a price, and it catches the careless: an arch does not only press *down* — it shoves *outward* at its feet. Span a wide gap and that outward thrust will spread the supports and bring the whole thing down, unless you brace each foot with a heavy **abutment** or a **buttress** to take the shove.

And your age is the moment this all comes alive. Right now — 1157 — masons are learning that if you make the arch *pointed* rather than round, the thrust line runs steeper and the outward shove shrinks. Walls can climb higher and thinner; windows can open wide enough to drown a hall in light. The great cathedrals beginning to rise in this very generation stand on exactly this insight.

## 5. The puzzle
A small, scripted **build-the-gateway** sandbox (not a full physics sim — see Production notes). Three beats, each forcing one true idea. The goal: raise a gateway that carries the new Town Wall without collapsing.

- **Type:** interactive arrange-and-test, with a "load it and see" button between beats.
- **Setup:** an open gateway in the half-built wall. A pile of stones to the side: flat slabs *and* wedge-shaped voussoirs. A weight (the wall section) to drop on top to test.

- **Beat 1 — tension vs. compression.** The player first tries the obvious: lay a flat lintel across and load it. It bows and a crack races along its *underside*. The UI highlights the stretched bottom edge ("being pulled apart — stone's weakness"). Action: abandon the lintel; choose to curve the span.
- **Beat 2 — the ring & the keystone.** The player places voussoirs from both feet inward. The half-ring visibly wants to fall until propped on centering. The final gap takes the **keystone** — and only when it's seated does the centering come away and the ring hold. (If they try to load it before the keystone is in, it collapses.)
- **Beat 3 — the thrust.** Load the finished arch: it holds, but the feet visibly slide *outward* and, untreated, the arch splays and falls. Action: place an **abutment/buttress** at each foot to take the outward shove. *(Optional mastery: switch the profile from round to pointed and watch the outward slide shrink — fewer/lighter buttresses needed.)*

- **Win condition:** keystone seated, both feet braced, the wall section loaded and held. The gateway stands.
- **Principle tested:** stone fails in tension, not compression; an arch routes load as pure compression; the ring is only stable once closed by the keystone; arches thrust *outward* and must be braced.
- **Failure feedback (teach through failure):** the lintel cracks on its underside; the unkeyed half-arch falls; the unbraced arch splays at the feet. Each failure shows *where* and *why*, not just "wrong."

- **Difficulty / graceful path (Linnea's hints, 1 per run; auto-solves after ~5):**
  1. "A flat stone over a gap snaps along its *underside* — that's where it's being pulled apart, and stone hates being pulled. Can you arrange the stones so they're only ever *pushed*?"
  2. "Wedges. If each stone is a wedge leaning on the next, the weight presses them together instead of bending any one of them. But a ring isn't a ring until it's closed."
  3. "Set the top wedge — the keystone — *last*; that locks it. Then mind the feet: a finished arch shoves outward. Plant something heavy on each side to take the shove."
  - **Auto-solve (after ~5 runs):** *Linnea, at the riddle-wall in your home* — "Here — I worked it through. Wedge-stones, keystone last, brace the feet, and point the arch to spare the buttresses. The gate'll hold. Go raise your wall." *(Unlock granted; no delight lost — she shows her reasoning, so even the auto-path teaches.)*

## 6. The "aha" (post-solve)
*Delivered as the gateway holds and light catches the new stone.*

Here is the thing no mason of your century can prove, though their hands already know it. Hang a chain loose between two points and it falls into a particular curve — a **catenary** — the one shape in which the chain hangs in pure tension, no part straining sideways more than it must. Now flip that curve upside down. You have the one shape in which an arch stands in pure compression. *As hangs the flexible line, so but inverted will stand the rigid arch.* A dangling rope and a soaring vault are the **same curve**, mirrored through the ground.

The builders raising the great cathedrals don't have this. They work by inherited rule and stubborn intuition — by what hasn't fallen down yet. The catenary is the quiet reason their intuition is *right*. Understanding doesn't raise the cathedral. It tells you why the cathedral stands — and which ones won't.

*(Optional Wren tag, in town later):* "Funny — a thing that falls and a thing that rises, the same shape. Maybe that's all building is. Catch a falling line and turn it over."

## 7. Unlock & in-fiction beat
- **Mechanical:** unlocks the **Quarry** (begin producing Stone; small chance of Resonance Ore) and **Town Walls** (build → L1). Town Walls is flavor/morale now and the explicit **strategy-layer seed** — the first stone of the war to come.
- **Beat:** the wooden palisade comes down; the first stone wall goes up around the town. Herzog, gruff: "Huh. It holds." A visible, permanent change to the town silhouette — the player *sees* the age turning.

## 8. Educational integrity
- **True:** stone's compressive strength vastly exceeds its tensile strength (~order of magnitude); bending a beam puts its underside in tension; the arch carries load in compression along a thrust line; the keystone closes the ring and the structure is unstable until then (hence centering); arches exert horizontal thrust at the springings, resisted by abutments/buttresses; the pointed (Gothic) arch reduces horizontal thrust versus the semicircular arch, enabling taller, thinner, more open structures.
- **Era accuracy:** the game opens in **1157 AD**, squarely at the **birth of Gothic architecture** (the ambulatory of Saint-Denis, c. 1140–1144). The player is genuinely living through the pointed arch's arrival — this is not anachronism, it's the actual moment.
- **Honest simplification:** real thrust-line analysis (Hooke, Poleni, limit analysis) is centuries later; medieval masons built by geometric rules of thumb and trial, *not* by calculation. We say so. The **catenary "aha" (Robert Hooke, 1675)** is presented explicitly as knowledge the masons *didn't* have — the modern explanation of *why* their intuition worked. This framing is the rational-fiction point, not a historical error.
- **Misconception corrected:** "arches only push down" → no, they push *outward*; that outward thrust is the whole reason buttresses exist.
- **Sources to cite in-build:** Hooke's 1675 anagram ("Ut pendet continuum flexile…"); Gothic origins at Saint-Denis under Abbot Suger; standard masonry compression-vs-tension material properties.

## 9. Production notes
- The puzzle is a **scripted state machine, not a physics simulation** — three discrete beats with pre-baked "hold / crack / splay" outcomes triggered by the player's choices. Cheap to build, fully art-directable, and it can't get into ambiguous physics states. (Vibecode-friendly; do NOT reach for a rigid-body sim.)
- **Assets:** gateway frame; a set of flat-slab and wedge-voussoir pieces; keystone; centering (wooden frame); abutment/buttress block; a "wall section" load; crack decal; splay/collapse animation (can be simple). The cathedral/light "aha" moment can be a painterly 2D still (matches the static-screens decision) rather than 3D.
- **UI:** drag-place stones into snap slots; a "Load it" test button; profile toggle (round ↔ pointed) for the optional mastery beat; the explanation and "aha" use the standard tech-node reading panel.
- **Reusable pieces this node establishes:** the tech-node reading panel, the hint/auto-solve flow (Linnea, 1/run, full solve after N), the post-solve "aha" reveal screen, and the "town silhouette changes on unlock" hook. Build these generically — every node reuses them.

## 10. Open questions / tuning
- Knowledge cost (40) and auto-solve threshold (~5 runs) are placeholders — tune in playtest.
- Is the optional round/pointed mastery beat *delightful* or *fiddly*? Cut it if it muddies the core three beats.
- Does the catenary "aha" land for a non-technical player, or does it need a one-line visual (a chain photo flipping into an arch)? Likely yes — storyboard it.
- **The gate question for the whole project:** does this read as *delight* or *homework*? If homework, fix the format here (shorter explanation? puzzle first, explanation as reward?) before authoring node #2.
