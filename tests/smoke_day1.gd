extends Node
## Headless single-player smoke test (offline peer acts as host). Run from the project folder:
##   godot --headless --path . res://tests/smoke_day1.tscn
## Prints PASS/FAIL per check and exits with code 0 only if all pass.

const LEVEL_SCENE: PackedScene = preload("res://levels/greybox_01/greybox_01.tscn")
## Ten seconds of physics for the mannequin to reach the next room.
const MONSTER_KILL_FRAMES: int = 600
const SHUTDOWN_FRAMES: int = 30
## Shrinks footprints slightly so touching a cell edge is not a clash.
const FOOTPRINT_TOLERANCE: float = 0.02
## A navmesh path must end this close to the loot spawn.
const PATH_END_TOLERANCE: float = 0.75
const MIN_DECOR_COUNT: int = 100
## Carrying bulky loot for this many frames must cover less ground than this.
const BULKY_WALK_FRAMES: int = 45
const BULKY_MAX_DISTANCE: float = 1.0
const DOOR_SWING_FRAMES: int = 40
## Ceiling lights (15) + street lamps (4) + entrance lamp (1).
const MIN_MANNEQUIN_LIGHTS: int = 20
## Up to five seconds for a dropped item to stop rolling.
const ITEM_SETTLE_FRAMES: int = 300

var _failures: int = 0


func _ready() -> void:
	await _run()
	print("SMOKE DAY 1: %s (%d failed)" % ["OK" if _failures == 0 else "FAILED", _failures])
	# Unload the level first so no sound is still playing when the engine shuts down.
	for child in get_children():
		child.queue_free()
	await _physics_frames(SHUTDOWN_FRAMES)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	_check(GameConfig.MIN_PLAYERS == 2 and GameConfig.MAX_PLAYERS == 4, "player limits are 2..4")
	_check_translations()
	_check_every_key_translated()
	_check_sounds()

	# Offline peer acts as host (id 1); register it so the level spawns one player.
	Net.players[1] = "Tester"
	var level := LEVEL_SCENE.instantiate() as GreyboxLevel
	add_child(level)
	await _physics_frames(30)

	var player := level.get_player()
	_check(player != null, "player spawned")
	if player == null:
		return
	# Keep the mannequin asleep until its own test.
	var monster := level.get_monster()
	if monster != null:
		monster.asleep_for = INF
	_check(player.is_on_floor(), "player stands on the ground")
	_check(level.get_player_spawns().size() == GameConfig.MAX_PLAYERS, "one spawn point per max player")
	_check(level.get_doors().size() == 17, "17 doors built (got %d)" % level.get_doors().size())
	var loot_count := level.get_item_spawns().size() + level.get_bulky_spawns().size()
	_check(level.get_items().size() == loot_count and loot_count == 17,
		"15 loot + 2 bulky spawned (got %d)" % level.get_items().size())

	_check_decor(level)
	_check_exterior(level)
	await _check_walking(player)
	await _check_door(player, level.get_doors()[0])
	await _check_doors_open_inwards(level)
	_check_bulky_in_farthest_room(level)
	await _check_bulky_carry(level, player)
	await _check_item(player, level.get_item(0), level.get_item(14))
	_check_flashlight(player)
	await _check_round(level, player, level.get_item(0))
	await _check_monster(level, player)


func _check_translations() -> void:
	TranslationServer.set_locale("vi")
	_check(tr("ITEM_RADIO") == "Radio cũ", "Vietnamese translation loaded")
	_check(tr("HUD_PICK_UP").format({"item": tr("ITEM_LAMP")}) == "[E] Nhặt Đèn bàn", "placeholder format works")
	TranslationServer.set_locale(GameConfig.DEFAULT_LOCALE)
	_check(tr("ITEM_RADIO") == "Old radio", "English translation loaded")


func _check_every_key_translated() -> void:
	var file := FileAccess.open("res://i18n/translations.csv", FileAccess.READ)
	if file == null:
		_check(false, "translations.csv opens")
		return
	file.get_csv_line()  # header: keys,en,vi
	var missing: PackedStringArray = []
	while not file.eof_reached():
		var columns := file.get_csv_line()
		if columns.size() == 1 and columns[0].is_empty():
			continue
		if columns.size() < 3 or columns[1].is_empty() or columns[2].is_empty():
			missing.append(columns[0])
	_check(missing.is_empty(), "every key has en and vi (missing: %s)" % ", ".join(missing))


func _check_sounds() -> void:
	var recorded: Dictionary[AudioStream, int] = {
		Sfx.footstep(): Sfx.FOOTSTEP_FILES.size(),
		Sfx.door_open(): Sfx.DOOR_OPEN_FILES.size(),
		Sfx.door_close(): Sfx.DOOR_CLOSE_FILES.size(),
		Sfx.pickup(): Sfx.PICKUP_FILES.size(),
		Sfx.item_drop(): Sfx.DROP_FILES.size(),
		Sfx.mannequin_creak(): Sfx.CREAK_FILES.size(),
	}
	var recorded_ok := true
	for stream: AudioStream in recorded.keys():
		var randomizer := stream as AudioStreamRandomizer
		recorded_ok = recorded_ok and randomizer != null and randomizer.streams_count == recorded[stream]
	_check(recorded_ok, "recorded Kenney sounds load with every variant")
	var one_shots: Array[AudioStream] = [Sfx.thud(), Sfx.deposit(), Sfx.horn(), Sfx.beep(), Sfx.death_sting()]
	var loops: Array[AudioStream] = [Sfx.mannequin_music(), Sfx.ambience()]
	var synth_ok := true
	for stream in one_shots:
		var wav := stream as AudioStreamWAV
		synth_ok = synth_ok and wav != null and wav.data.size() > 0 and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED
	for stream in loops:
		var wav := stream as AudioStreamWAV
		synth_ok = synth_ok and wav != null and wav.data.size() > 0 and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check(synth_ok, "synthesised sounds are valid")
	_check(Sfx.footstep() == Sfx.footstep(), "sounds are built once and cached")


## The lot is fenced in and its lamps count as light for the mannequin rule.
func _check_exterior(level: GreyboxLevel) -> void:
	var lights := get_tree().get_nodes_in_group(MannequinSight.LIGHT_GROUP).size()
	_check(lights >= MIN_MANNEQUIN_LIGHTS, "street and entrance lamps are mannequin lights (%d)" % lights)
	var space := level.get_world_3d().direct_space_state
	var gate := PhysicsRayQueryParameters3D.create(Vector3(18.5, 1.0, 34.0), Vector3(18.5, 1.0, 37.0))
	_check(not space.intersect_ray(gate).is_empty(), "the gate is closed")
	var side := PhysicsRayQueryParameters3D.create(Vector3(2.0, 1.0, 30.0), Vector3(-1.0, 1.0, 30.0))
	_check(not space.intersect_ray(side).is_empty(), "the fence closes the side of the lot")


func _check_decor(level: GreyboxLevel) -> void:
	var footprints := level.get_decor_footprints()
	_check(footprints.size() >= MIN_DECOR_COUNT, "decor placed (%d props on the floor)" % footprints.size())
	var reserved := level.get_reserved_cells()
	var clashes: PackedStringArray = []
	var in_walls: PackedStringArray = []
	for footprint in footprints:
		var id: String = footprint["id"]
		var rect: Rect2 = footprint["rect"]
		rect = rect.grow(-FOOTPRINT_TOLERANCE)
		for cell in reserved:
			if rect.intersects(Rect2(Vector2(cell), Vector2.ONE)):
				clashes.append("%s@%s on %s" % [id, rect.get_center().snappedf(0.1), cell])
		for point: Vector2 in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.position.y), rect.get_center()]:
			if level.is_wall_cell(Vector2i(point.floor())):
				in_walls.append("%s@%s" % [id, rect.get_center().snappedf(0.1)])
				break
	_check(clashes.is_empty(), "decor keeps doors, loot and spawns clear %s" % str(clashes))
	_check(in_walls.is_empty(), "no decor inside walls %s" % str(in_walls))
	var map := level.get_world_3d().navigation_map
	var start := level.get_player_spawns()[0]
	var unreachable: PackedStringArray = []
	for spawn in level.get_item_spawns():
		var path := NavigationServer3D.map_get_path(map, start, spawn, true)
		var end := path[path.size() - 1] if not path.is_empty() else start
		if Vector2(end.x - spawn.x, end.z - spawn.z).length() > PATH_END_TOLERANCE:
			unreachable.append(str(spawn.snappedf(0.1)))
	_check(unreachable.is_empty(), "every loot spawn reachable from the parking lot %s" % str(unreachable))


## Every door must swing into the side deeper inside the building.
func _check_doors_open_inwards(level: GreyboxLevel) -> void:
	for door in level.get_doors():
		door._apply_open(true)
	await _physics_frames(DOOR_SWING_FRAMES)
	var outward: PackedStringArray = []
	for door in level.get_doors():
		var parts := String(door.name).split("_")
		var cell := Vector2i(parts[1].to_int(), parts[2].to_int())
		var centre := Vector2(cell) + Vector2(0.5, 0.5)
		var panel := door.get_panel_position()
		var offset := Vector2(panel.x, panel.z) - centre
		# Look one cell along the passage, on the side the panel ended up.
		var step := Vector2i(signi(roundi(offset.x * 2.0)), 0) if absf(offset.x) > absf(offset.y) \
			else Vector2i(0, signi(roundi(offset.y * 2.0)))
		if level.get_cell_depth(cell + step) < level.get_cell_depth(cell - step):
			outward.append(String(door.name))
	_check(outward.is_empty(), "every door opens inwards %s" % str(outward))
	for door in level.get_doors():
		door._apply_open(false)
	await _physics_frames(DOOR_SWING_FRAMES)


## Bulky loot sits in the room whose doorway is the farthest walk from outside.
func _check_bulky_in_farthest_room(level: GreyboxLevel) -> void:
	var farthest := 0
	var room_of_cell: Dictionary[Vector2i, int] = {}
	var room_depth: Array[int] = []
	for row in 30:
		for col in 40:
			var start := Vector2i(col, row)
			if room_of_cell.has(start) or not _is_room_floor(level, start):
				continue
			var depth := _flood_room(level, start, room_depth.size(), room_of_cell)
			room_depth.append(depth)
			farthest = maxi(farthest, depth)
	var placed := not level.get_bulky_spawns().is_empty()
	for spawn in level.get_bulky_spawns():
		var cell := Vector2i(floori(spawn.x), floori(spawn.z))
		placed = placed and room_of_cell.has(cell) and room_depth[room_of_cell[cell]] == farthest
	_check(placed, "bulky loot is in the farthest room (doorway %d steps in)" % farthest)


func _is_room_floor(level: GreyboxLevel, cell: Vector2i) -> bool:
	var tile := level.get_layout_char(cell)
	return GreyboxLevel.INDOOR_CHARS.contains(tile) and tile != "D" and not tile.is_empty()


## Marks one room's cells and returns its shallowest depth (its doorway).
func _flood_room(level: GreyboxLevel, start: Vector2i, room: int, room_of_cell: Dictionary[Vector2i, int]) -> int:
	var queue: Array[Vector2i] = [start]
	room_of_cell[start] = room
	var shallowest := level.get_cell_depth(start)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		shallowest = mini(shallowest, level.get_cell_depth(cell))
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if not room_of_cell.has(next) and _is_room_floor(level, next):
				room_of_cell[next] = room
				queue.append(next)
	return shallowest


## Carrying bulky loot: very slow even when sprinting, then drop it again.
func _check_bulky_carry(level: GreyboxLevel, player: Player) -> void:
	var bulky := level.get_item(level.get_item_spawns().size())
	_check(bulky != null and bulky.data.bulky, "bulky loot spawned after the normal loot")
	if bulky == null:
		return
	var spot := bulky.global_position
	_teleport(player, Vector3(spot.x + 1.2, 0.1, spot.z))
	await _physics_frames(5)
	bulky.request_pick_up()
	await _physics_frames(5)
	_check(player.is_carrying_bulky() and player.held_item == bulky, "player picks up bulky loot")
	var start := player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	Input.action_press(InputActions.SPRINT)
	await _physics_frames(BULKY_WALK_FRAMES)
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)
	var moved := start.distance_to(player.global_position)
	_check(moved < BULKY_MAX_DISTANCE, "carrying bulky loot is very slow, even sprinting (moved %.2f m)" % moved)
	player.drop_held_item()
	await _physics_frames(10)
	_check(not player.is_carrying_bulky(), "bulky loot can be dropped")
	# Back to the parking lot so later "too far" checks start far from everything.
	_teleport(player, level.get_player_spawns()[0])
	await _physics_frames(5)


func _check_walking(player: Player) -> void:
	var start := player.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _physics_frames(45)
	Input.action_release(InputActions.MOVE_FORWARD)
	var moved := start.distance_to(player.global_position)
	_check(moved > 1.0, "player walks forward (moved %.2f m)" % moved)
	var footsteps := player.get_node(^"Footsteps") as Footsteps
	_check(footsteps != null and footsteps.steps_played > 0, "walking plays footsteps")


func _check_door(player: Player, door: Door) -> void:
	var doorway := door.get_panel_position()
	_check(_doorway_blocked(door, doorway), "closed door blocks the doorway")
	door.request_set_open(true)
	await _physics_frames(10)
	_check(not door.is_open, "host refuses a door request from far away")
	_teleport(player, door.global_position + Vector3(1.5, 0.1, 0.5))
	await _physics_frames(5)
	door.request_set_open(true)
	await _physics_frames(45)
	_check(door.is_open and absf(door.get_swing_angle_deg()) > 80.0,
		"door opens (angle %.1f)" % door.get_swing_angle_deg())
	_check(not _doorway_blocked(door, doorway), "open door no longer blocks the doorway")
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
	var visual := item.get_node_or_null(^"Visual") as Node3D
	_check(visual != null and is_equal_approx(visual.scale.x, Item.HELD_SCALE), "loot has a model, drawn smaller while held")
	far_item.request_pick_up()
	await _physics_frames(5)
	_check(player.held_item == item and not far_item.is_held(), "cannot hold two items")
	player.drop_held_item()
	await _physics_frames(60)
	_check(player.held_item == null and not item.freeze and not item.is_held(), "item dropped")
	_check(visual == null or is_equal_approx(visual.scale.x, 1.0), "dropped loot is full size again")
	_check(item.global_position.y > -0.5, "dropped item stays above ground")
	# Some loot tumbles for a while; compare once it has settled.
	for _frame in ITEM_SETTLE_FRAMES:
		if item.sleeping:
			break
		await get_tree().physics_frame
	await _physics_frames(2)
	_check(item.synced_transform.is_equal_approx(item.global_transform), "host publishes the resting transform")


func _check_round(level: GreyboxLevel, player: Player, item: Item) -> void:
	var round_manager := level.get_round()
	var van := level.get_van()
	_check(round_manager.is_playing() and round_manager.quota > 0,
		"round running with a quota (%d)" % round_manager.quota)
	_check(round_manager.time_left < round_manager.duration_sec, "round clock counts down")
	var spot := item.global_position
	_teleport(player, Vector3(spot.x + 1.0, 0.1, spot.z + 1.0))
	await _physics_frames(5)
	item.request_pick_up()
	await _physics_frames(5)
	van.request_deposit()
	await _physics_frames(5)
	_check(player.held_item == item, "host refuses a deposit from far away")

	var value := item.data.value
	var items_before := level.get_items().size()
	_teleport(player, van.approach_point())
	await _physics_frames(5)
	van.request_deposit()
	await _physics_frames(5)
	_check(round_manager.collected == value and player.held_item == null,
		"deposit adds the item's value (%d)" % round_manager.collected)
	_check(level.get_items().size() == items_before - 1, "deposited item is removed")


func _check_monster(level: GreyboxLevel, player: Player) -> void:
	var monster := level.get_monster()
	_check(monster != null, "mannequin spawned")
	if monster == null:
		return
	_check_mannequin_body(monster)
	var round_manager := level.get_round()
	var start := monster.global_position
	# Same room, three metres away, looking straight at it (camera faces -Z).
	_teleport(player, Vector3(start.x, 0.1, start.z + 3.0))
	player.rotation = Vector3.ZERO
	(player.get_node(^"Head") as Node3D).rotation = Vector3.ZERO
	monster.asleep_for = 0.0
	await _physics_frames(60)
	_check(monster.is_awake() and monster.is_seen, "awake mannequin knows it is watched")
	_check(monster.global_position.distance_to(start) < 0.1, "mannequin freezes while watched")
	var music := monster.get_node(^"Music") as AudioStreamPlayer3D
	_check(not monster.is_moving() and not music.playing, "frozen mannequin has no chase music")

	# Room next door, wall in between: it must path through the closed door.
	var door := level.get_node_or_null(^"Door_28_4") as Door
	_teleport(player, Vector3(23.5, 0.1, 4.5))
	var flicker := level.get_light_flicker()
	var heard_moving := false
	var saw_flicker := false
	for _frame in MONSTER_KILL_FRAMES:
		if player.is_dead:
			break
		heard_moving = heard_moving or monster.is_moving()
		saw_flicker = saw_flicker or flicker.count_dimmed_near(monster.global_position, LightFlicker.MONSTER_RANGE) > 0
		await get_tree().physics_frame
	_check(heard_moving, "moving mannequin is flagged (chase music)")
	_check(saw_flicker, "lights near the moving mannequin flicker")
	_check(player.is_dead and not player.visible, "unseen mannequin reaches and kills the player")
	_check(door != null and door.is_open, "mannequin pushed the closed door open")
	await _physics_frames(2)
	_check(round_manager.phase == RoundManager.Phase.ENDED
		and round_manager.end_reason == RoundManager.EndReason.ALL_DEAD and not round_manager.success,
		"round ends as 'everyone died'")
	_check(not level.get_van().accepting and not monster.is_awake(), "van closes and the mannequin stops")
	await _check_dead_requests(level, player, door)


func _check_mannequin_body(monster: Mannequin) -> void:
	var skeleton := monster.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton != null, "mannequin uses the Quaternius model")
	if skeleton == null:
		return
	var arm := skeleton.find_bone("upperarm_l")
	var before := skeleton.get_bone_pose_rotation(arm)
	var old_pose := monster.pose_index
	monster.pose_index = (old_pose + 1) % MannequinBody.pose_count()
	var changed := not skeleton.get_bone_pose_rotation(arm).is_equal_approx(before)
	monster.pose_index = old_pose
	_check(changed, "changing pose moves the arms")


## A dead player's requests must be refused by the host, not just by its input.
func _check_dead_requests(level: GreyboxLevel, player: Player, open_door: Door) -> void:
	_teleport(player, open_door.get_panel_position() + Vector3(1.0, -1.0, 0.0))
	await _physics_frames(5)
	open_door.request_set_open(false)
	var item := level.get_items()[0]
	_teleport(player, Vector3(item.global_position.x + 1.0, 0.1, item.global_position.z))
	await _physics_frames(5)
	item.request_pick_up()
	await _physics_frames(5)
	_check(open_door.is_open and not item.is_held(), "host ignores door and item requests from a dead player")


## Ray across the doorway, along the panel's normal, against door panels only.
func _doorway_blocked(door: Door, doorway: Vector3) -> bool:
	var normal := door.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(doorway - normal * 0.5, doorway + normal * 0.5)
	query.collision_mask = GameConfig.LAYER_DOORS
	return not door.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
