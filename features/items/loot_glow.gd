class_name LootGlow
extends RefCounted
## Makes loot glow faintly in its own colour, so it can be spotted on dark
## floors without adding lights. Material copies are shared between items.

## Source material id -> glowing copy.
static var _glowing: Dictionary[int, BaseMaterial3D] = {}


static func apply(model: Node3D, energy: float) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if source != null:
				mesh.set_surface_override_material(surface, _glowing_copy(source, energy))


## Drops cached materials (the level calls this when it unloads).
static func clear_cache() -> void:
	_glowing.clear()


static func _glowing_copy(source: BaseMaterial3D, energy: float) -> BaseMaterial3D:
	var key := source.get_instance_id()
	if not _glowing.has(key):
		var copy := source.duplicate() as BaseMaterial3D
		copy.emission_enabled = true
		copy.emission = source.albedo_color
		copy.emission_energy_multiplier = energy
		if source.albedo_texture != null:
			copy.emission_texture = source.albedo_texture
		_glowing[key] = copy
	return _glowing[key]
