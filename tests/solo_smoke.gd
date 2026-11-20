extends Node
## Headless test of solo mode, driven through the real menu entry point:
##   godot --headless --path . res://tests/solo_smoke.tscn
## Checks it stays offline, uses the solo tuning, pauses the world, ends when
## the player dies, restarts and returns to the menu.
## Headless Godot cannot capture the mouse, so the game sits on the pause
## screen; that is exactly what the pause checks need.

const MONSTER_SCENE: PackedScene = preload("res://features/monster/mannequin.tscn")
const MENU_SCENE_PATH: String = "res://ui/main_menu/main_menu.tscn"
const PAUSE_CHECK_FRAMES: int = 30
const LOAD_TIMEOUT_SEC: float = 15.0
const SHUTDOWN_FRAMES: int = 30

var _failures: int = 0


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		_relaunch_at_root()
		return
	# Keep running while the solo game pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("SOLO SMOKE: %s (%d failed)" % ["OK" if _failures == 0 else "FAILED", _failures])
	get_tree().unload_current_scene()
	for _frame in SHUTDOWN_FRAMES:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _relaunch_at_root() -> void:
	var runner := Node.new()
	runner.name = "SoloSmokeRunner"
	runner.set_script(get_script())
	get_tree().root.add_child.call_deferred(runner)


func _run() -> void:
	Net.start_solo("Solo")
	var level := await _wait_for_level(-1)
	_check(level != null, "solo match loads the level")
	if level == null:
		return
	_check(Net.is_solo and not Net.is_online() and Net.players.size() == 1, "solo is offline with one player")
	_check(not Net.can_start_game(), "online start rule (2-4 players) is untouched")
	var player := level.get_player()
	_check(player != null and player.is_local(), "solo player spawned and controlled locally")
	_check_tuning(level)
	await _check_pause(level)
	await _check_death_ends_round(level)
	await _check_restart_and_leave(level)


func _check_tuning(level: GreyboxLevel) -> void:
	var total := 0
	for item in level.get_items():
		total += item.data.value
	var steps := roundi(total * GameConfig.SOLO_QUOTA_RATIO / GameConfig.QUOTA_STEP)
	var expected := maxi(steps, 1) * GameConfig.QUOTA_STEP
	var round_manager := level.get_round()
	_check(round_manager.quota == expected, "solo quota %d (expected %d of $%d loot)" % [round_manager.quota, expected, total])
	var monster := level.get_monster()
	var reference := MONSTER_SCENE.instantiate() as Mannequin
	var base_speed := reference.move_speed
	reference.free()
	_check(monster != null and is_equal_approx(monster.move_speed, base_speed * GameConfig.SOLO_MONSTER_SPEED_SCALE),
		"solo mannequin is slower")
	_check(monster != null and monster.asleep_for > GameConfig.MONSTER_WAKE_DELAY_SEC, "solo mannequin sleeps longer")


func _check_pause(level: GreyboxLevel) -> void:
	var round_manager := level.get_round()
	await _frames(5)
	var time_before := round_manager.time_left
	await _frames(PAUSE_CHECK_FRAMES)
	_check(get_tree().paused, "pause screen freezes the solo world")
	_check(is_equal_approx(round_manager.time_left, time_before), "round clock stops while paused")


func _check_death_ends_round(level: GreyboxLevel) -> void:
	level.kill_player(1)
	await _frames(5)
	var round_manager := level.get_round()
	_check(round_manager.phase == RoundManager.Phase.ENDED
		and round_manager.end_reason == RoundManager.EndReason.ALL_DEAD, "dying alone ends the round")
	_check(not get_tree().paused, "results screen is not paused")


func _check_restart_and_leave(level: GreyboxLevel) -> void:
	var old_id := level.get_instance_id()
	level.restart_round()
	var next := await _wait_for_level(old_id)
	_check(next != null and Net.is_solo and next.get_round().is_playing(), "play again starts a new solo round")
	Net.return_to_menu()
	var at_menu := await _wait_until(func() -> bool:
		var scene := get_tree().current_scene
		return scene != null and scene.scene_file_path == MENU_SCENE_PATH, LOAD_TIMEOUT_SEC)
	_check(at_menu and not Net.is_solo and not get_tree().paused, "leaving returns to an unpaused menu")


## Waits for a ready level (different from `old_id`) whose round is running.
func _wait_for_level(old_id: int) -> GreyboxLevel:
	var ready := await _wait_until(func() -> bool:
		var level := get_tree().current_scene as GreyboxLevel
		return (level != null and level.get_instance_id() != old_id and level.is_node_ready()
			and level.get_player() != null and level.get_round().is_playing()), LOAD_TIMEOUT_SEC)
	return get_tree().current_scene as GreyboxLevel if ready else null


func _wait_until(condition: Callable, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var done: bool = condition.call()
		if done:
			return true
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
