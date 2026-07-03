extends "res://tests/test_suite.gd"
## Unit tests for SfxCore + the sfx-map data domain (design/audio.md): resolve
## math, map validity, and the "every mapped file exists and loads" check the
## audio spec demands — a renamed wav fails HERE, not as a silent mute in-game.

## The feel-critical subset (audio.md § SFX) — these ids must stay mapped;
## they are human-tuned handles like `# FEEL:` numbers.
const FEEL_CRITICAL: Array[String] = [
	"hit-1", "hit-2", "hit-finisher", "kill", "player-hurt", "dash",
	"arrow-loose", "arrow-impact", "pickup", "echo-pick", "door-open",
]

const MAP := {
	"thud": {"file": "res://x/thud.wav", "volume_db": -6.0, "pitch_jitter": 0.1},
	"click": {"file": "res://x/click.wav", "bus": "UI"},
}


func test_resolve_math() -> void:
	var mid := SfxCore.resolve(MAP, "thud", 0.5)
	check_eq(mid["file"], "res://x/thud.wav", "file passes through")
	check_eq(mid["volume_db"], -6.0, "volume passes through")
	check_eq(mid["pitch_scale"], 1.0, "rand 0.5 = no jitter")
	check_eq(mid["bus"], "SFX", "bus defaults to SFX")
	check_eq(SfxCore.resolve(MAP, "thud", 0.0)["pitch_scale"], 0.9, "rand 0 = full jitter down")
	check_eq(SfxCore.resolve(MAP, "thud", 1.0)["pitch_scale"], 1.1, "rand 1 = full jitter up")


func test_resolve_defaults_and_unknown() -> void:
	var c := SfxCore.resolve(MAP, "click", 0.0)
	check_eq(c["volume_db"], 0.0, "volume defaults to 0 dB")
	check_eq(c["pitch_scale"], 1.0, "jitter defaults to 0")
	check_eq(c["bus"], "UI", "explicit bus wins")
	check(SfxCore.resolve(MAP, "nope", 0.5).is_empty(), "unknown id resolves empty")


func test_sfx_map_loads_and_covers_feel_critical() -> void:
	var sfx_map := DataLoader.load_sfx_map()
	check(sfx_map.size() >= FEEL_CRITICAL.size(), "map has entries (got %d)" % sfx_map.size())
	for id in FEEL_CRITICAL:
		check(sfx_map.has(id), "feel-critical sound mapped: " + id)


func test_every_mapped_file_exists_and_loads() -> void:
	var sfx_map := DataLoader.load_sfx_map()
	var missing := SfxCore.missing_files(sfx_map)
	check_eq(missing.size(), 0, "no mapped file is missing: %s" % ", ".join(missing))
	for id: String in sfx_map:
		var stream := load(str((sfx_map[id] as Dictionary).get("file", ""))) as AudioStream
		check(stream != null, "\"%s\" loads as an AudioStream" % id)
