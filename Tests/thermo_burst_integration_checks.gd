extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var primary := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var nearby := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var outside := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(primary)
	add_child(nearby)
	add_child(outside)
	primary.global_position = Vector2.ZERO
	nearby.global_position = Vector2(40.0, 0.0)
	outside.global_position = Vector2(60.0, 0.0)
	await get_tree().process_frame

	outside.apply_elemental_hit(30, outside.global_position, ElementalTypes.ElementType.WATER, 25.0)
	if outside.health_component.current_health != 1000:
		_fail("water should build elemental charge without dealing damage")
		return
	if not is_equal_approx(outside.elemental_gauge.get_value(ElementalTypes.ElementType.WATER), 25.0):
		_fail("non-damaging elements should still build reaction charge")
		return

	primary.definition.resistances["physical"] = 0.2
	primary.definition.resistances["fire"] = 0.2
	nearby.definition.resistances["physical"] = 0.5
	nearby.definition.resistances["fire"] = 0.2
	primary.apply_elemental_hit(0, primary.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	primary.apply_elemental_hit(0, primary.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	if primary.health_component.current_health != 973:
		_fail("thermo_burst AoE should also damage its source, using fire resistance")
		return
	if nearby.health_component.current_health != 976 or outside.health_component.current_health != 1000:
		_fail("thermo_burst AoE should damage only enemies within 50 px")
		return
	if not is_equal_approx(nearby.get_effective_resistance(DamageTypes.Type.PHYSICAL, 0.5), 0.5):
		_fail("thermo_burst resistance reduction should affect only its source")
		return
	if not is_equal_approx(primary.get_effective_resistance(DamageTypes.Type.FIRE, 0.2), 0.1):
		_fail("first thermo_burst should reduce resistances by 50%")
		return
	if EnemyDamageResolver.calculate_damage(primary, 100, DamageTypes.Type.FIRE) != 90:
		_fail("resistance reduction should halve the damage mitigation")
		return
	if EnemyDamageResolver.calculate_damage(primary, 100, DamageTypes.Type.PHYSICAL) != 90:
		_fail("thermo_burst should also reduce physical resistance")
		return

	primary._advance_resistance_reduction_effects(4.0)
	primary.elemental_gauge.advance_time(4.0)
	primary.apply_elemental_hit(0, primary.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	primary.apply_elemental_hit(0, primary.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	if primary.health_component.current_health != 946:
		_fail("repeated thermo_burst AoE should continue damaging its source")
		return
	if nearby.health_component.current_health != 952:
		_fail("thermo_burst AoE damage should not weaken on repeats")
		return

	primary._advance_resistance_reduction_effects(1.0)
	if not is_equal_approx(primary.get_effective_resistance(DamageTypes.Type.FIRE, 0.2), 0.13):
		_fail("weaker resistance reduction should remain after the first debuff expires")
		return
	primary._advance_resistance_reduction_effects(4.0)
	if not is_equal_approx(primary.get_effective_resistance(DamageTypes.Type.FIRE, 0.2), 0.2):
		_fail("resistance should return to its initial value when debuffs expire")
		return

	print("Thermo burst integration checks: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("Thermo burst integration checks: " + message)
	get_tree().quit(1)
