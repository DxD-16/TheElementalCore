class_name StatusCatalog
extends RefCounted

static func get_repeat_policy() -> String:
	if not ConfigManager:
		push_error("[StatusCatalog] ConfigManager is unavailable")
		return ""
	return ConfigManager.get_string("statuses", "repeat_policy", "")

static func get_definition(status_id: String) -> Dictionary:
	if not ConfigManager:
		push_error("[StatusCatalog] ConfigManager is unavailable")
		return {}
	var definition: Variant = ConfigManager.get_value("statuses", "statuses.%s" % status_id)
	if not definition is Dictionary:
		push_error("[StatusCatalog] Unknown status '%s' in Configs/statuses.json" % status_id)
		return {}
	return definition

static func get_default_duration(status_id: String) -> float:
	var definition := get_definition(status_id)
	if definition.is_empty():
		return 0.0
	var value: Variant = definition.get("default_duration_seconds")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0.0:
		push_error("[StatusCatalog] Invalid default duration for status '%s'" % status_id)
		return 0.0
	return float(value)
