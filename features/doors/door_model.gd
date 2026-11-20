class_name DoorModel
extends RefCounted
## Turns the "Old Door" model (CC BY, Game Ready Art) into what Door needs.
## The source is one mesh holding the frame and a half-open panel, so it is
## split into connected pieces: the frame stays put, and the panel (with its
## handles) is rotated shut around the hinge. Both are scaled to our doorway.
## Output space: hinge axis at the origin, panel extending along +X, floor at
## y = 0, same as the Door scene. Built once and shared by every door.

const SOURCE: PackedScene = preload("res://assets/models/old_door/old_door.glb")
## Source units are centimetres; this also shrinks the 110 cm opening to our 0.9 m panel.
const SCALE: float = 0.0081
## Inner edge of the hinge-side post in the source (cm), found by inspecting the mesh.
const HINGE_X: float = 55.6
## Posts are the frame pieces taller than this (cm).
const POST_MIN_HEIGHT: float = 200.0
## Anything sticking further than this out of the frame plane belongs to the open panel (cm).
const PANEL_MIN_DEPTH: float = 20.0
const ANGLE_STEP_DEG: float = 0.25
const MAX_CLOSE_ANGLE_DEG: float = 120.0

static var _frame: ArrayMesh = null
static var _panel: ArrayMesh = null


static func frame_mesh() -> ArrayMesh:
	_build_once()
	return _frame


static func panel_mesh() -> ArrayMesh:
	_build_once()
	return _panel


static func _build_once() -> void:
	if _panel != null:
		return
	var root := SOURCE.instantiate() as Node3D
	var source := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var to_root := _relative_transform(root, source)
	var arrays := source.mesh.surface_get_arrays(0)
	var material := source.mesh.surface_get_material(0)
	if material == null:
		material = source.get_active_material(0)
	root.free()

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = to_root * vertices[i]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size():
		normals[i] = (to_root.basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals

	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pieces := _connected_pieces(vertices, indices)
	var split := _split_frame_and_panel(vertices, indices, pieces)
	var frame_z := _frame_centre_z(vertices, indices, pieces, split)
	var pivot := Vector3(HINGE_X, 0.0, frame_z)
	var close := _closing_rotation(vertices, indices, pieces, split, pivot)
	# Turn 180 degrees so the panel extends along +X from the hinge, then scale.
	var to_door := Basis(Vector3.UP, PI)
	_frame = _build_mesh(arrays, pieces, split, false, material,
		func(p: Vector3) -> Vector3: return to_door * (p - pivot) * SCALE, to_door)
	_panel = _build_mesh(arrays, pieces, split, true, material,
		func(p: Vector3) -> Vector3: return to_door * (close * (p - pivot)) * SCALE, to_door * close)


## Union-find over vertices that share a triangle or a position.
static func _connected_pieces(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array()
	parent.resize(vertices.size())
	for i in vertices.size():
		parent[i] = i
	var by_position: Dictionary[Vector3i, int] = {}
	for i in vertices.size():
		var key := Vector3i((vertices[i] * 100.0).round())
		if by_position.has(key):
			_union(parent, i, by_position[key])
		else:
			by_position[key] = i
	for t in indices.size() / 3:
		_union(parent, indices[t * 3], indices[t * 3 + 1])
		_union(parent, indices[t * 3], indices[t * 3 + 2])
	for i in vertices.size():
		parent[i] = _find(parent, i)
	return parent


## Per-piece flag: true = panel (sticks out of the frame plane), false = frame.
static func _split_frame_and_panel(vertices: PackedVector3Array, indices: PackedInt32Array,
		pieces: PackedInt32Array) -> Dictionary[int, bool]:
	var max_z: Dictionary[int, float] = {}
	for index in indices:
		var piece := pieces[index]
		var previous: float = max_z.get(piece, -INF)
		max_z[piece] = maxf(previous, vertices[index].z)
	var result: Dictionary[int, bool] = {}
	for piece: int in max_z.keys():
		result[piece] = max_z[piece] > PANEL_MIN_DEPTH
	return result


static func _frame_centre_z(vertices: PackedVector3Array, indices: PackedInt32Array,
		pieces: PackedInt32Array, split: Dictionary[int, bool]) -> float:
	var boxes: Dictionary[int, AABB] = {}
	for index in indices:
		var piece := pieces[index]
		if split[piece]:
			continue
		var point := vertices[index]
		boxes[piece] = boxes[piece].expand(point) if boxes.has(piece) else AABB(point, Vector3.ZERO)
	for piece: int in boxes.keys():
		var box: AABB = boxes[piece]
		if box.size.y > POST_MIN_HEIGHT:
			return box.get_center().z
	return 0.0


## The rotation (around the hinge) that makes the panel flattest along Z,
## i.e. shut inside the frame.
static func _closing_rotation(vertices: PackedVector3Array, indices: PackedInt32Array,
		pieces: PackedInt32Array, split: Dictionary[int, bool], pivot: Vector3) -> Basis:
	var panel_points := PackedVector3Array()
	for index in indices:
		if split[pieces[index]]:
			panel_points.append(vertices[index] - pivot)
	var best_angle := 0.0
	var best_depth := INF
	var angle := -MAX_CLOSE_ANGLE_DEG
	while angle <= MAX_CLOSE_ANGLE_DEG:
		var turn := Basis(Vector3.UP, deg_to_rad(angle))
		var min_z := INF
		var max_z := -INF
		var max_x := -INF
		for point in panel_points:
			var turned := turn * point
			min_z = minf(min_z, turned.z)
			max_z = maxf(max_z, turned.z)
			max_x = maxf(max_x, turned.x)
		# The shut panel lies on the -X side of the hinge, inside the opening.
		if max_z - min_z < best_depth and max_x < 5.0:
			best_depth = max_z - min_z
			best_angle = angle
		angle += ANGLE_STEP_DEG
	return Basis(Vector3.UP, deg_to_rad(best_angle))


static func _build_mesh(arrays: Array, pieces: PackedInt32Array, split: Dictionary[int, bool], want_panel: bool,
		material: Material, place: Callable, turn: Basis) -> ArrayMesh:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for index in indices:
		if split[pieces[index]] != want_panel:
			continue
		tool.set_normal((turn * normals[index]).normalized())
		if index < uvs.size():
			tool.set_uv(uvs[index])
		var placed: Vector3 = place.call(vertices[index])
		tool.add_vertex(placed)
	tool.generate_tangents()
	return tool.commit()


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current != null:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_a] = root_b
