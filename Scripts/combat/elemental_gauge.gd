class_name ElementalGauge
extends RefCounted

var values: Dictionary = {}
var reaction_history: Dictionary = {}

func _init() -> void:
	for element in [
		ElementalTypes.ElementType.FIRE,
		ElementalTypes.ElementType.ELECTRIC,
		ElementalTypes.ElementType.ETHER,
		ElementalTypes.ElementType.ICE,
		ElementalTypes.ElementType.WATER,
		ElementalTypes.ElementType.AIR
	]:
		values[element] = 0.0

func set_value(element: int, amount: float) -> void:
	if element == ElementalTypes.ElementType.NONE:
		return
	values[element] = clampf(amount, 0.0, 100.0)

func add_value(element: int, amount: float) -> void:
	if element == ElementalTypes.ElementType.NONE:
		return
	var current: float = get_value(element)
	set_value(element, current + amount)

func get_value(element: int) -> float:
	if not values.has(element):
		values[element] = 0.0
	return float(values[element])

func get_primed_element() -> int:
	var result: int = ElementalTypes.ElementType.NONE
	var highest: float = -1.0
	var priority: Array[int] = [
		ElementalTypes.ElementType.FIRE,
		ElementalTypes.ElementType.ELECTRIC,
		ElementalTypes.ElementType.ETHER,
		ElementalTypes.ElementType.ICE,
		ElementalTypes.ElementType.WATER,
		ElementalTypes.ElementType.AIR
	]
	for element in priority:
		if not values.has(element):
			continue
		var value: float = float(values[element])
		if value >= 100.0 and value > highest:
			highest = value
			result = int(element)
	return result

func is_primed() -> bool:
	return get_primed_element() != ElementalTypes.ElementType.NONE

func reset_element(element: int) -> void:
	if values.has(element):
		values[element] = 0.0

func reset_all() -> void:
	for element in values.keys():
		values[element] = 0.0
	reaction_history.clear()

func get_top_elements() -> Array[int]:
	var entries: Array = []
	for element in values.keys():
		entries.append({"element": int(element), "value": float(values[element])})
	entries.sort_custom(func(a, b):
		return a["value"] > b["value"]
	)
	var result: Array[int] = []
	for entry in entries:
		result.append(int(entry["element"]))
	return result
