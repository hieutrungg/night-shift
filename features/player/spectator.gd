class_name Spectator
extends Node
## Created on a peer whose player died: shows the view of a living player.
## Jump (Space) switches to the next one; if the watched player dies, it
## moves on by itself.

signal target_changed(target: Player)

var _target: Player = null


func _ready() -> void:
	_pick_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.JUMP):
		_pick_next()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var lost := _target != null and (not is_instance_valid(_target) or _target.is_dead)
	if lost or (_target == null and not _living_players().is_empty()):
		_pick_next()


func get_target() -> Player:
	return _target if is_instance_valid(_target) else null


func _pick_next() -> void:
	var candidates := _living_players()
	if candidates.is_empty():
		_set_target(null)
		return
	var index := candidates.find(get_target()) + 1
	_set_target(candidates[index % candidates.size()])


func _living_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player != null and not player.is_dead and not player.is_queued_for_deletion():
			result.append(player)
	result.sort_custom(func(a: Player, b: Player) -> bool: return a.get_peer_id() < b.get_peer_id())
	return result


func _set_target(target: Player) -> void:
	var previous := get_target()
	if previous == target and target != null:
		return
	if previous != null:
		previous.set_spectated(false)
	_target = target
	if target != null:
		target.set_spectated(true)
	target_changed.emit(target)
