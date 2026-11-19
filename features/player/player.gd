class_name Player
extends CharacterBody3D
## First-person controller: movement, mouse look, crouch, flashlight,
## interaction and carrying one item.
## The node is named after its peer id; that peer owns its movement and the
## MultiplayerSynchronizer copies it to everyone else.

signal held_item_changed(item: Item)
signal interact_prompt_changed(text: String)
signal died

const GROUP: StringName = &"players"

@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var crouch_speed: float = 1.8
@export var jump_velocity: float = 4.2
@export var acceleration: float = 12.0
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var max_look_pitch_deg: float = 85.0
@export var drop_distance: float = 0.6
@export var drop_push: float = 1.5

var held_item: Item = null
## Set on every peer by the host (see GreyboxLevel.kill_player).
var is_dead: bool = false
## Replicated so other players see us crouch.
var crouching: bool = false:
	set(value):
		crouching = value
		if is_node_ready():
			_apply_crouch_shape()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _head_stand_y: float = 0.0
var _capsule: CapsuleShape3D
var _current_prompt: String = ""
## Forces the prompt to be sent again, e.g. after the language changed.
var _prompt_dirty: bool = false
## The first motion event after capturing the mouse is a large warp jump.
var _skip_next_mouse_motion: bool = true

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _hold_point: Marker3D = $Head/Camera3D/HoldPoint
@onready var _nameplate: Label3D = $Nameplate
@onready var _sync: MultiplayerSynchronizer = $Sync
@onready var _footsteps: Footsteps = $Footsteps


func _enter_tree() -> void:
	add_to_group(GROUP)
	var peer_id := get_peer_id()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)


func _ready() -> void:
	_capsule = _collision.shape as CapsuleShape3D
	_head_stand_y = _head.position.y
	_interact_ray.add_exception(self)
	_nameplate.text = Net.players.get(get_peer_id(), "")
	_apply_crouch_shape()
	if is_multiplayer_authority():
		_setup_local()
	else:
		_setup_remote()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_dead:
			return
		if _skip_next_mouse_motion:
			_skip_next_mouse_motion = false
		else:
			_look(mouse_motion.relative)
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button and mouse_button.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
	elif event.is_action_pressed(InputActions.PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif is_dead:
		return
	elif event.is_action_pressed(InputActions.FLASHLIGHT):
		toggle_flashlight()
	elif event.is_action_pressed(InputActions.INTERACT):
		_try_interact()
	elif event.is_action_pressed(InputActions.DROP):
		drop_held_item()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	_update_crouch()
	_apply_movement(delta)
	_update_interact_prompt()


## Finds the player node of a peer, or null (left, not spawned yet).
static func find_by_peer(tree: SceneTree, peer_id: int) -> Player:
	for node in tree.get_nodes_in_group(GROUP):
		var player := node as Player
		if player != null and player.get_peer_id() == peer_id and not player.is_queued_for_deletion():
			return player
	return null


func get_peer_id() -> int:
	return String(name).to_int()


func is_local() -> bool:
	return is_multiplayer_authority()


func toggle_flashlight() -> void:
	_flashlight.visible = not _flashlight.visible


func is_flashlight_on() -> bool:
	return _flashlight.visible


## Stops sending our movement so nothing arrives for this node after the host
## despawns it (used before a new round).
func stop_syncing() -> void:
	_sync.public_visibility = false


## Where this player looks from; the host uses it for the monster's sight check.
func get_view_transform() -> Transform3D:
	return _camera.global_transform


## Runs on every peer when the host says this player died.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Hides the body, nameplate and flashlight for everyone.
	visible = false
	_collision.set_deferred(&"disabled", true)
	_interact_ray.enabled = false
	_footsteps.muted = true
	velocity = Vector3.ZERO
	if not _current_prompt.is_empty():
		_current_prompt = ""
		interact_prompt_changed.emit("")
	died.emit()


## Local only: look through this player's eyes while spectating them.
func set_spectated(spectated: bool) -> void:
	_camera.current = spectated
	_body_mesh.visible = not spectated
	_nameplate.visible = not spectated and not is_local()


func get_hold_point() -> Node3D:
	return _hold_point


## Called by Item on every peer once the host has decided who holds it.
func set_held_item(item: Item) -> void:
	if held_item == item:
		return
	held_item = item
	held_item_changed.emit(item)


## Asks the host to drop the held item in front of the camera.
func drop_held_item() -> void:
	if held_item == null:
		return
	var forward := -_camera.global_basis.z
	var distance := drop_distance
	# Don't push the item through a wall we are standing against.
	if _interact_ray.is_colliding():
		var hit_distance := _camera.global_position.distance_to(_interact_ray.get_collision_point())
		distance = minf(distance, maxf(hit_distance - 0.25, 0.1))
	var drop_transform := Transform3D(global_basis, _camera.global_position + forward * distance)
	held_item.request_drop(drop_transform, forward * drop_push)


func _setup_local() -> void:
	Settings.locale_changed.connect(_on_locale_changed)
	_camera.current = true
	_nameplate.visible = false
	_capture_mouse()


func _setup_remote() -> void:
	_camera.current = false
	_interact_ray.enabled = false
	set_process_unhandled_input(false)
	# Our own body is hidden from inside; other players should see and cast shadows.
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_nameplate.visible = true


func _capture_mouse() -> void:
	_skip_next_mouse_motion = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _look(relative: Vector2) -> void:
	var sensitivity := Settings.mouse_sensitivity
	rotate_y(-relative.x * sensitivity)
	var max_pitch := deg_to_rad(max_look_pitch_deg)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * sensitivity, -max_pitch, max_pitch)


func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(InputActions.JUMP) and not crouching:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_velocity := direction * _current_speed()
	var weight := clampf(acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target_velocity.x, weight)
	velocity.z = lerpf(velocity.z, target_velocity.z, weight)
	move_and_slide()


func _current_speed() -> float:
	if crouching:
		return crouch_speed
	if Input.is_action_pressed(InputActions.SPRINT):
		return sprint_speed
	return walk_speed


func _update_crouch() -> void:
	var wants_crouch := Input.is_action_pressed(InputActions.CROUCH)
	if wants_crouch == crouching:
		return
	if not wants_crouch and not _has_headroom():
		return  # Stay crouched under low ceilings.
	crouching = wants_crouch


func _apply_crouch_shape() -> void:
	var height := crouch_height if crouching else stand_height
	_capsule.height = height
	_collision.position.y = height * 0.5
	_body_mesh.scale.y = height / stand_height
	_body_mesh.position.y = height * 0.5
	_head.position.y = _head_stand_y - (stand_height - height)


func _has_headroom() -> bool:
	return not test_move(global_transform, Vector3.UP * (stand_height - crouch_height))


func _find_interactable() -> Interactable:
	if not _interact_ray.is_colliding():
		return null
	var collider := _interact_ray.get_collider() as Node
	if collider == null:
		return null
	return collider.get_node_or_null(^"Interactable") as Interactable


func _try_interact() -> void:
	var target := _find_interactable()
	if target != null:
		target.interact(self)


func _update_interact_prompt() -> void:
	var prompt := ""
	var target := _find_interactable()
	if target != null and target.can_interact(self):
		prompt = target.get_prompt_text()
	if prompt != _current_prompt or _prompt_dirty:
		_prompt_dirty = false
		_current_prompt = prompt
		interact_prompt_changed.emit(prompt)


func _on_locale_changed(_locale: String) -> void:
	_prompt_dirty = true
