extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var failures: int = 0

	failures += _check_order_independent_reaction()
	failures += _check_reaction_history_is_stored()
	failures += _check_reaction_resets_trigger_elements()
	failures += _check_strength_diminishes_on_repeat()
	failures += _check_multiple_primed_elements_react_together()
	failures += _check_element_charge_expires_after_inactivity()
	failures += _check_reaction_strength_resets_after_inactivity()
	failures += _check_damage_type_resistances()
	failures += _check_water_and_air_environment_reactions()

	if failures == 0:
		print("Elemental reaction checks: PASS")
		quit(0)
	else:
		print("Elemental reaction checks: FAIL (%d checks failed)" % failures)
		quit(1)

func _check_order_independent_reaction() -> int:
	var resolver := ElementalReactionResolver.new()

	var gauge_fire_first := ElementalGauge.new()
	gauge_fire_first.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var fire_then_electric := resolver.resolve(gauge_fire_first, ElementalTypes.ElementType.ELECTRIC)

	var gauge_electric_first := ElementalGauge.new()
	gauge_electric_first.set_value(ElementalTypes.ElementType.ELECTRIC, 100.0)
	var electric_then_fire := resolver.resolve(gauge_electric_first, ElementalTypes.ElementType.FIRE)

	if fire_then_electric.get("reaction") != electric_then_fire.get("reaction"):
		print("FAIL: reaction order should not change result")
		return 1
	if fire_then_electric.get("reaction") != "plasma_discharge":
		print("FAIL: expected plasma_discharge when FIRE and ELECTRIC react")
		return 1
	return 0

func _check_reaction_history_is_stored() -> int:
	var resolver := ElementalReactionResolver.new()
	var gauge := ElementalGauge.new()
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)

	var result := resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	if not result.has("history"):
		print("FAIL: result should include reaction history")
		return 1
	if not gauge.reaction_history.has("1_2"):
		print("FAIL: reaction history should be stored on gauge")
		return 1
	if int(gauge.reaction_history["1_2"]) != 1:
		print("FAIL: history count should be one after first reaction")
		return 1
	return 0

func _check_reaction_resets_trigger_elements() -> int:
	var resolver := ElementalReactionResolver.new()
	var gauge := ElementalGauge.new()
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)

	resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	if abs(gauge.get_value(ElementalTypes.ElementType.FIRE)) > 0.001:
		print("FAIL: FIRE should be reset after reaction")
		return 1
	if abs(gauge.get_value(ElementalTypes.ElementType.ELECTRIC)) > 0.001:
		print("FAIL: ELECTRIC should be reset after reaction")
		return 1
	return 0

func _check_strength_diminishes_on_repeat() -> int:
	var resolver := ElementalReactionResolver.new()

	var gauge_one := ElementalGauge.new()
	gauge_one.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var result_one := resolver.resolve(gauge_one, ElementalTypes.ElementType.ELECTRIC)

	var gauge_two := ElementalGauge.new()
	gauge_two.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var result_two := resolver.resolve(gauge_two, ElementalTypes.ElementType.ELECTRIC, ElementalTypes.ElementType.NONE, result_one.get("history", {}))

	if result_two.get("strength", 0) >= result_one.get("strength", 0):
		print("FAIL: repeated reaction strength should decrease")
		return 1
	if result_two.get("reaction") != "plasma_discharge":
		print("FAIL: repeated reaction should keep the same reaction type")
		return 1
	return 0

func _check_multiple_primed_elements_react_together() -> int:
	var resolver := ElementalReactionResolver.new()
	var gauge := ElementalGauge.new()
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	gauge.set_value(ElementalTypes.ElementType.ETHER, 100.0)

	var result := resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	var reactions: Array = result.get("reactions", [])
	if reactions.size() != 2:
		print("FAIL: each primed element should react with the trigger")
		return 1
	if reactions[0].get("reaction") != "plasma_discharge" or reactions[1].get("reaction") != "ether_shock":
		print("FAIL: simultaneous reactions should use configured reaction mappings")
		return 1
	if not gauge.get_primed_elements().is_empty():
		print("FAIL: reacted primed elements should be consumed")
		return 1
	return 0

func _check_element_charge_expires_after_inactivity() -> int:
	var gauge := ElementalGauge.new()
	gauge.add_value(ElementalTypes.ElementType.FIRE, 100.0, 10.0)
	gauge.advance_time(9.9)
	if not gauge.is_primed():
		print("FAIL: element charge should remain before its timeout")
		return 1
	gauge.advance_time(0.1)
	if gauge.is_primed():
		print("FAIL: element charge should expire after ten seconds")
		return 1
	return 0

func _check_reaction_strength_resets_after_inactivity() -> int:
	var resolver := ElementalReactionResolver.new()
	var gauge := ElementalGauge.new()
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var first := resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	if int(first.get("strength", 0)) != 100:
		print("FAIL: first reaction should have full strength")
		return 1

	gauge.advance_time(29.9)
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var before_timeout := resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	if int(before_timeout.get("strength", 0)) != 70:
		print("FAIL: reaction strength should be reduced before the timeout")
		return 1

	gauge.advance_time(30.0)
	gauge.set_value(ElementalTypes.ElementType.FIRE, 100.0)
	var after_timeout := resolver.resolve(gauge, ElementalTypes.ElementType.ELECTRIC)
	if int(after_timeout.get("strength", 0)) != 100:
		print("FAIL: reaction strength should reset after thirty seconds")
		return 1
	return 0

func _check_damage_type_resistances() -> int:
	var enemy := Node.new()
	var definition := EnemyDefinition.new("test_enemy", {
		"resistances": {
			"physical": 0.2,
			"fire": 0.1,
			"electric": 0.3,
			"ether": 0.4,
			"ice": 0.5,
			"water": 0.9,
			"air": 0.9,
			"unknown": 0.9
		}
	})
	enemy.set_meta("enemy_definition", definition)

	var damage_types: Array[int] = [
		DamageTypes.Type.PHYSICAL,
		DamageTypes.Type.FIRE,
		DamageTypes.Type.ELECTRIC,
		DamageTypes.Type.ETHER,
		DamageTypes.Type.ICE
	]
	var expected_damage: Array[int] = [80, 90, 70, 60, 50]
	for i in range(damage_types.size()):
		if EnemyDamageResolver.calculate_damage(enemy, 100, damage_types[i]) != expected_damage[i]:
			print("FAIL: damage type %s should use its own resistance" % DamageTypes.to_key(damage_types[i]))
			enemy.free()
			return 1
	if EnemyDamageResolver.calculate_damage(enemy, 100, DamageTypes.Type.PURE) != 100:
		print("FAIL: pure damage should ignore all resistances")
		enemy.free()
		return 1

	definition.resistances["fire"] = -0.5
	if EnemyDamageResolver.calculate_damage(enemy, 100, DamageTypes.Type.FIRE) != 150:
		print("FAIL: negative resistance should increase incoming damage")
		enemy.free()
		return 1

	definition.apply_data({"resistances": {"fire": 1.5}})
	if definition.resistances["fire"] != 1.0:
		print("FAIL: resistance should be capped at 1.0")
		enemy.free()
		return 1
	if definition.resistances.size() != 5:
		print("FAIL: enemy definitions should contain exactly five resistance types")
		enemy.free()
		return 1
	enemy.free()
	return 0

func _check_water_and_air_environment_reactions() -> int:
	var resolver := ElementalReactionResolver.new()
	var cases: Array[Dictionary] = [
		{"primed": ElementalTypes.ElementType.FIRE, "trigger": ElementalTypes.ElementType.WATER, "reaction": "neutralization"},
		{"primed": ElementalTypes.ElementType.ELECTRIC, "trigger": ElementalTypes.ElementType.WATER, "reaction": "chain_conductivity"},
		{"primed": ElementalTypes.ElementType.FIRE, "trigger": ElementalTypes.ElementType.AIR, "reaction": "ignition"}
	]
	for test_case in cases:
		var gauge := ElementalGauge.new()
		gauge.set_value(int(test_case["primed"]), 100.0)
		var result := resolver.resolve(gauge, int(test_case["trigger"]))
		if result.get("reaction") != test_case["reaction"]:
			print("FAIL: environmental element should trigger %s" % test_case["reaction"])
			return 1
	return 0
