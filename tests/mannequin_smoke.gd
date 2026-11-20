extends Node3D
## Isolated integration checks for light, lethal reach and movement-only music.

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const MONSTER_SCENE: PackedScene = preload("res://features/monster/mannequin.tscn")
const SETTLE_FRAMES: int = 30

var _failures: int = 0
var _caught: Array[int] = []
var _player: Player
var _helper: Player
var _monster: Mannequin
var _music: AudioStreamPlayer3D
var _lamp: OmniLight3D


func _ready() -> void:
	_add_block(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	_player = _add_player(1, Vector3(0.0, 0.0, 5.0))
	_helper = _add_player(2, Vector3(3.0, 0.0, 0.0))
	_set_torch(_helper, false)
	_monster = MONSTER_SCENE.instantiate() as Mannequin
	_monster.asleep_for = INF
	add_child(_monster)
	_monster.player_caught.connect(_on_caught)
	_music = _monster.get_node(^"Music") as AudioStreamPlayer3D
	await _frames(5)
	await _check_movement_music()
	await _check_lighting()
	await _check_lethal_reach()
	print("MANNEQUIN SMOKE: %s (%d failed)" % ["OK" if _failures == 0 else "FAILED", _failures])
	for child in get_children():
		child.queue_free()
	await _frames(SETTLE_FRAMES)
	Sfx.clear_cache()
	get_tree().quit(0 if _failures == 0 else 1)


func _check_movement_music() -> void:
	_set_torch(_player, false)
	_monster.hunting = true
	_monster.asleep_for = 0.0
	var start := _monster.global_position
	await _frames(8)
	_check(not _monster.is_seen and _monster.global_position.distance_to(start) > 0.2,
		"looking in darkness does not stop the chase")
	_check(_monster.is_moving() and _music.playing, "moving mannequin plays chase music")
	_set_torch(_player, true)
	await _frames(SETTLE_FRAMES)
	_check(_monster.is_seen and not _monster.is_moving() and not _music.playing,
		"flashlight freezes it and stops the music")
	var frozen := _monster.global_position
	await _frames(SETTLE_FRAMES)
	_check(_monster.global_position.distance_to(frozen) < 0.01, "lit watched mannequin stays still")
	var torch := _player.get_node(^"Head/Camera3D/Flashlight") as SpotLight3D
	torch.rotation.y = PI
	await _frames(8)
	_check(not _monster.is_seen and _music.playing, "torch pointing away cannot freeze it")
	torch.rotation = Vector3.ZERO
	_monster.move_speed = 0.0
	_monster.global_position = Vector3.ZERO
	await _frames(SETTLE_FRAMES)
	_check(not _music.playing, "stationary nearby mannequin has no music")
	_check(_music.max_distance > 6.0 and _music.unit_size > 1.0, "music has proximity attenuation")


func _check_lighting() -> void:
	_set_torch(_player, false)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0.0, 2.0, 0.0)
	_lamp.light_energy = 0.6
	_lamp.omni_range = 6.0
	add_child(_lamp)
	_lamp.add_to_group(MannequinSight.LIGHT_GROUP)
	await _frames(3)
	_check(_monster.is_seen, "ceiling light lets a viewer freeze the mannequin")
	_lamp.visible = false
	await _frames(3)
	_check(not _monster.is_seen, "switched-off ceiling light cannot freeze it")
	_lamp.visible = true
	_lamp.light_energy = 0.001
	await _frames(3)
	_check(not _monster.is_seen, "almost extinguished light counts as darkness")
	_lamp.light_energy = 0.6
	_lamp.position = Vector3(3.0, 1.5, 0.0)
	var wall := _add_block(Vector3(1.5, 1.5, 0.0), Vector3(0.2, 3.0, 2.0))
	await _frames(3)
	_check(not _monster.is_seen, "light behind a wall cannot illuminate the visible body")
	wall.queue_free()
	await _frames(3)
	_check(_monster.is_seen, "unobstructed lamp illuminates it again")
	_lamp.visible = false
	_set_torch(_helper, true)
	_helper.rotation.y = PI * 0.5
	await _frames(3)
	_check(_monster.is_seen, "another living player's flashlight also counts")
	_helper.die()
	await _frames(3)
	_check(not _monster.is_seen, "a dead player's flashlight cannot freeze it")
	_set_torch(_player, true)
	var torch := _player.get_node(^"Head/Camera3D/Flashlight") as SpotLight3D
	var normal_range := torch.spot_range
	torch.spot_range = 1.0
	await _frames(3)
	_check(not _monster.is_seen, "flashlight cannot illuminate beyond its range")
	torch.spot_range = normal_range
	_player.rotation.y = PI
	_lamp.visible = true
	await _frames(3)
	_check(not _monster.is_seen, "light alone does not freeze it without a viewer")
	_player.rotation = Vector3.ZERO
	_lamp.visible = false


func _check_lethal_reach() -> void:
	_check(is_equal_approx(_monster.kill_range, 1.2)
		and is_equal_approx(_monster.kill_range, _monster.door_open_range), "kill reach matches 1.2 m door reach")
	_player.global_position = Vector3(0.0, 0.0, 1.3)
	_caught.clear()
	await _frames(3)
	_check(_caught.is_empty(), "outside 1.2 m is safe while it is frozen")
	_player.global_position.z = 1.1
	await _frames(3)
	_check(_monster.is_seen and _caught.has(1), "watched frozen mannequin still catches within 1.2 m")
	var wall := _add_block(Vector3(0.0, 1.5, 0.55), Vector3(2.0, 3.0, 0.1))
	await _frames(3)
	_caught.clear()
	await _frames(3)
	_check(_caught.is_empty(), "wall blocks lethal reach")
	wall.collision_layer = GameConfig.LAYER_DOORS
	await _frames(3)
	_check(_caught.is_empty(), "closed door panel blocks lethal reach")
	wall.queue_free()
	_monster.asleep_for = INF
	_caught.clear()
	await _frames(3)
	_check(_caught.is_empty(), "sleeping mannequin does not kill")
	_monster.asleep_for = 0.0
	_monster.hunting = false
	await _frames(3)
	_check(_caught.is_empty(), "mannequin does not kill after the round")
	_monster.hunting = true
	_player.global_position.y = 2.0
	await _frames(3)
	_check(_caught.is_empty(), "player on another floor is not caught")


func _add_player(peer_id: int, at: Vector3) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id)
	player.position = at
	add_child(player)
	player.set_physics_process(false)
	return player


func _set_torch(player: Player, enabled: bool) -> void:
	if player.is_flashlight_on() != enabled:
		player.toggle_flashlight()


func _add_block(at: Vector3, size: Vector3) -> StaticBody3D:
	var block := StaticBody3D.new()
	block.position = at
	block.collision_layer = GameConfig.LAYER_WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	block.add_child(collision)
	add_child(block)
	return block


func _on_caught(peer_id: int) -> void:
	_caught.append(peer_id)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
