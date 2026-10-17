class_name InventoryUI
extends Control

var player_inventory: InventoryData
var chest_inventory: InventoryData
var current_chest: Node
var held_item: ItemData
var held_quantity: int = 0
var held_source_inv: InventoryData
var held_source_index: int = -1
var hovered_inv: InventoryData
var hovered_index: int = -1
var selected_category: String = "all"
var pinned_item: ItemData
var _is_open: bool = false

@export var lock_player_controls_when_open: bool = true

var category_buttons: Dictionary = {}
var player_grid: GridContainer
var chest_grid: GridContainer
var chest_placeholder: Label
var chest_title: Label
var description_title: Label
var description_text: Label
var equipment_slots: Dictionary = {}
var player_slot_buttons: Array[Button] = []
var chest_slot_buttons: Array[Button] = []
var close_button: Button
var held_preview: Control
var held_icon: TextureRect
var held_count: Label

func _ready() -> void:
	add_to_group("InventoryUI")
	visible = false
	_bind_scene_nodes()
	_setup_input()
	_find_player_inventory()

func _bind_scene_nodes() -> void:
	player_grid = get_node("Center/Panels/InventoryPanel/Margin/Content/PlayerInventoryPanel/Margin/Content/Grid")
	chest_grid = get_node("Center/Panels/InventoryPanel/Margin/Content/LowerPanel/Margin/Content/Grid")
	chest_placeholder = get_node("Center/Panels/InventoryPanel/Margin/Content/LowerPanel/Margin/Content/Placeholder")
	chest_title = get_node("Center/Panels/InventoryPanel/Margin/Content/LowerPanel/Margin/Content/Title")
	description_title = get_node("Center/Panels/CategoriesPanel/Margin/Content/DetailsPanel/Margin/Content/Title")
	description_text = get_node("Center/Panels/CategoriesPanel/Margin/Content/DetailsPanel/Margin/Content/DescriptionScroll/Description")
	close_button = get_node("Center/Panels/EquipmentPanel/Margin/Content/Header/CloseButton")
	held_preview = get_node("HeldItemPreview")
	held_icon = get_node("HeldItemPreview/Icon")
	held_count = get_node("HeldItemPreview/Count")

	var category_ids := {
		"all": "AllItems",
		"weapon": "Weapons",
		"stone": "Stones",
		"accessory": "Accessories",
		"consumable": "Consumables",
		"material": "Materials",
		"story": "StoryItems"
	}
	for category_id in category_ids:
		var button := get_node("Center/Panels/CategoriesPanel/Margin/Content/CategoryButtons/%s" % category_ids[category_id]) as Button
		category_buttons[category_id] = button
		button.pressed.connect(_select_category.bind(category_id))

	for slot_id in [
		"primary_weapon", "primary_weapon_stone", "backup_weapon", "backup_weapon_stone",
		"accessory_0", "accessory_stone_0", "accessory_1", "accessory_stone_1",
		"accessory_2", "accessory_3", "accessory_4", "accessory_5", "accessory_6",
		"consumable_0", "consumable_1"
	]:
		var button := find_child("Equipment_%s" % slot_id, true, false) as Button
		equipment_slots[slot_id] = button
		button.pressed.connect(_on_equipment_slot_pressed.bind(slot_id))
		button.gui_input.connect(_on_equipment_slot_input.bind(slot_id))
		button.mouse_entered.connect(_on_equipment_slot_hovered.bind(slot_id))

	close_button.pressed.connect(close)
	(get_node("DropBackground") as ColorRect).gui_input.connect(_on_drop_background_input)

	for child in player_grid.get_children():
		var button := child as Button
		player_slot_buttons.append(button)
		button.gui_input.connect(_on_player_slot_input.bind(player_slot_buttons.size() - 1))
		button.mouse_entered.connect(_on_player_slot_hovered.bind(player_slot_buttons.size() - 1))
		button.mouse_exited.connect(_on_player_slot_exited.bind(player_slot_buttons.size() - 1))

	for child in chest_grid.get_children():
		var button := child as Button
		chest_slot_buttons.append(button)
		button.gui_input.connect(_on_chest_slot_input.bind(chest_slot_buttons.size() - 1))
		button.mouse_entered.connect(_on_chest_slot_hovered.bind(chest_slot_buttons.size() - 1))
		button.mouse_exited.connect(_on_chest_slot_exited.bind(chest_slot_buttons.size() - 1))

	_select_category("all")

func _setup_input() -> void:
	if not InputMap.has_action("toggle_inventory"):
		InputMap.add_action("toggle_inventory")
		var tab_event := InputEventKey.new()
		tab_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("toggle_inventory", tab_event)
		var i_event := InputEventKey.new()
		i_event.physical_keycode = KEY_I
		InputMap.action_add_event("toggle_inventory", i_event)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var interact_event := InputEventKey.new()
		interact_event.physical_keycode = KEY_E
		InputMap.action_add_event("interact", interact_event)

func _find_player_inventory() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player:
		player_inventory = player.get_node_or_null("InventoryData") as InventoryData
	if player_inventory:
		if not player_inventory.inventory_changed.is_connected(_refresh_ui):
			player_inventory.inventory_changed.connect(_refresh_ui)
		if not player_inventory.equipment_changed.is_connected(_refresh_ui):
			player_inventory.equipment_changed.connect(_refresh_ui)
		_refresh_ui()

func _process(_delta: float) -> void:
	if not _is_open or held_item == null:
		return
	held_preview.visible = true
	held_preview.global_position = get_global_mouse_position() - held_preview.size * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		if event.is_action_pressed("toggle_inventory"):
			toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		_handle_q_drop(event.ctrl_pressed)
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open_player_only()

func open_player_only() -> void:
	if player_inventory == null:
		_find_player_inventory()
	current_chest = null
	chest_inventory = null
	_is_open = true
	visible = true
	_set_player_controls_locked(true)
	_update_lower_panel()
	_refresh_ui()

func open_chest(chest: Node) -> void:
	if player_inventory == null:
		_find_player_inventory()
	current_chest = chest
	chest_inventory = chest.get_node_or_null("InventoryData") as InventoryData
	if chest_inventory == null:
		push_error("Inventory UI cannot open a chest without InventoryData")
		current_chest = null
		return
	_is_open = true
	visible = true
	if lock_player_controls_when_open:
		_set_player_controls_locked(true)
	if chest_inventory and not chest_inventory.inventory_changed.is_connected(_refresh_ui):
		chest_inventory.inventory_changed.connect(_refresh_ui)
	_update_lower_panel()
	_refresh_ui()

func close_chest() -> void:
	current_chest = null
	chest_inventory = null
	_update_lower_panel()
	if _is_open:
		close()

func close() -> void:
	_return_or_drop_held_item()
	_is_open = false
	visible = false
	_set_player_controls_locked(false)
	hovered_inv = null
	hovered_index = -1
	_clear_pinned_details()
	_show_empty_details()
	if current_chest and is_instance_valid(current_chest):
		var chest := current_chest
		current_chest = null
		chest_inventory = null
		if chest.has_method("close_chest"):
			chest.call("close_chest")
	else:
		current_chest = null
		chest_inventory = null

func _update_lower_panel() -> void:
	if chest_title == null or chest_grid == null:
		return
	if chest_inventory:
		var title := str(current_chest.get("chest_name")) if current_chest else "Chest"
		chest_title.text = "%s Contents" % title
		chest_placeholder.visible = false
	else:
		chest_title.text = "Craftables — Coming Soon"
		chest_placeholder.visible = true

func _set_player_controls_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_controls_locked"):
		player.call("set_controls_locked", locked)

func _select_category(category_id: String) -> void:
	selected_category = category_id
	for id in category_buttons:
		var button: Button = category_buttons[id]
		button.button_pressed = id == category_id
		button.toggle_mode = true
	_refresh_player_grid()

func _category_for_item(item: ItemData) -> String:
	match item.type:
		"weapon", "stone", "accessory", "consumable", "material":
			return item.type
		_:
			return "story"

func _refresh_ui() -> void:
	_refresh_player_grid()
	_refresh_chest_grid()
	_refresh_equipment_slots()

func _refresh_player_grid() -> void:
	if player_grid == null:
		return
	if player_inventory == null:
		for button in player_slot_buttons:
			button.visible = false
		return
	_update_inventory_grid(player_inventory, player_slot_buttons)

func _refresh_chest_grid() -> void:
	if chest_grid == null:
		return
	if chest_inventory == null:
		for button in chest_slot_buttons:
			button.visible = false
		return
	_update_inventory_grid(chest_inventory, chest_slot_buttons)

func _update_inventory_grid(inventory: InventoryData, buttons: Array[Button]) -> void:
	if inventory.slots.size() > buttons.size():
		push_error("Inventory has %d slots, but its scene grid only contains %d slot controls" % [
			inventory.slots.size(),
			buttons.size()
		])
	for index in range(buttons.size()):
		var button := buttons[index]
		button.visible = index < inventory.slots.size()
		if button.visible:
			_update_inventory_slot(button, inventory, index)

func _update_inventory_slot(button: Button, inventory: InventoryData, index: int) -> void:
	button.icon = null
	button.text = ""
	button.tooltip_text = ""
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var slot := inventory.slots[index]
	var show_item := not slot.is_empty()
	if show_item and inventory == player_inventory and selected_category != "all":
		show_item = _category_for_item(slot.item) == selected_category
	if show_item:
		var item := slot.item
		button.tooltip_text = "%s\n%s" % [item.item_name, item.description]
		if item.type == "consumable" and inventory == player_inventory and chest_inventory == null:
			button.tooltip_text += "\nRight-click to use"
		var icon := item.get_icon()
		if icon:
			button.icon = icon
		button.text = "%s%s" % [item.item_name, " x%d" % slot.quantity if slot.quantity > 1 else ""]

func _on_player_slot_input(event: InputEvent, index: int) -> void:
	if player_inventory:
		_on_inventory_slot_input(event, player_inventory, index)

func _on_chest_slot_input(event: InputEvent, index: int) -> void:
	if chest_inventory:
		_on_inventory_slot_input(event, chest_inventory, index)

func _on_player_slot_hovered(index: int) -> void:
	if player_inventory:
		_on_inventory_slot_hovered(player_inventory, index)

func _on_chest_slot_hovered(index: int) -> void:
	if chest_inventory:
		_on_inventory_slot_hovered(chest_inventory, index)

func _on_player_slot_exited(index: int) -> void:
	if player_inventory:
		_on_inventory_slot_exited(player_inventory, index)

func _on_chest_slot_exited(index: int) -> void:
	if chest_inventory:
		_on_inventory_slot_exited(chest_inventory, index)

func _on_inventory_slot_input(event: InputEvent, inventory: InventoryData, index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_pin_slot_details(inventory, index)
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT) and chest_inventory:
			if inventory == player_inventory:
				inventory.quick_transfer(index, chest_inventory)
			elif inventory == chest_inventory:
				inventory.quick_transfer(index, player_inventory)
		else:
			_handle_left_click(inventory, index)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(inventory, index)
	accept_event()

func _handle_left_click(inventory: InventoryData, index: int) -> void:
	if held_item == null:
		var taken := inventory.take_all(index)
		if taken.item:
			held_item = taken.item
			held_quantity = taken.quantity
			held_source_inv = inventory
			held_source_index = index
	else:
		var result := inventory.place_or_merge(index, held_item, held_quantity)
		held_item = result.item
		held_quantity = result.quantity
		if held_item == null:
			_clear_held_source()
	_update_held_preview()
	_refresh_ui()

func _handle_right_click(inventory: InventoryData, index: int) -> void:
	if held_item == null:
		var slot := inventory.slots[index]
		if not slot.is_empty() and slot.item.type == "consumable" and inventory == player_inventory and chest_inventory == null:
			inventory.use_item(index)
		else:
			var taken := inventory.take_half(index)
			held_item = taken.item
			held_quantity = taken.quantity
			held_source_inv = inventory if held_item else null
			held_source_index = index if held_item else -1
	else:
		if inventory.place_one(index, held_item):
			held_quantity -= 1
			if held_quantity <= 0:
				held_item = null
				_clear_held_source()
	_update_held_preview()
	_refresh_ui()

func _on_equipment_slot_pressed(slot_id: String) -> void:
	if player_inventory == null:
		return
	var preview_item := held_item if held_item else player_inventory.get_equipment_item(slot_id)
	if preview_item:
		_pin_item_details(preview_item)
	else:
		_clear_pinned_details()
		description_title.text = _equipment_slot_label(slot_id)
		description_text.text = "Empty equipment slot."
	if held_item == null:
		var equipped := player_inventory.get_equipment_item(slot_id)
		if equipped and player_inventory.set_equipment_item(slot_id, null):
			held_item = equipped
			held_quantity = 1
			held_source_inv = player_inventory
			held_source_index = -1
	else:
		var current_item := player_inventory.get_equipment_item(slot_id)
		if held_item.stackable and current_item != null:
			return
		if player_inventory.set_equipment_item(slot_id, held_item):
			var placed_item := held_item
			held_quantity -= 1
			held_item = current_item
			if held_item == null and held_quantity > 0:
				held_item = placed_item
			if held_item == null:
				_clear_held_source()
			elif held_quantity <= 0:
				held_quantity = 1
	_update_held_preview()
	_refresh_ui()

func _on_equipment_slot_input(event: InputEvent, slot_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if slot_id.begins_with("consumable_") and player_inventory:
		player_inventory.use_equipped_consumable(int(slot_id.trim_prefix("consumable_")))
	accept_event()

func _refresh_equipment_slots() -> void:
	if player_inventory == null:
		return
	for slot_id in equipment_slots:
		var button: Button = equipment_slots[slot_id]
		var item := player_inventory.get_equipment_item(slot_id)
		var label_text := _equipment_slot_label(slot_id)
		if item:
			button.text = item.item_name
			button.tooltip_text = "%s\n%s" % [item.item_name, item.description]
			var icon := item.get_icon()
			button.icon = icon
		else:
			button.text = label_text
			button.tooltip_text = label_text
			button.icon = null
	if player_inventory.has_method("get_active_weapon_slot"):
		var active := str(player_inventory.call("get_active_weapon_slot"))
		var active_button := find_child("ActiveWeaponButton", true, false) as Button
		if active_button:
			active_button.text = "Use Backup Weapon" if active == "primary" else "Use Primary Weapon"

func _equipment_slot_label(slot_id: String) -> String:
	match slot_id:
		"primary_weapon":
			return "Primary Weapon"
		"primary_weapon_stone":
			return "Weapon Stone"
		"backup_weapon":
			return "Backup Weapon"
		"backup_weapon_stone":
			return "Weapon Stone"
		"accessory_0", "accessory_1", "accessory_2", "accessory_3", "accessory_4", "accessory_5", "accessory_6":
			return "Accessory %d" % (int(slot_id.trim_prefix("accessory_")) + 1)
		"accessory_stone_0", "accessory_stone_1":
			return "Stone"
		"consumable_0", "consumable_1":
			return "Consumable %d" % (int(slot_id.trim_prefix("consumable_")) + 1)
	return "Empty Slot"

func _toggle_active_weapon() -> void:
	if player_inventory:
		player_inventory.set_active_weapon_slot(
			"backup" if player_inventory.active_weapon_slot == "primary" else "primary"
		)

func _on_inventory_slot_hovered(inventory: InventoryData, index: int) -> void:
	hovered_inv = inventory
	hovered_index = index
	if index < inventory.slots.size() and not inventory.slots[index].is_empty():
		_show_item_details(inventory.slots[index].item)
	elif pinned_item:
		_show_item_details(pinned_item)
	else:
		_show_empty_details()

func _on_inventory_slot_exited(inventory: InventoryData, index: int) -> void:
	if hovered_inv == inventory and hovered_index == index:
		hovered_inv = null
		hovered_index = -1
		if pinned_item:
			_show_item_details(pinned_item)
		else:
			_show_empty_details()

func _on_equipment_slot_hovered(slot_id: String) -> void:
	if player_inventory == null:
		return
	var item := player_inventory.get_equipment_item(slot_id)
	if item:
		_show_item_details(item)
	elif pinned_item:
		_show_item_details(pinned_item)
	else:
		description_title.text = _equipment_slot_label(slot_id)
		description_text.text = "Empty equipment slot."

func _pin_slot_details(inventory: InventoryData, index: int) -> void:
	if index < inventory.slots.size() and not inventory.slots[index].is_empty():
		_pin_item_details(inventory.slots[index].item)

func _pin_item_details(item: ItemData) -> void:
	pinned_item = item
	_show_item_details(item)

func _clear_pinned_details() -> void:
	pinned_item = null

func _show_item_details(item: ItemData) -> void:
	description_title.text = item.item_name
	description_text.text = item.description if item.description != "" else "No description available."

func _show_empty_details() -> void:
	description_title.text = "Item Details"
	description_text.text = "Hover or click an item to see its description."

func _handle_q_drop(drop_all: bool) -> void:
	if held_item and held_quantity > 0:
		var amount := held_quantity if drop_all else 1
		held_quantity -= amount
		if player_inventory:
			player_inventory.spawn_world_drop(held_item, amount)
		if held_quantity <= 0:
			held_item = null
			_clear_held_source()
		_update_held_preview()
	elif hovered_inv and hovered_index >= 0:
		hovered_inv.drop_item(hovered_index, -1 if drop_all else 1)
	_refresh_ui()

func _on_drop_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and held_item and held_quantity > 0:
			if player_inventory:
				player_inventory.spawn_world_drop(held_item, held_quantity)
			held_item = null
			held_quantity = 0
			_clear_held_source()
			_update_held_preview()
			_refresh_ui()

func _return_or_drop_held_item() -> void:
	if held_item == null or held_quantity <= 0:
		held_item = null
		held_quantity = 0
		_update_held_preview()
		return
	var target_inventory := held_source_inv if held_source_inv else player_inventory
	if target_inventory:
		var leftover := target_inventory.add_item(held_item, held_quantity)
		if leftover > 0:
			target_inventory.spawn_world_drop(held_item, leftover)
	elif player_inventory:
		player_inventory.spawn_world_drop(held_item, held_quantity)
	held_item = null
	held_quantity = 0
	_clear_held_source()
	_update_held_preview()

func _clear_held_source() -> void:
	held_source_inv = null
	held_source_index = -1

func _update_held_preview() -> void:
	if held_preview == null:
		return
	held_preview.visible = held_item != null and held_quantity > 0
	if held_item and held_quantity > 0:
		held_icon.texture = held_item.get_icon()
		held_count.text = str(held_quantity) if held_quantity > 1 else ""
	else:
		held_icon.texture = null
		held_count.text = ""
