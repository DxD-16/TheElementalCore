extends SceneTree

func _initialize() -> void:
	var failures: int = 0

	failures += _check_order_independent_reaction()
	failures += _check_reaction_history_is_stored()
	failures += _check_reaction_resets_trigger_elements()
	failures += _check_strength_diminishes_on_repeat()

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
