class_name ItemData
extends Resource

## Данные одного типа предмета.
## Загружается из Configs/items.json через ConfigManager.

@export var id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var type: String = "misc"           # consumable, weapon, material, misc
@export var stackable: bool = false
@export var max_stack: int = 1
@export var icon_path: String = ""

## Эффекты при использовании (для consumable)
var use_effects: Dictionary = {}

## Кешированная текстура иконки
var _icon_texture: Texture2D = null

func get_icon() -> Texture2D:
	if _icon_texture:
		return _icon_texture
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon_texture = load(icon_path) as Texture2D
	return _icon_texture

## Создаёт ItemData из словаря конфига
static func from_config(item_id: String, data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.item_name = data.get("name", item_id)
	item.description = data.get("description", "")
	item.type = data.get("type", "misc")
	item.stackable = data.get("stackable", false)
	item.max_stack = int(data.get("max_stack", 1))
	item.icon_path = data.get("icon", "")
	item.use_effects = data.get("use_effect", {})
	return item
