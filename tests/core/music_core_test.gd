extends "res://tests/test_suite.gd"
## Unit tests for MusicCore + the music-map data domain (design/audio.md § Music):
## resolve, the equal-power crossfade curve, map validity, and the "every mapped
## track exists, loads, AND loops" check — a track with loop=false in its .import
## would silence between plays, so this pins the .import state too.

## The tracks the game hooks demand (game.gd): title/town/dungeon/boss must stay
## mapped — dropping one breaks a scene's music silently.
const REQUIRED: Array[String] = ["title", "town", "dungeon", "boss"]

const MAP := {
	"town": {"file": "res://x/town.ogg", "volume_db": -3.0},
	"boss": {"file": "res://x/boss.ogg"},
}


func test_resolve_and_unknown() -> void:
	var t := MusicCore.resolve(MAP, "town")
	check_eq(t["file"], "res://x/town.ogg", "file passes through")
	check_eq(t["volume_db"], -3.0, "volume passes through")
	check_eq(MusicCore.resolve(MAP, "boss")["volume_db"], 0.0, "volume defaults to 0 dB")
	check(MusicCore.resolve(MAP, "nope").is_empty(), "unknown id resolves empty")


func test_crossfade_endpoints_and_midpoint() -> void:
	var a := MusicCore.crossfade_gain(0.0)
	check_eq(a["fade_in"], 0.0, "t=0: incoming silent")
	check_eq(a["fade_out"], 1.0, "t=0: outgoing full")
	var b := MusicCore.crossfade_gain(1.0)
	check_eq(b["fade_in"], 1.0, "t=1: incoming full")
	check_eq(b["fade_out"], 0.0, "t=1: outgoing silent")
	var m := MusicCore.crossfade_gain(0.5)
	check_eq(m["fade_in"], 0.70710678, "t=0.5: equal-power (~0.7071 in)")
	check_eq(m["fade_out"], 0.70710678, "t=0.5: equal-power (~0.7071 out)")


func test_crossfade_clamps() -> void:
	var lo := MusicCore.crossfade_gain(-1.0)
	check_eq(lo["fade_in"], 0.0, "t<0 clamps to 0")
	check_eq(lo["fade_out"], 1.0, "t<0 clamps: outgoing full")
	var hi := MusicCore.crossfade_gain(2.0)
	check_eq(hi["fade_in"], 1.0, "t>1 clamps to 1")
	check_eq(hi["fade_out"], 0.0, "t>1 clamps: outgoing silent")


func test_music_map_loads_and_covers_required() -> void:
	var music_map := DataLoader.load_music_map()
	check(music_map.size() >= REQUIRED.size(), "map has entries (got %d)" % music_map.size())
	for id in REQUIRED:
		check(music_map.has(id), "required track mapped: " + id)


func test_every_mapped_file_exists_loads_and_loops() -> void:
	var music_map := DataLoader.load_music_map()
	var missing := MusicCore.missing_files(music_map)
	check_eq(missing.size(), 0, "no mapped track is missing: %s" % ", ".join(missing))
	for id: String in music_map:
		var stream := load(str((music_map[id] as Dictionary).get("file", ""))) as AudioStream
		check(stream != null, "\"%s\" loads as an AudioStream" % id)
		if stream is AudioStreamOggVorbis:
			check((stream as AudioStreamOggVorbis).loop, "\"%s\" imports with loop=true" % id)
