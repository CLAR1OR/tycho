extends RefCounted
class_name SettingsCore
## Pure logic for the settings screen — "The quiet page" (SET1, human-picked 2026-07-09 via
## claude.ai/design). No engine singletons, no file IO — just the value math so it unit-tests
## headless. SettingsPanel owns pixels + the live-apply/persist wiring; this owns the numbers.
##
## Volumes are LINEAR 0..1 (the profile's storage form; Music converts to bus dB). The display
## number, the track notch fill, the drag mapping, the arrow nudge, and the window-mode fallback
## all live here.
##
## HUMAN: STEP + the row labels are PLACEHOLDERS (dial like FEEL numbers).

## Nudge step for the Left/Right arrows (HUMAN placeholder).
const STEP := 0.05

## The three volume rows, in display order. `key` is the profile settings key (linear 0..1);
## `label` is HUMAN-placeholder copy.
const VOLUME_ROWS: Array[Dictionary] = [
	{"key": "music_volume", "label": "Music"},
	{"key": "sfx_volume", "label": "Sound"},
	{"key": "ui_volume", "label": "Interface"},
]


## The big readout number for a volume: 0..100, clamped and rounded.
static func display_value(v: float) -> int:
	return int(round(clampf(v, 0.0, 1.0) * 100.0))


## How many of a track's notches are lit for a value (0..notch_count).
static func notches_lit(v: float, notch_count: int) -> int:
	return int(round(clampf(v, 0.0, 1.0) * float(notch_count)))


## Map a 0..1 track ratio (x position along the track) to a stored volume, clamped.
static func value_from_ratio(r: float) -> float:
	return clampf(r, 0.0, 1.0)


## Nudge a value by one STEP in `dir` (-1 / +1), clamped to 0..1.
static func nudge(v: float, dir: int) -> float:
	return clampf(v + float(dir) * STEP, 0.0, 1.0)


## The window mode stored in the profile, defensively normalized: anything that is not the
## literal "fullscreen" reads as "windowed" (so a missing/garbage value never crashes a boot).
static func window_mode(profile: Dictionary) -> String:
	var settings: Dictionary = profile.get("settings", {})
	var mode := str(settings.get("window_mode", "windowed"))
	return "fullscreen" if mode == "fullscreen" else "windowed"
