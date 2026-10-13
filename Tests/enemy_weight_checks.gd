extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var failures := 0
	failures += _check_weight_scales_knockback()
	failures += _check_invalid_weight_keeps_default()
	failures += await _check_horizontal_friction_preserves_gravity()

	if failures == 0:
		print("Enemy physics checks: PASS")
		quit(0)
	else:
		print("Enemy physics checks: FAIL (%d checks failed)" % failures)
		quit(1)

func _check_weight_scales_knockback() -> int:
	var enemy_script = load("res://Scripts/enemies/enemy_base.gd")
	var light_enemy = enemy_script.new()
	light_enemy.set_definition(EnemyDefinition.new("light", {"weight": 0.5}))
	light_enemy.apply_knockback(Vector2(100.0, 0.0))

	var heavy_enemy = enemy_script.new()
	heavy_enemy.set_definition(EnemyDefinition.new("heavy", {"weight": 2.0}))
	heavy_enemy.apply_knockback(Vector2(100.0, 0.0))

	var passed := is_equal_approx(light_enemy.velocity.x, 200.0) and is_equal_approx(heavy_enemy.velocity.x, 50.0)
	light_enemy.free()
	heavy_enemy.free()
	if not passed:
		print("FAIL: lighter enemies should receive more knockback than heavier enemies")
		return 1
	return 0

func _check_invalid_weight_keeps_default() -> int:
	var definition := EnemyDefinition.new("invalid_weight", {"weight": 0.0})
	if not is_equal_approx(definition.weight, 1.0):
		print("FAIL: non-positive weight should retain the safe default")
		return 1
	return 0

func _check_horizontal_friction_preserves_gravity() -> int:
	var enemy_script = load("res://Scripts/enemies/enemy_base.gd")
	var enemy = enemy_script.new()
	root.add_child(enemy)
	enemy.set_definition(EnemyDefinition.new("friction_test", {"horizontal_friction": 900.0}))
	await physics_frame
	enemy.velocity = Vector2(300.0, 0.0)
	await physics_frame

	var friction_reduces_horizontal_speed: bool = enemy.velocity.x < 300.0
	var gravity_increases_vertical_speed: bool = enemy.velocity.y > 0.0
	enemy.queue_free()
	await process_frame
	if not friction_reduces_horizontal_speed or not gravity_increases_vertical_speed:
		print("FAIL: enemy friction should slow horizontal motion without cancelling gravity")
		return 1
	return 0
