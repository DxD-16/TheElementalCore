class_name ItemCatalog
extends Node

const ITEM_ROOT := "res://Resources/Items"
const ITEM_FILE_EXTENSIONS: Array[String] = [".tres", ".res"]
const CATEGORY_FOLDERS: Dictionary = {
	"weapon": "Weapons",
	"consumable": "Consumables",
	"material": "Materials",
	"accessory": "Accessories",
	"stone": "Stones",
	"quest": "Quest",
}

var _definitions: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	_definitions.clear()
	if not DirAccess.dir_exists_absolute(ITEM_ROOT):
		push_error("[ItemCatalog] Item resource directory does not exist: %s" % ITEM_ROOT)
		return
	for category_key in CATEGORY_FOLDERS:
		var category := String(category_key)
		var folder_name := String(CATEGORY_FOLDERS[category])
		var category_path := ITEM_ROOT.path_join(folder_name)
		if DirAccess.dir_exists_absolute(category_path):
			_scan_directory(category_path, category)
	print("[ItemCatalog] Loaded item definitions: %d" % _definitions.size())

func get_definition(item_id: String) -> ItemDefinition:
	return _definitions.get(item_id) as ItemDefinition

func get_definitions() -> Dictionary:
	return _definitions.duplicate()

func _scan_directory(path: String, expected_category: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("[ItemCatalog] Could not open item directory: %s" % path)
		return

	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path := path.path_join(entry)
		if directory.current_is_dir():
			if entry != "." and entry != "..":
				_scan_directory(entry_path, expected_category)
		elif _is_item_resource(entry):
			_register_resource(entry_path, expected_category)
		entry = directory.get_next()
	directory.list_dir_end()

func _is_item_resource(file_name: String) -> bool:
	for extension in ITEM_FILE_EXTENSIONS:
		if file_name.ends_with(extension):
			return true
	return false

func _register_resource(resource_path: String, expected_category: String) -> void:
	var resource := load(resource_path)
	if not resource is ItemDefinition:
		push_error("[ItemCatalog] Resource is not an ItemDefinition: %s" % resource_path)
		return
	var definition := resource as ItemDefinition
	if definition.id.strip_edges().is_empty():
		push_error("[ItemCatalog] Item definition has an empty ID: %s" % resource_path)
		return
	if _definitions.has(definition.id):
		push_error("[ItemCatalog] Duplicate item ID '%s' in %s" % [definition.id, resource_path])
		return
	if definition.max_stack < 1:
		push_error("[ItemCatalog] Item '%s' must have max_stack >= 1" % definition.id)
		return
	if definition.get_category() != expected_category:
		push_error(
			"[ItemCatalog] Item '%s' belongs to '%s', but is stored under '%s'" % [
				definition.id,
				definition.get_category(),
				expected_category
			]
		)
		return
	_definitions[definition.id] = definition
