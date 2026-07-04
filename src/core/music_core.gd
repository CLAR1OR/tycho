extends RefCounted
class_name MusicCore
## Pure music-map logic (design/audio.md § Music): resolve a track id against the
## data/audio/music-map.json map into concrete playback params, and the pure
## equal-power crossfade curve. No engine singletons, no players — the Music
## autoload owns those. Volumes here are placeholder mix values (human dials the
## music-map row, no code), the mapped volume_db is the fade ceiling per track.

## id -> {file, volume_db} or {} for unknown. Mirrors SfxCore.resolve.
static func resolve(music_map: Dictionary, id: String) -> Dictionary:
	if not music_map.has(id):
		return {}
	var entry: Dictionary = music_map[id]
	return {
		"file": str(entry.get("file", "")),
		"volume_db": float(entry.get("volume_db", 0.0)),
	}


## Equal-power crossfade gains for t in 0..1: a quarter-cycle sin/cos so the two
## tracks sum to constant PERCEIVED loudness through the fade (a linear crossfade
## dips in the middle). t=0 → {in:0, out:1}; t=1 → {in:1, out:0}; t=0.5 → both
## ≈ 0.7071. Returns LINEAR gains (the caller converts to dB).
static func crossfade_gain(t: float) -> Dictionary:
	var x := clampf(t, 0.0, 1.0)
	return {
		"fade_in": sin(x * PI * 0.5),
		"fade_out": cos(x * PI * 0.5),
	}


## Every mapped file must exist on disk — the loud early check audio.md asks for
## (a renamed track fails a test, not silently muting the score).
static func missing_files(music_map: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in music_map:
		var file := str((music_map[id] as Dictionary).get("file", ""))
		if not ResourceLoader.exists(file):
			out.append("%s -> %s" % [id, file])
	return out
