class_name Item
extends RigidBody3D
## A loot object, spawned by the host through the level's MultiplayerSpawner.
## The host decides who holds it and runs its physics; clients keep it frozen
## and copy `synced_transform`. While held it has no collision and every peer
## moves it to the holder's hold point locally (smoother than syncing it).

const NO_HOLDER: int = 0
## Caps the drop push a client may ask for.
const MAX_DROP_PUSH: float = 3.0
## Held loot is drawn smaller so big things (radio, speaker) do not cover the view.
const HELD_SCALE: float = 0.7
## Bulky loot stays bigger in hand: it is meant to be in the way.
const BULKY_HELD_SCALE: float = 0.85
## Loot glows faintly so it can be spotted in dark rooms (share of its colour).
const GLOW_ENERGY: float = 0.15

@export var data: ItemData

## Peer id of the player holding this item, or NO_HOLDER.
var holder_id: int = NO_HOLDER
## Written by the host while the item is loose; the synchronizer copies it.
var synced_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		synced_transform = value
		if is_inside_tree() and not multiplayer.is_server() and holder_id == NO_HOLDER:
			global_transform = value

var _follow_target: Node3D = null
## Holds the model so it can be shrunk while held without moving its centre.
var _visual: Node3D = null
var _default_layer: int = 1

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	if data == null:
		data = ItemData.new()
	_default_layer = collision_layer
	_build_shape()
	_interactable.prompt_subject_key = data.name_key
	_interactable.condition = _can_be_picked_up_by
	_interactable.interacted.connect(_on_interacted)
	if multiplayer.is_server():
		synced_transform = global_transform
	else:
		freeze = true


func _exit_tree() -> void:
	# Runs on every peer when the host frees the item (deposit, new round).
	if holder_id == NO_HOLDER:
		return
	var player := Player.find_by_peer(get_tree(), holder_id)
	if player != null and player.held_item == self:
		player.set_held_item(null)


func _physics_process(_delta: float) -> void:
	if holder_id != NO_HOLDER:
		if is_instance_valid(_follow_target):
			global_transform = _follow_target.global_transform
		return
	if multiplayer.is_server() and not global_transform.is_equal_approx(synced_transform):
		synced_transform = global_transform


func is_held() -> bool:
	return holder_id != NO_HOLDER


## Asks the host to give this item to the local player.
func request_pick_up() -> void:
	_request_pick_up.rpc_id(1)


## Asks the host to drop this item, placed at `at` and pushed by `push`.
func request_drop(at: Transform3D, push: Vector3) -> void:
	_request_drop.rpc_id(1, at, push)


## Host only: removes the item from the match; the spawner removes it on clients.
func consume() -> void:
	if not multiplayer.is_server():
		return
	queue_free()


## Host only: drop the item where it is, e.g. when its holder disconnects.
func force_release() -> void:
	if not multiplayer.is_server() or holder_id == NO_HOLDER:
		return
	_release.rpc(global_transform, Vector3.ZERO)


@rpc("any_peer", "call_local", "reliable")
func _request_pick_up() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := Player.find_by_peer(get_tree(), sender)
	# First request wins: a second player asking for the same item is refused here.
	if player == null or player.is_dead or holder_id != NO_HOLDER or player.held_item != null:
		return
	if player.global_position.distance_to(global_position) > GameConfig.INTERACT_MAX_DISTANCE:
		return
	_set_holder.rpc(sender)


@rpc("any_peer", "call_local", "reliable")
func _request_drop(at: Transform3D, push: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if holder_id != sender:
		return
	var player := Player.find_by_peer(get_tree(), sender)
	if player != null and player.global_position.distance_to(at.origin) > GameConfig.INTERACT_MAX_DISTANCE:
		at.origin = player.get_hold_point().global_position
	_release.rpc(at, push.limit_length(MAX_DROP_PUSH))


@rpc("authority", "call_local", "reliable")
func _set_holder(peer_id: int) -> void:
	var player := Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	holder_id = peer_id
	_follow_target = player.get_hold_point(data.bulky)
	freeze = true
	collision_layer = 0
	_interactable.enabled = false
	player.set_held_item(self)
	_set_visual_scale(BULKY_HELD_SCALE if data.bulky else HELD_SCALE)
	_sound.stream = Sfx.pickup()
	_sound.play()


@rpc("authority", "call_local", "reliable")
func _release(at: Transform3D, push: Vector3) -> void:
	var player := Player.find_by_peer(get_tree(), holder_id)
	holder_id = NO_HOLDER
	_follow_target = null
	global_transform = at
	collision_layer = _default_layer
	_interactable.enabled = true
	if player != null and player.held_item == self:
		player.set_held_item(null)
	_sound.stream = Sfx.item_drop()
	_set_visual_scale(1.0)
	_sound.play()
	if not multiplayer.is_server():
		return
	synced_transform = at
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	apply_central_impulse(push * mass)


func _build_shape() -> void:
	mass = data.mass
	# Each instance gets its own shape so sizes don't leak between items.
	var shape := BoxShape3D.new()
	_collision.shape = shape
	if data.model != null:
		shape.size = _add_model()
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	material.roughness = 0.7
	var mesh := BoxMesh.new()
	mesh.size = data.size
	mesh.material = material
	_mesh_instance.mesh = mesh
	shape.size = data.size


## Adds the loot model centred on the body (so it spins and is held around its
## middle) and returns the size of its box.
func _add_model() -> Vector3:
	var model := data.model.instantiate() as Node3D
	model.scale = Vector3.ONE * data.model_scale
	var box := ModelBounds.local_aabb(model)
	var scaled := AABB(box.position * model.scale, box.size * model.scale)
	model.position = -scaled.get_center()
	LootGlow.apply(model, GLOW_ENERGY)
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.add_child(model)
	add_child(_visual)
	return scaled.size


func _can_be_picked_up_by(player: Player) -> bool:
	return holder_id == NO_HOLDER and player.held_item == null


func _on_interacted(_player: Player) -> void:
	request_pick_up()


func _set_visual_scale(factor: float) -> void:
	if _visual != null:
		_visual.scale = Vector3.ONE * factor
