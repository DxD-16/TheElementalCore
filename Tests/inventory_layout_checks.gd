extends SceneTree

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("Player")
	var inventory := InventoryData.new()
	inventory.name = "InventoryData"
	inventory.slot_count = 24
	player.add_child(inventory)
	var health := HealthComponent.new()
	player.add_child(health)
	host.add_child(player)
	var canvas_layer := CanvasLayer.new()
	host.add_child(canvas_layer)

	var ui_scene := load("res://Scenes/ui/inventory_ui.tscn") as PackedScene
	if ui_scene == null:
		await _finish(host, 1, "Inventory UI scene should load")
		return
	var ui := ui_scene.instantiate() as InventoryUI
	canvas_layer.add_child(ui)
	await process_frame
	await process_frame

	if inventory.slots.size() != 24 or inventory.equipment_storage_slots.size() != 15:
		await _finish(host, 1, "Inventory should initialize both storage grids")
		return
	if ui.main_slot_buttons.size() != 24 or ui.equipment_slot_buttons.size() != 15:
		await _finish(host, 1, "UI grids should match the inventory storage capacities")
		return
	if ui.physical_equipment_buttons.size() != 12:
		await _finish(host, 1, "UI should expose two weapon slots, four stone slots and six accessory slots")
		return

	var weapon_definition := WeaponItemDefinition.new()
	weapon_definition.id = "test_weapon"
	weapon_definition.item_name = "Test Weapon"
	weapon_definition.weapon_definition = WeaponData.new()
	var weapon_item := ItemInstance.new()
	weapon_item.definition = weapon_definition
	var accessory_definition := AccessoryItemDefinition.new()
	accessory_definition.id = "test_accessory"
	accessory_definition.item_name = "Test Accessory"
	var accessory_item := ItemInstance.new()
	accessory_item.definition = accessory_definition
	var stone_definition := StoneItemDefinition.new()
	stone_definition.id = "test_stone"
	stone_definition.item_name = "Test Stone"
	var stone_item := ItemInstance.new()
	stone_item.definition = stone_definition

	if not inventory.set_equipment_item("primary_weapon", weapon_item) \
	or not inventory.set_equipment_item("accessory_0", accessory_item) \
	or not inventory.set_equipment_item("primary_weapon_stone", stone_item):
		await _finish(host, 1, "Each equipment type should fit its matching slot")
		return
	if inventory.set_equipment_item("accessory_1", weapon_item) \
	or inventory.set_equipment_item("primary_weapon", accessory_item) \
	or inventory.set_equipment_item("accessory_2", stone_item) \
	or inventory.set_equipment_item("primary_weapon_stone", accessory_item):
		await _finish(host, 1, "Equipment slots should reject incompatible item types")
		return
	if inventory.get_equipment_item("primary_weapon") != weapon_item \
	or inventory.get_equipment_item("accessory_0") != accessory_item \
	or inventory.get_equipment_item("primary_weapon_stone") != stone_item:
		await _finish(host, 1, "Rejected equipment should not change equipped items")
		return

	ui._handle_physical_equipment_click("primary_weapon")
	if ui.held_item != weapon_item or ui.held_quantity != 1 \
	or inventory.get_equipment_item("primary_weapon") != null:
		await _finish(host, 1, "Clicking an equipped item should pick it up")
		return
	ui._handle_physical_equipment_click("accessory_0")
	if ui.held_item != weapon_item \
	or inventory.get_equipment_item("accessory_0") != accessory_item:
		await _finish(host, 1, "Invalid equipment attempts should preserve the held item")
		return
	ui._handle_physical_equipment_click("backup_weapon")
	if ui.held_item != null or inventory.get_equipment_item("backup_weapon") != weapon_item:
		await _finish(host, 1, "A held weapon should equip into a compatible empty slot")
		return

	var catalog := root.get_node_or_null("ItemCatalogService") as ItemCatalog
	var potion_definition := catalog.get_definition("health_potion") if catalog else null
	if potion_definition == null:
		await _finish(host, 1, "Health potion definition should load from the item catalog")
		return
	if inventory.add_item_by_id("health_potion", 12) != 0:
		await _finish(host, 1, "Equipment storage should accept the full potion stack")
		return
	if inventory.equipment_storage_slots[0].quantity != 10 \
	or inventory.equipment_storage_slots[1].quantity != 2 \
	or not inventory.slots[0].is_empty():
		await _finish(host, 1, "Weapons, stones, accessories and consumables should use equipment storage")
		return

	ui._handle_right_click("equipment", 0)
	if ui.held_quantity != 5 or inventory.equipment_storage_slots[0].quantity != 5:
		await _finish(host, 1, "Right-click should take the upper half of a stack")
		return
	ui._handle_left_click("equipment", 2)
	if ui.held_quantity != 4 or inventory.equipment_storage_slots[2].quantity != 1:
		await _finish(host, 1, "Left-click on an empty cell should place one item")
		return
	ui._handle_left_click("main", 2)
	if ui.held_quantity != 4 or not inventory.slots[2].is_empty():
		await _finish(host, 1, "Equipment items should not move into the main inventory")
		return

	var quest_definition := QuestItemDefinition.new()
	quest_definition.id = "test_quest_item"
	quest_definition.item_name = "Test Quest Item"
	var quest_item := ItemInstance.new()
	quest_item.definition = quest_definition
	if inventory.add_item_instance(quest_item, 1) != 0 \
	or inventory.slots[0].item.id != "test_quest_item":
		await _finish(host, 1, "Quest items should use the main inventory")
		return

	ui._transfer_quick_consumable(0)
	var equipped_potion := inventory.get_equipment_item("consumable_0")
	if equipped_potion == null or equipped_potion.id != "health_potion" \
	or inventory.get_equipment_quantity("consumable_0") != 4 or ui.held_quantity != 0:
		await _finish(host, 1, "Held consumables should be assignable to quick-use slots")
		return

	health.current_health = 0
	if not inventory.use_equipped_consumable(0) or health.current_health != 50:
		await _finish(host, 1, "Quick-use consumables should apply their configured behavior")
		return
	if inventory.get_equipment_quantity("consumable_0") != 3:
		await _finish(host, 1, "Using a quick consumable should decrement its quantity")
		return

	var open_event := InputEventKey.new()
	open_event.pressed = true
	open_event.physical_keycode = KEY_I
	Input.parse_input_event(open_event)
	await process_frame
	if not ui.visible or not paused:
		await _finish(host, 1, "I should open inventory and pause the game")
		return
	if not ui._is_transitioning or ui.panels.position.y <= 0.0:
		await _finish(host, 1, "Opening should animate the panels up from below the screen")
		return
	await create_timer(0.35, true).timeout
	if ui._is_transitioning or not is_equal_approx(ui.panels.position.y, 0.0):
		await _finish(host, 1, "Opening transition should finish in 0.3 seconds")
		return

	var next_event := InputEventKey.new()
	next_event.pressed = true
	next_event.physical_keycode = KEY_D
	Input.parse_input_event(next_event)
	await process_frame
	if ui._active_window_index != 2 or not ui._is_transitioning:
		await _finish(host, 1, "D should start a horizontal transition to the next panel")
		return
	await create_timer(0.35, true).timeout
	if not is_equal_approx(ui.panels.position.x, -1920.0):
		await _finish(host, 1, "Next panel should slide into view")
		return

	var previous_event := InputEventKey.new()
	previous_event.pressed = true
	previous_event.physical_keycode = KEY_A
	Input.parse_input_event(previous_event)
	await process_frame
	if ui._active_window_index != 1:
		await _finish(host, 1, "A should select the previous panel")
		return
	await create_timer(0.35, true).timeout
	if not is_equal_approx(ui.panels.position.x, -960.0):
		await _finish(host, 1, "Previous panel should slide back into view")
		return

	var close_event := InputEventKey.new()
	close_event.pressed = true
	close_event.physical_keycode = KEY_TAB
	Input.parse_input_event(close_event)
	await process_frame
	if not ui.visible or not ui._is_transitioning or not paused \
	or ui.panels.position.y <= 0.0:
		await _finish(host, 1, "Closing should animate the panels down without resuming early")
		return
	await create_timer(0.35, true).timeout
	if ui.visible or paused:
		await _finish(host, 1, "Tab should close inventory and restore the previous pause state")
		return

	print("Inventory layout checks: PASS")
	await _finish(host, 0)

func _finish(host: Node, exit_code: int, failure: String = "") -> void:
	if not failure.is_empty():
		print("FAIL: %s" % failure)
	host.queue_free()
	await process_frame
	quit(exit_code)
