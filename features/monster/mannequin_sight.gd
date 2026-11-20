class_name MannequinSight
extends RefCounted
## Direct artificial light only: ambient light and moonlight cannot freeze it.

const LIGHT_GROUP: StringName = &"mannequin_lights"
const MIN_ENERGY: float = 0.05
const MIN_DISTANCE: float = 0.001


static func is_lit(point: Vector3, lights: Array[Node], space: PhysicsDirectSpaceState3D,
		exclude: Array[RID]) -> bool:
	for node in lights:
		var light := node as Light3D
		if light == null or not light.is_visible_in_tree() or light.light_negative:
			continue
		if _energy_at(light, point) < MIN_ENERGY:
			continue
		if has_clear_ray(light.global_position, point, space, exclude):
			return true
	return false


static func has_clear_ray(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID], mask: int = 0xFFFFFFFF) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query).is_empty()


static func _energy_at(light: Light3D, point: Vector3) -> float:
	var offset := point - light.global_position
	var distance := offset.length()
	var light_range: float = 0.0
	var spot := light as SpotLight3D
	var omni := light as OmniLight3D
	if spot != null:
		light_range = spot.spot_range
		if distance > MIN_DISTANCE \
				and -spot.global_basis.z.dot(offset / distance) < cos(deg_to_rad(spot.spot_angle)):
			return 0.0
	elif omni != null:
		light_range = omni.omni_range
	if light_range <= MIN_DISTANCE or distance >= light_range:
		return 0.0
	# A small brightness threshold keeps almost extinguished flickers dark.
	var falloff := 1.0 - distance / light_range
	return light.light_energy * falloff * falloff
