class_name ModelBounds
extends RefCounted
## Bounding box of every mesh under a node, in that node's own space.
## Works before the node is in the scene tree (no global transforms needed).


static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var part := relative_transform(root, mesh) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Transform of `node` relative to its ancestor `root`.
static func relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current != null:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result
