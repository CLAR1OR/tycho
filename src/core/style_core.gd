extends RefCounted
class_name StyleCore
## The project palette + pure ramp derivation for the STYLE-UNIFICATION LAYER
## (design/asset-pipeline.md §C; dial board: design/feel-tuning.md § Style unification).
## Every 3D mesh renders through one toon shader (assets/materials/tycho_toon.gdshader);
## per-stratum identity is a 3-stop colour RAMP derived here from the floor's env
## profile — while the player/enemies/bosses stay on NEUTRAL_RAMP so identity hues and
## telegraph colours read IDENTICALLY on every floor (the readability guard).
##
## PURE: static funcs over value types only (Color is a value type) — no scene access,
## no engine singletons; mirrors src/combat/strata_core.gd. Everything that touches
## Shader/Material/Texture resources lives in StyleMaterials instead.
##
## `# style:` CONTRACT (established here, 2026-07-11): same untouchable rule as
## `# FEEL:` — human-tuned, agents do not optimize or "clean up". Every value below is
## a PLACEHOLDER awaiting the human's dial pass. Shader uniform defaults mirror these.

# --- Core style dials ---------------------------------------------------------------
const BAND_COUNT := 5                            # style: human-tuned, do not optimize — toon light bands
const OUTLINE_WIDTH := 0.01                       # style: human-tuned, do not optimize — inverted-hull width (m)
const OUTLINE_COLOR := Color(0.07, 0.06, 0.10)   # style: human-tuned, do not optimize — near-black outline

# --- Ramps (3 stops, dark -> light) ---------------------------------------------------
## Characters (player/enemies/bosses/NPCs/gate models) ALWAYS use this grey-scale ramp
## (slightly cool dark end) — the readability guard: stratum tinting must never shift
## how an enemy's identity hue or a telegraph colour reads.
const NEUTRAL_RAMP: Array[Color] = [
	Color(0.22, 0.23, 0.30),   # style: human-tuned, do not optimize — cool dark end
	Color(0.62, 0.62, 0.66),   # style: human-tuned, do not optimize — mid
	Color(1.0, 1.0, 1.0),      # style: human-tuned, do not optimize — light end
]

## The town has no floor profile — it gets its own ramp (warm daylight neutral).
const TOWN_RAMP: Array[Color] = [
	Color(0.33, 0.28, 0.26),   # style: human-tuned, do not optimize — warm shadow
	Color(0.72, 0.66, 0.58),   # style: human-tuned, do not optimize — mid
	Color(1.0, 0.97, 0.90),    # style: human-tuned, do not optimize — sunlit end
]

# --- Ramp derivation dials ------------------------------------------------------------
# How strongly a stratum's env colours tint the derived ramp. Brightness always comes
# from NEUTRAL_RAMP (keeps the dark->light order + overall value readable); only hue and
# a CAPPED fraction of saturation come from the floor — a subtle tint, not a hue takeover.
const RAMP_TINT_SATURATION := 0.5   # style: human-tuned, do not optimize — kept fraction of the env colour's saturation
const RAMP_SATURATION_CAP := 0.4    # style: human-tuned, do not optimize — max saturation of any derived stop

# --- Starter prop palette (medieval placeholder set, for future props/buildings) ------
const PALETTE_PARCHMENT := Color(0.85, 0.79, 0.64)   # style: human-tuned, do not optimize
const PALETTE_STONE := Color(0.55, 0.54, 0.52)       # style: human-tuned, do not optimize
const PALETTE_WOOD := Color(0.48, 0.35, 0.23)        # style: human-tuned, do not optimize
const PALETTE_VERDIGRIS := Color(0.31, 0.56, 0.48)   # style: human-tuned, do not optimize
const PALETTE_IRON := Color(0.35, 0.37, 0.40)        # style: human-tuned, do not optimize
const PALETTE_EMBER := Color(0.85, 0.44, 0.20)       # style: human-tuned, do not optimize


## The 3 ramp stops (dark -> light) a stratum's geometry/props render with, from its
## ALREADY-PARSED env profile dict (StrataCore.environment_of output). If the env
## carries an explicit non-empty `ramp` array (optional env key, parsed to Colors by
## StrataCore), that wins verbatim. Otherwise derive: dark from fog+background, mid
## from ambient, light from light_color — each stop keeps NEUTRAL_RAMP's brightness
## and takes only the env colour's hue + capped saturation (subtle tint by construction).
static func ramp_stops(env: Dictionary) -> Array[Color]:
	var explicit: Variant = env.get("ramp", [])
	if explicit is Array:
		var arr: Array = explicit
		var out: Array[Color] = []
		for c: Variant in arr:
			if c is Color:
				out.append(c)
		if not out.is_empty():
			return out
	var dark_src := _env_color(env, "background_color", NEUTRAL_RAMP[0]) \
		.lerp(_env_color(env, "fog_color", NEUTRAL_RAMP[0]), 0.5)
	var sources: Array[Color] = [
		dark_src,
		_env_color(env, "ambient_color", NEUTRAL_RAMP[1]),
		_env_color(env, "light_color", NEUTRAL_RAMP[2]),
	]
	var stops: Array[Color] = []
	for i in NEUTRAL_RAMP.size():
		stops.append(_tinted_stop(NEUTRAL_RAMP[i], sources[i]))
	return stops


# --- Helpers ---------------------------------------------------------------------------

## One derived stop: the neutral stop's brightness (value), the source's hue, and a
## damped+capped saturation. from_hsv clamps every channel into a valid Color.
static func _tinted_stop(neutral: Color, source: Color) -> Color:
	var sat := minf(source.s * RAMP_TINT_SATURATION, RAMP_SATURATION_CAP)
	return Color.from_hsv(source.h, sat, neutral.v)


static func _env_color(env: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = env.get(key, fallback)
	return v if v is Color else fallback
