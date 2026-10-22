extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var attacker := Node2D.new()
	attacker.add_to_group("Player")
	var attacker_health := HealthComponent.new()
	attacker_health.name = "HealthComponent"
	attacker.add_child(attacker_health)
	add_child(attacker)

	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	await get_tree().process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	attacker_health.current_health = 50

	_trigger_exhaustion(enemy, attacker)
	if not is_equal_approx(enemy._exhaustion_remaining, 5.0):
		_fail("exhaustion should mark the enemy for five seconds")
		return

	enemy.apply_elemental_hit(100, enemy.global_position, ElementalTypes.ElementType.NONE, 0.0, Vector2.ZERO, attacker)
	if attacker_health.current_health != 60:
		_fail("the first marked hit should heal 10% of damage dealt")
		return

	_trigger_exhaustion(enemy, attacker)
	enemy.apply_elemental_hit(100, enemy.global_position, ElementalTypes.ElementType.NONE, 0.0, Vector2.ZERO, attacker)
	if attacker_health.current_health != 67:
		_fail("a repeated exhaustion reaction should reduce healing by 30%")
		return

	enemy._advance_exhaustion(5.0)
	enemy.apply_elemental_hit(100, enemy.global_position, ElementalTypes.ElementType.NONE, 0.0, Vector2.ZERO, attacker)
	if attacker_health.current_health != 67:
		_fail("expired exhaustion should no longer heal the attacker")
		return

	print("Exhaustion integration checks: PASS")
	await _finish(0)

func _trigger_exhaustion(enemy: Dummy, attacker: Node) -> void:
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ELECTRIC, 100.0)
	enemy.apply_elemental_hit(0, enemy.global_position, ElementalTypes.ElementType.ETHER, 100.0, Vector2.ZERO, attacker)

func _fail(message: String) -> void:
	push_error("Exhaustion integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
