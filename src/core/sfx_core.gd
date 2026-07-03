extends RefCounted
class_name SfxCore
## Pure SFX-map logic (design/audio.md): resolve a sound id against the
## data/audio/sfx-map.json map into concrete playback parameters. No engine
## singletons, no players — the Sfx autoload owns those. Volumes here are
## placeholder mix values; the feel-critical subset is human-tuned like
## `# FEEL:` numbers (swap file / dial volume in the JSON, no code).

const DEFAULT_BUS := "SFX"

## Pitch jitter is the single cheapest anti-repetition trick (audio.md):
## every play gets pitch_scale in [1 - jitter, 1 + jitter]. `rand01` is
## injected so this stays deterministic under test.
static func resolve(sfx_map: Dictionary, id: String, rand01: float) -> Dictionary:
	if not sfx_map.has(id):
		return {}
	var entry: Dictionary = sfx_map[id]
	var jitter := float(entry.get("pitch_jitter", 0.0))
	return {
		"file": str(entry.get("file", "")),
		"volume_db": float(entry.get("volume_db", 0.0)),
		"pitch_scale": 1.0 + jitter * (2.0 * clampf(rand01, 0.0, 1.0) - 1.0),
		"bus": str(entry.get("bus", DEFAULT_BUS)),
	}


## Every mapped file must exist on disk — the loud early check audio.md asks
## for (a renamed wav should fail a test, not silently mute a sound).
static func missing_files(sfx_map: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in sfx_map:
		var file := str((sfx_map[id] as Dictionary).get("file", ""))
		if not ResourceLoader.exists(file):
			out.append("%s -> %s" % [id, file])
	return out
