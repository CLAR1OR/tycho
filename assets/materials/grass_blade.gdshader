shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_schlick_ggx;

// Stylized multimesh grass — by @_Malido, CC0, from
// https://godotshaders.com/shader/stylized-multimesh-grass-shader/
// Used verbatim apart from uniform defaults. Driven by src/core/grass_patch.gd
// (builds the MultiMesh + wind noise and feeds `player_position` per frame).
// UV convention: the blade mesh's UV.y is 0 at the TIP, 1 at the ROOT — tips sway
// and catch the top colour, roots stay planted. All uniform values are style
// placeholders the human dials (see design/feel-tuning.md § Style unification).

uniform vec3 top_color: source_color = vec3(0.45, 0.58, 0.28);
uniform vec3 bottom_color: source_color = vec3(0.18, 0.28, 0.14);
uniform float ambient_occlusion_factor: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float specular_strength: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float player_displacement_strength: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float player_displacement_size: hint_range(0.0, 2.0, 0.01) = 1.0;

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.35);
uniform float wind_strength: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform sampler2D wind_noise;
uniform float wind_noise_size: hint_range(0.0, 1.0, 0.001) = 0.05;
uniform float wind_noise_speed: hint_range(0.0, 1.0, 0.001) = 0.1;

instance uniform vec3 player_position;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec3 wind_texture = texture(wind_noise, world_position.xz * wind_noise_size + normalize(-wind_direction.xz) * (TIME + UV.y / 2.5) * wind_noise_speed).rgb;
	vec3 wind_vector = (vec4(wind_texture * normalize(wind_direction) * wind_strength, 0.0) * MODEL_MATRIX).xyz;

	float player_height = smoothstep(1.0, 0.0, length(player_position.y - world_position.y + 0.3));
	vec3 push_direction = vec3(world_position - player_position) * vec3(1, -0.3, 1);
	float player_position_factor = smoothstep(player_displacement_size, 0.0, length(push_direction));

	vec3 player_push_vector = (vec4(normalize(push_direction), 0.0) * MODEL_MATRIX).xyz;

	VERTEX += player_push_vector * (1.0 - UV.y) * player_position_factor * player_displacement_strength * player_height;
	VERTEX += wind_vector * (1.0 - UV.y) * (1.0 - player_position_factor * 0.7);

	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 color = mix(bottom_color, top_color, 1.0 - UV.y);

	float ao_fallof = pow(UV.y, 5.0);
	vec3 ao_color = bottom_color * (1.0 - ambient_occlusion_factor);

	ALBEDO = mix(color, ao_color, ao_fallof);
	ROUGHNESS = 0.4;

	SPECULAR *= (1.0 - UV.y) * specular_strength;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
