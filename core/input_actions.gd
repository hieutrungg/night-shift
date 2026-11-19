class_name InputActions
extends RefCounted
## Action names and their default keys. Registered in code so every agent
## sees the bindings in one readable place.

const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const JUMP: StringName = &"jump"
const SPRINT: StringName = &"sprint"
const CROUCH: StringName = &"crouch"
const INTERACT: StringName = &"interact"
const DROP: StringName = &"drop"
const FLASHLIGHT: StringName = &"flashlight"
const PAUSE: StringName = &"pause"


static func register_defaults() -> void:
	_add_key(MOVE_FORWARD, KEY_W)
	_add_key(MOVE_BACK, KEY_S)
	_add_key(MOVE_LEFT, KEY_A)
	_add_key(MOVE_RIGHT, KEY_D)
	_add_key(JUMP, KEY_SPACE)
	_add_key(SPRINT, KEY_SHIFT)
	_add_key(CROUCH, KEY_CTRL)
	_add_key(INTERACT, KEY_E)
	_add_key(DROP, KEY_G)
	_add_key(FLASHLIGHT, KEY_F)
	_add_key(PAUSE, KEY_ESCAPE)


static func _add_key(action: StringName, key: Key) -> void:
	# Skip actions that already exist so a binding set in the editor wins.
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
