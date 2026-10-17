extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	await get_tree().process_frame

	enemy.definition.resistances["ether"] = 1.0
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0)
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0)
	if enemy.health_component.current_health != 900:
		_fail("first hemorrhage should deal 10% max-health pure damage")
		return

	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0)
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0)
	if enemy.health_component.current_health != 830:
		_fail("repeated hemorrhage should deal 7% max-health pure damage")
		return

	print("Hemorrhage integration checks: PASS")
	await _finish(0)

func _fail(message: String) -> void:
	push_error("Hemorrhage integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
