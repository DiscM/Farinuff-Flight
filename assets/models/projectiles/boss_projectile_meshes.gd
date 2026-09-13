extends RefCounted
## Authored silhouettes in the X/Z combat plane, forward along -Z.
## Geometry is shared by pooled instances; palette and motion remain independent.

static var _meshes: Dictionary[int, Mesh] = {}

static func get_mesh(style: int) -> Mesh:
	if _meshes.has(style):
		return _meshes[style]
	var outline: PackedVector2Array
	match style:
		0: # Arrowhead, recessed shoulders and split tail.
			outline = PackedVector2Array([Vector2(0,-1.3), Vector2(0.65,-0.3), Vector2(0.24,-0.43), Vector2(0.3,0.65), Vector2(0,0.42), Vector2(-0.3,0.65), Vector2(-0.24,-0.43), Vector2(-0.65,-0.3)])
		1: # Siege shell: chamfered nose, stepped side armor, notched tail.
			outline = PackedVector2Array([Vector2(-0.35,-0.85), Vector2(0.35,-0.85), Vector2(0.7,-0.4), Vector2(0.7,0.1), Vector2(0.48,0.1), Vector2(0.48,0.7), Vector2(0,0.48), Vector2(-0.48,0.7), Vector2(-0.48,0.1), Vector2(-0.7,0.1), Vector2(-0.7,-0.4)])
		2: # Open crescent with a sharp leading tip and hooked trailing edge.
			outline = PackedVector2Array([Vector2(0.2,-1), Vector2(0.75,-0.65), Vector2(0.9,0), Vector2(0.65,0.7), Vector2(0,0.95), Vector2(-0.7,0.5), Vector2(-0.2,0.6), Vector2(0.35,0.35), Vector2(0.5,-0.1), Vector2(0.25,-0.55), Vector2(-0.15,-0.75)])
		3: # Barbed teardrop with two swept-back fins.
			outline = PackedVector2Array([Vector2(0,-1.1), Vector2(0.4,-0.55), Vector2(0.6,0), Vector2(0.28,0.55), Vector2(0.65,0.85), Vector2(0,0.55), Vector2(-0.65,0.85), Vector2(-0.28,0.55), Vector2(-0.6,0), Vector2(-0.4,-0.55)])
		_: # Four reactor lobes separated by deep cooling slots.
			outline = PackedVector2Array([Vector2(-0.22,-0.9), Vector2(0.22,-0.9), Vector2(0.35,-0.35), Vector2(0.9,-0.22), Vector2(0.9,0.22), Vector2(0.35,0.35), Vector2(0.22,0.9), Vector2(-0.22,0.9), Vector2(-0.35,0.35), Vector2(-0.9,0.22), Vector2(-0.9,-0.22), Vector2(-0.35,-0.35)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(outline)
	for face in range(0, triangles.size(), 3):
		for corner in [2, 1, 0]:
			var point := outline[triangles[face + corner]] * 0.78
			surface.add_vertex(Vector3(point.x, 0.18, point.y))
		for corner in 3:
			var point := outline[triangles[face + corner]] * 0.78
			surface.add_vertex(Vector3(point.x, -0.18, point.y))
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var upper_a := Vector3(a.x * 0.78, 0.18, a.y * 0.78)
		var upper_b := Vector3(b.x * 0.78, 0.18, b.y * 0.78)
		var edge_a := Vector3(a.x, 0, a.y)
		var edge_b := Vector3(b.x, 0, b.y)
		var bevel_vertices := [upper_a, edge_a, edge_b, upper_a, edge_b, upper_b, edge_a, Vector3(a.x * 0.78,-0.18,a.y * 0.78), Vector3(b.x * 0.78,-0.18,b.y * 0.78), edge_a, Vector3(b.x * 0.78,-0.18,b.y * 0.78), edge_b]
		for triangle in range(0, bevel_vertices.size(), 3):
			for corner in [2, 1, 0]:
				surface.add_vertex(bevel_vertices[triangle + corner])
	surface.generate_normals()
	_meshes[style] = surface.commit()
	return _meshes[style]
