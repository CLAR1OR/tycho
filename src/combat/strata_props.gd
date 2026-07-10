extends RefCounted
class_name StrataProps
## Placeholder prop registry for the dungeon strata (design/dungeon-strata.md). Each
## floor's `props` list names a few kebab-case ids; this maps each id to a throwaway
## PRIMITIVE MeshInstance3D — dressing only, NO collision (props must never block a
## path — the dead-roll rule). An unknown id warns and is skipped (a future prop id
## never crashes a room). Crystal / void ids glow (emissive) — the "imitation thins
## with depth" gradient leaking into the props. ALL geometry/colour is a HUMAN
## placeholder awaiting the painterly pass.

# id -> {mesh: "box|cyl|prism|sphere", size: Vector3, color: Color, emissive: bool}
const PROPS: Dictionary = {
	# Floor 1 — The Scanned Cave (natural rock)
	"rock-formation": {"mesh": "box", "size": Vector3(2.4, 2.0, 2.4), "color": Color(0.26, 0.22, 0.16), "emissive": false},
	"stalagmite": {"mesh": "prism", "size": Vector3(1.2, 2.6, 1.2), "color": Color(0.30, 0.26, 0.20), "emissive": false},
	# Floor 2 — The Borrowed Hall (worked stone)
	"broken-column": {"mesh": "cyl", "size": Vector3(0.9, 2.8, 0.9), "color": Color(0.40, 0.40, 0.44), "emissive": false},
	"arch-fragment": {"mesh": "box", "size": Vector3(2.2, 1.4, 0.7), "color": Color(0.42, 0.41, 0.44), "emissive": false},
	# Floor 3 — The Resonant Stratum (crystal seams, glowing)
	"crystal-seam": {"mesh": "prism", "size": Vector3(0.7, 2.2, 0.7), "color": Color(0.35, 0.85, 0.9), "emissive": true},
	"crystal-cluster": {"mesh": "prism", "size": Vector3(1.4, 1.8, 1.4), "color": Color(0.45, 0.95, 0.95), "emissive": true},
	# Floor 4 — The Filed World (clean planes, floating masses)
	"filed-block": {"mesh": "box", "size": Vector3(1.8, 1.8, 1.8), "color": Color(0.55, 0.58, 0.64), "emissive": false},
	"floating-mass": {"mesh": "sphere", "size": Vector3(1.6, 1.6, 1.6), "color": Color(0.60, 0.63, 0.70), "emissive": false},
	# Floor 5 — The Core (void, light traces)
	"light-trace": {"mesh": "box", "size": Vector3(0.4, 3.0, 0.4), "color": Color(0.5, 0.9, 1.0), "emissive": true},
	"void-shard": {"mesh": "prism", "size": Vector3(1.0, 2.0, 1.0), "color": Color(0.25, 0.6, 0.75), "emissive": true},
}


## Build a placeholder prop node (a MeshInstance3D, no collision) for `id`. Returns null
## for an unknown id after a loud warning — the room skips it. Caller positions it.
static func build(id: String) -> MeshInstance3D:
	if not PROPS.has(id):
		push_warning("StrataProps: unknown prop id \"%s\" — skipped" % id)
		return null
	var spec: Dictionary = PROPS[id]
	var size: Vector3 = spec["size"]
	var mesh := MeshInstance3D.new()
	match str(spec["mesh"]):
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh.mesh = bm
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x * 0.5
			cm.bottom_radius = size.x * 0.5
			cm.height = size.y
			mesh.mesh = cm
		"prism":
			var pm := PrismMesh.new()
			pm.size = size
			mesh.mesh = pm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh.mesh = sm
	var mat := StandardMaterial3D.new()  # fresh per prop — no shared-material aliasing
	var col: Color = spec["color"]
	mat.albedo_color = col
	if bool(spec["emissive"]):
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.4
	# surface override (not material_override) so the mesh surface carries a real material —
	# matches the scene's floor/walls and keeps the headless dummy renderer quiet.
	mesh.set_surface_override_material(0, mat)
	return mesh
