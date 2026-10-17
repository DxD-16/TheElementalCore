extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var wave_source := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var wave_target := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var wave_outside := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var death_source := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var death_target := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var death_outside := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	for enemy in [wave_source, wave_target, wave_outside, death_source, death_target, death_outside]:
		add_child(enemy)
	wave_source.global_position = Vector2.ZERO
	wave_target.global_position = Vector2(40.0, 0.0)
	wave_outside.global_position = Vector2(41.0, 0.0)
	death_source.global_position = Vector2(200.0, 0.0)
	death_target.global_position = Vector2(240.0, 0.0)
	death_outside.global_position = Vector2(241.0, 0.0)
	await get_tree().process_frame
	for enemy in [wave_source, wave_target, wave_outside, death_source, death_target, death_outside]:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	_trigger_ether_detonation(wave_source)
	_trigger_ether_detonation(wave_source)
	if wave_source._ether_detonation_effects.size() != 2:
		_fail("repeated ether detonations should remain as separate effects")
		return
	wave_source._advance_ether_detonation_effects(10.0)
	if wave_target.health_component.current_health != 949:
		_fail("parallel timeout waves should deal 30 then 21 fire damage")
		return
	if wave_outside.health_component.current_health != 1000:
		_fail("ether detonation shockwave should not affect targets outside 40 px")
		return

	_trigger_ether_detonation(death_source)
	_trigger_ether_detonation(death_source)
	death_source.apply_damage(1000, death_source.global_position, DamageTypes.Type.PURE)
	if not death_source.is_dead:
		_fail("lethal damage should kill an ether-detonated enemy")
		return
	if death_target.health_component.current_health != 700:
		_fail("multiple bomb marks should cause only one 300 fire-damage explosion")
		return
	if death_outside.health_component.current_health != 1000:
		_fail("death explosion should not affect targets outside 40 px")
		return

	print("Ether detonation integration checks: PASS")
	await _finish(0)

func _trigger_ether_detonation(enemy: Dummy) -> void:
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0)

func _fail(message: String) -> void:
	push_error("Ether detonation integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
