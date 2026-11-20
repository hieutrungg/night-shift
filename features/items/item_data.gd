class_name ItemData
extends Resource
## Data for one kind of loot. Create new kinds as .tres files in items/data/.

@export var name_key: String = "ITEM_UNKNOWN"
@export_range(1, 1000) var value: int = 10
@export var mass: float = 2.0
## Model shown for this loot; its bounds become the collision box.
@export var model: PackedScene
@export var model_scale: float = 1.0
## Fallback look when there is no model: a coloured box.
@export var size: Vector3 = Vector3(0.3, 0.3, 0.3)
@export var color: Color = Color(0.7, 0.7, 0.7)
