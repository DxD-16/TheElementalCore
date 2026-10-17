extends SceneTree

class ChestStub:
	extends Node
	var chest_name: String = "Test Chest"

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	root.size = Vector2i(1920, 1080)
	var host := Node2D.new()
	root.add_child(host)
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("Player")
	var inventory_data := InventoryData.new()
	inventory_data.name = "InventoryData"
	player.add_child(inventory_data)
	host.add_child(player)
	var canvas_layer := CanvasLayer.new()
	host.add_child(canvas_layer)
	var ui_scene := load("res://Scenes/ui/inventory_ui.tscn") as PackedScene
	if ui_scene == null:
		print("FAIL: inventory UI scene should load")
		await _finish_test(host, 1)
		return
	var ui := ui_scene.instantiate() as InventoryUI
	canvas_layer.add_child(ui)
	await process_frame
	await process_frame
	ui.open_player_only()
	await process_frame

	var panels := ui.get_node("Center/Panels") as HBoxContainer
	if panels == null or panels.get_child_count() != 3:
		print("FAIL: the inventory should have three vertical panels")
		await _finish_test(host, 1)
		return
	if ui.player_grid.get_child_count() != inventory_data.slots.size():
		print("FAIL: an empty inventory should still display every slot")
		await _finish_test(host, 1)
		return
	for slot_button in ui.player_grid.get_children():
		var button := slot_button as Button
		if button.text.strip_edges() != "":
			print("FAIL: empty inventory slots should be visually empty")
			await _finish_test(host, 1)
			return
		if button.custom_minimum_size.x <= 0.0 or button.custom_minimum_size.y <= 0.0 \
		or button.size.x < button.custom_minimum_size.x or button.size.y < button.custom_minimum_size.y:
			print("FAIL: empty inventory slots should keep their scene-defined size")
			await _finish_test(host, 1)
			return
	var panel_layout_rect := panels.get_global_rect()
	if panel_layout_rect.size.x <= 0.0 or panel_layout_rect.size.y <= 0.0 \
	or not Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0)).encloses(panel_layout_rect):
		print("FAIL: panel layout rect is outside the viewport: %s" % panel_layout_rect)
		await _finish_test(host, 1)
		return
	var player_scroll := ui.get_node("Center/Panels/InventoryPanel/Margin/Content/PlayerInventoryPanel/Margin/Content/Scroll") as ScrollContainer
	var equipment_scroll := ui.get_node("Center/Panels/EquipmentPanel/Margin/Content/GearPanel/Margin/Scroll") as ScrollContainer
	var first_slot := ui.player_grid.get_child(0) as Control
	if player_scroll.size.y < 200.0 \
	or equipment_scroll.size.y < 200.0 \
	or first_slot.size.x < first_slot.custom_minimum_size.x \
	or first_slot.size.y < first_slot.custom_minimum_size.y \
	or not player_scroll.get_global_rect().intersects(first_slot.get_global_rect()):
		print("FAIL: inventory/equipment sections must expand and show real slot controls")
		await _finish_test(host, 1)
		return
	if ui.equipment_slots.size() != 15:
		print("FAIL: the equipment slot count is incorrect")
		await _finish_test(host, 1)
		return
	var weapon_slot: Button = ui.equipment_slots["primary_weapon"]
	var accessory_slot: Button = ui.equipment_slots["accessory_2"]
	var stone_slot: Button = ui.equipment_slots["primary_weapon_stone"]
	if weapon_slot.custom_minimum_size.x <= accessory_slot.custom_minimum_size.x \
	or accessory_slot.custom_minimum_size.x <= stone_slot.custom_minimum_size.x:
		print("FAIL: weapon, accessory and stone slots should use descending sizes")
		await _finish_test(host, 1)
		return
	if ui.close_button.get_parent().get_parent().get_parent().get_parent() != panels.get_child(2):
		print("FAIL: the close button should be inside the third panel")
		await _finish_test(host, 1)
		return
	if ui.equipment_slots["primary_weapon"].get_parent() != ui.equipment_slots["primary_weapon_stone"].get_parent() \
	or ui.equipment_slots["accessory_0"].get_parent() != ui.equipment_slots["accessory_stone_0"].get_parent():
		print("FAIL: stone slots should appear next to their equipment carriers")
		await _finish_test(host, 1)
		return

	var inventory := inventory_data
	var weapon := ItemData.new()
	weapon.id = "test_weapon"
	weapon.item_name = "Test Weapon"
	weapon.type = "weapon"
	weapon.weapon_definition = (load("res://Resources/Weapons/fists.tres") as WeaponData).duplicate() as WeaponData
	weapon.weapon_definition.id = "test_equipped_weapon"
	var backup_weapon := ItemData.new()
	backup_weapon.id = "backup_weapon"
	backup_weapon.item_name = "Backup Weapon"
	backup_weapon.type = "weapon"
	backup_weapon.weapon_definition = weapon.weapon_definition.duplicate() as WeaponData
	backup_weapon.weapon_definition.id = "test_backup_weapon"
	var stone := ItemData.new()
	stone.id = "test_stone"
	stone.item_name = "Test Stone"
	stone.type = "stone"
	var accessory := ItemData.new()
	accessory.id = "test_accessory"
	accessory.item_name = "Test Accessory"
	accessory.type = "accessory"
	if not inventory.set_equipment_item("primary_weapon", weapon) \
	or not inventory.set_equipment_item("backup_weapon", backup_weapon) \
	or not inventory.set_equipment_item("primary_weapon_stone", stone) \
	or not inventory.set_equipment_item("accessory_0", accessory) \
	or not inventory.set_equipment_item("accessory_stone_0", stone):
		print("FAIL: valid gear and stone items should fit their matching equipment slots")
		await _finish_test(host, 1)
		return
	if not inventory.set_active_weapon_slot("backup") or inventory.active_weapon_slot != "backup":
		print("FAIL: the active weapon slot should be switchable")
		await _finish_test(host, 1)
		return
	if inventory.backup_weapon.weapon_definition.id != "test_backup_weapon":
		print("FAIL: the backup weapon equipment slot should keep its weapon definition")
		await _finish_test(host, 1)
		return

	inventory.slots[0].set_slot(weapon, 1)
	inventory.slots[1].set_slot(stone, 1)
	var replacement_weapon := weapon.duplicate() as ItemData
	replacement_weapon.id = "replacement_weapon"
	replacement_weapon.item_name = "Replacement Weapon"
	inventory.slots[2].set_slot(replacement_weapon, 1)
	inventory.inventory_changed.emit()
	ui._handle_left_click(inventory, 2)
	ui._on_equipment_slot_pressed("primary_weapon")
	if inventory.get_equipment_item("primary_weapon") != replacement_weapon or ui.held_item != weapon:
		print("FAIL: inventory items should transfer into equipment slots by clicking")
		await _finish_test(host, 1)
		return
	ui._handle_left_click(inventory, 2)
	if ui.held_item != null:
		print("FAIL: swapping an equipped item should allow returning it to the inventory")
		await _finish_test(host, 1)
		return
	ui._select_category("weapon")
	await process_frame
	var visible_item_count := 0
	for slot_button in ui.player_grid.get_children():
		if (slot_button as Button).text.strip_edges() != "":
			visible_item_count += 1
	if visible_item_count != 2 or ui.player_grid.get_child_count() != 48:
		print("FAIL: category filters should update existing scene slots")
		await _finish_test(host, 1)
		return
	ui._select_category("all")
	await process_frame
	if ui.player_grid.get_child_count() != inventory.slots.size():
		print("FAIL: the all-items filter should retain empty inventory slots")
		await _finish_test(host, 1)
		return
	ui.open_player_only()
	await process_frame
	if ui.chest_title.text != "Craftables — Coming Soon":
		print("FAIL: craftables should be a placeholder when no chest is open")
		await _finish_test(host, 1)
		return
	var panel_positions: Array[Vector2] = []
	for panel_content in panels.get_children():
		var panel := panel_content as Control
		if panel.custom_minimum_size.x <= 0.0 or panel.custom_minimum_size.y <= 0.0 \
		or panel.size.x < panel.custom_minimum_size.x or panel.size.y < panel.custom_minimum_size.y:
			print("FAIL: inventory panel size is %s (minimum %s)" % [panel.size, panel.custom_minimum_size])
			await _finish_test(host, 1)
			return
		panel_positions.append(panel.position)
	ui._on_inventory_slot_hovered(inventory, 0)
	if ui.description_title.text != "Test Weapon":
		print("FAIL: hovering an item should update the item details panel")
		await _finish_test(host, 1)
		return

	var consumable := ItemData.new()
	consumable.id = "test_consumable"
	consumable.item_name = "Test Consumable"
	consumable.type = "consumable"
	if not inventory.set_equipment_item("consumable_0", consumable):
		print("FAIL: consumables should fit their quick-use equipment slots")
		await _finish_test(host, 1)
		return
	var use_event := InputEventMouseButton.new()
	use_event.button_index = MOUSE_BUTTON_RIGHT
	use_event.pressed = true
	ui._on_equipment_slot_input(use_event, "consumable_0")
	if inventory.get_equipment_item("consumable_0") != null:
		print("FAIL: right-clicking an equipped consumable should use and clear it")
		await _finish_test(host, 1)
		return

	var chest := ChestStub.new()
	var chest_inventory := InventoryData.new()
	chest_inventory.slot_count = 3
	chest_inventory.name = "InventoryData"
	chest.add_child(chest_inventory)
	host.add_child(chest)
	await process_frame
	chest_inventory.slots[0].set_slot(stone, 1)
	ui.open_chest(chest)
	await process_frame
	var chest_first_slot := ui.chest_grid.get_child(0) as Button
	if ui.chest_title.text != "Test Chest Contents" \
	or ui.chest_grid.get_child_count() != 20 \
	or not chest_first_slot.visible \
	or (ui.chest_grid.get_child(3) as Button).visible \
	or chest_first_slot.text != "Test Stone" or not ui.chest_scroll.visible:
		print("FAIL: opening a chest should update existing scene slots")
		await _finish_test(host, 1)
		return
	for index in range(panels.get_child_count()):
		var panel := panels.get_child(index) as Control
		if panel.position != panel_positions[index]:
			print("FAIL: opening a chest should not move the inventory panels")
			await _finish_test(host, 1)
			return
	ui.close_chest()
	if ui.chest_title.text != "Craftables — Coming Soon" \
	or not ui.chest_placeholder.visible or ui.chest_scroll.visible:
		print("FAIL: closing a chest should restore the craftables placeholder")
		await _finish_test(host, 1)
		return

	print("Inventory layout checks: PASS")
	await _finish_test(host, 0)

func _finish_test(host: Node, exit_code: int) -> void:
	host.queue_free()
	await process_frame
	quit(exit_code)
