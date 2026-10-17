extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var weapon := load("res://Resources/Weapons/fists.tres") as WeaponData
	if weapon == null or weapon.attacks.size() != 4:
		print("FAIL: the fists resource should contain its four combo attacks")
		quit(1)
		return
	for index in range(weapon.attacks.size()):
		if weapon.attacks[index].animation_name != "PlayerAttack_%d" % (index + 1):
			print("FAIL: each combo attack should select its own animation")
			quit(1)
			return

	var player_scene := load("res://Scenes/actors/player.tscn") as PackedScene
	if player_scene == null:
		print("FAIL: the player scene should load")
		quit(1)
		return
	var player: Node = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var controller := player.get_node("WeaponController") as WeaponController
	if controller == null or controller.weapon_data.id != weapon.id or controller.hit_shapes.size() != 1:
		print("FAIL: the player should equip the fists definition and its first attack zone")
		await _finish_test(player, 1)
		return
	if not controller.start_attack():
		print("FAIL: the default weapon should start its first combo attack")
		await _finish_test(player, 1)
		return
	controller.finish_attack()
	if controller.runtime.combo_index != 1 or controller.get_current_attack().animation_name != "PlayerAttack_2":
		print("FAIL: the next combo attack should use its own attack definition")
		await _finish_test(player, 1)
		return

	var inventory := player.get_node("InventoryData") as InventoryData
	var primary_weapon := ItemData.new()
	primary_weapon.id = "test_primary"
	primary_weapon.item_name = "Test Primary"
	primary_weapon.type = "weapon"
	primary_weapon.weapon_definition = weapon.duplicate() as WeaponData
	primary_weapon.weapon_definition.id = "test_primary"
	if not inventory.set_equipment_item("primary_weapon", primary_weapon):
		print("FAIL: a valid primary weapon should be equipable")
		await _finish_test(player, 1)
		return
	if controller.weapon_data.id != "test_primary":
		print("FAIL: equipping the primary weapon should update the player's weapon controller")
		await _finish_test(player, 1)
		return

	var backup_weapon := ItemData.new()
	backup_weapon.id = "test_backup"
	backup_weapon.item_name = "Test Backup"
	backup_weapon.type = "weapon"
	backup_weapon.weapon_definition = weapon.duplicate() as WeaponData
	backup_weapon.weapon_definition.id = "test_backup"
	if not inventory.set_equipment_item("backup_weapon", backup_weapon) \
	or not inventory.set_active_weapon_slot("backup"):
		print("FAIL: the backup weapon slot should be selectable")
		await _finish_test(player, 1)
		return
	if controller.weapon_data.id != "test_backup":
		print("FAIL: selecting the backup slot should update the player's weapon controller")
		await _finish_test(player, 1)
		return

	var alternate_weapon := _make_multi_zone_weapon()
	var config_manager := root.get_node("ConfigManager")
	var configs: Dictionary = config_manager.get("configs")
	var weapon_configs: Dictionary = configs["weapons"]
	weapon_configs["test_weapon"] = {
		"attack_speed": 1.5,
		"combo_reset_time": 2.0,
		"damage_list": [22],
		"knockback_list": [75.0],
		"attack_time_list": [1.0]
	}
	configs["weapons"] = weapon_configs
	config_manager.set("configs", configs)
	if not bool(player.call("equip_weapon", alternate_weapon)):
		print("FAIL: the player should equip another valid weapon definition")
		await _finish_test(player, 1)
		return
	var config_overrides_applied := (
		controller.weapon_data.attacks[0].damage == 22
		and controller.weapon_data.attacks[0].duration == 1.0
		and alternate_weapon.attacks[0].damage == 10
	)
	if not config_overrides_applied:
		print("FAIL: config overrides should affect runtime data without mutating the weapon resource")
		await _finish_test(player, 1)
		return
	if controller.hit_shapes.size() != 2:
		print("FAIL: all damage zones for the active attack should be created")
		await _finish_test(player, 1)
		return
	if not controller.start_attack():
		print("FAIL: the equipped weapon should start its first attack")
		await _finish_test(player, 1)
		return
	await physics_frame
	if controller.hit_shapes[0].disabled or not controller.hit_shapes[1].disabled:
		print("FAIL: hitboxes should follow their configured active windows")
		await _finish_test(player, 1)
		return
	controller._process(0.6)
	await physics_frame
	if controller.hit_shapes[1].disabled:
		print("FAIL: a later hitbox should activate during its configured window")
		await _finish_test(player, 1)
		return
	if bool(player.call("equip_weapon", weapon)):
		print("FAIL: weapon switching should be rejected during an attack")
		await _finish_test(player, 1)
		return

	controller.cancel_attack()
	if not bool(player.call("equip_weapon", weapon)) or controller.hit_shapes.size() != 1:
		print("FAIL: the player should be able to switch weapons after cancelling the attack")
		await _finish_test(player, 1)
		return

	print("Weapon definition checks: PASS")
	await _finish_test(player, 0)

func _make_multi_zone_weapon() -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = "test_weapon"
	weapon.display_name = "Test Weapon"

	var attack := AttackDefinition.new()
	attack.attack_name = "Two-zone strike"
	attack.animation_name = "PlayerAttack_1"
	var first_zone := WeaponHitboxDefinition.new()
	first_zone.shape = CircleShape2D.new()
	first_zone.offset = Vector2(12.0, 0.0)
	var second_zone := WeaponHitboxDefinition.new()
	second_zone.shape = RectangleShape2D.new()
	second_zone.offset = Vector2(20.0, 0.0)
	second_zone.active_start_ratio = 0.5
	attack.hitboxes = [first_zone, second_zone]
	weapon.attacks = [attack]
	return weapon

func _finish_test(player: Node, exit_code: int) -> void:
	player.queue_free()
	await process_frame
	quit(exit_code)
