class_name RoundManager
extends Node
## One round: a countdown, a quota and the value loaded into the van so far.
## The host decides everything and tells every peer; clients only count the
## clock down locally between messages.

signal round_started(duration_sec: float, quota: int)
signal collected_changed(collected: int, quota: int)
signal round_ended(success: bool, collected: int, quota: int)
signal time_expired

enum Phase { WAITING, ARRIVING, PLAYING, DEPARTING, ENDED }
enum EndReason { TIME_UP, ALL_COLLECTED, ALL_DEAD, TEAM_LEFT, DRIVER_LEFT }

## Translation key per EndReason, shown on the results screen.
const END_REASON_KEYS: Array[String] = [
	"ROUND_REASON_TIME_UP",
	"ROUND_REASON_ALL_COLLECTED",
	"ROUND_REASON_ALL_DEAD",
	"ROUND_REASON_TEAM_LEFT",
	"ROUND_REASON_DRIVER_LEFT",
]

@export var duration_sec: float = GameConfig.ROUND_DURATION_SEC

var phase: Phase = Phase.WAITING
var quota: int = 0
var collected: int = 0
var time_left: float = 0.0
var success: bool = false
var end_reason: EndReason = EndReason.TIME_UP
var survivors: int = 0
var left_names: Array[String] = []


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and multiplayer.is_server():
		time_expired.emit()


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
func finish(reason: EndReason, survivor_count: int = 0, abandoned: Array[String] = []) -> void:
	if not multiplayer.is_server() or (phase != Phase.PLAYING and phase != Phase.DEPARTING):
		return
	var was_success := collected >= quota and reason != EndReason.ALL_DEAD and survivor_count > 0
	_end.rpc(was_success, collected, quota, reason, survivor_count, abandoned)


func get_end_reason_key() -> String:
	return END_REASON_KEYS[end_reason]


@rpc("authority", "call_local", "reliable")
func _begin(duration: float, quota_value: int) -> void:
	phase = Phase.ARRIVING
	duration_sec = duration
	time_left = duration
	quota = quota_value
	collected = 0
	success = false
	collected_changed.emit(collected, quota)


@rpc("authority", "call_local", "reliable")
func begin_playing() -> void:
	phase = Phase.PLAYING
	round_started.emit(duration_sec, quota)


@rpc("authority", "call_local", "reliable")
func begin_departing() -> void:
	phase = Phase.DEPARTING


@rpc("authority", "call_local", "reliable")
func _set_collected(value: int) -> void:
	collected = value
	collected_changed.emit(collected, quota)


# Final numbers travel with the message so every screen shows the same result.
@rpc("authority", "call_local", "reliable")
func _end(was_success: bool, collected_value: int, quota_value: int, reason: int, survivor_count: int, abandoned: Array[String]) -> void:
	phase = Phase.ENDED
	end_reason = clampi(reason, 0, END_REASON_KEYS.size() - 1) as EndReason
	success = was_success
	collected = collected_value
	quota = quota_value
	survivors = survivor_count
	left_names.assign(abandoned)
	time_left = 0.0
	round_ended.emit(success, collected, quota)
