extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var source := _create_enemy(Vector2.ZERO)
	var inside := _create_enemy(Vector2(60.0, 0.0))
	var outside := _create_enemy(Vector2(0.0, 51.0))
	var target := Node2D.new()
	source.add_child(target)
	source.set_target(target)
	await get_tree().process_frame
	for enemy in [source, inside, outside]:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

	_trigger_condensation(source)
	var cloud := _get_latest_cloud()
	if cloud == null:
		_fail("fire and ice should create a condensation cloud")
		return
	if not is_equal_approx(cloud.remaining, 5.0) or not is_equal_approx(cloud.cloud_radius, 50.0) or not is_equal_approx(cloud.cloud_length, 40.0):
		_fail("condensation cloud should use its configured duration and capsule dimensions")
		return
	cloud.advance(0.01)
	if not source.has_status("blind") or not inside.has_status("blind"):
		_fail("enemies inside the horizontal capsule should be blinded")
		return
	if source.get_target() != null:
		_fail("blinded enemies should not see their current target")
		return
	if outside.has_status("blind"):
		_fail("enemies outside the capsule should not be blinded")
		return
	cloud.advance(4.99)
	if source.elemental_gauge.get_value(ElementalTypes.ElementType.WATER) != source.elemental_gauge.charge_threshold:
		_fail("affected enemies should receive full water charge when the cloud disperses")
		return
	if inside.elemental_gauge.get_value(ElementalTypes.ElementType.WATER) != inside.elemental_gauge.charge_threshold:
		_fail("all affected enemies should receive full water charge")
		return
	if outside.elemental_gauge.get_value(ElementalTypes.ElementType.WATER) != 0.0:
		_fail("enemies outside the capsule should not become wet")
		return
	for enemy in [source, inside, outside]:
		enemy.status_effect_manager.tick(5.0)
	if source.has_status("blind"):
		_fail("blindness should expire after the cloud has dispersed")
		return
	if source.get_target() != target:
		_fail("enemy target access should resume after blindness expires")
		return

	source.elemental_gauge.reset_element(ElementalTypes.ElementType.WATER)
	_trigger_condensation(source)
	cloud = _get_latest_cloud()
	if cloud == null or not is_equal_approx(cloud.remaining, 3.5):
		_fail("the second reaction should reduce cloud lifetime by 30 percent")
		return
	cloud.advance(3.5)
	if source.elemental_gauge.get_value(ElementalTypes.ElementType.WATER) != source.elemental_gauge.charge_threshold:
		_fail("the 70-percent repeat should still apply wet")
		return

	source.elemental_gauge.reset_element(ElementalTypes.ElementType.WATER)
	_trigger_condensation(source)
	cloud = _get_latest_cloud()
	if cloud == null or not is_equal_approx(cloud.remaining, 2.45):
		_fail("the third reaction should scale cloud lifetime with its 49-percent strength")
		return
	cloud.advance(2.45)
	if source.elemental_gauge.get_value(ElementalTypes.ElementType.WATER) != 0.0:
		_fail("reactions below 69 percent strength should not apply wet")
		return

	print("Condensation integration checks: PASS")
	await _finish(0)

func _create_enemy(position: Vector2) -> Dummy:
	var enemy := load("res://Scenes/enemies/dummy.tscn").instantiate() as Dummy
	add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	return enemy

func _trigger_condensation(source: Dummy) -> void:
	source.apply_elemental_hit(0, source.global_position, ElementalTypes.ElementType.FIRE, 100.0)
	source.apply_elemental_hit(0, source.global_position, ElementalTypes.ElementType.ICE, 100.0)

func _get_latest_cloud() -> SteamCloud:
	var clouds := get_tree().get_nodes_in_group("SteamClouds")
	if clouds.is_empty():
		return null
	return clouds[clouds.size() - 1] as SteamCloud

func _fail(message: String) -> void:
	push_error("Condensation integration checks: " + message)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
