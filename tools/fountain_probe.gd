extends SceneTree
## Throwaway probe: does TownFountain's generated geometry face the right way?
## SurfaceTool.generate_normals() derives normals from the SAME winding convention the
## rasterizer uses for back-face culling, so "do the normals point where the helper
## promised?" answers "is the winding right?" definitively.
##
## Strategy: test the two geometry PRIMITIVES (_wall, _cap) in isolation — those carry
## all the winding risk; the composed fountain is then correct by construction from the
## flags passed. Then sanity-check the assembled piece's bounds/containment.
##   godot --headless --path . -s tools/fountain_probe.gd

var _fails := 0


func _init() -> void:
	var f := TownFountain.new()

	# --- The two primitives, in isolation -------------------------------------------
	_expect_faces("wall(outward=true)", _bake(func(st: SurfaceTool) -> void:
		f._wall(st, 1.0, 1.0, 0.0, 1.0, 8, true)),
		func(c: Vector3, n: Vector3) -> bool: return n.dot(_radial(c)) > 0.9)

	_expect_faces("wall(outward=false)", _bake(func(st: SurfaceTool) -> void:
		f._wall(st, 1.0, 1.0, 0.0, 1.0, 8, false)),
		func(c: Vector3, n: Vector3) -> bool: return n.dot(_radial(c)) < -0.9)

	_expect_faces("wall cone (r shrinks upward, outward)", _bake(func(st: SurfaceTool) -> void:
		f._wall(st, 1.0, 0.4, 0.0, 1.0, 8, true)),
		func(c: Vector3, n: Vector3) -> bool: return n.dot(_radial(c)) > 0.3 and n.y > 0.0)

	_expect_faces("cap disc (up)", _bake(func(st: SurfaceTool) -> void:
		f._cap(st, 0.0, 1.0, 0.0, 8, true)),
		func(_c: Vector3, n: Vector3) -> bool: return n.y > 0.99)

	_expect_faces("cap annulus (up)", _bake(func(st: SurfaceTool) -> void:
		f._cap(st, 0.5, 1.0, 0.0, 8, true)),
		func(_c: Vector3, n: Vector3) -> bool: return n.y > 0.99)

	_expect_faces("cap annulus (down)", _bake(func(st: SurfaceTool) -> void:
		f._cap(st, 0.5, 1.0, 0.0, 8, false)),
		func(_c: Vector3, n: Vector3) -> bool: return n.y < -0.99)

	# --- The assembled piece ---------------------------------------------------------
	var stone: ArrayMesh = f._build_stone()
	var bb: AABB = stone.get_aabb()
	print("stone: %d tris, AABB pos=%v size=%v" % [
		stone.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, bb.position, bb.size])
	_check(absf(bb.size.x - f.step_radius * 2.0) < 0.01,
		"stone footprint spans the lower step")
	_check(absf((bb.position.y + bb.size.y) - f.finial_top_y) < 0.01,
		"stone tops out at finial_top_y (%.2f m tall)" % f.finial_top_y)

	var water: ArrayMesh = f._build_water_disc()
	var wa: Array = water.surface_get_arrays(0)
	var wv: PackedVector3Array = wa[Mesh.ARRAY_VERTEX]
	var wn: PackedVector3Array = wa[Mesh.ARRAY_NORMAL]
	var water_ok := wv.size() > 0
	for i in wv.size():
		if wn[i].y < 0.99 or absf(wv[i].y - f.water_y) > 0.001 \
				or Vector2(wv[i].x, wv[i].z).length() > f.rim_inner + 0.001:
			water_ok = false
	_check(water_ok, "water disc: %d verts, flat + up-facing + inside the rim" % wv.size())
	_check(f.basin_floor_y < f.water_y and f.water_y < f.rim_top,
		"water sits below the rim and above the basin floor (has depth to absorb)")

	var cs: CollisionShape3D = f._collision_part()
	var cyl: CylinderShape3D = cs.shape
	_check(cyl.radius <= f.apron_radius,
		"collision r=%.2f stays inside the paving apron r=%.2f" % [cyl.radius, f.apron_radius])
	_check(absf(cyl.radius - f.step_radius) < 0.001,
		"collision matches the step, so the player never stands in raised stone")
	cs.free()

	print("FOUNTAIN PROBE: ", "OK" if _fails == 0 else "%d FAILURE(S)" % _fails)
	quit(0 if _fails == 0 else 1)


static func _radial(c: Vector3) -> Vector3:
	return Vector3(c.x, 0.0, c.z).normalized()


func _bake(emit: Callable) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	emit.call(st)
	st.generate_normals()
	return st.commit().surface_get_arrays(0)


## Every triangle's centroid + face normal must satisfy `predicate`.
func _expect_faces(label: String, arrays: Array, predicate: Callable) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad := 0
	var tris := v.size() / 3
	for t in tris:
		var c := (v[t * 3] + v[t * 3 + 1] + v[t * 3 + 2]) / 3.0
		if not predicate.call(c, n[t * 3]):
			bad += 1
	_check(tris > 0 and bad == 0, "%s: %d tris, %d wrong-facing" % [label, tris, bad])


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", msg])
