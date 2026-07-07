# Font provenance

All fonts are SIL Open Font License 1.1 (license copies beside each file).
Source drops live in `temp/fonts/` (full families incl. variable-weight files);
only the weights actually used ship here. Swapping a font = replacing the .ttf
and (if the name changes) the `FONT_*` preload path in its consumer.

| File | Family / weight | Used for | Consumer |
|---|---|---|---|
| `Cinzel-SemiBold.ttf` | Cinzel SemiBold (Natanael Gama) | Display: ability/echo monograms, boss-bar label | `src/combat/run_hud.gd` |
| `EBGaramond-Medium.ttf` | EB Garamond Medium (Georg Duffner / Octavio Pardo) | Prose: the contextual hint line | `src/combat/run_hud.gd` |
| `JetBrainsMono-Medium.ttf` | JetBrains Mono Medium (JetBrains) | Numbers/readouts: info chip, HP, cooldowns, pickups, key badges | `src/combat/run_hud.gd` |

Held back (in `temp/fonts/`, no HUD job yet — candidates for the dialogue panel,
codex, and title screens): Cormorant, Cormorant Garamond, EB Garamond italics,
IM Fell English (the "aliens' wikipedia" / codex look), other weights of the three above.
