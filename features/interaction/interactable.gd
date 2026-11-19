class_name Interactable
extends Node
## Add as a child named "Interactable" to any CollisionObject3D the player can
## use with the interact key. The owner listens to `interacted`.

signal interacted(player: Player)

## Translation key shown when the player looks at this object.
@export var prompt_key: String = ""
@export var enabled: bool = true

## Translation key inserted into the prompt as {item}, e.g. the item's name.
var prompt_subject_key: String = ""
## Optional extra check set by the owner: func(player: Player) -> bool.
var condition: Callable = Callable()


func can_interact(player: Player) -> bool:
	if not enabled:
		return false
	if condition.is_valid():
		var allowed: bool = condition.call(player)
		return allowed
	return true


func interact(player: Player) -> void:
	if can_interact(player):
		interacted.emit(player)


func get_prompt_text() -> String:
	return tr(prompt_key).format({"item": tr(prompt_subject_key)})
