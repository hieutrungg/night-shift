class_name Door
extends Node3D
## Hinged door. The root sits at the hinge on the floor; the panel extends
## along local +X. Rotates the Hinge node to open.
## The host decides: players ask with request_set_open(), the host checks
## distance and tells every peer the result.

signal toggled(is_open: bool)

const GROUP: StringName = &"doors"

@export var open_angle_deg: float = 95.0
@export var swing_time: float = 0.45

var is_open: bool = false

var _tween: Tween

@onready var _hinge: Node3D = $Hinge
@onready var _panel: Node3D = $Hinge/Panel
@onready var _interactable: Interactable = $Hinge/Panel/Interactable
@onready var _sound: AudioStreamPlayer3D = $Hinge/Panel/Sound
@onready var _frame_mesh: MeshInstance3D = $Frame
@onready var _panel_mesh: MeshInstance3D = $Hinge/PanelMesh


func _ready() -> void:
	add_to_group(GROUP)
	_frame_mesh.mesh = DoorModel.frame_mesh()
	_panel_mesh.mesh = DoorModel.panel_mesh()
	_interactable.interacted.connect(_on_interacted)
	_update_prompt()


## Asks the host to open or close the door for the local player.
func request_set_open(open: bool) -> void:
	_request_set_open.rpc_id(1, open)


## Host only: opens the door without a player request (the monster pushes it).
func open_by_host() -> void:
	if multiplayer.is_server() and not is_open:
		_apply_open.rpc(true)


## Centre of the panel (in the doorway while closed).
func get_panel_position() -> Vector3:
	return _panel.global_position


func get_swing_angle_deg() -> float:
	return rad_to_deg(_hinge.rotation.y)


# The wanted state (not "toggle") is sent so two players pressing at once
# don't cancel each other out.
@rpc("any_peer", "call_local", "reliable")
func _request_set_open(open: bool) -> void:
	if not multiplayer.is_server():
		return
	if open == is_open:
		return
	var player := Player.find_by_peer(get_tree(), multiplayer.get_remote_sender_id())
	if player == null or player.is_dead:
		return
	if player.global_position.distance_to(_panel.global_position) > GameConfig.INTERACT_MAX_DISTANCE:
		return
	_apply_open.rpc(open)


@rpc("authority", "call_local", "reliable")
func _apply_open(open: bool) -> void:
	_set_open(open)


func _set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	# Physics process mode keeps the AnimatableBody3D in sync with collisions.
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var target_angle := deg_to_rad(open_angle_deg) if is_open else 0.0
	_tween.tween_property(_hinge, "rotation:y", target_angle, swing_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sound.stream = Sfx.door_open() if is_open else Sfx.door_close()
	_sound.play()
	_update_prompt()
	toggled.emit(is_open)


func _on_interacted(_player: Player) -> void:
	request_set_open(not is_open)


func _update_prompt() -> void:
	_interactable.prompt_key = "HUD_CLOSE_DOOR" if is_open else "HUD_OPEN_DOOR"
