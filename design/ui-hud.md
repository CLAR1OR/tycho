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

**Every color, size, font, and timing is a placeholder** grouped at the top of `run_hud.gd` under the "Style" banner (palette as `Color(r/255,…)` with the hex in the comment, bar/tile/slot sizes, the font files + per-role `FS_*` sizes, the vignette shape, the pickup hold/fade seconds). Dial them like FEEL numbers — they are not `# FEEL:`-tagged (they carry no combat feel), but the same "human owns the values" spirit applies. Semantic rules (segment order, fold, threshold) live in `HudCore` and are covered by tests, so changing wording/thresholds is a one-line edit with a test to match.

## Deferred (document-don't-build)

- **Echo tile tooltips / a hold-Tab detail view** (full echo names + descriptions on demand) — the shelf is monograms only for now.
- **Town HUD restyle** — `game.gd`'s `$HUD/Resources` economy readout stays as-is (just hidden in-run); restyling it to the slate language is a separate chunk.
- **Pause / panel restyle to the slate language** — the ESC menu, forge, tech, etchings, dialogue panels keep their current look; unifying them under Slate is future polish.
- **Ability cooldown pie-wedge** — v1 uses a flat face-darken + seconds; a radial sweep is a later flourish.
- **Painterly art pass** — the HUD is placeholder primitives (the fonts are real as of 2026-07-07); the eventual painterly treatment rides the general art pass.
