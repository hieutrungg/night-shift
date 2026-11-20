class_name ExteriorBuilder
extends RefCounted
## Dresses the outside of a greybox level, all from primitives:
##   - building: parapet on the roof edge, dark plinth, boarded-up windows and a
##     sidewalk along every wall that faces outdoors; canopy, lamp and company
##     sign over every outside door
##   - lot: a chain-link fence around the outdoor area with a gate opposite
##     the entrance
## Built the same on every peer; nothing here moves.

const PARAPET_HEIGHT: float = 0.45
const PLINTH_HEIGHT: float = 0.6
const FACE_INSET: float = 0.04
const SIDEWALK_DEPTH: float = 1.4
const SIDEWALK_LIFT: float = 0.006
const WINDOW_SIZE: Vector2 = Vector2(1.3, 1.1)
const WINDOW_SILL: float = 1.0
## A window every this many cells along an outside wall, kept away from doors.
const WINDOW_EVERY: int = 5
const WINDOW_DOOR_GAP: int = 3
const BOARD_SIZE: Vector3 = Vector3(1.55, 0.14, 0.04)
const BOARD_ANGLE_DEG: float = 24.0
const CANOPY_SIZE: Vector3 = Vector3(3.2, 0.15, 1.6)
const CANOPY_HEIGHT: float = 2.65
const ENTRANCE_LIGHT_ENERGY: float = 0.9
const ENTRANCE_LIGHT_RANGE: float = 6.0
const SIGN_HEIGHT: float = 3.32
const SIGN_FONT_SIZE: int = 72
const SIGN_PIXEL_SIZE: float = 0.005
const FENCE_HEIGHT: float = 2.2
const FENCE_POST_EVERY: float = 2.5
const FENCE_POST_SIZE: float = 0.08
const FENCE_RAIL_SIZE: float = 0.05
## Size of one chain-link diamond, in metres.
const MESH_CELL: float = 0.25
const GATE_WIDTH: float = 5.0
const GATE_POST_SIZE: float = 0.16

const FACES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Lights created here (the level makes them flicker and lets them freeze the mannequin).
var lights: Array[Light3D] = []

var _rows: PackedStringArray
var _parent: Node3D
var _wall_height: float
var _outdoor_chars: String
var _materials: Dictionary[String, BaseMaterial3D] = {}


func _init(rows: PackedStringArray, parent: Node3D, wall_height: float, outdoor_chars: String,
		wall_material: BaseMaterial3D) -> void:
	_rows = rows
	_parent = parent
	_wall_height = wall_height
	_outdoor_chars = outdoor_chars
	_create_materials(wall_material)


func build(sign_key: String) -> void:
	_build_parapet()
	for row in _rows.size():
		for col in _rows[row].length():
			var cell := Vector2i(col, row)
			for face in FACES:
				if _is_building(cell) and _is_outdoor(cell + face):
					_dress_face(cell, face, sign_key)
	_build_fence()


func _create_materials(wall_material: BaseMaterial3D) -> void:
	var concrete := wall_material.duplicate() as BaseMaterial3D
	concrete.albedo_color = Color(0.42, 0.42, 0.4)
	_materials["concrete"] = concrete
	var plinth := wall_material.duplicate() as BaseMaterial3D
	plinth.albedo_color = Color(0.22, 0.21, 0.2)
	_materials["plinth"] = plinth
	_materials["glass"] = _plain(Color(0.02, 0.025, 0.035), 0.08, 0.4)
	_materials["wood"] = _plain(Color(0.28, 0.2, 0.13), 0.9, 0.0)
	_materials["metal"] = _plain(Color(0.32, 0.33, 0.35), 0.55, 0.7)
	_materials["mesh"] = _chain_link_material()


func _plain(colour: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material


## Diamond wire pattern drawn into a small texture; the holes are see-through.
func _chain_link_material() -> StandardMaterial3D:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in size:
		for width in 2:
			image.set_pixel((i + width) % size, i, Color(0.55, 0.57, 0.6, 1.0))
			image.set_pixel((size - 1 - i + width) % size, i, Color(0.55, 0.57, 0.6, 1.0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.6
	material.roughness = 0.5
	return material


func _is_outdoor(cell: Vector2i) -> bool:
	return _is_inside(cell) and _outdoor_chars.contains(_rows[cell.y][cell.x])


func _is_building(cell: Vector2i) -> bool:
	return _is_inside(cell) and not _outdoor_chars.contains(_rows[cell.y][cell.x])


func _is_inside(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < _rows.size() and cell.x >= 0 and cell.x < _rows[cell.y].length()


## A low wall along the roof edge, around the building's bounding box.
func _build_parapet() -> void:
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-1, -1)
	for row in _rows.size():
		for col in _rows[row].length():
			if _is_building(Vector2i(col, row)):
				low = Vector2i(mini(low.x, col), mini(low.y, row))
				high = Vector2i(maxi(high.x, col), maxi(high.y, row))
	if high.x < 0:
		return
	var y := _wall_height + PARAPET_HEIGHT * 0.5 + 0.2
	var width := float(high.x - low.x + 1)
	var depth := float(high.y - low.y + 1)
	var centre_x := low.x + width * 0.5
	var centre_z := low.y + depth * 0.5
	var concrete := _materials["concrete"]
	_box(Vector3(centre_x, y, low.y + 0.5), Vector3(width, PARAPET_HEIGHT, 1.0), concrete)
	_box(Vector3(centre_x, y, high.y + 0.5), Vector3(width, PARAPET_HEIGHT, 1.0), concrete)
	_box(Vector3(low.x + 0.5, y, centre_z), Vector3(1.0, PARAPET_HEIGHT, depth), concrete)
	_box(Vector3(high.x + 0.5, y, centre_z), Vector3(1.0, PARAPET_HEIGHT, depth), concrete)


## One building cell seen from outside through `face`.
func _dress_face(cell: Vector2i, face: Vector2i, sign_key: String) -> void:
	var normal := Vector3(face.x, 0.0, face.y)
	var along := Vector3(absf(normal.z), 0.0, absf(normal.x))
	var surface := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) + normal * 0.5
	var tile := _rows[cell.y][cell.x]
	if tile != "D":
		# Doorways stay open: no plinth across the threshold.
		_box(surface + normal * FACE_INSET * 0.5 + Vector3.UP * PLINTH_HEIGHT * 0.5,
			along + Vector3.UP * PLINTH_HEIGHT + normal.abs() * FACE_INSET, _materials["plinth"])
	_visual_box(surface + normal * SIDEWALK_DEPTH * 0.5 + Vector3.UP * SIDEWALK_LIFT,
		along + Vector3.UP * 0.01 + normal.abs() * SIDEWALK_DEPTH, _materials["concrete"])
	if tile == "D":
		_build_entrance(surface, normal, along, sign_key)
	elif tile == "#" and _wants_window(cell, along):
		_build_window(surface, normal, along)


func _wants_window(cell: Vector2i, along: Vector3) -> bool:
	var position_along := cell.x if along.x > 0.5 else cell.y
	if position_along % WINDOW_EVERY != 2:
		return false
	for offset in range(-WINDOW_DOOR_GAP, WINDOW_DOOR_GAP + 1):
		var step := Vector2i(offset, 0) if along.x > 0.5 else Vector2i(0, offset)
		var near := cell + step
		if _is_inside(near) and _rows[near.y][near.x] == "D":
			return false
	return true


## Black glass with two planks nailed across it.
func _build_window(surface: Vector3, normal: Vector3, along: Vector3) -> void:
	var centre := surface + normal * FACE_INSET + Vector3.UP * (WINDOW_SILL + WINDOW_SIZE.y * 0.5)
	_box(centre, along * WINDOW_SIZE.x + Vector3.UP * WINDOW_SIZE.y + normal.abs() * 0.03, _materials["glass"])
	for side: float in [-1.0, 1.0]:
		var board := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = BOARD_SIZE
		mesh.material = _materials["wood"]
		board.mesh = mesh
		var facing := Basis.looking_at(-normal)
		board.basis = facing * Basis(Vector3.BACK, deg_to_rad(BOARD_ANGLE_DEG * side))
		board.position = centre + normal * 0.04
		_parent.add_child(board)


func _build_entrance(surface: Vector3, normal: Vector3, along: Vector3, sign_key: String) -> void:
	var canopy_size := along * CANOPY_SIZE.x + Vector3.UP * CANOPY_SIZE.y + normal.abs() * CANOPY_SIZE.z
	_visual_box(surface + normal * CANOPY_SIZE.z * 0.5 + Vector3.UP * CANOPY_HEIGHT, canopy_size, _materials["metal"])
	var lamp := OmniLight3D.new()
	lamp.position = surface + normal * (CANOPY_SIZE.z * 0.5) + Vector3.UP * (CANOPY_HEIGHT - 0.25)
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = ENTRANCE_LIGHT_ENERGY
	lamp.omni_range = ENTRANCE_LIGHT_RANGE
	lamp.shadow_enabled = true
	_parent.add_child(lamp)
	lights.append(lamp)
	var sign := Label3D.new()
	sign.text = sign_key
	sign.font_size = SIGN_FONT_SIZE
	sign.pixel_size = SIGN_PIXEL_SIZE
	sign.modulate = Color(0.85, 0.8, 0.62)
	sign.outline_size = 10
	sign.outline_modulate = Color(0.05, 0.05, 0.05)
	sign.shaded = false
	sign.basis = Basis.looking_at(-normal)
	sign.position = surface + normal * 0.6 + Vector3.UP * SIGN_HEIGHT
	_parent.add_child(sign)


## Chain-link fence along every edge where the outdoor area meets the map edge,
## with a gate in the middle of the edge opposite the building.
func _build_fence() -> void:
	var width := _rows[0].length()
	var depth := _rows.size()
	var first_row := depth
	for row in depth:
		if _is_outdoor(Vector2i(0, row)) and _is_outdoor(Vector2i(width - 1, row)):
			first_row = mini(first_row, row)
	if first_row >= depth:
		return
	var inset := 0.3
	_fence_run(Vector3(inset, 0, first_row), Vector3(inset, 0, depth - inset))
	_fence_run(Vector3(width - inset, 0, first_row), Vector3(width - inset, 0, depth - inset))
	var gate_centre := width * 0.5
	var south := depth - inset
	_fence_run(Vector3(inset, 0, south), Vector3(gate_centre - GATE_WIDTH * 0.5, 0, south))
	_fence_run(Vector3(gate_centre + GATE_WIDTH * 0.5, 0, south), Vector3(width - inset, 0, south))
	_build_gate(Vector3(gate_centre, 0.0, south))


## A straight fence from `from` to `to`: posts, two rails, wire mesh, one collider.
func _fence_run(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var direction := (to - from) / length
	var across := Vector3(-direction.z, 0.0, direction.x)
	var posts := maxi(ceili(length / FENCE_POST_EVERY), 1)
	for i in posts + 1:
		var at := from + direction * (length * i / posts)
		_box(at + Vector3.UP * FENCE_HEIGHT * 0.5, Vector3(FENCE_POST_SIZE, FENCE_HEIGHT, FENCE_POST_SIZE), _materials["metal"])
	var middle := (from + to) * 0.5
	var rail := direction.abs() * length + Vector3.UP * FENCE_RAIL_SIZE + across.abs() * FENCE_RAIL_SIZE
	for height: float in [FENCE_HEIGHT - 0.05, 0.15]:
		_visual_box(middle + Vector3.UP * height, rail, _materials["metal"])
	var wire := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(length, FENCE_HEIGHT - 0.2)
	var material := (_materials["mesh"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.uv1_scale = Vector3(length / MESH_CELL, (FENCE_HEIGHT - 0.2) / MESH_CELL, 1.0)
	quad.material = material
	wire.mesh = quad
	wire.position = middle + Vector3.UP * (FENCE_HEIGHT * 0.5)
	wire.basis = Basis.looking_at(across) if across.length() > 0.5 else Basis.IDENTITY
	_parent.add_child(wire)
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = direction.abs() * length + Vector3.UP * FENCE_HEIGHT + across.abs() * 0.1
	shape.shape = box
	body.position = middle + Vector3.UP * FENCE_HEIGHT * 0.5
	body.add_child(shape)
	_parent.add_child(body)


## Two closed gate leaves between heavy posts.
func _build_gate(centre: Vector3) -> void:
	var half := GATE_WIDTH * 0.5
	for side: float in [-1.0, 1.0]:
		_box(centre + Vector3(half * side, (FENCE_HEIGHT + 0.3) * 0.5, 0.0),
			Vector3(GATE_POST_SIZE, FENCE_HEIGHT + 0.3, GATE_POST_SIZE), _materials["metal"])
	_fence_run(centre + Vector3(-half + 0.1, 0.0, 0.0), centre + Vector3(half - 0.1, 0.0, 0.0))
	_visual_box(centre + Vector3(0.0, FENCE_HEIGHT * 0.5, 0.0),
		Vector3(0.06, FENCE_HEIGHT - 0.1, 0.06), _materials["metal"])


## Box with collision (so the navmesh and players treat it as solid).
func _box(centre: Vector3, size: Vector3, material: BaseMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh.mesh = box_mesh
	body.add_child(mesh)
	_parent.add_child(body)


func _visual_box(centre: Vector3, size: Vector3, material: BaseMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh.mesh = box_mesh
	mesh.position = centre
	_parent.add_child(mesh)
