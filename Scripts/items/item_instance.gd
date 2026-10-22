class_name ItemInstance
extends Resource

@export var definition: ItemDefinition

var id: String:
	get:
		return definition.id if definition != null else ""

var item_name: String:
	get:
		return definition.item_name if definition != null else ""

var description: String:
	get:
		return definition.description if definition != null else ""

var type: String:
	get:
		return definition.get_category() if definition != null else "misc"

var stackable: bool:
	get:
		return definition.stackable if definition != null else false

var max_stack: int:
	get:
		return definition.max_stack if definition != null else 1

func get_icon() -> Texture2D:
	return definition.get_icon() if definition != null else null

func duplicate_instance() -> ItemInstance:
	var copy := ItemInstance.new()
	copy.definition = definition
	return copy
