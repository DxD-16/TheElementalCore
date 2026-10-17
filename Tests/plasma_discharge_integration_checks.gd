extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	await get_tree().process_frame
	enemy.set_physics_process(false)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.definition.resistances["electric"] = 0.5
	enemy.health_component.max_health = 10000
	enemy.health_component.current_health = 10000

	_trigger_plasma_discharge(enemy)
	if enemy._plasma_discharge_effects.size() != 1:
		_fail("first plasma discharge should create one independent DoT")
		return
	enemy._advance_plasma_discharge_effects(1.0)
	if enemy.health_component.current_health != 9950 or not enemy.is_stunned():
		_fail("first electric tick should respect resistance and stun for 0.1 seconds")
		return
	enemy._advance_stun(0.1)
	if enemy.is_stunned():
		_fail("plasma tick stun should expire after 0.1 seconds")
		return

	_trigger_plasma_discharge(enemy)
	if enemy._plasma_discharge_effects.size() != 2:
		_fail("repeated plasma discharges should run concurrently")
		return
	enemy._advance_plasma_discharge_effects(1.0)
	if enemy.health_component.current_health != 9865 or not enemy.is_stunned():
		_fail("second cast should overlap its reduced first tick with the first cast")
		return
	enemy._advance_plasma_discharge_effects(1.0)
	if enemy.health_component.current_health != 9680:
		_fail("first cast's final tick should be pure while second cast keeps ticking")
		return
	enemy._advance_plasma_discharge_effects(1.0)
	if enemy.health_component.current_health != 9575 or not enemy._plasma_discharge_effects.is_empty():
		_fail("repeated discharge should deal 1.7-scaled ticks and then expire")
		return

	print("Plasma discharge integration checks: PASS")
	await _finish(0)

func _trigger_plasma_discharge(enemy: Dummy) -> void:
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)

func _fail(message: String) -> void:
	push_error("Plasma discharge integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
