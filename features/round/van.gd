class_name Van
extends StaticBody3D
## The drop-off van (greybox box). A player holding an item presses E on it;
## the host checks the request and reports the deposit with `item_deposited`.

## Host only.
signal item_deposited(item: Item, peer_id: int)

@export var size: Vector3 = Vector3(4.0, 2.0, 2.0)
@export var color: Color = Color(0.8, 0.8, 0.82)

## Set on every peer while a round is running.
var accepting: bool = false

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	_interactable.condition = _can_deposit
	_interactable.interacted.connect(_on_interacted)


## Asks the host to load the local player's held item into the van.
func request_deposit() -> void:
	_request_deposit.rpc_id(1)


## Distance from a point to the van's box (0 inside it).
func distance_to(point: Vector3) -> float:
	var local := to_local(point)
	var half := size * 0.5
	var closest := local.clamp(-half, half)
	return local.distance_to(closest)


@rpc("any_peer", "call_local", "reliable")
func _request_deposit() -> void:
	if not multiplayer.is_server() or not accepting:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := Player.find_by_peer(get_tree(), sender)
	if player == null or player.held_item == null:
		return
	if distance_to(player.global_position) > GameConfig.INTERACT_MAX_DISTANCE:
		return
	item_deposited.emit(player.held_item, sender)


func _can_deposit(player: Player) -> bool:
	return accepting and player.held_item != null


func _on_interacted(_player: Player) -> void:
	request_deposit()
