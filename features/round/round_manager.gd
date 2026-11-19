class_name RoundManager
extends Node
## One round: a countdown, a quota and the value loaded into the van so far.
## The host decides everything and tells every peer; clients only count the
## clock down locally between messages.

signal round_started(duration_sec: float, quota: int)
signal collected_changed(collected: int, quota: int)
signal round_ended(success: bool, collected: int, quota: int)

enum Phase { WAITING, PLAYING, ENDED }
enum EndReason { TIME_UP, ALL_COLLECTED, ALL_DEAD }

## Translation key per EndReason, shown on the results screen.
const END_REASON_KEYS: Array[String] = [
	"ROUND_REASON_TIME_UP",
	"ROUND_REASON_ALL_COLLECTED",
	"ROUND_REASON_ALL_DEAD",
]

@export var duration_sec: float = GameConfig.ROUND_DURATION_SEC

var phase: Phase = Phase.WAITING
var quota: int = 0
var collected: int = 0
var time_left: float = 0.0
var success: bool = false
var end_reason: EndReason = EndReason.TIME_UP


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and multiplayer.is_server():
		finish(EndReason.TIME_UP)


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


## Host only: ends the round now. A wiped-out team fails whatever it collected.
func finish(reason: EndReason) -> void:
	if not multiplayer.is_server() or phase != Phase.PLAYING:
		return
	var was_success := collected >= quota and reason != EndReason.ALL_DEAD
	_end.rpc(was_success, collected, quota, reason)


func get_end_reason_key() -> String:
	return END_REASON_KEYS[end_reason]


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
func _end(was_success: bool, collected_value: int, quota_value: int, reason: int) -> void:
	phase = Phase.ENDED
	end_reason = clampi(reason, 0, END_REASON_KEYS.size() - 1) as EndReason
	success = was_success
	collected = collected_value
	quota = quota_value
	time_left = 0.0
	round_ended.emit(success, collected, quota)
