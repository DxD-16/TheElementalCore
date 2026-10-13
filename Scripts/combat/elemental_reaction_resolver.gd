class_name ElementalReactionResolver
extends RefCounted

func resolve(gauge: ElementalGauge, trigger_element: int, environment_element: int = ElementalTypes.ElementType.NONE, reaction_history: Dictionary = {}) -> Dictionary:
	if gauge == null or trigger_element == ElementalTypes.ElementType.NONE:
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none"}

	var primed_element: int = gauge.get_primed_element()
	if primed_element == ElementalTypes.ElementType.NONE:
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none"}

	var history: Dictionary = gauge.reaction_history.duplicate()
	if not reaction_history.is_empty():
		history = reaction_history.duplicate()

	var reaction_key: String = _normalize_reaction_key(primed_element, trigger_element)
	var count: int = int(history.get(reaction_key, 0))
	var strength: float = 100.0
	for i in range(count):
		strength *= 0.7
		if strength < 10.0:
			strength = 10.0
	strength = round(strength)

	var reaction_type: String = "none"
	if primed_element == trigger_element:
		reaction_type = _resolve_single_reaction(primed_element)
	else:
		reaction_type = _resolve_combined_reaction(primed_element, trigger_element, environment_element)

	if reaction_type == "none":
		return {"triggered": false, "type": "none", "strength": int(strength), "reaction": "none"}

	gauge.reset_element(primed_element)
	gauge.reset_element(trigger_element)
	history[reaction_key] = count + 1
	gauge.reaction_history = history
	return {
		"triggered": true,
		"type": reaction_type,
		"strength": int(strength),
		"reaction": reaction_type,
		"history": history
	}

func _normalize_reaction_key(first: int, second: int) -> String:
	var pair: Array[int] = [first, second]
	pair.sort()
	return "%d_%d" % [pair[0], pair[1]]

func _resolve_single_reaction(element: int) -> String:
	match element:
		ElementalTypes.ElementType.FIRE:
			return "thermo_burst"
		ElementalTypes.ElementType.ELECTRIC:
			return "magnetic_overload"
		ElementalTypes.ElementType.ETHER:
			return "hemorrhage"
		ElementalTypes.ElementType.ICE:
			return "deep_freeze"
		_:
			return "none"

func _resolve_combined_reaction(first: int, second: int, environment_element: int) -> String:
	var key := _normalize_reaction_key(first, second)
	match key:
		"1_2":
			return "plasma_discharge"
		"1_3":
			return "ether_detonation"
		"1_4":
			return "steam_veil"
		"2_3":
			return "ether_shock"
		"2_4":
			return "isolation"
		"3_4":
			return "weakness"
		_:
			if environment_element != ElementalTypes.ElementType.NONE:
				return _resolve_environment_reaction(first, environment_element)
			return "none"

func _resolve_environment_reaction(element: int, environment_element: int) -> String:
	if element == ElementalTypes.ElementType.FIRE and environment_element == ElementalTypes.ElementType.WATER:
		return "neutralization"
	if element == ElementalTypes.ElementType.FIRE and environment_element == ElementalTypes.ElementType.AIR:
		return "ignition"
	if element == ElementalTypes.ElementType.ELECTRIC and environment_element == ElementalTypes.ElementType.WATER:
		return "chain_conductivity"
	if element == ElementalTypes.ElementType.ETHER and environment_element == ElementalTypes.ElementType.WATER:
		return "poison"
	if element == ElementalTypes.ElementType.ICE and environment_element == ElementalTypes.ElementType.WATER:
		return "instant_freeze"
	if element == ElementalTypes.ElementType.ICE and environment_element == ElementalTypes.ElementType.AIR:
		return "cold_wind"
	return "none"
