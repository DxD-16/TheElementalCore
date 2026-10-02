extends Node

## Глобальный менеджер конфигураций.
## Автоматически загружает все .json файлы из папки res://Configs/

const CONFIG_DIR: String = "res://Configs/"
const DEFAULT_CONFIG_FILES: Array[String] = [
	"player.json",
	"weapons.json",
	"entities.json",
	"ui_effects.json"
]

var configs: Dictionary = {}

func _enter_tree() -> void:
	load_all_configs()

func _ready() -> void:
	if configs.is_empty():
		load_all_configs()

## Загружает все JSON-файлы из папки Configs
func load_all_configs() -> void:
	configs.clear()

	# 1. Загрузка базовых известных файлов конфигураций
	for file_name in DEFAULT_CONFIG_FILES:
		var config_name := file_name.get_basename()
		var full_path := CONFIG_DIR.path_join(file_name)
		var data = _load_json_file(full_path)
		if data != null:
			configs[config_name] = data

	# 2. Поиск любых дополнительных .json файлов в папке
	var dir := DirAccess.open(CONFIG_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var config_name := file_name.get_basename()
				if not configs.has(config_name):
					var full_path := CONFIG_DIR.path_join(file_name)
					var data = _load_json_file(full_path)
					if data != null:
						configs[config_name] = data
			file_name = dir.get_next()
		dir.list_dir_end()

	print("[ConfigManager] Успешно загружено конфигов: %d (%s)" % [configs.size(), ", ".join(configs.keys())])

## Чтение и парсинг отдельного JSON файла
func _load_json_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_warning("[ConfigManager] Файл не существует: %s" % file_path)
		return null

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[ConfigManager] Не удалось открыть файл: %s" % file_path)
		return null

	var content := file.get_as_text()
	var parsed: Variant = JSON.parse_string(content)
	if parsed == null:
		push_error("[ConfigManager] Ошибка синтаксиса JSON в файле: %s" % file_path)
	return parsed

## Перезагрузка всех конфигураций на лету
func reload_configs() -> void:
	load_all_configs()

## Универсальное получение значения по точечному пути (например "movement.speed")
func get_value(file_id: String, path: String = "", default_value: Variant = null) -> Variant:
	if not configs.has(file_id):
		return default_value

	if path.strip_edges().is_empty():
		return configs[file_id]

	var current: Variant = configs[file_id]
	var keys := path.split(".")
	for k in keys:
		if current is Dictionary and current.has(k):
			current = current[k]
		else:
			return default_value
	return current

## Типизированное получение float
func get_float(file_id: String, path: String, default_value: float = 0.0) -> float:
	var val = get_value(file_id, path, default_value)
	if val != null and (val is float or val is int):
		var number := float(val)
		if is_finite(number):
			return number
	return default_value

## Типизированное получение int
func get_int(file_id: String, path: String, default_value: int = 0) -> int:
	var val = get_value(file_id, path, default_value)
	if val != null and (val is int or val is float):
		var number := float(val)
		if is_finite(number):
			return int(number)
	return default_value

## Типизированное получение bool
func get_bool(file_id: String, path: String, default_value: bool = false) -> bool:
	var val = get_value(file_id, path, default_value)
	if val != null:
		return bool(val)
	return default_value

## Типизированное получение String
func get_string(file_id: String, path: String, default_value: String = "") -> String:
	var val = get_value(file_id, path, default_value)
	if val != null:
		return str(val)
	return default_value

## Получение массива
func get_array(file_id: String, path: String, default_value: Array = []) -> Array:
	var val = get_value(file_id, path, default_value)
	if val is Array:
		return val
	return default_value

## Получение словаря/секции
func get_dict(file_id: String, path: String, default_value: Dictionary = {}) -> Dictionary:
	var val = get_value(file_id, path, default_value)
	if val is Dictionary:
		return val
	return default_value
