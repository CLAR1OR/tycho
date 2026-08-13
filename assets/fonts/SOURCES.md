# Font provenance

All fonts are SIL Open Font License 1.1 (license copies beside each file).
Source drops live in `temp/fonts/` (full families incl. variable-weight files);
only the weights actually used ship here. Swapping a font = replacing the .ttf
and (if the name changes) the `FONT_*` preload path in its consumer.

| File | Family / weight | Used for | Consumer |
|---|---|---|---|
| `Cinzel-SemiBold.ttf` | Cinzel SemiBold (Natanael Gama) | Display: screen titles, ability/echo monograms, boss-bar label | `src/core/ember_hud.gd` |
| `EBGaramond-Medium.ttf` | EB Garamond Medium (Georg Duffner / Octavio Pardo) | Prose: descriptions, flavour, dialogue, subtitles, the in-run hint | `src/core/ember_hud.gd` |
| `JetBrainsMono-Medium.ttf` | JetBrains Mono Medium (JetBrains) | Numbers/readouts: HP, cooldowns, resources, stat values, costs | `src/core/ember_hud.gd` |
| `AlegreyaSans-Regular.ttf` | Alegreya Sans Regular (Huerta Tipográfica) | **UI voice**: labels, list rows, buttons, prompts, objective labels | `src/core/ember_hud.gd` |
| `AlegreyaSans-Medium.ttf` | Alegreya Sans Medium (Huerta Tipográfica) | UI voice, small tracked caps (section heads) — Regular goes thin there | `src/core/ember_hud.gd` |

Roles are declared as `FONT_*_FILE` consts in `src/core/ember_hud.gd` (the one dial
source; `EmberTheme` and `SlateTheme` both read them from there). Slate's own copies live
in `src/core/slate_hud.gd` until Slate is retired.

**Alegreya Sans (added 2026-08-13)** closes the gap Ember shipped with: both reference
anchors are set in a humanist sans the project did not own, so EB Garamond was standing in
for interface labels. It is humanist rather than geometric and comes from the same
old-style calligraphic roots as EB Garamond, so the two read as one system — a neutral UI
sans (Inter, Source Sans) would be equally legible and would look like a productivity app
over a painted medieval world. Downloaded from `github.com/google/fonts/ofl/alegreyasans`.

Held back (in `temp/fonts/`, no job yet — candidates for the codex and title screens):
Cormorant, Cormorant Garamond, EB Garamond italics, IM Fell English (the "aliens'
wikipedia" / codex look), Alegreya Sans Light, other weights of the above.
