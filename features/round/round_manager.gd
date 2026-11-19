class_name RoundManager
extends Node
## One round: a countdown, a quota and the value loaded into the van so far.
## The host decides everything and tells every peer; clients only count the
## clock down locally between messages.

signal round_started(duration_sec: float, quota: int)
signal collected_changed(collected: int, quota: int)
signal round_ended(success: bool, collected: int, quota: int)

enum Phase { WAITING, PLAYING, ENDED }

@export var duration_sec: float = GameConfig.ROUND_DURATION_SEC

var phase: Phase = Phase.WAITING
var quota: int = 0
var collected: int = 0
var time_left: float = 0.0
var success: bool = false


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and multiplayer.is_server():
		finish()


func is_playing() -> bool:
	return phase == Phase.PLAYING


## Host only.
func start(quota_value: int) -> void:
	if not multiplayer.is_server():
		return
	_begin.rpc(duration_sec, quota_value)


## Host only: adds the value of an item loaded into the van.
func add_collected(amount: int) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	_set_collected.rpc(collected + amount)


## Host only: ends the round now (time up, or nothing left to collect).
func finish() -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	_end.rpc(collected >= quota, collected, quota)


@rpc("authority", "call_local", "reliable")
func _begin(duration: float, quota_value: int) -> void:
	phase = Phase.PLAYING
	time_left = duration
	quota = quota_value
	collected = 0
	success = false
	round_started.emit(duration, quota)
	collected_changed.emit(collected, quota)


@rpc("authority", "call_local", "reliable")
func _set_collected(value: int) -> void:
	collected = value
	collected_changed.emit(collected, quota)


# Final numbers travel with the message so every screen shows the same result.
@rpc("authority", "call_local", "reliable")
func _end(was_success: bool, collected_value: int, quota_value: int) -> void:
	phase = Phase.ENDED
	success = was_success
	collected = collected_value
	quota = quota_value
	time_left = 0.0
	round_ended.emit(success, collected, quota)
