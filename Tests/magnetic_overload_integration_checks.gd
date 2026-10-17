extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var magnet := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var nearby := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var heavy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	var outside := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(magnet)
	add_child(nearby)
	add_child(heavy)
	add_child(outside)
	magnet.global_position = Vector2.ZERO
	nearby.global_position = Vector2(80.0, 0.0)
	heavy.global_position = Vector2(150.0, 0.0)
	outside.global_position = Vector2(250.0, 0.0)
	heavy.definition.weight = 2.0
	await get_tree().process_frame
	for enemy in [magnet, nearby, heavy, outside]:
		enemy.set_physics_process(false)
		enemy.velocity = Vector2.ZERO

	magnet.apply_elemental_hit(0, magnet.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)
	magnet.apply_elemental_hit(0, magnet.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)
	magnet.apply_elemental_hit(0, magnet.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)
	magnet.apply_elemental_hit(0, magnet.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)
	if magnet._magnetic_overload_fields.size() != 2:
		_fail("repeated magnetic overload should create concurrent fields")
		return

	magnet._update_magnetic_overload_fields(3.0)
	if nearby.health_component.current_health != 830:
		_fail("concurrent discharges should deal 100 then 70 electric damage inside 100 px")
		return
	if heavy.health_component.current_health != 1000:
		_fail("discharge should not affect enemies outside its 100 px radius")
		return
	if absf(outside.velocity.x) > 0.001:
		_fail("enemies outside the 200 px attraction radius should not be pulled")
		return
	if nearby.velocity.x <= 0.0:
		_fail("discharge should knock a nearby enemy away from the magnet")
		return
	if heavy.velocity.x >= 0.0:
		_fail("magnet should pull in an enemy within 200 px")
		return
	if absf(heavy.velocity.x) >= absf(nearby.velocity.x):
		_fail("higher enemy weight should reduce magnetic acceleration")
		return
	if not magnet._magnetic_overload_fields.is_empty():
		_fail("magnetic fields should end after three seconds")
		return

	print("Magnetic overload integration checks: PASS")
	await _finish(0)

func _fail(message: String) -> void:
	push_error("Magnetic overload integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
