# Audio provenance (design/audio.md licensing rule: track every file from day one)

| Path | Source | License | Notes |
| --- | --- | --- | --- |
| `sfx/*.wav` (15 files, 2026-07-04) | Agent-synthesized (deterministic script; jfxr-register synth per audio.md's one-off path) | CC0 / project-owned | **Placeholders.** Feel-critical subset expects human tuning or replacement from Kenney packs; swapping = editing `data/audio/sfx-map.json`, no code. |

## Pending
- Kenney CC0 packs → drop into `sfx/raw/`, add a row per pack here (audio.md § SFX, human step).
- Music placeholders (FreePD/CC0) land with the `Music` autoload chunk.

## Rules (from design/audio.md)
- CC0 preferred; CC-BY OK with a `CREDITS.md` here; nothing NC/SA; AI-gen per service terms.
- Every file added to `assets/audio/` gets a row in this table **in the same commit**.
