extends RefCounted
class_name StyleEnvironment
## The ONE WorldEnvironment definition for the painted-lite look (the art-style.png fork,
## 2026-08-13). Sibling of StyleMaterials in the style-unification layer: StyleCore holds
## pure colour maths, StyleMaterials builds materials, this builds Environments.
##
## Before the fork every scene carried a hand-inlined Environment with nothing but a
## background colour and an ambient light — no tonemap, no glow, no fog, no AO. That gap,
## not the geometry, was the largest single distance between the build and the anchor.
##
## Callers pass only what differs per scene (background / ambient); everything else is a
## project-wide `# style:` dial below — the SAME untouchable contract as `# FEEL:`. Every
## value is a PLACEHOLDER awaiting the human's dial pass (design/feel-tuning.md).
##
## scenes/combat/feel_room.tscn is EXEMPT by design and must never call this — the
## combat-feel sandbox keeps its raw look.

# --- Tonemap ---------------------------------------------------------------------------
# AgX is a filmic curve — it rolls the whole image down hard compared to the default
# linear tonemap the scenes had before the fork. Exposure carries that back, so the
# scenes' existing light energies stay meaningful instead of every one needing a re-dial.
const TONEMAP_EXPOSURE := 1.8        # style: human-tuned, do not optimize
const TONEMAP_WHITE := 6.0           # style: human-tuned, do not optimize

# --- Glow (the warm practicals' halo — the anchor's forge/lantern read) ------------------
const GLOW_INTENSITY := 0.5          # style: human-tuned, do not optimize
const GLOW_BLOOM := 0.15             # style: human-tuned, do not optimize
# Above 1.0 = only genuinely HDR-bright things bloom. Kept just under 1.0 so warm
# practicals catch while ordinary lit surfaces do not turn to soup.
const GLOW_HDR_THRESHOLD := 0.95     # style: human-tuned, do not optimize

# --- Volumetric fog (depth + the light-shaft haze around practicals) ---------------------
const FOG_DENSITY := 0.015           # style: human-tuned, do not optimize
const FOG_ALBEDO := Color(0.42, 0.48, 0.58)   # style: human-tuned, do not optimize — cool dusk haze
const FOG_ANISOTROPY := 0.2          # style: human-tuned, do not optimize
const FOG_LENGTH := 64.0             # style: human-tuned, do not optimize — metres of fog depth
const FOG_AMBIENT_INJECT := 0.1      # style: human-tuned, do not optimize

# --- Ambient occlusion (contact shadows in the clutter) ----------------------------------
const SSAO_RADIUS := 1.0             # style: human-tuned, do not optimize
const SSAO_INTENSITY := 2.0          # style: human-tuned, do not optimize
const SSAO_POWER := 1.5              # style: human-tuned, do not optimize
const SSAO_DETAIL := 0.5             # style: human-tuned, do not optimize

# --- Grade -------------------------------------------------------------------------------
const ADJ_BRIGHTNESS := 1.0          # style: human-tuned, do not optimize
const ADJ_CONTRAST := 1.05           # style: human-tuned, do not optimize
## DOUBLE DUTY — do not "clean this up" toward 1.0. Desaturating the world is (a) most of
## what reads as "painted" rather than "3D render", and (b) the combat-readability guard:
## it leaves telegraph red / hazard amber / pickup cyan as the only saturated pixels on
## screen, so they pop on hue alone without needing to be brightened out of the palette.
const ADJ_SATURATION := 0.85         # style: human-tuned, do not optimize


# --- Vignette (Environment has none; the anchor's corners are near-black) ----------------
const VIGNETTE_SHADER: Shader = preload("res://assets/materials/tycho_vignette.gdshader")
const VIGNETTE_STRENGTH := 0.55      # style: human-tuned, do not optimize
const VIGNETTE_RADIUS := 0.75        # style: human-tuned, do not optimize
const VIGNETTE_SOFTNESS := 0.45      # style: human-tuned, do not optimize
const VIGNETTE_COLOR := Color(0.02, 0.02, 0.04)   # style: human-tuned, do not optimize
## Layer 0 puts it under every gameplay CanvasLayer (the HUDs sit on the default layer 1),
## so the vignette darkens the WORLD and never the UI. Combat readability depends on this:
## a dimmed HUD would undo the Ember language's whole contrast story.
const VIGNETTE_LAYER := 0


## A ready-to-add vignette overlay. Add it to a 3D scene root; it needs no wiring.
static func build_vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = VIGNETTE_LAYER

	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	mat.set_shader_parameter("strength", VIGNETTE_STRENGTH)
	mat.set_shader_parameter("radius", VIGNETTE_RADIUS)
	mat.set_shader_parameter("softness", VIGNETTE_SOFTNESS)
	mat.set_shader_parameter("vignette_color", VIGNETTE_COLOR)

	var rect := ColorRect.new()
	rect.name = "VignetteRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	layer.add_child(rect)
	return layer


## The project Environment. `bg` and `ambient` are the per-scene identity (a stratum's
## background/ambient, or the town's); everything else is the shared painted look.
static func build(bg: Color, ambient: Color, ambient_energy: float) -> Environment:
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = TONEMAP_EXPOSURE
	env.tonemap_white = TONEMAP_WHITE

	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = FOG_DENSITY
	env.volumetric_fog_albedo = FOG_ALBEDO
	env.volumetric_fog_emission = Color.BLACK
	env.volumetric_fog_anisotropy = FOG_ANISOTROPY
	env.volumetric_fog_length = FOG_LENGTH
	env.volumetric_fog_ambient_inject = FOG_AMBIENT_INJECT

	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_power = SSAO_POWER
	env.ssao_detail = SSAO_DETAIL

	env.adjustment_enabled = true
	env.adjustment_brightness = ADJ_BRIGHTNESS
	env.adjustment_contrast = ADJ_CONTRAST
	env.adjustment_saturation = ADJ_SATURATION

	return env
