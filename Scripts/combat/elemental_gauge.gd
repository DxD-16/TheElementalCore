class_name ElementalGauge
extends RefCounted

var values: Dictionary = {}
var reaction_history: Dictionary = {}
var charge_timers: Dictionary = {}
var reaction_history_timers: Dictionary = {}
var charge_threshold: float = 100.0

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

func set_charge_threshold(value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		push_error("ElementalGauge charge threshold must be finite and greater than zero")
		return
	charge_threshold = value
	for element in values:
		values[element] = minf(float(values[element]), charge_threshold)

func set_value(element: int, amount: float) -> void:
	if element == ElementalTypes.ElementType.NONE:
		return
	values[element] = clampf(amount, 0.0, charge_threshold)

func add_value(element: int, amount: float, duration: float = 0.0) -> void:
	if element == ElementalTypes.ElementType.NONE or not is_finite(amount) or amount <= 0.0:
		return
	var current: float = get_value(element)
	set_value(element, current + amount)
	if is_finite(duration) and duration > 0.0:
		charge_timers[element] = duration

func advance_time(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return

	for element in charge_timers.keys():
		var remaining := float(charge_timers[element]) - delta
		if remaining <= 0.0:
			reset_element(int(element))
		else:
			charge_timers[element] = remaining

	for reaction_key in reaction_history_timers.keys():
		var remaining := float(reaction_history_timers[reaction_key]) - delta
		if remaining <= 0.0:
			reaction_history_timers.erase(reaction_key)
			reaction_history.erase(reaction_key)
		else:
			reaction_history_timers[reaction_key] = remaining

func get_value(element: int) -> float:
	if not values.has(element):
		values[element] = 0.0
	return float(values[element])

func get_primed_elements() -> Array[int]:
	var priority: Array[int] = [
		ElementalTypes.ElementType.FIRE,
		ElementalTypes.ElementType.ELECTRIC,
		ElementalTypes.ElementType.ETHER,
		ElementalTypes.ElementType.ICE,
		ElementalTypes.ElementType.WATER,
		ElementalTypes.ElementType.AIR
	]
	var result: Array[int] = []
	for element in priority:
		if not values.has(element):
			continue
		var value: float = float(values[element])
		if value >= charge_threshold:
			result.append(int(element))
	return result

func get_primed_element() -> int:
	var primed := get_primed_elements()
	if primed.is_empty():
		return ElementalTypes.ElementType.NONE
	return primed[0]

func is_primed() -> bool:
	return not get_primed_elements().is_empty()

func reset_element(element: int) -> void:
	if values.has(element):
		values[element] = 0.0
	charge_timers.erase(element)

func reset_all() -> void:
	for element in values.keys():
		values[element] = 0.0
	reaction_history.clear()
	charge_timers.clear()
	reaction_history_timers.clear()

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
