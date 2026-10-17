extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var timed_enemy := _create_enemy(Vector2.ZERO)
	if timed_enemy == null:
		return

	var shatter_enemy := _create_enemy(Vector2(500.0, 0.0))
	if shatter_enemy == null:
		return
	await get_tree().process_frame
	_set_enemy_health(timed_enemy, 5000)
	_set_enemy_health(shatter_enemy, 10000)

	timed_enemy.apply_elemental_hit(0, timed_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	timed_enemy.apply_elemental_hit(900, timed_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	if not timed_enemy.is_deep_frozen() or timed_enemy._deep_freeze_accumulated_damage != 900:
		_fail("triggering ice hit should be accumulated by the freeze")
		return
	if timed_enemy.health_component.current_health != 5000:
		_fail("frozen enemy should not lose health before the freeze ends")
		return
	if timed_enemy.elemental_gauge.get_value(ElementalTypes.ElementType.ICE) != 0.0:
		_fail("frozen enemies should not accumulate ice charge")
		return

	timed_enemy.definition.resistances["fire"] = 0.5
	timed_enemy.apply_elemental_hit(200, timed_enemy.global_position, ElementalTypes.ElementType.FIRE, 25.0)
	if timed_enemy._deep_freeze_accumulated_damage != 1000:
		_fail("frozen damage counter should use damage after resistance")
		return
	if timed_enemy.elemental_gauge.get_value(ElementalTypes.ElementType.FIRE) != 25.0:
		_fail("non-ice elemental gauges should continue filling while frozen")
		return
	timed_enemy._advance_deep_freeze(10.0)
	if timed_enemy.is_deep_frozen() or timed_enemy.health_component.current_health != 4000:
		_fail("freeze expiry should apply accumulated damage once without a bonus")
		return

	shatter_enemy.apply_elemental_hit(0, shatter_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	shatter_enemy.apply_elemental_hit(1500, shatter_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	if shatter_enemy.is_deep_frozen() or shatter_enemy.health_component.current_health != 7000:
		_fail("first shatter should immediately deal 2x accumulated damage")
		return

	shatter_enemy.apply_elemental_hit(0, shatter_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	shatter_enemy.apply_elemental_hit(1500, shatter_enemy.global_position, ElementalTypes.ElementType.ICE, 100.0)
	if shatter_enemy.is_deep_frozen() or shatter_enemy.health_component.current_health != 4450:
		_fail("repeated shatter should deal 1.7x accumulated damage")
		return

	print("Deep freeze integration checks: PASS")
	await _finish(0)

func _create_enemy(position: Vector2) -> Dummy:
	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	return enemy

func _set_enemy_health(enemy: Dummy, max_health: int) -> void:
	enemy.definition.max_health = max_health
	enemy.health_component.max_health = max_health
	enemy.health_component.current_health = max_health

func _fail(message: String) -> void:
	push_error("Deep freeze integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
