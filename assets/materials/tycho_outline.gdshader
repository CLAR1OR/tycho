shader_type spatial;
render_mode cull_front, unshaded;

// Tycho outline — inverted-hull pass (design/asset-pipeline.md §C). Chained onto the
// toon material via `next_pass` (StyleMaterials); CHARACTERS only (player, enemies,
// bosses, NPCs, gate models) — never environment geometry or props. Uniform defaults
// mirror StyleCore's `# style:` consts (placeholders the human dials).
//
// Known gotcha: hard-edged primitive meshes (BoxMesh) have split normals, so the hull
// can gap at corners — acceptable for placeholders; real (smooth-normal) models won't.
// Width is in model-space units (≈ world units while characters are unscaled).

// style: human-tuned, do not optimize — hull push distance (m)
uniform float outline_width = 0.03;
// style: human-tuned, do not optimize — near-black from the project palette
uniform vec4 outline_color : source_color = vec4(0.07, 0.06, 0.10, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
