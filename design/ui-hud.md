# The in-run HUD — the "Slate" design

> Converged in a HUD design round on **claude.ai/design** (project "Tycho UI", the **HUD — C iterations** group) and human-picked 2026-07-07: the **Slate** visual language, the **C** direction (an echo shelf sitting over the HP bar), with the **C1 shelf married to a C2-style clean top row**. Built the same day as `RunHud`. Mockups + iteration history live in that claude.ai/design project; this doc is the converged spec.

The in-run HUD replaces the old debug-style stacked text Labels (`RoomInfo` / `HP` / `Hint` / `Echoes`). It is **one code-built `Control`** — `src/combat/run_hud.gd` (`RunHud`) — added by `combat_room.gd` onto its existing `$HUD` CanvasLayer, `mouse_filter = IGNORE`, filling the screen. It draws everything itself in `_draw` (rounded panels via a `StyleBoxFlat`, text via the three project fonts — see Typography) and polls the player/boss each frame; `combat_room.gd` + `game.gd` push the room/hint/wave/HP/boss state in through setters.

**Sizing gotcha (fixed 2026-07-07, same day):** anchors set in a Control's own `_ready` under a CanvasLayer never receive a layout pass — `size` stays (0,0) and everything anchored to `size.x`/`size.y` draws off-screen (only the fixed-coordinate info chip was visible). `RunHud._process` therefore syncs `size` to `get_viewport_rect().size` explicitly (also covers window resizes), and the smoke asserts the HUD spans the viewport so this can't regress.

**Pure logic is in `HudCore`** (`src/combat/hud_core.gd`, static, unit-tested `tests/core/hud_core_test.gd`): the info-chip segment rules (`chip_text`), the echo-shelf fold (`fold_echoes`), the monogram scheme (`monogram`), and the low-HP threshold (`is_low_hp`). `RunHud` owns only pixels.

## Components

1. **Info chip — top-left.** One semi-transparent rounded panel: `F2 · R3/5 ⚠ · Wave 2/3`. Segments: floor short-form always; `R{n}/{m}` for combat, `BOSS` / `Reprieve` for those kinds; a red `⚠` appended to the room segment only when the room was entered through a **peril** door; `Wave n/m` only in a multi-wave room while uncleared (wave progress lives here, NOT in the hint).
2. **Pickup strip — top-right, fading.** In-run pickups only: gold / resonance-ore / resonance-dust / knowledge-shards, colored text, no unicode icons. Hidden by default; on a tracked `EventBus.resource_changed` while `RunState.in_run()` it snaps to full alpha, holds ~3.0 s, fades over ~0.8 s. (The town economy readout on `game.gd`'s HUD is hidden during a run — pickups are this strip's job.)
3. **HP cluster — bottom-left.** A 340×26 slate bar, red fill, `72 / 100` overlaid. **Low-HP state** at ≤25% of max: border + number tint shift red and a soft red screen-edge **vignette** appears (cheap nested-frame `_draw`, no text warning).
4. **Echo shelf — directly above the HP bar.** The run's echo picks as 32×32 slate monogram tiles (initials, e.g. Tempest Stride → `TS`). Stackable repeats fold into one tile with a small gold count badge. Wraps to a second row (upward) after 8 tiles. Rebuilt on room spawn and after each echo pick from `RunState.echoes` (names via `EchoCore.defs()`). This replaced `game.gd`'s `$HUD/Echoes` text label.
5. **Ability slots — bottom-right.** Three 66×66 slate panels (RMB / Q / R) + a 46×46 dash pip (`SPC`). Slot face = an ability monogram (`P`/`B`/`Sn`/`Sh`/`Su`; empty = dim `–`); a key badge sits under each. On cooldown the face darkens and shows remaining seconds; ready = gold border. Read via `player.ability_slot_info()` (clean getter — no poking privates). **Dash reality:** the player has no separate dash-cooldown accessor beyond `_dash_cd`; the getter exposes it as `{cd_left, cd_total}`, so the pip sweeps during the dash cooldown and is otherwise ready.
6. **Contextual hint — bottom-center.** The exit-open / choose-a-door / wellspring / artifact strings, on a slate chip, hidden when empty. Wave progress no longer routes through the hint.
7. **Boss bar — top-center, boss rooms only.** A 520×18 purple bar under a `FLOOR N — BOSS` label; tracks the boss node's `current_hp()` / `max_hp` (passed in by `combat_room` at spawn). Hidden once the boss dies.

## Typography (added 2026-07-07, human-provided fonts)

Three OFL fonts under `assets/fonts/` (provenance: `assets/fonts/SOURCES.md`; the full family drops live outside the project in `temp/`, which carries a `.gdignore` so Godot doesn't import them all), each with one role:

- **Cinzel SemiBold — display.** The engraved-Roman-caps voice: ability-slot and echo-tile monograms, the `FLOOR N — BOSS` label. Cinzel renders lowercase as small caps, so `Sn`/`Sh`/`Su` stay distinct.
- **JetBrains Mono Medium — numbers/readouts.** The info chip, HP numerals, cooldown seconds, the pickup strip, key badges, stack-count badges. Mono digits don't shuffle as values tick, and it natively carries the chip's `⚠`.
- **EB Garamond Medium — prose.** The contextual hint line only (the one place the HUD speaks sentences). Garamond runs small for its px size, so `FS_HINT` sits larger than the old body size.

Each font is wrapped in a `FontVariation` with `fallbacks = [ThemeDB.fallback_font]` (`RunHud._with_fallback`) so a missing glyph never renders as a box, without mutating the shared imported resource. Held back for later UI (dialogue panel, codex, titles): Cormorant, Cormorant Garamond, IM Fell English.

**Vertical centering (fixed in the same pass):** the original `_text` helper sized text boxes by the font-size px and dropped by the full ascent — but a line box is `ascent + descent` tall (~20 px at fs 14), so text sat ~3 px low in every panel. The replacement `_text_in(rect, …)` centers via baseline math (`baseline = rect center + (ascent − descent)/2`) and panel heights use `font.get_height(fs)`.

## Constants / where to dial

**Every color, size, font, and timing is a placeholder.** The **shared** Slate style now lives ONE level up, in **`SlateHud`** (`src/core/slate_hud.gd` — see the Town HUD section below): the Slate palette + pickup/resource colours, the three project fonts, the shared font sizes (`FS_CHIP` / `FS_BODY` / `FS_HINT` / `FS_SMALL`) + `MARGIN`. The **run-specific** placeholders (HP bar, echo tiles, ability slots, boss bar, vignette, pickup hold/fade seconds, `FS_TILE`/`FS_SLOT`/`FS_HP`/`FS_BOSS`) stay grouped at the top of `run_hud.gd` under its "Style" banner (palette as `Color(r/255,…)` with the hex in the comment). Dial them like FEEL numbers — they are not `# FEEL:`-tagged (they carry no combat feel), but the same "human owns the values" spirit applies. Semantic rules (segment order, fold, threshold) live in `HudCore` and are covered by tests, so changing wording/thresholds is a one-line edit with a test to match.

## Town HUD (decided + built 2026-07-07)

> Converged in a **Town HUD** design round on claude.ai/design (project "Tycho UI", the "Town HUD" group) and human-picked 2026-07-07: the **T1 "Slate strip"** direction, the **overnight production toast** from the states card, plus a human-requested addition — **a small semi-transparent "+n/d" under each resource** showing its projected per-day generation.

The town HUD replaces the old plain `DayInfo` / `FoodStatus` / `Hint` Labels on `town.tscn` **and** `game.gd`'s stacked `$HUD/Resources` readout. It is **one code-built `Control`** — `src/town/town_hud.gd` (`TownHud`) — added by `town.gd` in `_ready` onto the town's `$HUD` CanvasLayer. It reuses the in-run HUD's **exact** Slate visual language via a shared base class (below), draws everything in `_draw`, and polls the Ledger each frame (town is cheap).

**Shared base — `SlateHud`** (`src/core/slate_hud.gd`, `class_name SlateHud extends Control`): the visual language RunHud and TownHud both need, so the human dials shared style in ONE place. It owns the Slate palette + pickup/resource colours, the three fonts (`_with_fallback`), the shared `FS_*`/`MARGIN`, the `_ready` common setup (FULL_RECT anchors + `MOUSE_FILTER_IGNORE` + build the three `FontVariation`s), the `_sync_viewport_size()` helper (the CanvasLayer-under-`_ready` layout quirk — subclasses call it from their own `_process`), and the draw plumbing (`_panel` / `_text_w` / `_text_in`). `RunHud` and `TownHud` both `extends SlateHud`, call `super._ready()` first, and add only their own state + pixels. Pure zero-render lift for RunHud (no behavior change).

**Four components:**

1. **Day chip — top-left.** `Day 4 · Well-Fed +25%` (gold status span) / `Day 4 · Short on food` (dim status span) / just `Day 1` before any day has ticked. NEVER red — red is reserved for player danger. The `+25%` literal derives from `TownCore.WELL_FED_BONUS` so the two can't drift.
2. **Resource strip — top-right, TWO panels (split 2026-07-07, human decision).** The seven resources (Ledger ids `gold`, `stone`, `food`, `knowledge`, `knowledge-shards`, `resonance-ore`, `resonance-dust`) are partitioned into a **town-economy panel** (resources a building can generate on a day tick) and a **run-pickups panel** (only ever brought home from runs), each under a tiny dim Cinzel header (`TOWN` / `RUN`, placeholder copy). The split is **derived from the building defs** (`TownHudCore.producible_resources` — `produce` effects + the `knowledge` kind), so it self-maintains: today town = stone/food/knowledge and run = gold/shards/ore/dust (exactly the in-run pickup-strip set — the run panel holds the top-right corner so the same resources sit in the same place in both scenes), and a future gold-producing Market would migrate gold to the town panel by itself. Per column: value (mono, per-resource colour) then a small dim label; amounts poll `Ledger.get_amount` per frame. Three new resource colours (stone `#b5ada0`, food `#a4d97a`, knowledge `#9fdcff`) are TownHud consts; gold/shards/ore/dust reuse the shared pickup colours.
3. **Projections — below the strip, outside the panel.** Under each column, centred, a small ~0.55-alpha `+n/d` showing that resource's projected **net** per-day generation, from `TownHudCore.day_deltas(TownCore.tick(…))`. **The rule:** derived only from the tick RESULT — every `produced` entry is a `+`, and **food nets its upkeep** (produced food MINUS `food_consumed`, so a farmless town shows food going negative). Zero → nothing drawn. Recomputed on `resource_changed` **and** `building_built` (a build's resource-spend fires before the building lands in state), never per frame.
4. **Hint chip — bottom-center.** `WASD move · E interact · the portal starts a run` (Garamond, placeholder copy — `HINT_TEXT`).

**The overnight toast — top-center, fading.** `game.gd` stashes each day tick's result (`_last_day_tick`, in-memory) and hands it to `town.show_day_toast(tick)` on the run-end return; the Forfeit path reaches town WITHOUT setting it, so it never toasts (Forfeit ticks no day). A slate panel with a small Cinzel `OVERNIGHT` header over one row of `TownHudCore.toast_segments`: produced resources first (`+5 gold`, display order gold/stone/food/knowledge then extras alphabetically, short labels for shards/ore/dust), then `-5 eaten` only when Food was consumed (drawn in the food colour), then `Well-Fed` only when fed (gold). Lifecycle mirrors RunHud's pickup strip: snap to full alpha, hold `TOAST_HOLD_S` (4.0 s), fade over `TOAST_FADE_S` (1.0 s). `TownHud` is `PROCESS_MODE_ALWAYS` so the toast fades (and `size` syncs) even behind a town-entry cutscene.

**Pure `TownHudCore`** (`src/town/town_hud_core.gd`, static, unit-tested `tests/core/town_hud_core_test.gd`) owns the day-chip text (`day_chip_text`), the per-resource day deltas (`day_deltas` — food nets upkeep), the projection string (`projection_text` → `+3/d` / `-2/d` / `+3.8/d` / `""`), and the toast segment list (`toast_segments`). `TownHud` owns only pixels.

**HUMAN dial placeholders:** `HINT_TEXT`, the toast copy + `TOAST_HOLD_S`/`TOAST_FADE_S`, `PROJECTION_ALPHA`, every `FS_*`, and the three new resource colours are TownHud consts; the shared palette/fonts/sizes are in `SlateHud`. Dial like FEEL numbers.

## Panels & the pause menu — Slate (2026-07-07)

> Human directive: "continue with the pause/panel restyle to slate. pause menu should be fullscreen." Cashes in the deferred "pause / panel restyle" item below.

The six Control-tree UIs that were plain default-gray are now in the Slate language. They do NOT draw in `_draw` like the HUDs — they are node trees (Labels/Buttons/PanelContainers), so they take a shared **Godot `Theme`** instead.

**`SlateTheme`** (`src/core/slate_theme.gd`, `class_name SlateTheme extends RefCounted`) — a static factory + cache: `SlateTheme.get_theme()` builds ONE `Theme` and caches it in a static var. It reads every colour and font **off `SlateHud`'s constants** (`COL_SLATE_BG` / `COL_SLATE_BORDER` / `COL_TEXT` / `COL_READY` / `COL_KEY_TEXT` / `COL_CHIP_BORDER`, and the three font files via `SlateHud._with_fallback`) so the Slate palette + fonts stay ONE dial source — the human's SlateHud tweaks propagate to both the `_draw` HUDs and these panels. Only the SIZES / MARGINS / RADII are `SlateTheme`'s own placeholder consts (`FS_DEFAULT`/`FS_TITLE`/`FS_NUM`/`FS_MENU_BUTTON`, `BTN_RADIUS`/`PANEL_RADIUS`, button content margins). It styles the base **Button** (five slate styleboxes: normal / hover→border lightens to `COL_TEXT` / pressed→bg darkened / focus→gold `COL_READY` border / disabled→dim), **Panel/PanelContainer** (slate `panel` box, ~0.97 alpha), and **Label** (`COL_TEXT`), plus four **type variations** (applied per-node via `theme_type_variation`): `TitleLabel` (Cinzel caps, panel titles), `NumLabel` (mono, purely-numeric readouts), `DimLabel` (Garamond in the dim key colour, hints/footnotes/statuses), `MenuButton` (Button in Cinzel with roomier margins, the pause menu's big buttons).

Each UI sets `theme = SlateTheme.get_theme()` on its root in `_ready`/`play`/`present` (it inherits to every child), then uses `theme_type_variation` in place of the old ad-hoc `add_theme_font_size_override` / `modulate` fiddling — the diffs made the panels SIMPLER. **Six UIs covered:** `PauseMenu`, `ForgePanel`, `TechPanel`, `EtchingsPanel`, `DialoguePanel`, `EchoOfferPanel` (the in-run pick-1-of-3 — included so no default-gray UI remains). **RESTYLE ONLY** — every public method, signal, flow, pause semantic, guard, and game-copy string is byte-identical; the smoke drives them all unchanged.

**Per-UI notes:** DialoguePanel keeps its speaker name gold-tinted (TitleLabel + a local down-size) and its spoken line at a larger local Garamond size (~19); its advance hint is a `DimLabel`. TechPanel/EtchingsPanel dim/locked/"researched" lines became `DimLabel`; the quiz's red wrong-answer feedback keeps its local semantic colour. EchoOfferPanel's cards are slate-styled Buttons (kept as single Buttons so pick semantics are untouched).

**The pause menu is now FULLSCREEN.** `PauseMenu` changed base from `PanelContainer` to `Control`: a near-opaque backdrop (`#0c0b10` @ 0.88, a const) over the whole screen with a centred column — Cinzel `Paused` title, the existing Resume / Forfeit / Quit buttons as `MenuButton` variations (min width 320), and the gate-refusal status line as a `DimLabel`. **CanvasLayer geometry quirk** (the RunHud bug): anchors set in this Control's own `_ready` under game.gd's `$HUD` CanvasLayer get no layout pass, so `size` is synced to `get_viewport_rect().size` in `open()` AND each frame in `_process` while visible (it is PROCESS_MODE_ALWAYS). The smoke opens it and asserts the root spans the viewport. All flow (tree pause/unpause, the guards, inert-at-slot-select, the Hades gate) is untouched.

**Stays un-themed (out of scope):** the slot-select screen, the F1 tuning panel, the F2 cheat panel (debug tools), and the arch puzzle (`puzzle_arch.gd` draws its own diagram).

**HUMAN dial placeholders:** `SlateTheme`'s sizes / margins / radii and the pause backdrop colour are placeholders; the shared palette/fonts live in `SlateHud`. Dial like FEEL numbers.

## Research screen — Star chart (R1) (decided + built 2026-07-08)

> Human picked **R1 — Star chart** on claude.ai/design (project "Tycho UI", the "Research Screen" group): the tech tree drawn as Sophia's constellation map — the strongest thematic fit (Tycho Brahe charted stars; Sophia charts what the resonance knows). The old LIST + NODE screens merge into a chart; the solve flow (READ → QUIZ/PUZZLE → LOCKED/AHA) keeps its scrolling reading page with two small Slate touches.

`TechPanel` (`src/learning/tech_panel.gd`) is now a fullscreen `Control` with two child roots toggled by screen: the **chart** (`TechChart`, `src/learning/tech_chart.gd`, custom-drawn in `_draw` like the HUDs) plus the header/dock/hint/close, and the **reading page** (the original margin→scroll→rows stack) for the post-invest solve flow.

**Components (chart screen):**
- **Header** — top-left Cinzel title `Sophia's Desk — Research` (byte-identical) + a dim Garamond subtitle (placeholder UI copy). Top-right a **carry chip** (mono knowledge in the knowledge colour + shards in the shards colour, with dim labels) and the **turn-in button** (shipped `Turn in %d Knowledge Shards → %d Knowledge`, disabled at 0, same Sfx + `TechState.turn_in_shards`).
- **Constellation** — each node is a star at a `chart_pos`; prereq edges are lines between stars. Clicking a researchable star selects it → `select_node` (→ `TechState.set_active`, unchanged) and fills the dock; a dashed ring marks the selection. Locked / researched stars are inert to clicks.
- **Detail dock** (right) — Slate PanelContainer: node name (Cinzel), meta (tier caps gold for KEY · AGE n · puzzle kind · 🧠), a progress bar + `n / cost knowledge` (mono, knowledge colour), `Requires:` (✓ when researched) and `Unlocks:` (building ids resolved to display names), then the action: ready → the shipped `It's ready…` line + `Read & solve`; else `Invest everything you carry`. No flavor quote (dialogue is human territory).
- **Age-II tease** — a few unnamed dim dots toward the right edge + a right-edge darkening fade + a dim caps label (decorative constants, no data).
- **Starfield dust** — a fixed const array of faint dots (deterministic; never re-randomized per frame/open).
- **Hint chip** (bottom-center) + **Close** (bottom-left).

**State grammar** (pure `TechChartCore`, `src/learning/tech_chart_core.gd`, unit-tested — layered on the existing TechCore predicates):
- `node_state` precedence: **researched** (gold disc) > **locked** (prereq unmet — dim dot, `needs <prereq>`) > **ready** (funded — gold ring + glow, the screen's one call-to-action) > **active** (== `tech.active`, not ready — cyan ring + a progress arc, `n/cost · Sophia's focus`) > **available** (slate outline, cost meta).
- Quiz-lock is ORTHOGONAL: a *ready* node whose quiz is locked shows its meta in the peril red (`ask again after a run`) — the ONLY red on the screen.
- `edge_kind(prereq_state, dependent_state)`: **lit** (prereq researched — gold line) > **dim** (dependent still locked — dashed) > **open** (both ends ≥ available — solid slate).
- `chart_pos(def, id)`: the def's authored `chart_pos` when valid, else a DETERMINISTIC in-band fallback from the id (x 0.1–0.55, y 0.15–0.8) so an unpositioned node never crashes or overlaps the dock; `has_chart_pos` lets the panel warn on fallback.

**`chart_pos` authoring rule:** optional `"chart_pos": [x, y]` normalized 0..1 in each `data/tech/<id>.json` (spec field on the `tech` domain). Author it to place the star on the map; omit it and the node still renders at a stable fallback. Placeholders today: arithmetic `[0.18, 0.58]`, masonry `[0.34, 0.46]`.

**Colour source:** the stone/food/knowledge resource colours were lifted UP from `TownHud` to `SlateHud` (next to gold/ore/dust/shards) so the chart reads the knowledge colour off the ONE dial source.

**Solve-flow touches (restyle only):** the AHA title (`✦ <name>`) renders in gold (`COL_READY`); everything else on READ/QUIZ/LOCKED/AHA is byte-identical.

**Frozen API** (the smoke drives it): `open / close / select_node / invest_all / turn_in_shards / begin_read / begin_quiz / answer / begin_puzzle / puzzle_node / finish / on_locked_screen`, plus a `star_state(id)` debug getter.

**HUMAN dial placeholders:** all chart visual numbers (star radii per state, glow/arc/ring widths, dust positions/alpha, right-fade width, hit radius, dock width/bar height) live at the top of `tech_chart.gd` + `tech_panel.gd` under a placeholder block; the new UI copy (subtitle, carry/dock labels, hint, age-II label, quiz-lock meta) is placeholder too. The shared palette/fonts live in `SlateHud`. Dial like FEEL numbers.

## Deferred (document-don't-build)

- **Echo tile tooltips / a hold-Tab detail view** (full echo names + descriptions on demand) — the shelf is monograms only for now.
- **Ability cooldown pie-wedge** — v1 uses a flat face-darken + seconds; a radial sweep is a later flourish.
- **Painterly art pass** — the HUD is placeholder primitives (the fonts are real as of 2026-07-07); the eventual painterly treatment rides the general art pass.
