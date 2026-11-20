class_name LightFlicker
extends Node
## Makes ceiling lights flicker. The pattern comes from (light index, round
## time), so every peer sees the same flicker without sending messages.
## It gets worse in the last minute, and lights near a moving mannequin
## sputter hard: a warning that something moved.

## One flicker decision per light per slot.
const SLOT_SEC: float = 0.1
const BASE_CHANCE: float = 0.012
const LATE_CHANCE: float = 0.08
const LATE_ROUND_SEC: float = 60.0
const MONSTER_RANGE: float = 6.0
const MONSTER_SLOT_SEC: float = 0.05
## A flickering light drops to this share of its normal energy.
const DIM_MIN: float = 0.05
const DIM_MAX: float = 0.45
const HASH_RANGE: float = 65536.0

var round_manager: RoundManager = null
## Every mannequin; lights near any moving one sputter.
var monsters: Array[Mannequin] = []

var _lights: Array[Light3D] = []
var _base_energy: Array[float] = []


func _process(_delta: float) -> void:
	var elapsed := _round_elapsed()
	var chance := LATE_CHANCE if _is_late() else BASE_CHANCE
	var moving := _moving_monster_positions()
	for index in _lights.size():
		var light := _lights[index]
		var factor := _flicker_factor(index, elapsed, chance)
		if _is_near_any(light.global_position, moving):
			var slot := int(elapsed / MONSTER_SLOT_SEC)
			factor = minf(factor, _noise(index, slot, 3) * DIM_MAX)
		light.light_energy = _base_energy[index] * factor


func add_light(light: Light3D) -> void:
	_lights.append(light)
	_base_energy.append(light.light_energy)


## How many lights within `radius` of `point` are below half energy right now.
func count_dimmed_near(point: Vector3, radius: float) -> int:
	var count := 0
	for index in _lights.size():
		var light := _lights[index]
		if light.global_position.distance_to(point) <= radius \
				and light.light_energy < _base_energy[index] * 0.5:
			count += 1
	return count


func _round_elapsed() -> float:
	if round_manager == null or round_manager.phase == RoundManager.Phase.WAITING:
		return 0.0
	return round_manager.duration_sec - round_manager.time_left


func _is_late() -> bool:
	return round_manager != null and round_manager.is_playing() \
		and round_manager.time_left < LATE_ROUND_SEC


func _flicker_factor(index: int, elapsed: float, chance: float) -> float:
	var slot := int(elapsed / SLOT_SEC)
	if _noise(index, slot, 1) >= chance:
		return 1.0
	return lerpf(DIM_MIN, DIM_MAX, _noise(index, slot, 2))


## Same inputs give the same value on every machine running this build.
func _noise(index: int, slot: int, salt: int) -> float:
	return float(hash(Vector3i(index, slot, salt)) & 0xFFFF) / HASH_RANGE


func _moving_monster_positions() -> PackedVector3Array:
	var result := PackedVector3Array()
	for monster in monsters:
		if is_instance_valid(monster) and monster.is_moving():
			result.append(monster.global_position)
	return result


func _is_near_any(point: Vector3, positions: PackedVector3Array) -> bool:
	for position in positions:
		if point.distance_to(position) < MONSTER_RANGE:
			return true
	return false
