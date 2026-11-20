class_name PropFactory
extends RefCounted
## Builds decor props from their models. Every prop is centred on its
## footprint and stands on y = 0, so decor data only gives a floor position
## and a turn. Solid props get a box collider (players and the mannequin walk
## around them, the navmesh avoids them, and they block line of sight).
## Props never move, so they are built the same on every peer and need no sync.

const FURNITURE_DIR: String = "res://assets/models/kenney_furniture/"
const CAR_KIT_DIR: String = "res://assets/models/kenney_car_kit/"
## Kenney kits are built smaller than real life.
const FURNITURE_SCALE: float = 2.0
const CAR_KIT_SCALE: float = 1.7
## Sketchfab exports here are in centimetres.
const CENTIMETRES: float = 0.01
const MANNEQUIN_SIZE: Vector3 = Vector3(0.55, 1.82, 0.4)
const MANNEQUIN: String = "mannequin"
## Kenney models come in bright toy colours; grey and darken them to fit an
## abandoned building (share of grey mixed in, then brightness kept).
const WEATHER_GREY: float = 0.6
const WEATHER_BRIGHTNESS: float = 0.65
const WEATHER_MIN_ROUGHNESS: float = 0.85
## Models that keep their own look (already realistic textures).
const UNWEATHERED: PackedStringArray = ["lotta"]

## Furniture without collision: flat, small, or sitting on another prop.
const DECORATIVE: PackedStringArray = [
	"computerScreen", "computerKeyboard", "rugRectangle", "rugRound",
	"kitchenCoffeeMachine", "kitchenMicrowave", "bathroomMirror",
	"televisionModern", "televisionVintage", "plantSmall1",
]
## Props that are not in the Kenney Furniture Kit: id -> [path, scale].
const OTHER_MODELS: Dictionary[String, Array] = {
	"lotta": ["res://assets/models/lotta_tra_como/lotta_tra_como.glb", CENTIMETRES],
	"cone": [CAR_KIT_DIR + "cone.glb", CAR_KIT_SCALE],
	"crate": [CAR_KIT_DIR + "box.glb", CAR_KIT_SCALE],
}

## id -> scaled model bounds, so each model is measured once.
static var _bounds: Dictionary[String, AABB] = {}
## Source material id -> weathered copy, shared by every prop using it.
static var _weathered: Dictionary[int, BaseMaterial3D] = {}


## `pose` is only used by the mannequin decoy.
static func create(id: String, pose: int = 0) -> Node3D:
	if id == MANNEQUIN:
		return _create_mannequin(pose)
	var model := _instantiate_model(id)
	if model == null:
		return Node3D.new()
	if not UNWEATHERED.has(id):
		weather(model)
	var box := bounds(id)
	# Centre the footprint on the origin and stand the model on the floor.
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	if DECORATIVE.has(id):
		var holder := Node3D.new()
		holder.add_child(model)
		return holder
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.add_child(model)
	body.add_child(_box_shape(box.size))
	return body


## Gives every surface of `model` a greyed, darker copy of its material.
static func weather(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if source != null:
				mesh.set_surface_override_material(surface, _weathered_copy(source))


## Drops cached materials and sizes (the level calls this when it unloads).
static func clear_cache() -> void:
	_weathered.clear()
	_bounds.clear()


## Size of the prop before turning (x = width, y = height, z = depth).
static func size_of(id: String) -> Vector3:
	return MANNEQUIN_SIZE if id == MANNEQUIN else bounds(id).size


static func bounds(id: String) -> AABB:
	if not _bounds.has(id):
		var model := _instantiate_model(id)
		var scaled := AABB()
		if model != null:
			var box := ModelBounds.local_aabb(model)
			scaled = AABB(box.position * model.scale, box.size * model.scale)
			model.free()
		_bounds[id] = scaled
	return _bounds[id]


static func _instantiate_model(id: String) -> Node3D:
	var path := FURNITURE_DIR + id + ".glb"
	var scale := FURNITURE_SCALE
	if OTHER_MODELS.has(id):
		var info: Array = OTHER_MODELS[id]
		path = info[0]
		scale = info[1]
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Unknown prop '%s' (%s)" % [id, path])
		return null
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * scale
	return model


## A decoy: looks exactly like the real mannequin but never moves.
static func _create_mannequin(pose: int) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	var figure := MannequinBody.new()
	figure.start_pose = pose
	body.add_child(figure)
	body.add_child(_box_shape(MANNEQUIN_SIZE))
	return body


static func _box_shape(size: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = size.y * 0.5
	return shape


static func _weathered_copy(source: BaseMaterial3D) -> BaseMaterial3D:
	var key := source.get_instance_id()
	if not _weathered.has(key):
		var copy := source.duplicate() as BaseMaterial3D
		var colour := copy.albedo_color
		var grey := colour.get_luminance()
		var greyed := colour.lerp(Color(grey, grey, grey, colour.a), WEATHER_GREY)
		copy.albedo_color = Color(greyed.r * WEATHER_BRIGHTNESS, greyed.g * WEATHER_BRIGHTNESS,
			greyed.b * WEATHER_BRIGHTNESS, colour.a)
		copy.roughness = maxf(copy.roughness, WEATHER_MIN_ROUGHNESS)
		_weathered[key] = copy
	return _weathered[key]
