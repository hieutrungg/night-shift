class_name GreyboxLevel
extends Node3D
## Builds a blockout level from an ASCII layout: one character = one cell.
## Subclasses override _get_layout() and _get_item_pool().
##
## Legend:
##   #  wall (full height)        .  indoor floor (has ceiling)
##   D  doorway with a door       L  indoor floor + ceiling light
##   i  indoor floor + item spawn ,  outdoor ground (no ceiling)
##   P  outdoor player spawn      V  van / drop-off area (placeholder)

enum RunKind { WALL, INDOOR, OUTDOOR }

const CELL: float = 1.0
const WALL_HEIGHT: float = 3.0
const CEILING_THICKNESS: float = 0.2
const DOOR_HEIGHT: float = 2.2
const BOUNDARY_HEIGHT: float = 6.0
const INDOOR_CHARS: String = ".DLi"

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const DOOR_SCENE: PackedScene = preload("res://features/doors/door.tscn")
const ITEM_SCENE: PackedScene = preload("res://features/items/item.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/hud.tscn")

@export var item_seed: int = 1

var _rows: PackedStringArray = []
var _player: Player = null
var _doors: Array[Door] = []
var _items: Array[Item] = []
var _player_spawns: Array[Vector3] = []
var _item_spawns: Array[Vector3] = []
var _van_cells: Array[Vector3] = []

var _geometry: Node3D
var _wall_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
var _ground_material: StandardMaterial3D
var _van_material: StandardMaterial3D


func _ready() -> void:
	_rows = _get_layout()
	if not _is_layout_valid():
		return
	_create_materials()
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)
	_build()
	_spawn_items()
	_spawn_local_player()


func get_player() -> Player:
	return _player


func get_doors() -> Array[Door]:
	return _doors


func get_items() -> Array[Item]:
	return _items


func get_player_spawns() -> Array[Vector3]:
	return _player_spawns


## Override: the ASCII rows of the level, all the same length.
func _get_layout() -> PackedStringArray:
	return PackedStringArray()


## Override: kinds of loot that can appear at item spawns.
func _get_item_pool() -> Array[ItemData]:
	return []


func _is_layout_valid() -> bool:
	if _rows.is_empty():
		push_error("Greybox layout is empty.")
		return false
	var width := _rows[0].length()
	for row in _rows.size():
		if _rows[row].length() != width:
			push_error("Layout row %d has length %d, expected %d." % [row, _rows[row].length(), width])
			return false
	return true


func _create_materials() -> void:
	_wall_material = _make_material(Color(0.55, 0.53, 0.48))
	_ceiling_material = _make_material(Color(0.35, 0.35, 0.35))
	_ground_material = _make_material(Color(0.18, 0.19, 0.17))
	_van_material = _make_material(Color(0.8, 0.8, 0.82))


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _build() -> void:
	var width := _rows[0].length()
	var depth := _rows.size()
	var size := Vector3(width * CELL, 0.2, depth * CELL)
	_add_block(Vector3(size.x * 0.5, -0.1, size.z * 0.5), size, _ground_material)
	_add_boundary(width, depth)
	_add_moon()
	for row in depth:
		_build_runs(row)
		for col in width:
			_build_cell(col, row, _rows[row][col])
	_build_van()


## Merges neighbouring cells of the same kind into one box to keep node count low.
func _build_runs(row: int) -> void:
	var line := _rows[row]
	var col := 0
	while col < line.length():
		var kind := _run_kind(line[col])
		var end := col
		while end + 1 < line.length() and _run_kind(line[end + 1]) == kind:
			end += 1
		_add_run(kind, row, col, end)
		col = end + 1


func _run_kind(cell: String) -> RunKind:
	if cell == "#":
		return RunKind.WALL
	if INDOOR_CHARS.contains(cell):
		return RunKind.INDOOR
	return RunKind.OUTDOOR


func _add_run(kind: RunKind, row: int, first_col: int, last_col: int) -> void:
	var length := (last_col - first_col + 1) * CELL
	var center_x := (first_col + last_col + 1) * CELL * 0.5
	var center_z := (row + 0.5) * CELL
	match kind:
		RunKind.WALL:
			_add_block(Vector3(center_x, WALL_HEIGHT * 0.5, center_z),
				Vector3(length, WALL_HEIGHT, CELL), _wall_material)
		RunKind.INDOOR:
			_add_block(Vector3(center_x, WALL_HEIGHT + CEILING_THICKNESS * 0.5, center_z),
				Vector3(length, CEILING_THICKNESS, CELL), _ceiling_material)
		RunKind.OUTDOOR:
			pass


func _build_cell(col: int, row: int, cell: String) -> void:
	var center := _cell_center(col, row)
	match cell:
		"D":
			_add_door(col, row)
		"L":
			_add_ceiling_light(center)
		"i":
			_item_spawns.append(center + Vector3.UP * 0.5)
		"P":
			_player_spawns.append(center + Vector3.UP * 0.1)
		"V":
			_van_cells.append(center)


func _cell_center(col: int, row: int) -> Vector3:
	return Vector3((col + 0.5) * CELL, 0.0, (row + 0.5) * CELL)


func _is_wall(col: int, row: int) -> bool:
	if row < 0 or row >= _rows.size() or col < 0 or col >= _rows[row].length():
		return false
	return _rows[row][col] == "#"


func _add_door(col: int, row: int) -> void:
	var door := DOOR_SCENE.instantiate() as Door
	var x0 := col * CELL
	var z0 := row * CELL
	if _is_wall(col - 1, row) and _is_wall(col + 1, row):
		# Walls left and right: the panel lies along X.
		door.position = Vector3(x0 + 0.05, 0.0, z0 + 0.5 * CELL)
	else:
		# Walls above and below: turn the panel to lie along Z.
		door.position = Vector3(x0 + 0.5 * CELL, 0.0, z0 + 0.05)
		door.rotation.y = -PI * 0.5
	add_child(door)
	_doors.append(door)
	var lintel_height := WALL_HEIGHT - DOOR_HEIGHT
	_add_block(_cell_center(col, row) + Vector3.UP * (DOOR_HEIGHT + lintel_height * 0.5),
		Vector3(CELL, lintel_height, CELL), _wall_material)


func _add_ceiling_light(center: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = center + Vector3.UP * (WALL_HEIGHT - 0.3)
	light.light_color = Color(1.0, 0.85, 0.65)
	light.light_energy = 0.6
	light.omni_range = 6.0
	light.shadow_enabled = true
	add_child(light)


func _add_moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.15
	moon.shadow_enabled = true
	add_child(moon)


func _build_van() -> void:
	if _van_cells.is_empty():
		return
	var center := Vector3.ZERO
	for cell in _van_cells:
		center += cell
	center /= _van_cells.size()
	var size := Vector3(_van_cells.size() * CELL, 2.0, 2.0)
	_add_block(center + Vector3.UP * size.y * 0.5, size, _van_material)


func _add_boundary(width: int, depth: int) -> void:
	var size_x := width * CELL
	var size_z := depth * CELL
	var half_height := BOUNDARY_HEIGHT * 0.5
	_add_collider(Vector3(size_x * 0.5, half_height, -0.5), Vector3(size_x, BOUNDARY_HEIGHT, 1.0))
	_add_collider(Vector3(size_x * 0.5, half_height, size_z + 0.5), Vector3(size_x, BOUNDARY_HEIGHT, 1.0))
	_add_collider(Vector3(-0.5, half_height, size_z * 0.5), Vector3(1.0, BOUNDARY_HEIGHT, size_z))
	_add_collider(Vector3(size_x + 0.5, half_height, size_z * 0.5), Vector3(1.0, BOUNDARY_HEIGHT, size_z))


func _add_block(center: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var body := _add_collider(center, size)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)


func _add_collider(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	_geometry.add_child(body)
	return body


func _spawn_items() -> void:
	var pool := _get_item_pool()
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = item_seed
	var items_root := Node3D.new()
	items_root.name = "Items"
	add_child(items_root)
	for spawn in _item_spawns:
		var item := ITEM_SCENE.instantiate() as Item
		item.data = pool[rng.randi_range(0, pool.size() - 1)]
		item.position = spawn
		items_root.add_child(item)
		_items.append(item)


## Day 1 only: one local player. Day 2 replaces this with networked spawning.
func _spawn_local_player() -> void:
	if _player_spawns.is_empty():
		push_error("Layout has no player spawn (P).")
		return
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = _player_spawns[0]
	add_child(_player)
	var hud := HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.bind_player(_player)
