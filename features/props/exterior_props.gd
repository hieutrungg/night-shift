class_name ExteriorProps
extends RefCounted
## Small outdoor props, built from primitives with shared materials.

const SIZES: Dictionary[String, Vector3] = {
	"guardBooth": Vector3(2.5, 2.8, 2.4),
	"dumpster": Vector3(2.3, 1.5, 1.3),
	"palletStack": Vector3(1.25, 0.48, 1.1),
	"puddle": Vector3(3.2, 0.01, 1.7),
	"oilStain": Vector3(1.5, 0.01, 0.9),
	"asphaltCrack": Vector3(2.6, 0.01, 1.0),
}
const PATCH_RADII: Array[float] = [1.0, 0.84, 0.95, 0.72, 0.9, 1.0, 0.76, 0.9, 0.78, 1.0, 0.86, 0.74]
const PATCH_HEIGHT: float = 0.014
const BOOTH_LIGHT_ENERGY: float = 0.75
const BOOTH_LIGHT_RANGE: float = 3.8
const SIGN_FONT_SIZE: int = 48
const SIGN_PIXEL_SIZE: float = 0.005
const WATER_SHADER: Shader = preload("res://features/props/puddle.gdshader")

static var _materials: Dictionary[StringName, StandardMaterial3D] = {}
static var _water_material: ShaderMaterial = null


static func create(id: String) -> Node3D:
	var prop: Node3D
	match id:
		"guardBooth":
			prop = _booth()
		"dumpster":
			prop = _dumpster()
		"palletStack":
			prop = _pallets()
		"asphaltCrack":
			prop = _crack()
		_:
			prop = _patch(id)
	prop.name = id.to_pascal_case()
	return prop


static func clear_cache() -> void:
	_materials.clear()
	_water_material = null


static func _material(key: StringName, colour: Color, roughness: float = 0.85,
		metallic: float = 0.0) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _part(parent: Node3D, at: Vector3, size: Vector3, material: Material,
		solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = GameConfig.LAYER_WORLD
		body.position = at
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
	return mesh


static func _booth() -> Node3D:
	var root := Node3D.new()
	var panel := _material(&"booth_panel", Color(0.25, 0.3, 0.28))
	var trim := _material(&"booth_trim", Color(0.09, 0.13, 0.13), 0.65, 0.3)
	var inside := _material(&"booth_inside", Color(0.38, 0.34, 0.26))
	_part(root, Vector3(0.0, 0.06, 0.0), Vector3(2.2, 0.12, 2.1), inside, true)
	_part(root, Vector3(0.0, 2.55, 0.0), Vector3(2.5, 0.2, 2.4), trim, true)
	_part(root, Vector3(0.0, 1.25, -1.0), Vector3(2.2, 2.5, 0.1), panel, true)
	# Window openings use separate wall segments, so light rays are not trapped inside a solid box.
	for side: float in [-1.0, 1.0]:
		_part(root, Vector3(side * 1.05, 0.55, 0.0), Vector3(0.1, 1.1, 2.0), panel, true)
		_part(root, Vector3(side * 1.05, 2.22, 0.0), Vector3(0.1, 0.45, 2.0), panel, true)
		for end: float in [-1.0, 1.0]:
			_part(root, Vector3(side * 1.05, 1.55, end * 0.92), Vector3(0.12, 1.0, 0.16), trim, true)
	_part(root, Vector3(-0.55, 0.55, 1.0), Vector3(1.0, 1.1, 0.1), panel, true)
	_part(root, Vector3(0.0, 2.22, 1.0), Vector3(2.2, 0.45, 0.1), trim, true)
	_part(root, Vector3(0.55, 1.15, 1.0), Vector3(1.05, 2.2, 0.12), panel, true)
	_part(root, Vector3(-0.55, 1.12, 1.08), Vector3(1.15, 0.06, 0.28), trim)
	_part(root, Vector3(-0.48, 0.85, 0.36), Vector3(1.0, 0.07, 0.65), inside)
	_part(root, Vector3(-0.48, 0.96, 0.2), Vector3(0.32, 0.18, 0.2), trim)
	_part(root, Vector3(0.87, 1.03, 1.09), Vector3(0.05, 0.08, 0.05), trim)
	_add_booth_light(root)
	_add_booth_sign(root)
	return root


static func _add_booth_light(root: Node3D) -> void:
	var light := OmniLight3D.new()
	light.name = "BoothLamp"
	light.position = Vector3(-0.4, 2.26, 0.1)
	light.light_color = Color(0.72, 0.86, 0.78)
	light.light_energy = BOOTH_LIGHT_ENERGY
	light.omni_range = BOOTH_LIGHT_RANGE
	light.shadow_enabled = true
	root.add_child(light)
	var bulb := _material(&"booth_bulb", Color(0.5, 0.66, 0.55))
	bulb.emission_enabled = true
	bulb.emission = Color(0.3, 0.5, 0.35)
	_part(root, light.position + Vector3.UP * 0.04, Vector3(0.55, 0.04, 0.16), bulb)


static func _add_booth_sign(root: Node3D) -> void:
	var sign := Label3D.new()
	sign.text = "WORLD_SECURITY_SIGN"
	sign.position = Vector3(0.0, 2.25, 1.065)
	sign.font_size = SIGN_FONT_SIZE
	sign.pixel_size = SIGN_PIXEL_SIZE
	sign.modulate = Color(0.7, 0.75, 0.65)
	sign.outline_size = 4
	root.add_child(sign)


static func _dumpster() -> Node3D:
	var root := Node3D.new()
	var green := _material(&"dumpster_green", Color(0.12, 0.21, 0.18), 0.8, 0.35)
	var steel := _material(&"dumpster_steel", Color(0.12, 0.14, 0.14), 0.65, 0.55)
	var rust := _material(&"dumpster_rust", Color(0.3, 0.16, 0.08))
	_part(root, Vector3(0.0, 0.77, 0.0), Vector3(2.15, 1.15, 1.15), green, true)
	for side: float in [-1.0, 1.0]:
		var lid := _part(root, Vector3(side * 0.56, 1.4, 0.0), Vector3(1.12, 0.09, 1.3), steel)
		lid.rotation.z = side * 0.06
		_part(root, Vector3(side * 1.1, 0.93, 0.0), Vector3(0.14, 0.08, 0.42), steel)
		for end: float in [-1.0, 1.0]:
			_part(root, Vector3(side * 0.78, 0.14, end * 0.4), Vector3(0.18, 0.25, 0.16), steel)
	for index in 5:
		_part(root, Vector3(-0.85 + index * 0.42, 0.77, 0.59), Vector3(0.06, 0.95, 0.04), green)
	_part(root, Vector3(-0.61, 0.37, 0.601), Vector3(0.6, 0.13, 0.006), rust)
	_part(root, Vector3(0.55, 0.53, 0.601), Vector3(0.27, 0.32, 0.006), rust)
	return root


static func _pallets() -> Node3D:
	var root := Node3D.new()
	var wood := _material(&"pallet_wood", Color(0.29, 0.22, 0.14))
	var faded := _material(&"pallet_faded", Color(0.38, 0.31, 0.2))
	for layer in 3:
		var height := layer * 0.16
		for runner: float in [-0.45, 0.0, 0.45]:
			_part(root, Vector3(runner, height + 0.05, 0.0), Vector3(0.12, 0.1, 1.1), wood)
		for plank in 5:
			_part(root, Vector3(0.0, height + 0.13, -0.44 + plank * 0.22),
				Vector3(1.25, 0.05, 0.15), faded if plank % 2 == 0 else wood)
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SIZES["palletStack"]
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	body.add_child(collision)
	root.add_child(body)
	return root


static func _patch(id: String) -> Node3D:
	var root := Node3D.new()
	var size := SIZES[id]
	var wet := id == "puddle"
	var material: Material = _material(&"oil", Color(0.018, 0.019, 0.022), 0.42, 0.1)
	if wet:
		if _water_material == null:
			_water_material = ShaderMaterial.new()
			_water_material.shader = WATER_SHADER
		material = _water_material
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in PATCH_RADII.size():
		var next := (index + 1) % PATCH_RADII.size()
		for vertex: Vector3 in [Vector3.ZERO, _patch_edge(index, size), _patch_edge(next, size)]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x / size.x + 0.5, vertex.z / size.z + 0.5))
			surface.add_vertex(vertex + Vector3.UP * PATCH_HEIGHT)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


static func _patch_edge(index: int, size: Vector3) -> Vector3:
	var angle := TAU * index / PATCH_RADII.size()
	return Vector3(cos(angle) * size.x, 0.0, sin(angle) * size.z) * PATCH_RADII[index] * 0.5


static func _crack() -> Node3D:
	var root := Node3D.new()
	var material := _material(&"crack", Color(0.012, 0.014, 0.016))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = [Vector2(-1.3, 0.2), Vector2(-0.8, 0.02), Vector2(-0.3, 0.14),
		Vector2(0.08, -0.16), Vector2(0.62, -0.05), Vector2(1.3, -0.35)]
	for index in points.size() - 1:
		_crack_segment(surface, points[index], points[index + 1], 0.018 + (index % 2) * 0.009)
	_crack_segment(surface, points[2], Vector2(-0.15, 0.48), 0.014)
	_crack_segment(surface, points[4], Vector2(0.8, 0.35), 0.014)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


static func _crack_segment(surface: SurfaceTool, start: Vector2, end: Vector2, width: float) -> void:
	var direction := (end - start).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var corners: Array[Vector2] = [start - side, start + side, end + side, end - side]
	for index: int in [0, 2, 1, 0, 3, 2]:
		var point := corners[index]
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x, PATCH_HEIGHT, point.y))
