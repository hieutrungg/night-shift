class_name Door
extends Node3D
## Hinged door. The root sits at the hinge on the floor; the panel extends
## along local +X. Rotates the Hinge node to open.

signal toggled(is_open: bool)

@export var open_angle_deg: float = 95.0
@export var swing_time: float = 0.45

var is_open: bool = false

var _tween: Tween

@onready var _hinge: Node3D = $Hinge
@onready var _interactable: Interactable = $Hinge/Panel/Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_update_prompt()


func set_open(open: bool) -> void:
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
	_update_prompt()
	toggled.emit(is_open)


func get_swing_angle_deg() -> float:
	return rad_to_deg(_hinge.rotation.y)


func _on_interacted(_player: Player) -> void:
	set_open(not is_open)


func _update_prompt() -> void:
	_interactable.prompt_key = "HUD_CLOSE_DOOR" if is_open else "HUD_OPEN_DOOR"
