extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var test_scene := Node2D.new()
	root.add_child(test_scene)
	current_scene = test_scene

	var player = load("res://Scenes/actors/player.tscn").instantiate()
	var dummy = load("res://Scenes/enemies/dummy.tscn").instantiate()
	test_scene.add_child(player)
	test_scene.add_child(dummy)
	player.global_position = Vector2.ZERO
	dummy.global_position = Vector2(25.0, 0.0)
	dummy.contact_damage = 0
	player.set_physics_process(false)
	dummy.set_physics_process(false)

	await physics_frame
	await physics_frame

	var weapon_controller = player.get_weapon_controller()
	var hit_position: Vector2 = weapon_controller._get_hit_position(dummy, weapon_controller.hit_shapes[0])
	if hit_position.distance_squared_to(dummy.global_position) < 0.001:
		print("FAIL: hit position should be the collision contact, not the target origin")
		await _finish_test(test_scene, 1)
		return

	var presentation: Node = root.get_node("CombatPresentation")
	var previous_numbers: Array[int] = []
	for child in test_scene.get_children():
		if child.name.begins_with("DamageNumber"):
			previous_numbers.append(child.get_instance_id())
	presentation.show_hit(dummy, 15, hit_position)
	var sprite: Sprite2D = dummy.get_node("Sprite2D")
	if not sprite.material is ShaderMaterial:
		print("FAIL: presentation should flash the target visual")
		await _finish_test(test_scene, 1)
		return
	var flash_material := sprite.material as ShaderMaterial
	if flash_material.get_shader_parameter("flash_color") != Color.WHITE:
		print("FAIL: hit flash should use white")
		await _finish_test(test_scene, 1)
		return

	var damage_number: Node2D
	for child in test_scene.get_children():
		if child.name.begins_with("DamageNumber") and not previous_numbers.has(child.get_instance_id()):
			damage_number = child as Node2D
			break
	if damage_number == null or not damage_number.global_position.is_equal_approx(hit_position):
		print("FAIL: damage number should spawn at the collision contact")
		await _finish_test(test_scene, 1)
		return

	print("Combat presentation checks: PASS")
	await _finish_test(test_scene, 0)

func _finish_test(test_scene: Node, exit_code: int) -> void:
	test_scene.queue_free()
	await process_frame
	quit(exit_code)
