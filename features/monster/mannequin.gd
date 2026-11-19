class_name Mannequin
extends CharacterBody3D
## The mannequin: moves only while no living player can see it, and kills a
## player it reaches. Only the host runs this logic; clients show the position
## copied by the synchronizer.

## Host only.
signal player_caught(peer_id: int)

## Points on the body a player may see (feet, chest, head).
const SAMPLE_HEIGHTS: Array[float] = [0.3, 1.0, 1.7]
## Stops chasing a target this close; the kill check takes over.
const ARRIVE_DISTANCE: float = 0.05
const MAX_KILL_HEIGHT_DIFF: float = 1.5
## Remote positions arrive in steps; keep "moving" true briefly between them.
const MOVING_HOLD_SEC: float = 0.25
const MOVING_MIN_SPEED: float = 0.5

@export var move_speed: float = 7.0
## Horizontal distance at which it opens a closed door in its way.
@export var door_open_range: float = 1.2
@export var kill_range: float = 1.0
## Wider than the camera's real view so it never moves at the edge of the screen.
@export var seen_half_angle_deg: float = 60.0
@export var seen_max_distance: float = 40.0

## Set by the level while a round is running.
var hunting: bool = false
## Counts down only while hunting.
var asleep_for: float = GameConfig.MONSTER_WAKE_DELAY_SEC
## Host's latest answer to "does any living player see me?".
var is_seen: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _seen_cos: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _moving_for: float = 0.0
var _scrape_on: bool = false

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _scrape: AudioStreamPlayer3D = $Scrape


func _ready() -> void:
	_seen_cos = cos(deg_to_rad(seen_half_angle_deg))
	# Pass through door panels (they would wedge it); _open_nearby_doors opens them.
	collision_mask = GameConfig.LAYER_WORLD
	_scrape.stream = Sfx.mannequin_scrape()
	_last_position = global_position
	if not multiplayer.is_server():
		set_physics_process(false)


func _process(delta: float) -> void:
	# Runs on every peer from the synced position, so clients hear it too.
	var moved := global_position - _last_position
	_last_position = global_position
	moved.y = 0.0
	if delta > 0.0 and moved.length() / delta > MOVING_MIN_SPEED:
		_moving_for = MOVING_HOLD_SEC
	else:
		_moving_for = maxf(_moving_for - delta, 0.0)
	if is_moving() != _scrape_on:
		_scrape_on = is_moving()
		if _scrape_on:
			_scrape.play()
		else:
			_scrape.stop()


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	if hunting:
		asleep_for = maxf(asleep_for - delta, 0.0)
	is_seen = _is_seen_by_anyone()
	var can_move := is_awake() and not is_seen
	if can_move:
		_chase()
	move_and_slide()
	if can_move:
		_open_nearby_doors()
		_catch_players()


func is_awake() -> bool:
	return hunting and asleep_for <= 0.0


## True on every peer while it is visibly moving (drives sound and light flicker).
func is_moving() -> bool:
	return _moving_for > 0.0


func _chase() -> void:
	var target := _nearest_living_player()
	if target == null:
		return
	_agent.target_position = target.global_position
	var next := _agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < ARRIVE_DISTANCE:
		# No path yet (navigation map still syncing): head straight for the target.
		direction = target.global_position - global_position
		direction.y = 0.0
	if direction.length() < ARRIVE_DISTANCE:
		return
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	rotation.y = atan2(-direction.x, -direction.z)


func _nearest_living_player() -> Player:
	var nearest: Player = null
	var best := INF
	for player in _living_players():
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < best:
			best = distance
			nearest = player
	return nearest


func _living_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player != null and not player.is_dead and not player.is_queued_for_deletion():
			result.append(player)
	return result


func _is_seen_by_anyone() -> bool:
	var players := _living_players()
	var exclude: Array[RID] = [get_rid()]
	for player in players:
		exclude.append(player.get_rid())
	for player in players:
		if _is_seen_from(player.get_view_transform(), exclude):
			return true
	return false


func _is_seen_from(view: Transform3D, exclude: Array[RID]) -> bool:
	var forward := -view.basis.z
	var space := get_world_3d().direct_space_state
	for height in SAMPLE_HEIGHTS:
		var point := global_position + Vector3.UP * height
		var to_point := point - view.origin
		var distance := to_point.length()
		if distance > seen_max_distance or distance < 0.001:
			continue
		if forward.dot(to_point / distance) < _seen_cos:
			continue
		var query := PhysicsRayQueryParameters3D.create(view.origin, point)
		query.exclude = exclude
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _open_nearby_doors() -> void:
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if door == null or door.is_open:
			continue
		var offset := door.get_panel_position() - global_position
		offset.y = 0.0
		if offset.length() <= door_open_range:
			door.open_by_host()


func _catch_players() -> void:
	for player in _living_players():
		var offset := player.global_position - global_position
		if absf(offset.y) > MAX_KILL_HEIGHT_DIFF:
			continue
		offset.y = 0.0
		if offset.length() <= kill_range:
			player_caught.emit(player.get_peer_id())
