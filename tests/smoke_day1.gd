extends Node
## Headless single-player smoke test (offline peer acts as host). Run from the project folder:
##   godot --headless --path . res://tests/smoke_day1.tscn
## Prints PASS/FAIL per check and exits with code 0 only if all pass.

const LEVEL_SCENE: PackedScene = preload("res://levels/greybox_01/greybox_01.tscn")

var _failures: int = 0


func _ready() -> void:
	await _run()
	print("SMOKE DAY 1: %s (%d failed)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	_check(GameConfig.MIN_PLAYERS == 2 and GameConfig.MAX_PLAYERS == 4, "player limits are 2..4")
	_check_translations()

	# Offline peer acts as host (id 1); register it so the level spawns one player.
	Net.players[1] = "Tester"
	var level := LEVEL_SCENE.instantiate() as GreyboxLevel
	add_child(level)
	await _physics_frames(30)

	var player := level.get_player()
	_check(player != null, "player spawned")
	if player == null:
		return
	_check(player.is_on_floor(), "player stands on the ground")
	_check(level.get_player_spawns().size() == GameConfig.MAX_PLAYERS, "one spawn point per max player")
	_check(level.get_doors().size() == 17, "17 doors built (got %d)" % level.get_doors().size())
	_check(level.get_items().size() == 15, "15 items spawned (got %d)" % level.get_items().size())

	await _check_walking(player)
	await _check_door(player, level.get_doors()[0])
	await _check_item(player, level.get_item(0), level.get_item(14))
	_check_flashlight(player)


func _check_translations() -> void:
	TranslationServer.set_locale("vi")
	_check(tr("ITEM_RADIO") == "Radio cũ", "Vietnamese translation loaded")
	_check(tr("HUD_PICK_UP").format({"item": tr("ITEM_LAMP")}) == "[E] Nhặt Đèn bàn", "placeholder format works")
	TranslationServer.set_locale(GameConfig.DEFAULT_LOCALE)
	_check(tr("ITEM_RADIO") == "Old radio", "English translation loaded")


func _check_walking(player: Player) -> void:
	var start := player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _physics_frames(45)
	Input.action_release(InputActions.MOVE_FORWARD)
	var moved := start.distance_to(player.global_position)
	_check(moved > 1.0, "player walks forward (moved %.2f m)" % moved)


func _check_door(player: Player, door: Door) -> void:
	door.request_set_open(true)
	await _physics_frames(10)
	_check(not door.is_open, "host refuses a door request from far away")
	_teleport(player, door.global_position + Vector3(1.5, 0.1, 0.5))
	await _physics_frames(5)
	door.request_set_open(true)
	await _physics_frames(45)
	_check(door.is_open and door.get_swing_angle_deg() > 80.0,
		"door opens (angle %.1f)" % door.get_swing_angle_deg())
	door.request_set_open(false)
	await _physics_frames(45)
	_check(not door.is_open and absf(door.get_swing_angle_deg()) < 1.0, "door closes")


func _check_item(player: Player, item: Item, far_item: Item) -> void:
	item.request_pick_up()
	await _physics_frames(5)
	_check(not item.is_held(), "host refuses a pick-up from far away")
	var spot := item.global_position
	_teleport(player, Vector3(spot.x + 1.5, 0.1, spot.z + 1.0))
	await _physics_frames(5)
	item.request_pick_up()
	await _physics_frames(5)
	var hold_point := player.get_hold_point()
	_check(player.held_item == item and item.freeze and item.holder_id == player.get_peer_id(),
		"item picked up and frozen")
	_check(item.global_position.distance_to(hold_point.global_position) < 0.05, "held item follows hold point")
	far_item.request_pick_up()
	await _physics_frames(5)
	_check(player.held_item == item and not far_item.is_held(), "cannot hold two items")
	player.drop_held_item()
	await _physics_frames(60)
	_check(player.held_item == null and not item.freeze and not item.is_held(), "item dropped")
	_check(item.global_position.y > -0.5, "dropped item stays above ground")
	_check(item.synced_transform.is_equal_approx(item.global_transform), "host publishes the resting transform")


func _teleport(player: Player, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


func _check_flashlight(player: Player) -> void:
	var was_on := player.is_flashlight_on()
	player.toggle_flashlight()
	_check(player.is_flashlight_on() != was_on, "flashlight toggles")


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
