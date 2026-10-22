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

	var expected_colors := {
		DamageTypes.Type.PURE: Color.WHITE,
		DamageTypes.Type.PHYSICAL: Color.RED,
		DamageTypes.Type.ETHER: Color("#A020F0"),
		DamageTypes.Type.FIRE: Color("#FF8C00"),
		DamageTypes.Type.ICE: Color("#00BFFF"),
		DamageTypes.Type.ELECTRIC: Color.YELLOW
	}
	for damage_type_value in expected_colors:
		var damage_type := int(damage_type_value)
		presentation.show_hit(dummy, 15, hit_position, damage_type)
		var latest_number := _get_latest_damage_number(test_scene)
		var number_label: RichTextLabel = null
		if latest_number != null:
			number_label = latest_number.get_node("RichTextLabel") as RichTextLabel
		if number_label == null or number_label.get_theme_color("default_color") != expected_colors[damage_type]:
			print("FAIL: damage type %d should use its configured number color" % damage_type)
			await _finish_test(test_scene, 1)
			return

	presentation.show_hit(dummy, 15, hit_position, DamageTypes.Type.FIRE)
	var regular_number := _get_latest_damage_number(test_scene)
	var regular_label: RichTextLabel = null
	if regular_number != null:
		regular_label = regular_number.get_node("RichTextLabel") as RichTextLabel
	if regular_label == null or regular_label.material != null:
		print("FAIL: regular damage should not have a custom material")
		await _finish_test(test_scene, 1)
		return
	var regular_font_size := regular_label.get_theme_font_size("normal_font_size")

	presentation.show_hit(dummy, 15, hit_position, DamageTypes.Type.FIRE, true)
	var reaction_number := _get_latest_damage_number(test_scene)
	var reaction_label: RichTextLabel = null
	if reaction_number != null:
		reaction_label = reaction_number.get_node("RichTextLabel") as RichTextLabel
	if (
		reaction_label == null
		or reaction_label.material != null
		or reaction_label.get_theme_color("font_outline_color") != Color.WHITE
		or reaction_label.get_theme_constant("outline_size") <= 0
		or reaction_label.get_theme_font_size("normal_font_size") <= regular_font_size
	):
		print("FAIL: reaction damage should have a white outline and larger text without a custom material")
		await _finish_test(test_scene, 1)
		return

	presentation.show_hit(player, 15, hit_position)
	var player_number := _get_latest_damage_number(test_scene)
	var player_label: RichTextLabel = null
	if player_number != null:
		player_label = player_number.get_node("RichTextLabel") as RichTextLabel
	if player_label == null or player_label.get_theme_color("default_color") != Color("#8B0000"):
		print("FAIL: player damage should use dark red")
		await _finish_test(test_scene, 1)
		return

	print("Combat presentation checks: PASS")
	await _finish_test(test_scene, 0)

func _get_latest_damage_number(test_scene: Node) -> Node2D:
	for index in range(test_scene.get_child_count() - 1, -1, -1):
		var child := test_scene.get_child(index)
		if child.name.begins_with("DamageNumber"):
			return child as Node2D
	return null

func _finish_test(test_scene: Node, exit_code: int) -> void:
	test_scene.queue_free()
	await process_frame
	quit(exit_code)
