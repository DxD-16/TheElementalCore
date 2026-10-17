class_name ElementalReactionResolver
extends RefCounted

func resolve(gauge: ElementalGauge, trigger_element: int, environment_element: int = ElementalTypes.ElementType.NONE, reaction_history: Dictionary = {}) -> Dictionary:
	if gauge == null or trigger_element == ElementalTypes.ElementType.NONE:
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none"}

	var config := _get_reaction_config()
	if config.is_empty():
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none"}

	var primed_elements: Array[int] = gauge.get_primed_elements()
	if primed_elements.is_empty():
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none"}

	var history: Dictionary = gauge.reaction_history.duplicate()
	if not reaction_history.is_empty():
		history = reaction_history.duplicate()

	var reactions: Array[Dictionary] = []
	var consumed_elements: Array[int] = []
	for primed_element in primed_elements:
		var reaction_key: String = _normalize_reaction_key(primed_element, trigger_element)
		var count: int = int(history.get(reaction_key, 0))
		var strength: float = float(config["strength"]["initial"])
		for i in range(count):
			strength *= float(config["strength"]["repeat_multiplier"])
			if strength < float(config["strength"]["minimum"]):
				strength = float(config["strength"]["minimum"])
		strength = round(strength)

		var reaction_type := _resolve_reaction(config, primed_element, trigger_element, environment_element)

		if reaction_type == "none":
			continue

		history[reaction_key] = count + 1
		reactions.append({
			"source": primed_element,
			"trigger": trigger_element,
			"key": reaction_key,
			"type": reaction_type,
			"strength": int(strength),
			"reaction": reaction_type
		})
		if not consumed_elements.has(primed_element):
			consumed_elements.append(primed_element)
		if not consumed_elements.has(trigger_element):
			consumed_elements.append(trigger_element)
		gauge.reaction_history_timers[reaction_key] = float(config["timers"]["reaction_strength_reset_seconds"])

	if reactions.is_empty():
		return {"triggered": false, "type": "none", "strength": 0, "reaction": "none", "history": history}

	var strongest_reaction: Dictionary = reactions[0]
	for reaction in reactions:
		if int(reaction.get("strength", 0)) > int(strongest_reaction.get("strength", 0)):
			strongest_reaction = reaction

	for element in consumed_elements:
		gauge.reset_element(element)

	gauge.reaction_history = history
	return {
		"triggered": true,
		"type": strongest_reaction.get("type", "none"),
		"strength": int(strongest_reaction.get("strength", 0)),
		"reaction": strongest_reaction.get("reaction", "none"),
		"reactions": reactions,
		"history": history,
		"primed_elements": primed_elements
	}

func _get_reaction_config() -> Dictionary:
	var main_loop := Engine.get_main_loop() as SceneTree
	var config_manager := main_loop.root.get_node_or_null("ConfigManager") if main_loop else null
	if config_manager == null:
		push_error("[ElementalReactionResolver] ConfigManager is unavailable")
		return {}

	var config: Variant = config_manager.call("get_value", "elemental_reactions")
	if not config is Dictionary:
		push_error("[ElementalReactionResolver] Configs/elemental_reactions.json is missing or invalid")
		return {}

	for section in ["timers", "charge", "strength", "single", "combined", "environment", "effects"]:
		if not config.has(section) or not config[section] is Dictionary:
			push_error("[ElementalReactionResolver] Invalid or missing '%s' section in elemental_reactions.json" % section)
			return {}

	var timers: Dictionary = config["timers"]
	for key in ["element_charge_seconds", "reaction_strength_reset_seconds"]:
		if not timers.has(key) or not (timers[key] is int or timers[key] is float) or not is_finite(float(timers[key])) or float(timers[key]) <= 0.0:
			push_error("[ElementalReactionResolver] Invalid or missing timers.%s in elemental_reactions.json" % key)
			return {}

	var charge: Dictionary = config["charge"]
	if not charge.has("threshold_percent") or not (charge["threshold_percent"] is int or charge["threshold_percent"] is float) or not is_finite(float(charge["threshold_percent"])) or float(charge["threshold_percent"]) <= 0.0:
		push_error("[ElementalReactionResolver] Invalid or missing charge.threshold_percent in elemental_reactions.json")
		return {}

	var strength: Dictionary = config["strength"]
	for key in ["initial", "repeat_multiplier", "minimum"]:
		if not strength.has(key) or not (strength[key] is int or strength[key] is float) or not is_finite(float(strength[key])):
			push_error("[ElementalReactionResolver] Invalid or missing strength.%s in elemental_reactions.json" % key)
			return {}
	if float(strength["initial"]) < 0.0 or float(strength["repeat_multiplier"]) < 0.0 or float(strength["minimum"]) < 0.0:
		push_error("[ElementalReactionResolver] Strength values must be non-negative")
		return {}

	var effects: Dictionary = config["effects"]
	var thermo_burst: Variant = effects.get("thermo_burst")
	if not thermo_burst is Dictionary:
		push_error("[ElementalReactionResolver] Missing effects.thermo_burst in elemental_reactions.json")
		return {}
	for key in [
		"resistance_reduction_percent",
		"resistance_reduction_seconds",
		"aoe_fire_damage",
		"aoe_radius_px"
	]:
		if not thermo_burst.has(key) or not (thermo_burst[key] is int or thermo_burst[key] is float) or not is_finite(float(thermo_burst[key])):
			push_error("[ElementalReactionResolver] Invalid or missing effects.thermo_burst.%s" % key)
			return {}
	if (
		float(thermo_burst["resistance_reduction_percent"]) < 0.0
		or float(thermo_burst["resistance_reduction_percent"]) > 100.0
		or float(thermo_burst["resistance_reduction_seconds"]) <= 0.0
		or float(thermo_burst["aoe_fire_damage"]) < 0.0
		or float(thermo_burst["aoe_radius_px"]) < 0.0
	):
		push_error("[ElementalReactionResolver] Thermo burst values are outside valid ranges")
		return {}

	var hemorrhage: Variant = effects.get("hemorrhage")
	if not hemorrhage is Dictionary or not hemorrhage.has("pure_damage_max_health_percent"):
		push_error("[ElementalReactionResolver] Missing effects.hemorrhage.pure_damage_max_health_percent in elemental_reactions.json")
		return {}
	if (
		not (hemorrhage["pure_damage_max_health_percent"] is int or hemorrhage["pure_damage_max_health_percent"] is float)
		or not is_finite(float(hemorrhage["pure_damage_max_health_percent"]))
		or float(hemorrhage["pure_damage_max_health_percent"]) < 0.0
	):
		push_error("[ElementalReactionResolver] Invalid effects.hemorrhage.pure_damage_max_health_percent")
		return {}

	var deep_freeze: Variant = effects.get("deep_freeze")
	if not deep_freeze is Dictionary:
		push_error("[ElementalReactionResolver] Missing effects.deep_freeze in elemental_reactions.json")
		return {}
	for key in ["freeze_duration_seconds", "shatter_threshold_damage", "shatter_bonus_damage_multiplier"]:
		if not deep_freeze.has(key) or not (deep_freeze[key] is int or deep_freeze[key] is float) or not is_finite(float(deep_freeze[key])):
			push_error("[ElementalReactionResolver] Invalid or missing effects.deep_freeze.%s" % key)
			return {}
	if (
		float(deep_freeze["freeze_duration_seconds"]) <= 0.0
		or float(deep_freeze["shatter_threshold_damage"]) < 0.0
		or float(deep_freeze["shatter_bonus_damage_multiplier"]) < 0.0
	):
		push_error("[ElementalReactionResolver] Deep freeze values are outside valid ranges")
		return {}

	var plasma_discharge: Variant = effects.get("plasma_discharge")
	if not plasma_discharge is Dictionary:
		push_error("[ElementalReactionResolver] Missing effects.plasma_discharge in elemental_reactions.json")
		return {}
	for key in ["tick_interval_seconds", "stun_duration_seconds"]:
		if not plasma_discharge.has(key) or not (plasma_discharge[key] is int or plasma_discharge[key] is float) or not is_finite(float(plasma_discharge[key])) or float(plasma_discharge[key]) <= 0.0:
			push_error("[ElementalReactionResolver] Invalid or missing effects.plasma_discharge.%s" % key)
			return {}
	if not plasma_discharge.has("ticks") or not plasma_discharge["ticks"] is Array or plasma_discharge["ticks"].size() != 3:
		push_error("[ElementalReactionResolver] effects.plasma_discharge.ticks must contain exactly three ticks")
		return {}
	for tick in plasma_discharge["ticks"]:
		if (
			not tick is Dictionary
			or not tick.has("damage")
			or not (tick["damage"] is int or tick["damage"] is float)
			or not is_finite(float(tick["damage"]))
			or float(tick["damage"]) < 0.0
			or not tick.has("type")
			or not ["electric", "pure"].has(str(tick["type"]))
		):
			push_error("[ElementalReactionResolver] Invalid tick in effects.plasma_discharge.ticks")
			return {}

	var ether_detonation: Variant = effects.get("ether_detonation")
	if not ether_detonation is Dictionary:
		push_error("[ElementalReactionResolver] Missing effects.ether_detonation in elemental_reactions.json")
		return {}
	for key in [
		"duration_seconds",
		"explosion_fire_damage",
		"explosion_radius_px",
		"shockwave_fire_damage",
		"shockwave_radius_px"
	]:
		if not ether_detonation.has(key) or not (ether_detonation[key] is int or ether_detonation[key] is float) or not is_finite(float(ether_detonation[key])):
			push_error("[ElementalReactionResolver] Invalid or missing effects.ether_detonation.%s" % key)
			return {}
	if (
		float(ether_detonation["duration_seconds"]) <= 0.0
		or float(ether_detonation["explosion_fire_damage"]) < 0.0
		or float(ether_detonation["explosion_radius_px"]) < 0.0
		or float(ether_detonation["shockwave_fire_damage"]) < 0.0
		or float(ether_detonation["shockwave_radius_px"]) < 0.0
	):
		push_error("[ElementalReactionResolver] Ether detonation values are outside valid ranges")
		return {}

	var magnetic_overload: Variant = effects.get("magnetic_overload")
	if not magnetic_overload is Dictionary:
		push_error("[ElementalReactionResolver] Missing effects.magnetic_overload in elemental_reactions.json")
		return {}
	for key in [
		"attraction_duration_seconds",
		"attraction_radius_px",
		"attraction_acceleration_px_per_second_squared",
		"discharge_radius_px",
		"discharge_electric_damage",
		"discharge_knockback"
	]:
		if not magnetic_overload.has(key) or not (magnetic_overload[key] is int or magnetic_overload[key] is float) or not is_finite(float(magnetic_overload[key])):
			push_error("[ElementalReactionResolver] Invalid or missing effects.magnetic_overload.%s" % key)
			return {}
	if (
		float(magnetic_overload["attraction_duration_seconds"]) <= 0.0
		or float(magnetic_overload["attraction_radius_px"]) < 0.0
		or float(magnetic_overload["attraction_acceleration_px_per_second_squared"]) < 0.0
		or float(magnetic_overload["discharge_radius_px"]) < 0.0
		or float(magnetic_overload["discharge_electric_damage"]) < 0.0
		or float(magnetic_overload["discharge_knockback"]) < 0.0
	):
		push_error("[ElementalReactionResolver] Magnetic overload values are outside valid ranges")
		return {}

	return config

func _normalize_reaction_key(first: int, second: int) -> String:
	var pair: Array[int] = [first, second]
	pair.sort()
	return "%d_%d" % [pair[0], pair[1]]

func _resolve_reaction(config: Dictionary, primed_element: int, trigger_element: int, environment_element: int) -> String:
	var reaction_type := "none"
	if primed_element == trigger_element:
		reaction_type = str(config["single"].get(str(primed_element), "none"))
	else:
		reaction_type = str(config["combined"].get(_normalize_reaction_key(primed_element, trigger_element), "none"))
		if reaction_type == "none":
			var environmental_trigger := environment_element
			var damage_element := primed_element
			if trigger_element == ElementalTypes.ElementType.WATER or trigger_element == ElementalTypes.ElementType.AIR:
				environmental_trigger = trigger_element
			elif primed_element == ElementalTypes.ElementType.WATER or primed_element == ElementalTypes.ElementType.AIR:
				environmental_trigger = primed_element
				damage_element = trigger_element
			if environmental_trigger != ElementalTypes.ElementType.NONE:
				reaction_type = str(config["environment"].get(_normalize_reaction_key(damage_element, environmental_trigger), "none"))
	return reaction_type
