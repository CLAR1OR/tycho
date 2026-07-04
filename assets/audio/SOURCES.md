# Audio provenance (design/audio.md licensing rule: track every file from day one)

| Path | Source | License | Notes |
| --- | --- | --- | --- |
| `sfx/*.wav` (15 files, 2026-07-04) | Agent-synthesized (deterministic script; jfxr-register synth per audio.md's one-off path) | CC0 / project-owned | **Placeholders.** Feel-critical subset expects human tuning or replacement from Kenney packs; swapping = editing `data/audio/sfx-map.json`, no code. |
| `music/{title,town,dungeon,boss}.ogg` (4 files, 2026-07-04) | Agent-synthesized (deterministic pure-python additive synth → ffmpeg libvorbis q4; seamless-looping by construction). **Deviation from audio.md's FreePD placeholder path** — synthesized instead, same rationale as the SFX (zero legal risk, deterministic, good enough for mood/loop-point testing). | CC0 / project-owned | **Placeholders.** Real tracks = AI-gen (Suno/Udio), human-curated. Swapping one = editing its `data/audio/music-map.json` row, no code. Loops via `loop=true` in each `.ogg.import`. |

## Pending
- Kenney CC0 packs → drop into `sfx/raw/`, add a row per pack here (audio.md § SFX, human step).
- Real music: Suno/Udio taste-curated tracks replace the synthesized placeholders (audio.md § Music, human step).

## Rules (from design/audio.md)
- CC0 preferred; CC-BY OK with a `CREDITS.md` here; nothing NC/SA; AI-gen per service terms.
- Every file added to `assets/audio/` gets a row in this table **in the same commit**.
