extends Node
## Thin SFX autoload (design/audio.md § integration): a small pool of
## AudioStreamPlayer3D (positioned combat sounds) + AudioStreamPlayer (UI/2D),
## fed by data/audio/sfx-map.json through pure SfxCore — swapping a sound or
## dialing the mix is data, never code. Call sites: Sfx.play("hit-1", world_pos)
## for positioned sounds, Sfx.play("ui-click") for flat ones.
##
## Cross-domain sounds hook EventBus HERE (pickup chirp on run-drop resource
## gains, the boss-kill boom) so gameplay code never calls audio for
## bookkeeping-shaped events — conventions rule 1.
##
## PROCESS_MODE_ALWAYS: the pause-panel UIs (echo offer, tech, forge) must
## still click; the cost is combat tails ringing through a pause, acceptable
## for placeholders.

const POOL_3D := 10   # concurrent positioned sounds before the oldest is stolen
const POOL_2D := 6
const UNIT_SIZE := 25.0  # generous 3D attenuation — the fixed camera sits far away

var _map: Dictionary = {}
var _streams: Dictionary = {}   # file -> AudioStream, loaded once at boot (loud on breakage)
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _warned: Dictionary = {}    # unknown-id spam guard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map = DataLoader.load_sfx_map()
	for id: String in _map:
		var file := str((_map[id] as Dictionary).get("file", ""))
		if not _streams.has(file):
			var stream := load(file) as AudioStream
			if stream == null:
				push_error("Sfx: \"%s\" maps to unloadable stream %s" % [id, file])
				continue
			_streams[file] = stream
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = UNIT_SIZE
		add_child(p)
		_players_3d.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer.new()
		add_child(q)
		_players_2d.append(q)
	# Cross-domain hooks (audio.md phase-1 list): loot chirps, boss kill booms.
	EventBus.resource_changed.connect(func(_id: String, old: float, new_amount: float, reason: String) -> void:
		if new_amount > old and (reason == "run-drop" or reason == "boss-drop"):
			play("pickup"))
	EventBus.boss_killed.connect(func(_boss_id: String, _boss_floor: int) -> void:
		play("boss-kill"))


# Known shutdown notice: sounds still mid-play when the game quits print
# "N resources still in use at exit" — the AudioServer's playback objects hold
# the stream and are released after the leak check runs. Engine-order noise,
# not an app leak (stopping players in _exit_tree was tried; it changes nothing).

## Fire-and-forget. `at` = Vector3 world position for a 3D positioned sound;
## omit it for flat 2D playback (UI, chimes). Unknown ids error once, not never.
func play(id: String, at: Variant = null) -> void:
	var params := SfxCore.resolve(_map, id, randf())
	if params.is_empty() or not _streams.has(params["file"]):
		if not _warned.has(id):
			_warned[id] = true
			push_error("Sfx: no playable sound \"%s\" (data/audio/sfx-map.json)" % id)
		return
	var stream: AudioStream = _streams[params["file"]]
	if at is Vector3:
		var p := _free_3d()
		p.stream = stream
		p.bus = params["bus"]
		p.volume_db = params["volume_db"]
		p.pitch_scale = params["pitch_scale"]
		p.global_position = at
		p.play()
	else:
		var q := _free_2d()
		q.stream = stream
		q.bus = params["bus"]
		q.volume_db = params["volume_db"]
		q.pitch_scale = params["pitch_scale"]
		q.play()


func _free_3d() -> AudioStreamPlayer3D:
	for p in _players_3d:
		if not p.playing:
			return p
	return _players_3d[0]  # all busy: steal one — placeholder-grade voice management


func _free_2d() -> AudioStreamPlayer:
	for p in _players_2d:
		if not p.playing:
			return p
	return _players_2d[0]
