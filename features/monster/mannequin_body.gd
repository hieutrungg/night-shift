class_name MannequinBody
extends Node3D
## The mannequin's visible body: the Quaternius base character with a plain
## plastic material, frozen in one of a few poses.
## Poses are written as directions in model space (the model faces +Z, its
## left hand is on +X), so they do not depend on how each bone's axes are set up.

const MODEL: PackedScene = preload("res://assets/models/quaternius_ubc/Superhero_Male_FullBody.gltf")
## Meshes that would give it a face; a mannequin has none.
const HIDDEN_MESHES: Array[String] = ["Eyes", "Eyebrows"]
const ARM_CHAINS: Dictionary[String, Array] = {
	"left": ["upperarm_l", "lowerarm_l", "hand_l"],
	"right": ["upperarm_r", "lowerarm_r", "hand_r"],
}

## Each pose: upper/lower arm direction per side, plus a head tilt (degrees,
## + leans to its left) and a head nod (degrees, + looks down).
const POSES: Array[Dictionary] = [
	{  # Standing still, arms hanging.
		"left": [Vector3(0.15, -1.0, 0.0), Vector3(0.1, -1.0, 0.05)],
		"right": [Vector3(-0.15, -1.0, 0.0), Vector3(-0.1, -1.0, 0.05)],
		"tilt": 0.0, "nod": 5.0,
	},
	{  # Both arms reaching for you.
		"left": [Vector3(0.15, -0.1, 1.0), Vector3(0.05, 0.0, 1.0)],
		"right": [Vector3(-0.15, -0.1, 1.0), Vector3(-0.05, 0.0, 1.0)],
		"tilt": 0.0, "nod": -5.0,
	},
	{  # One hand grabbing forward, head cocked.
		"left": [Vector3(0.2, -1.0, 0.1), Vector3(0.1, -1.0, 0.2)],
		"right": [Vector3(-0.2, 0.25, 1.0), Vector3(-0.05, 0.35, 1.0)],
		"tilt": -25.0, "nod": 0.0,
	},
	{  # Broken doll: elbow bent up, head snapped sideways.
		"left": [Vector3(0.35, -1.0, 0.25), Vector3(0.1, 0.2, 1.0)],
		"right": [Vector3(-0.1, -1.0, -0.1), Vector3(-0.1, -1.0, 0.1)],
		"tilt": 40.0, "nod": 15.0,
	},
]

@export var plastic_color: Color = Color(0.88, 0.84, 0.78)
## Pose applied when the body is ready (decoys keep it forever).
@export var start_pose: int = 0

var _model: Node3D
var _skeleton: Skeleton3D


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	_apply_material()
	set_pose(start_pose)


static func pose_count() -> int:
	return POSES.size()


func set_pose(index: int) -> void:
	if _skeleton == null:
		return
	_skeleton.reset_bone_poses()
	var pose: Dictionary = POSES[posmod(index, POSES.size())]
	for side: String in ARM_CHAINS.keys():
		var chain: Array = ARM_CHAINS[side]
		var directions: Array = pose[side]
		var upper: String = chain[0]
		var lower: String = chain[1]
		var hand: String = chain[2]
		var upper_direction: Vector3 = directions[0]
		var lower_direction: Vector3 = directions[1]
		_aim_bone(upper, lower, upper_direction)
		_aim_bone(lower, hand, lower_direction)
	var tilt: float = pose["tilt"]
	var nod: float = pose["nod"]
	_turn_bone("Head", Vector3.BACK, deg_to_rad(tilt))
	_turn_bone("Head", Vector3.RIGHT, deg_to_rad(nod))


func _apply_material() -> void:
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = plastic_color
	plastic.roughness = 0.35
	plastic.metallic_specular = 0.6
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.visible = not HIDDEN_MESHES.has(String(mesh.name))
		mesh.material_override = plastic


## Rotates `bone` so the line from it to `child` points along `direction`
## (model space). Parents must be posed first.
func _aim_bone(bone_name: String, child_name: String, direction: Vector3) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var child := _skeleton.find_bone(child_name)
	if bone < 0 or child < 0:
		return
	_skeleton.force_update_all_bone_transforms()
	var bone_global := _skeleton.get_bone_global_pose(bone)
	var current := (_skeleton.get_bone_global_pose(child).origin - bone_global.origin).normalized()
	var target := (_model_to_skeleton() * direction).normalized()
	_set_global_rotation(bone, Quaternion(current, target) * bone_global.basis.get_rotation_quaternion())


## Turns `bone` around a model-space axis.
func _turn_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone < 0 or is_zero_approx(angle):
		return
	_skeleton.force_update_all_bone_transforms()
	var bone_global := _skeleton.get_bone_global_pose(bone)
	var turn := Quaternion((_model_to_skeleton() * axis).normalized(), angle)
	_set_global_rotation(bone, turn * bone_global.basis.get_rotation_quaternion())


func _set_global_rotation(bone: int, global_rotation: Quaternion) -> void:
	var parent := _skeleton.get_bone_parent(bone)
	var parent_rotation := Quaternion.IDENTITY
	if parent >= 0:
		parent_rotation = _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * global_rotation).normalized())


## Converts a direction from the model root's space into skeleton space.
func _model_to_skeleton() -> Basis:
	var skeleton_in_model := _model.global_transform.affine_inverse() * _skeleton.global_transform
	return skeleton_in_model.basis.orthonormalized().inverse()
