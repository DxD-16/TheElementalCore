extends SceneTree

func _initialize() -> void:
	var failures := 0
	failures += _check_weight_scales_knockback()
	failures += _check_invalid_weight_keeps_default()

	if failures == 0:
		print("Enemy weight checks: PASS")
		quit(0)
	else:
		print("Enemy weight checks: FAIL (%d checks failed)" % failures)
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
