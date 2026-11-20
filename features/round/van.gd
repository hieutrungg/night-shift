class_name Van
extends StaticBody3D
## The drop-off truck (Kenney Car Kit garbage truck, CC0). A player holding an item presses E on it;
## the host checks the request and reports the deposit with `item_deposited`.

## Host only.
signal item_deposited(item: Item, peer_id: int)

const TRUCK_SCENE: PackedScene = preload("res://assets/models/kenney_car_kit/garbage-truck.glb")
## The Car Kit is built smaller than real life.
const TRUCK_SCALE: float = 1.7

## Size of the truck's collision box; set from the model in _ready.
var size: Vector3 = Vector3.ZERO

## Set on every peer while a round is running.
var accepting: bool = false

var _truck: Node3D

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _interactable: Interactable = $Interactable
@onready var _deposit_sound: AudioStreamPlayer3D = $DepositSound
@onready var _horn_sound: AudioStreamPlayer3D = $HornSound


func _ready() -> void:
	_add_truck()
	_interactable.condition = _can_deposit
	_interactable.interacted.connect(_on_interacted)
	_deposit_sound.stream = Sfx.deposit()
	_horn_sound.stream = Sfx.horn()


## Local feedback; the level calls these on every peer.
func play_deposit() -> void:
	_deposit_sound.play()


func play_horn() -> void:
	_horn_sound.play()


## Asks the host to load the local player's held item into the van.
func request_deposit() -> void:
	_request_deposit.rpc_id(1)


## A spot on the ground 1 m in front of the truck's long side (towards -Z),
## close enough to load items from.
func approach_point() -> Vector3:
	var centre := global_transform * _collision.position
	return Vector3(centre.x, global_position.y + 0.1, centre.z - size.z * 0.5 - 1.0)


## Distance from a point to the van's box (0 inside it).
func distance_to(point: Vector3) -> float:
	var local := to_local(point) - _collision.position
	var half := size * 0.5
	var closest := local.clamp(-half, half)
	return local.distance_to(closest)


@rpc("any_peer", "call_local", "reliable")
func _request_deposit() -> void:
	if not multiplayer.is_server() or not accepting:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := Player.find_by_peer(get_tree(), sender)
	if player == null or player.is_dead or player.held_item == null:
		return
	if distance_to(player.global_position) > GameConfig.INTERACT_MAX_DISTANCE:
		return
	item_deposited.emit(player.held_item, sender)


func _can_deposit(player: Player) -> bool:
	return accepting and player.held_item != null


func _on_interacted(_player: Player) -> void:
	request_deposit()


## The truck lies along X (the van cells run left to right); the box shape
## is fitted to the model so players and the monster walk around it.
func _add_truck() -> void:
	_truck = TRUCK_SCENE.instantiate() as Node3D
	_truck.scale = Vector3.ONE * TRUCK_SCALE
	_truck.rotation.y = PI * 0.5
	add_child(_truck)
	PropFactory.weather(_truck)
	var box := _truck.transform * ModelBounds.local_aabb(_truck)
	size = box.size
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	_collision.position = box.get_center()
