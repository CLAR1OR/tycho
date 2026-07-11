extends "res://tests/test_suite.gd"
## Tests StyleCore (src/core/style_core.gd) — the pure ramp/palette maths of the
## style-unification layer (design/asset-pipeline.md §C) — plus StrataCore's optional
## `ramp` env-key parse. ONLY pure logic: the shaders and StyleMaterials factory are
## deliberately NOT unit-tested (visuals are judged by the human in-scene).

const EPS := 0.002  # from_hsv round-trips accumulate tiny float error


# A saturated, plausible stratum env (floor-3-ish) for derivation tests.
func _fixture_env() -> Dictionary:
	return StrataCore.environment_of({"environment": {
		"background_color": "#1a2438",
		"fog_color": "#101a2c",
		"ambient_color": "#3c4a66",
		"light_color": "#ffd9a0",
	}})


# --- NEUTRAL_RAMP / TOWN_RAMP shape ------------------------------------------------

func test_neutral_ramp_shape() -> void:
	check_eq(StyleCore.NEUTRAL_RAMP.size(), 3, "neutral ramp has exactly 3 stops")
	check(StyleCore.NEUTRAL_RAMP[0].v < StyleCore.NEUTRAL_RAMP[1].v
		and StyleCore.NEUTRAL_RAMP[1].v < StyleCore.NEUTRAL_RAMP[2].v,
		"neutral stops run dark -> light")
	check(StyleCore.NEUTRAL_RAMP[0].b > StyleCore.NEUTRAL_RAMP[0].r,
		"neutral dark end leans cool (blue > red)")


func test_town_ramp_shape() -> void:
	check_eq(StyleCore.TOWN_RAMP.size(), 3, "town ramp has exactly 3 stops")
	check(StyleCore.TOWN_RAMP[0].v < StyleCore.TOWN_RAMP[1].v
		and StyleCore.TOWN_RAMP[1].v < StyleCore.TOWN_RAMP[2].v,
		"town stops run dark -> light")


# --- ramp_stops derivation -----------------------------------------------------------

func test_ramp_stops_count_and_order() -> void:
	var stops := StyleCore.ramp_stops(_fixture_env())
	check_eq(stops.size(), 3, "derivation yields 3 stops")
	check(stops[0].v < stops[1].v and stops[1].v < stops[2].v,
		"derived stops run dark -> light (%s)" % [stops])


func test_ramp_stops_keep_neutral_brightness() -> void:
	# Brightness comes from NEUTRAL_RAMP — that is what makes the tint subtle and the
	# dark->light order structural, not incidental.
	var stops := StyleCore.ramp_stops(_fixture_env())
	for i in 3:
		check(absf(stops[i].v - StyleCore.NEUTRAL_RAMP[i].v) <= EPS,
			"stop %d keeps the neutral brightness (got %f want %f)"
			% [i, stops[i].v, StyleCore.NEUTRAL_RAMP[i].v])


func test_ramp_stops_saturation_capped() -> void:
	# Even a maximally-garish env must stay a subtle tint, never a hue takeover.
	var env := StrataCore.environment_of({"environment": {
		"background_color": "#ff0000", "fog_color": "#00ff00",
		"ambient_color": "#0000ff", "light_color": "#ff00ff",
	}})
	for i in 3:
		var stop := StyleCore.ramp_stops(env)[i]
		check(stop.s <= StyleCore.RAMP_SATURATION_CAP + EPS,
			"stop %d saturation capped (got %f, cap %f)"
			% [i, stop.s, StyleCore.RAMP_SATURATION_CAP])


func test_ramp_stops_output_valid_and_deterministic() -> void:
	var a := StyleCore.ramp_stops(_fixture_env())
	var b := StyleCore.ramp_stops(_fixture_env())
	check_eq(a, b, "pure: same env -> identical stops")
	for stop in a:
		for ch: float in [stop.r, stop.g, stop.b, stop.a]:
			check(ch >= 0.0 and ch <= 1.0, "channel in [0,1] (%s)" % [stop])


func test_ramp_stops_defaults_env_works() -> void:
	# An empty profile (floor 1 / the sandbox) derives fine from ENV_DEFAULTS.
	var stops := StyleCore.ramp_stops(StrataCore.environment_of({}))
	check_eq(stops.size(), 3, "defaults env yields 3 stops")
	check(stops[0].v < stops[2].v, "defaults env stops run dark -> light")


func test_explicit_ramp_override_wins() -> void:
	var env := StrataCore.environment_of({"environment": {
		"ramp": ["#112233", "#445566", "#778899"],
		"light_color": "#ff0000",  # would tint the derived light stop — must be ignored
	}})
	var stops := StyleCore.ramp_stops(env)
	check_eq(stops, [Color.html("#112233"), Color.html("#445566"), Color.html("#778899")],
		"an explicit env ramp is used verbatim, derivation skipped")


# --- StrataCore `ramp` env-key parse ---------------------------------------------------

func test_ramp_env_key_absent_is_empty() -> void:
	var env := StrataCore.environment_of({})
	check_eq(env.get("ramp"), [], "no authored ramp -> empty array (derive)")


func test_ramp_env_key_parses_hex_array() -> void:
	var env := StrataCore.environment_of({"environment": {"ramp": ["#0a0b0c", "#a0b0c0"]}})
	check_eq(env["ramp"], [Color.html("#0a0b0c"), Color.html("#a0b0c0")],
		"hex stops parse to Colors in order")


func test_ramp_env_key_skips_invalid_entries() -> void:
	var env := StrataCore.environment_of({"environment": {"ramp": ["#112233", "nope", 5]}})
	check_eq(env["ramp"], [Color.html("#112233")], "invalid entries skipped, never crash")
	var bad := StrataCore.environment_of({"environment": {"ramp": "not-an-array"}})
	check_eq(bad["ramp"], [], "a non-array ramp value yields [] (derive)")
