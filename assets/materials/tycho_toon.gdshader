shader_type spatial;
render_mode specular_disabled;

// Tycho toon/ramp shader — THE style-unification layer (design/asset-pipeline.md §C).
// Every 3D mesh in the game renders through this one shader; per-stratum identity comes
// from the `ramp` gradient (built by StyleMaterials from StyleCore ramp stops), never
// from per-mesh shader tweaks. Uniform defaults MIRROR StyleCore's `# style:` consts —
// all of them are placeholders the human dials (same untouchable contract as `# FEEL:`).

uniform vec4 albedo : source_color = vec4(1.0);
// Optional albedo texture (imported models keep their baked texture; primitives leave
// this at the default white).
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
// style: human-tuned, do not optimize — number of light bands (mirrors StyleCore.BAND_COUNT)
uniform int band_count : hint_range(2, 8) = 3;
// Horizontal dark→light gradient; sampled at the quantized light level, so shadowed
// bands tint toward the ramp's DARK stop instead of going plain black.
uniform sampler2D ramp : source_color, filter_linear, repeat_disable, hint_default_white;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// style: human-tuned, do not optimize — banded rim light on the lit side (0 = off)
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	// Single-dominant-light trick: only DIRECTIONAL lights shape the bands (every scene
	// has exactly one), so any future omni/spot light can't fragment the look.
	if (LIGHT_IS_DIRECTIONAL) {
		// Fold shadowing (ATTENUATION) into the light level BEFORE quantizing: a
		// shadowed pixel lands in the lowest band and samples the ramp's dark stop.
		float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
		float band = clamp(floor(lit * float(band_count)) / float(band_count - 1), 0.0, 1.0);
		vec3 ramp_col = texture(ramp, vec2(band, 0.5)).rgb;
		vec3 out_light = ramp_col;
		if (rim_strength > 0.0) {
			// Minimal banded rim: a hard-edged fresnel step, lit side only.
			float rim = 1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
			out_light += step(0.75, rim) * rim_strength * band;
		}
		// ALBEDO is multiplied in by the engine after the light loop.
		DIFFUSE_LIGHT += out_light * LIGHT_COLOR / PI;
	}
}
