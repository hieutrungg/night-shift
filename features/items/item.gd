class_name Item
extends RigidBody3D
## A loot object. While held it is frozen, has no collision and follows the
## holder's hold point. Set `data` before adding to the tree.

@export var data: ItemData

var holder: Player = null

var _follow_target: Node3D = null
var _default_layer: int = 1

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if data == null:
		data = ItemData.new()
	_default_layer = collision_layer
	_build_shape()
	_interactable.prompt_subject_key = data.name_key
	_interactable.condition = _can_be_picked_up_by
	_interactable.interacted.connect(_on_interacted)


func _physics_process(_delta: float) -> void:
	if _follow_target != null:
		global_transform = _follow_target.global_transform


func attach_to(player: Player, follow_target: Node3D) -> void:
	holder = player
	_follow_target = follow_target
	freeze = true
	collision_layer = 0
	_interactable.enabled = false


func detach(at: Transform3D, impulse: Vector3) -> void:
	holder = null
	_follow_target = null
	global_transform = at
	collision_layer = _default_layer
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	apply_central_impulse(impulse * mass)
	_interactable.enabled = true


func _build_shape() -> void:
	# Each instance gets its own mesh and shape so sizes don't leak between items.
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	material.roughness = 0.7
	var mesh := BoxMesh.new()
	mesh.size = data.size
	mesh.material = material
	_mesh_instance.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = data.size
	_collision.shape = shape
	mass = data.mass


func _can_be_picked_up_by(player: Player) -> bool:
	return holder == null and player.held_item == null


func _on_interacted(player: Player) -> void:
	player.pick_up(self)
