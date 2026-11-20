class_name Footsteps
extends AudioStreamPlayer3D
## Plays steps at a walking rhythm while this node moves along the ground. It only
## watches its own position, so it works the same for the local player and for
## remote players moved by the synchronizer.

## Anything faster than this in one frame is a teleport/respawn, not walking.
const TELEPORT_DISTANCE: float = 3.0
const MAX_VERTICAL_SPEED: float = 1.5
## Smooths the speed estimate; remote positions arrive in network-sized jumps.
const SPEED_SMOOTHING: float = 0.2

## Seconds between steps: a calm walk, a jog, a run. Steps are paced in time
## like a real gait, not every fixed distance (that machine-guns when running).
@export var crouch_step_sec: float = 0.62
@export var walk_step_sec: float = 0.5
@export var sprint_step_sec: float = 0.36
@export var min_speed: float = 0.8
## Below this (crouch-walking) steps are quiet; above sprint_speed they are loud.
@export var quiet_speed: float = 2.5
@export var sprint_speed: float = 5.0
@export var quiet_volume_db: float = -28.0
@export var walk_volume_db: float = -18.0
@export var sprint_volume_db: float = -12.0
## Your own steps are heard all the time, so they are quieter than other players'.
@export var own_steps_offset_db: float = -8.0
## Other players' steps fade out over a room or two, not across the map.
@export var hearing_range: float = 18.0
@export var full_volume_range: float = 2.5

## Set when the owner dies.
var muted: bool = false
## Vehicle motion is not movement on foot, including for remote players.
var boarded: bool = false
## Set for the local player's own footsteps.
var is_own: bool = false
## Counted for tests.
var steps_played: int = 0

var _last_position: Vector3 = Vector3.ZERO
var _since_step: float = 0.0
var _speed: float = 0.0


func _ready() -> void:
	stream = Sfx.footstep()
	_last_position = global_position
	max_distance = hearing_range
	unit_size = full_volume_range


func _physics_process(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if muted or boarded or delta <= 0.0:
		return
	var horizontal := Vector2(moved.x, moved.z).length()
	if horizontal > TELEPORT_DISTANCE:
		_since_step = 0.0
		return
	_speed = lerpf(_speed, horizontal / delta, SPEED_SMOOTHING)
	if _speed < min_speed or absf(moved.y) / delta > MAX_VERTICAL_SPEED:
		# Half a step "banked", so the first step comes soon after starting.
		_since_step = _step_interval() * 0.5
		return
	_since_step += delta
	if _since_step >= _step_interval():
		_since_step = 0.0
		_step()


func set_boarded(value: bool) -> void:
	if boarded == value:
		return
	boarded = value
	_since_step = 0.0
	_speed = 0.0
	if is_inside_tree():
		_last_position = global_position
	if boarded:
		stop()


func _step_interval() -> float:
	if _speed < quiet_speed:
		return crouch_step_sec
	return walk_step_sec if _speed < sprint_speed else sprint_step_sec


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
