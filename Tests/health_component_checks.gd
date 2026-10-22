extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var health := HealthComponent.new()
	root.add_child(health)
	await process_frame
	health.current_health = 40

	health.take_damage(-10)
	if health.current_health != 40:
		print("FAIL: negative damage must not increase health")
		health.queue_free()
		await process_frame
		quit(1)
		return

	health.take_damage(10)
	if health.current_health != 30:
		print("FAIL: positive damage should still reduce health")
		health.queue_free()
		await process_frame
		quit(1)
		return

	print("Health component checks: PASS")
	health.queue_free()
	await process_frame
	quit(0)
