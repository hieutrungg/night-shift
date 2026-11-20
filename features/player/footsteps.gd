class_name Footsteps
extends AudioStreamPlayer3D
## Plays a step every stride while this node moves along the ground. It only
## watches its own position, so it works the same for the local player and for
## remote players moved by the synchronizer.

## Anything faster than this in one frame is a teleport/respawn, not walking.
const TELEPORT_DISTANCE: float = 3.0
const MAX_VERTICAL_SPEED: float = 1.5
## Smooths the speed estimate; remote positions arrive in network-sized jumps.
const SPEED_SMOOTHING: float = 0.2

@export var stride_length: float = 0.8
@export var min_speed: float = 0.8
## Below this (crouch-walking) steps are quiet; above sprint_speed they are loud.
@export var quiet_speed: float = 2.5
@export var sprint_speed: float = 5.0
@export var quiet_volume_db: float = -20.0
@export var walk_volume_db: float = -10.0
@export var sprint_volume_db: float = -5.0
## Your own steps are heard all the time, so they are quieter than other players'.
@export var own_steps_offset_db: float = -6.0

## Set when the owner dies.
var muted: bool = false
## Set for the local player's own footsteps.
var is_own: bool = false
## Counted for tests.
var steps_played: int = 0

var _last_position: Vector3 = Vector3.ZERO
var _travelled: float = 0.0
var _speed: float = 0.0


func _ready() -> void:
	stream = Sfx.footstep()
	_last_position = global_position


func _physics_process(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if muted or delta <= 0.0:
		return
	var horizontal := Vector2(moved.x, moved.z).length()
	if horizontal > TELEPORT_DISTANCE:
		_travelled = 0.0
		return
	_speed = lerpf(_speed, horizontal / delta, SPEED_SMOOTHING)
	if _speed < min_speed or absf(moved.y) / delta > MAX_VERTICAL_SPEED:
		return
	_travelled += horizontal
	if _travelled >= stride_length:
		_travelled = 0.0
		_step()


func _step() -> void:
	if _speed < quiet_speed:
		volume_db = quiet_volume_db
	elif _speed < sprint_speed:
		volume_db = walk_volume_db
	else:
		volume_db = sprint_volume_db
	if is_own:
		volume_db += own_steps_offset_db
	play()
	steps_played += 1
