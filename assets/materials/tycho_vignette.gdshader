shader_type canvas_item;

// Screen vignette — Godot's Environment has no vignette, and the painted anchor
// (assets_src/anchors/art-style.png) has near-black corners: the frame edges falling off
// is a large part of why it reads as a painting rather than a lit 3D scene.
//
// Drawn on a full-rect ColorRect on a CanvasLayer BELOW the HUD's layer, so it darkens
// the world and never the UI. Uniform defaults mirror StyleVignette's `# style:` consts.

// style: human-tuned, do not optimize — how dark the corners go (0 = off)
uniform float strength : hint_range(0.0, 1.0) = 0.55;
// style: human-tuned, do not optimize — where the falloff starts (fraction of half-diagonal)
uniform float radius : hint_range(0.0, 1.5) = 0.75;
// style: human-tuned, do not optimize — how gradual the falloff is
uniform float softness : hint_range(0.01, 1.0) = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);

void fragment() {
	// Distance from screen centre, normalized so 1.0 is the corner. Aspect is deliberately
	// NOT corrected: an elliptical vignette that follows the frame reads better on a wide
	// screen than a circular one that clips the sides.
	vec2 d = UV - vec2(0.5);
	float dist = length(d) / length(vec2(0.5));
	float v = smoothstep(radius, radius + softness, dist) * strength;
	COLOR = vec4(vignette_color.rgb, v);
}
