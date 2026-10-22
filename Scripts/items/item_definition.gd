class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var stackable: bool = false
@export_range(1, 9999, 1) var max_stack: int = 1
@export var icon_path: String = ""
@export_enum("common", "uncommon", "rare", "epic", "legendary") var rarity: String = "common"
@export var behavior: ItemBehavior

var _icon_texture: Texture2D

func get_category() -> String:
	return "misc"

func get_icon() -> Texture2D:
	if _icon_texture:
		return _icon_texture
	if icon_path.is_empty():
		return null
	if not ResourceLoader.exists(icon_path):
		push_warning("[ItemDefinition] Icon resource does not exist: %s" % icon_path)
		return null
	_icon_texture = load(icon_path) as Texture2D
	return _icon_texture
