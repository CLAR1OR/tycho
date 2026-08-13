shader_type spatial;
render_mode specular_disabled;

// Tycho painterly-ramp shader — THE style-unification layer (design/asset-pipeline.md §C).
// Every 3D mesh in the game renders through this one shader; per-stratum identity comes
// from the `ramp` gradient (built by StyleMaterials from StyleCore ramp stops), never
// from per-mesh shader tweaks. Uniform defaults MIRROR StyleCore's `# style:` consts —
// all of them are placeholders the human dials (same untouchable contract as `# FEEL:`).
//
// REWRITTEN 2026-08-13 for the art-style.png anchor (the painted-lite fork): the ramp is
// now sampled CONTINUOUSLY instead of quantized into hard bands. The ramp's meaning is
// unchanged (dark -> light, shadow colour -> light colour), so StyleCore.ramp_stops() and
// every per-stratum ramp survive the fork untouched — only the shading model changed.
// specular_disabled stays for now; a low spec for wet cobble / water sheen is a candidate
// later dial, not a default.

uniform vec4 albedo : source_color = vec4(1.0);
// Optional albedo texture (imported models keep their baked texture; primitives leave
// this at the default white).
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
// Horizontal dark→light gradient, sampled at the (soft) light level so shadowed pixels
// tint toward the ramp's DARK stop instead of going plain black.
uniform sampler2D ramp : source_color, filter_linear, repeat_disable, hint_default_white;
// style: human-tuned, do not optimize — diffuse wrap (mirrors StyleCore.SHADOW_WRAP).
// 0 = plain lambert (hard terminator), 1 = full half-lambert (soft painted falloff).
uniform float shadow_wrap : hint_range(0.0, 1.0) = 0.35;
// style: human-tuned, do not optimize — how much omni/spot practicals contribute
// (mirrors StyleCore.PRACTICAL_GAIN).
uniform float practical_gain : hint_range(0.0, 2.0) = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// style: human-tuned, do not optimize — soft rim light on the lit side (0 = off)
uniform float rim_strength : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// The ONE light that shapes the look. Every scene has exactly one, so the ramp
		// (and with it the stratum's identity) can never be fragmented by another source.
		float ndotl = dot(NORMAL, LIGHT);
		// Wrapped diffuse: lerp between lambert and half-lambert. Half-lambert never
		// reaches 0, which is exactly the soft painted terminator the anchor has.
		float lit = clamp(mix(ndotl, ndotl * 0.5 + 0.5, shadow_wrap), 0.0, 1.0);
		// Fold shadowing in BEFORE the ramp lookup: a shadowed pixel samples the dark stop.
		lit *= ATTENUATION;
		vec3 out_light = texture(ramp, vec2(lit, 0.5)).rgb;
		if (rim_strength > 0.0) {
			// Soft fresnel rim, lit side only — smoothstep, not step: a hard rim reads
			// as an outline, and the painted anchor has no outlines.
			float rim = 1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
			out_light += smoothstep(0.55, 1.0, rim) * rim_strength * lit;
		}
		// ALBEDO is multiplied in by the engine after the light loop.
		DIFFUSE_LIGHT += out_light * LIGHT_COLOR / PI;
	} else {
		// Practicals (lanterns, forge, window glow, braziers). Plain lambert, NOT through
		// the ramp — so warm point lights illuminate the scene without dragging the
		// stratum's colour identity around. This branch is why the painted lighting story
		// works at all: before the fork, every omni/spot was ignored outright.
		float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
		DIFFUSE_LIGHT += ndotl * ATTENUATION * LIGHT_COLOR * practical_gain / PI;
	}
}
