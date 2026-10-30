extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	await get_tree().process_frame
	enemy.process_mode = Node.PROCESS_MODE_DISABLED

	var custom_definition := EnemyDefinition.new("status_test", {
		"status_duration_overrides": {"immobilize": 4.0}
	})
	enemy.set_definition(custom_definition)
	enemy.apply_status("immobilize")
	var immobilize := enemy.status_effect_manager.get_effect("immobilize")
	if immobilize == null or not is_equal_approx(immobilize.duration, 4.0):
		_fail("enemy status duration overrides should replace the catalog default")
		return
	if enemy.can_perform_action("move") or enemy.can_perform_action("jump") or enemy.can_perform_action("dash"):
		_fail("immobilize should block movement, jumping and rolling")
		return
	if not enemy.can_perform_action("attack") or enemy.status_effect_manager.is_physics_disabled():
		_fail("immobilize should preserve attacks and physics")
		return
	enemy.status_effect_manager.remove("immobilize")

	enemy.apply_status("slow")
	if (
		not is_equal_approx(enemy.get_status_multiplier("movement_speed"), 0.5)
		or not is_equal_approx(enemy.get_status_multiplier("animation_speed"), 0.5)
		or not is_equal_approx(enemy.get_status_multiplier("attack_speed"), 0.5)
	):
		_fail("slow should reduce movement, animation and attack speed by half")
		return
	enemy.status_effect_manager.remove("slow")

	enemy.apply_status("stun")
	if enemy.can_perform_action("attack") or enemy.status_effect_manager.is_physics_disabled():
		_fail("stun should block attacks without disabling physics")
		return
	var health_before_stun := enemy.health_component.current_health
	enemy.health_component.take_damage(10)
	enemy.health_component.heal(10)
	if enemy.health_component.current_health != health_before_stun:
		_fail("stun should continue to allow damage and healing")
		return
	enemy.status_effect_manager.remove("stun")

	var target := Node2D.new()
	enemy.add_child(target)
	enemy.set_target(target)
	enemy.apply_status("blind")
	if enemy.get_target() != null:
		_fail("blind enemies should not expose their player target")
		return
	enemy.status_effect_manager.remove("blind")
	if enemy.get_target() != target:
		_fail("target access should resume after blindness")
		return

	var health_before_freeze := enemy.health_component.current_health
	enemy.apply_status("freeze")
	if not enemy.status_effect_manager.is_physics_disabled():
		_fail("freeze should disable physics")
		return
	if not enemy.get_node("Sprite2D").material is ShaderMaterial:
		_fail("freeze should apply its visual shader")
		return
	enemy.apply_damage(100, enemy.global_position)
	enemy.health_component.heal(100)
	if enemy.health_component.current_health != health_before_freeze:
		_fail("freeze should defer damage and block healing until it ends")
		return
	enemy.status_effect_manager.tick(10.0)
	if enemy.health_component.current_health != health_before_freeze - 100:
		_fail("deferred damage should be applied when freeze expires")
		return
	if enemy.get_node("Sprite2D").material != null:
		_fail("freeze shader should be removed when freeze expires")
		return

	var player := load("res://Scenes/actors/player.tscn").instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.apply_status("immobilize")
	if player.can_perform_action("move") or player.can_perform_action("jump") or player.can_perform_action("dash"):
		_fail("player should use the same immobilize action rules as enemies")
		return
	if not player.can_perform_action("attack"):
		_fail("player should still be able to attack while immobilized")
		return
	player.status_effect_manager.remove("immobilize")
	var player_health := player.get_node("HealthComponent") as HealthComponent
	player_health.current_health = player_health.max_health
	player.apply_status("freeze")
	player.take_damage(20)
	var health_while_frozen := player_health.current_health
	player_health.heal(10)
	if health_while_frozen != player_health.max_health or player_health.current_health != health_while_frozen:
		_fail("player freeze should defer damage and block healing")
		return
	player.status_effect_manager.tick(10.0)
	if player_health.current_health != player_health.max_health - 20:
		_fail("player freeze should release deferred damage when it expires")
		return

	print("Status effect integration checks: PASS")
	await _finish(0)

func _fail(message: String) -> void:
	push_error("Status effect integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
