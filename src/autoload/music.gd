extends Node
## Thin Music autoload (design/audio.md § Music, phase 1): two AudioStreamPlayers
## on the Music bus, equal-power crossfaded (~1 s) on scene changes. Content is
## data — data/audio/music-map.json maps id -> {file, volume_db} through pure
## MusicCore, so swapping a track or dialing its level is a JSON row, not code.
## Call sites: Music.play("town") / Music.play("dungeon") / Music.play("boss") /
## Music.play("title"); calling with the already-current id is a no-op.
##
## PROCESS_MODE_ALWAYS: the pause-panel UIs (echo offer, tech, forge) must not
## silence the score — same rationale as Sfx. The crossfade is driven per-frame
## in _process (not a Tween — Tweens pause with the tree and mis-time here).

const CROSSFADE_SECS := 1.0
const SILENCE_DB := -80.0   # the fading-out player's floor before it stops

var _map: Dictionary = {}
var _streams: Dictionary = {}   # file -> AudioStream, loaded once at boot
var _players: Array[AudioStreamPlayer] = []   # exactly 2
var _ceil: Array[float] = [0.0, 0.0]          # each player's mapped volume_db ceiling
var _active: int = 0            # index of the foreground (fading-in) player
var _out: int = 0               # index of the fading-out player during a crossfade
var _fading: bool = false
var _fade_t: float = 0.0        # 0..1 across CROSSFADE_SECS
var _warned: Dictionary = {}    # unknown-id spam guard

## The track currently playing / faded to (tests + smoke read this).
var current_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map = DataLoader.load_music_map()
	for id: String in _map:
		var file := str((_map[id] as Dictionary).get("file", ""))
		if not _streams.has(file):
			var stream := load(file) as AudioStream
			if stream == null:
				push_error("Music: \"%s\" maps to unloadable stream %s" % [id, file])
				continue
			_streams[file] = stream
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = SILENCE_DB
		add_child(p)
		_players.append(p)
	_apply_settings()


# Known shutdown notice (same as Sfx): a track still mid-play at quit prints
# "N resources still in use at exit" — AudioServer release order, not a leak.


## Apply the profile's linear audio volumes (0..1) to the Music/SFX/UI buses.
## Data-only per audio.md — no settings UI yet; a slider screen calls this later.
func _apply_settings() -> void:
	var settings: Dictionary = SaveManager.profile.get("settings", {})
	for bus_name: String in ["Music", "SFX", "UI"]:
		var key := bus_name.to_lower() + "_volume"
		var v := float(settings.get(key, 1.0))
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0, 1.0)))


## Crossfade to `id` over ~CROSSFADE_SECS. No-op if it is already current; unknown
## / unloadable id warns once and keeps the current track (Sfx's pattern).
func play(id: String) -> void:
	if id == current_id:
		return
	var params := MusicCore.resolve(_map, id)
	if params.is_empty() or not _streams.has(params["file"]):
		if not _warned.has(id):
			_warned[id] = true
			push_error("Music: no playable track \"%s\" (data/audio/music-map.json)" % id)
		return
	# Foreground and background swap: the previous foreground fades OUT, the other
	# player takes the new stream and fades IN. (On the first play the old player
	# is silent already, so the fade-out is a harmless no-op.)
	_out = _active
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stream = _streams[params["file"]]
	_ceil[_active] = float(params["volume_db"])
	incoming.volume_db = SILENCE_DB
	incoming.play()
	current_id = id
	_fade_t = 0.0
	_fading = true


func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_t += delta / CROSSFADE_SECS
	var t := clampf(_fade_t, 0.0, 1.0)
	var g := MusicCore.crossfade_gain(t)
	# Linear crossfade gain rides UNDER each track's mapped ceiling (dB adds).
	_players[_active].volume_db = _ceil[_active] + linear_to_db(maxf(float(g["fade_in"]), 0.0001))
	_players[_out].volume_db = _ceil[_out] + linear_to_db(maxf(float(g["fade_out"]), 0.0001))
	if _fade_t >= 1.0:
		_fading = false
		_players[_active].volume_db = _ceil[_active]   # snap to the exact ceiling
		if _out != _active:
			_players[_out].stop()
