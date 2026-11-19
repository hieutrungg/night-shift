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
##   M  indoor floor + monster spawn

enum RunKind { WALL, INDOOR, OUTDOOR }

const CELL: float = 1.0
const WALL_HEIGHT: float = 3.0
const CEILING_THICKNESS: float = 0.2
const DOOR_HEIGHT: float = 2.2
const BOUNDARY_HEIGHT: float = 6.0
const INDOOR_CHARS: String = ".DLiM"

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const DOOR_SCENE: PackedScene = preload("res://features/doors/door.tscn")
const ITEM_SCENE: PackedScene = preload("res://features/items/item.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud/hud.tscn")
const VAN_SCENE: PackedScene = preload("res://features/round/van.tscn")
const MONSTER_SCENE: PackedScene = preload("res://features/monster/mannequin.tscn")
const VAN_HEIGHT: float = 2.0
const RESTART_FLUSH_FRAMES: int = 2
## Time for in-flight player movement packets to land before despawning.
const RESTART_SYNC_STOP_SEC: float = 0.25
## Navigation mesh sizes: multiples of the 0.25 m voxel; the radius must fit
## a 1-cell doorway.
const NAV_AGENT_RADIUS: float = 0.25
const NAV_AGENT_HEIGHT: float = 2.0
const NAV_MAX_CLIMB: float = 0.25

## 0 picks new loot every round; any other value repeats the same loot.
@export var item_seed: int = 0

var _rows: PackedStringArray = []
var _player: Player = null
var _hud: Hud = null
var _round: RoundManager
var _van: Van = null
var _players_root: Node3D
var _player_spawner: MultiplayerSpawner
var _items_root: Node3D
var _item_spawner: MultiplayerSpawner
var _monsters_root: Node3D
var _monster_spawner: MultiplayerSpawner
var _monster: Mannequin = null
var _spectator: Spectator = null
var _doors: Array[Door] = []
var _items: Array[Item] = []
var _player_spawns: Array[Vector3] = []
var _item_spawns: Array[Vector3] = []
var _van_cells: Array[Vector3] = []
var _monster_spawns: Array[Vector3] = []

var _navigation: NavigationRegion3D
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
	# Geometry sits under the navigation region so the host can bake it.
	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	add_child(_navigation)
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	_navigation.add_child(_geometry)
	_build()
	if multiplayer.is_server():
		_bake_navigation()
	_setup_round()
	_setup_item_spawning()
	_setup_monster_spawning()
	_setup_player_spawning()
	if multiplayer.is_server():
		Net.all_players_loaded.connect(_on_all_players_loaded, CONNECT_ONE_SHOT)
		Net.player_left.connect(_on_player_left)
	Net.report_level_loaded()


## The player controlled on this machine (null until spawned).
func get_player() -> Player:
	return _player


func get_players() -> Array[Player]:
	var result: Array[Player] = []
	for child in _players_root.get_children():
		var player := child as Player
		if player != null and not player.is_queued_for_deletion():
			result.append(player)
	return result


func get_doors() -> Array[Door]:
	return _doors


func get_items() -> Array[Item]:
	return _items


## Items are named by spawn index, the same on every peer.
func get_item(index: int) -> Item:
	return _items_root.get_node_or_null(NodePath("Item_%d" % index)) as Item


func get_player_spawns() -> Array[Vector3]:
	return _player_spawns


func get_round() -> RoundManager:
	return _round


## Null when the layout has no van cells.
func get_van() -> Van:
	return _van


## Null until the host spawned it (or when the layout has no M cell).
func get_monster() -> Mannequin:
	return _monster if is_instance_valid(_monster) else null


## Host only: kills a player (monster touch). Ends the round when nobody is left.
func kill_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := Player.find_by_peer(get_tree(), peer_id)
	if player == null or player.is_dead:
		return
	if player.held_item != null:
		player.held_item.force_release()
	_set_player_dead.rpc(peer_id)
	_end_round_if_all_dead()


## Host only: clears players and items on every peer, then reloads the level.
func restart_round() -> void:
	if not multiplayer.is_server():
		return
	_stop_player_sync.rpc()
	await get_tree().create_timer(RESTART_SYNC_STOP_SEC).timeout
	for root: Node in [_items_root, _players_root, _monsters_root]:
		for child in root.get_children():
			child.queue_free()
	# Despawn messages must reach clients while they still have this level,
	# otherwise they arrive for nodes the client already unloaded.
	for _frame in RESTART_FLUSH_FRAMES:
		await get_tree().process_frame
	Net.restart_match()


@rpc("authority", "call_local", "reliable")
func _stop_player_sync() -> void:
	if _player != null:
		_player.stop_syncing()


@rpc("authority", "call_local", "reliable")
func _set_player_dead(peer_id: int) -> void:
	var player := Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	player.die()
	if player == _player and _spectator == null:
		_spectator = Spectator.new()
		_spectator.name = "Spectator"
		add_child(_spectator)
		if _hud != null:
			_hud.bind_spectator(_spectator)


func _end_round_if_all_dead() -> void:
	for player in get_players():
		if not player.is_dead:
			return
	_round.finish(RoundManager.EndReason.ALL_DEAD)


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
		"M":
			_monster_spawns.append(center + Vector3.UP * 0.1)


func _cell_center(col: int, row: int) -> Vector3:
	return Vector3((col + 0.5) * CELL, 0.0, (row + 0.5) * CELL)


func _is_wall(col: int, row: int) -> bool:
	if row < 0 or row >= _rows.size() or col < 0 or col >= _rows[row].length():
		return false
	return _rows[row][col] == "#"


func _add_door(col: int, row: int) -> void:
	var door := DOOR_SCENE.instantiate() as Door
	# Stable names give every peer the same node path for door RPCs.
	door.name = "Door_%d_%d" % [col, row]
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
	var size := Vector3(_van_cells.size() * CELL, VAN_HEIGHT, 2.0 * CELL)
	_van = VAN_SCENE.instantiate() as Van
	_van.name = "Van"
	_van.size = size
	_van.color = _van_material.albedo_color
	_van.position = center + Vector3.UP * size.y * 0.5
	# Inside Geometry so the navigation mesh routes around it.
	_geometry.add_child(_van)


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


## The round node exists on every peer with the same path, so its RPCs reach
## everyone. The van follows the round: it only accepts loot while it runs.
func _setup_round() -> void:
	_round = RoundManager.new()
	_round.name = "Round"
	add_child(_round)
	_round.round_started.connect(_on_round_started)
	_round.round_ended.connect(_on_round_ended)
	if _van != null and multiplayer.is_server():
		_van.item_deposited.connect(_on_item_deposited)


## Items live under "Items". The host spawns them; the spawner builds the same
## item on every client from a small dictionary (index, kind, position).
func _setup_item_spawning() -> void:
	_items_root = Node3D.new()
	_items_root.name = "Items"
	add_child(_items_root)
	_item_spawner = MultiplayerSpawner.new()
	_item_spawner.name = "ItemSpawner"
	add_child(_item_spawner)
	_item_spawner.spawn_path = _item_spawner.get_path_to(_items_root)
	_item_spawner.spawn_function = _create_item
	_items_root.child_entered_tree.connect(_on_item_entered)
	_items_root.child_exiting_tree.connect(_on_item_exiting)


## Players live under "Players"; the host adds them and the spawner copies
## them to every client.
func _setup_player_spawning() -> void:
	_players_root = Node3D.new()
	_players_root.name = "Players"
	add_child(_players_root)
	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	add_child(_player_spawner)
	_player_spawner.spawn_path = _player_spawner.get_path_to(_players_root)
	_player_spawner.add_spawnable_scene(PLAYER_SCENE.resource_path)
	_players_root.child_entered_tree.connect(_on_player_entered)


func _on_all_players_loaded() -> void:
	var total_value := _spawn_all_items()
	_spawn_all_players()
	_spawn_monster()
	_round.start(_quota_for(total_value))


func _quota_for(total_value: int) -> int:
	var steps := roundi(total_value * GameConfig.QUOTA_RATIO / GameConfig.QUOTA_STEP)
	return maxi(steps, 1) * GameConfig.QUOTA_STEP


## Host only. Returns the total value of the spawned loot.
func _spawn_all_items() -> int:
	if not multiplayer.is_server():
		return 0
	var pool := _get_item_pool()
	if pool.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	if item_seed == 0:
		rng.randomize()
	else:
		rng.seed = item_seed
	var total_value := 0
	for index in _item_spawns.size():
		var kind := rng.randi_range(0, pool.size() - 1)
		total_value += pool[kind].value
		_item_spawner.spawn({
			"index": index,
			"kind": kind,
			"position": _item_spawns[index],
		})
	return total_value


func _create_item(spawn_data: Variant) -> Node:
	var info: Dictionary = spawn_data
	var index: int = info["index"]
	var kind: int = info["kind"]
	var spawn_position: Vector3 = info["position"]
	var pool := _get_item_pool()
	var item := ITEM_SCENE.instantiate() as Item
	item.name = "Item_%d" % index
	item.data = pool[clampi(kind, 0, pool.size() - 1)]
	item.position = spawn_position
	return item


func _on_item_entered(node: Node) -> void:
	var item := node as Item
	if item != null:
		_items.append(item)


func _on_item_exiting(node: Node) -> void:
	var item := node as Item
	if item != null:
		_items.erase(item)


func _on_item_deposited(item: Item, _peer_id: int) -> void:
	if not multiplayer.is_server() or not _round.is_playing():
		return
	_round.add_collected(item.data.value)
	item.consume()
	if _count_items_left() == 0:
		_round.finish(RoundManager.EndReason.ALL_COLLECTED)


func _count_items_left() -> int:
	var count := 0
	for item in _items:
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			count += 1
	return count


func _on_round_started(_duration_sec: float, _quota: int) -> void:
	if _van != null:
		_van.accepting = true
	if get_monster() != null:
		_monster.hunting = true


func _on_round_ended(_success: bool, _collected: int, _quota: int) -> void:
	if _van != null:
		_van.accepting = false
	if get_monster() != null:
		_monster.hunting = false


func _spawn_all_players() -> void:
	if not multiplayer.is_server():
		return
	if _player_spawns.size() < GameConfig.MAX_PLAYERS:
		push_error("Layout needs %d player spawns (P)." % GameConfig.MAX_PLAYERS)
		return
	var peer_ids: Array[int] = []
	peer_ids.assign(Net.players.keys())
	peer_ids.sort()
	for index in peer_ids.size():
		var player := PLAYER_SCENE.instantiate() as Player
		player.name = str(peer_ids[index])
		player.position = _player_spawns[index]
		_players_root.add_child(player, true)


func _on_player_left(peer_id: int) -> void:
	for item in _items:
		if is_instance_valid(item) and item.holder_id == peer_id:
			item.force_release()
	var player := _players_root.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()
	if _round.is_playing():
		_end_round_if_all_dead()


func _on_player_entered(node: Node) -> void:
	var player := node as Player
	if player == null or player.get_peer_id() != multiplayer.get_unique_id():
		return
	_player = player
	if _hud == null:
		_hud = HUD_SCENE.instantiate() as Hud
		add_child(_hud)
		_hud.play_again_requested.connect(restart_round)
	# Wait until the player's own _ready has run so its nodes exist.
	if not player.is_node_ready():
		await player.ready
	_hud.bind_player(player)
	_hud.bind_round(_round)


## Host only: walkable areas for the monster, baked from the static geometry.
func _bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = NAV_AGENT_RADIUS
	mesh.agent_height = NAV_AGENT_HEIGHT
	mesh.agent_max_climb = NAV_MAX_CLIMB
	_navigation.navigation_mesh = mesh
	_navigation.bake_navigation_mesh(false)


func _setup_monster_spawning() -> void:
	_monsters_root = Node3D.new()
	_monsters_root.name = "Monsters"
	add_child(_monsters_root)
	_monster_spawner = MultiplayerSpawner.new()
	_monster_spawner.name = "MonsterSpawner"
	add_child(_monster_spawner)
	_monster_spawner.spawn_path = _monster_spawner.get_path_to(_monsters_root)
	_monster_spawner.add_spawnable_scene(MONSTER_SCENE.resource_path)
	_monsters_root.child_entered_tree.connect(_on_monster_entered)


## Host only. MVP: one mannequin at the first M cell.
func _spawn_monster() -> void:
	if not multiplayer.is_server() or _monster_spawns.is_empty():
		return
	var monster := MONSTER_SCENE.instantiate() as Mannequin
	monster.name = "Mannequin"
	monster.position = _monster_spawns[0]
	monster.player_caught.connect(kill_player)
	_monsters_root.add_child(monster, true)


func _on_monster_entered(node: Node) -> void:
	var monster := node as Mannequin
	if monster != null:
		_monster = monster
