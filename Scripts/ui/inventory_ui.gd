class_name InventoryUI
extends Control

const INVENTORY_SLOT_SCENE: PackedScene = preload("res://Scenes/ui/inventory_slot.tscn")
const DISPLAY_SLOT_SIZE := Vector2(70.0, 70.0)
const TRANSITION_DURATION := 0.3
const WINDOW_NAMES: Array[String] = ["EquipmentPanel", "InventoryPanel", "MapPanel"]

var player_inventory: InventoryData
var main_grid: GridContainer
var equipment_grid: GridContainer
var panels: HBoxContainer
var drop_background: ColorRect
var held_preview: Control
var held_icon: TextureRect
var held_count: Label
var main_description_title: Label
var main_description_body: RichTextLabel
var equipment_description_title: Label
var equipment_description_body: RichTextLabel
var main_slot_buttons: Array[Button] = []
var equipment_slot_buttons: Array[Button] = []
var quick_consumable_buttons: Array[Button] = []
var physical_equipment_buttons: Dictionary = {}

var held_item: ItemInstance
var held_quantity: int = 0
var hovered_kind: String = ""
var hovered_index: int = -1
var _is_open: bool = false
var _is_transitioning: bool = false
var _was_paused_before_open: bool = false
var _active_window_index: int = 1
var _background_alpha: float = 0.46666667
var _transition_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("InventoryUI")
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_bind_scene_nodes()
	_configure_window_layout()
	_find_player_inventory()
	call_deferred("_find_player_inventory")

func _bind_scene_nodes() -> void:
	panels = get_node("Panels") as HBoxContainer
	drop_background = get_node("DropBackground") as ColorRect
	main_grid = get_node(
		"Panels/InventoryPanel/Margin/Content/HBoxContainer/MainInventory/MarginContainer/GridContainer"
	) as GridContainer
	equipment_grid = get_node(
		"Panels/EquipmentPanel/Margin/Content/HBoxContainer/EquipmentsInventory/GridContainer"
	) as GridContainer
	held_preview = get_node("HeldItemPreview") as Control
	held_icon = get_node("HeldItemPreview/VBoxContainer/Icon") as TextureRect
	held_count = get_node("HeldItemPreview/VBoxContainer/Count") as Label
	main_description_title = get_node(
		"Panels/InventoryPanel/Margin/Content/HBoxContainer/Descriptions/Title"
	) as Label
	main_description_body = get_node(
		"Panels/InventoryPanel/Margin/Content/HBoxContainer/Descriptions/Body"
	) as RichTextLabel
	equipment_description_title = get_node(
		"Panels/EquipmentPanel/Margin/Content/HBoxContainer/Descriptions/VBoxContainer/Title"
	) as Label
	equipment_description_body = get_node(
		"Panels/EquipmentPanel/Margin/Content/HBoxContainer/Descriptions/VBoxContainer/Body"
	) as RichTextLabel

	_bind_grid(equipment_grid, "equipment")
	_bind_grid(main_grid, "main")
	quick_consumable_buttons = [
		get_node(
			"Panels/EquipmentPanel/Margin/Content/HBoxContainer/Descriptions/VBoxContainer/QuickConsumables/Consumable1"
		) as Button,
		get_node(
			"Panels/EquipmentPanel/Margin/Content/HBoxContainer/Descriptions/VBoxContainer/QuickConsumables/Consumable2"
		) as Button
	]
	for index in range(quick_consumable_buttons.size()):
		var button := quick_consumable_buttons[index]
		button.custom_minimum_size = DISPLAY_SLOT_SIZE
		button.gui_input.connect(_on_quick_consumable_input.bind(index))
		button.mouse_entered.connect(_on_quick_consumable_hovered.bind(index))
		button.mouse_exited.connect(_on_quick_consumable_exited.bind(index))

	var equipment_slot_paths := {
		"primary_weapon": "EquipedGear/Weapons/Weapon_Slot",
		"primary_weapon_stone": "EquipedGear/Weapons/Weapon_Slot/Weapon_Stone_Slot",
		"backup_weapon": "EquipedGear/Weapons/Weapon_Slot2",
		"backup_weapon_stone": "EquipedGear/Weapons/Weapon_Slot2/Weapon_Stone_Slot2",
		"accessory_0": "EquipedGear/Accessories/Acc_Slot",
		"accessory_1": "EquipedGear/Accessories/Acc_Slot2",
		"accessory_2": "EquipedGear/Accessories/Acc_Slot3",
		"accessory_3": "EquipedGear/Accessories/Acc_Slot4",
		"accessory_stone_0": "EquipedGear/Accessories/Acc_Slot4/Acc_stone_slot",
		"accessory_4": "EquipedGear/Accessories/Acc_Slot5",
		"accessory_stone_1": "EquipedGear/Accessories/Acc_Slot5/Acc_stone_slot",
		"accessory_5": "EquipedGear/Accessories/Acc_Slot6"
	}
	for slot_id in equipment_slot_paths:
		var button := get_node(
			"Panels/EquipmentPanel/Margin/Content/HBoxContainer/" \
			+ str(equipment_slot_paths[slot_id])
		) as Button
		button.focus_mode = Control.FOCUS_NONE
		physical_equipment_buttons[slot_id] = button
		button.gui_input.connect(_on_physical_equipment_input.bind(slot_id))
		button.mouse_entered.connect(_on_physical_equipment_hovered.bind(slot_id))
		button.mouse_exited.connect(_on_physical_equipment_exited.bind(slot_id))

	for path in [
		"Panels/EquipmentPanel/Margin/Content/Panel_Label/Button",
		"Panels/InventoryPanel/Margin/Content/Label/Button",
		"Panels/MapPanel/Margin/Content/Label/Button"
	]:
		var close_button := get_node(path) as Button
		close_button.pressed.connect(close)

	drop_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_alpha = drop_background.color.a
	drop_background.modulate.a = 0.0
	_show_empty_description("main")
	_show_empty_description("equipment")
	held_preview.visible = false

func _configure_window_layout() -> void:
	for index in range(WINDOW_NAMES.size()):
		var panel := panels.get_node(WINDOW_NAMES[index]) as Control
		panel.custom_minimum_size.x = get_viewport_rect().size.x
		panel.size.x = get_viewport_rect().size.x
	panels.position = Vector2.ZERO
	_update_window_position()

func _bind_grid(grid: GridContainer, storage_kind: String) -> void:
	var buttons := _get_slot_buttons(grid)
	for index in range(buttons.size()):
		var button := buttons[index]
		button.custom_minimum_size = DISPLAY_SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.gui_input.connect(_on_storage_slot_input.bind(storage_kind, index))
		button.mouse_entered.connect(_on_storage_slot_hovered.bind(storage_kind, index))
		button.mouse_exited.connect(_on_storage_slot_exited.bind(storage_kind, index))
	if storage_kind == "main":
		main_slot_buttons = buttons
	else:
		equipment_slot_buttons = buttons

func _get_slot_buttons(grid: GridContainer) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in grid.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons

func _find_player_inventory() -> void:
	if player_inventory != null:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	player_inventory = player.get_node_or_null("InventoryData") as InventoryData
	if player_inventory == null:
		return
	if not player_inventory.inventory_changed.is_connected(_refresh_ui):
		player_inventory.inventory_changed.connect(_refresh_ui)
	if not player_inventory.equipment_changed.is_connected(_refresh_ui):
		player_inventory.equipment_changed.connect(_refresh_ui)
	_ensure_grid_capacity()
	_refresh_ui()

func _ensure_grid_capacity() -> void:
	_ensure_grid_size(main_grid, main_slot_buttons, player_inventory.slots.size(), "MainSlot")
	_ensure_grid_size(
		equipment_grid,
		equipment_slot_buttons,
		player_inventory.equipment_storage_slots.size(),
		"EquipmentSlot"
	)

func _ensure_grid_size(
	grid: GridContainer,
	buttons: Array[Button],
	required_size: int,
	name_prefix: String
) -> void:
	while buttons.size() < required_size:
		var button := INVENTORY_SLOT_SCENE.instantiate() as Button
		if button == null:
			push_error("Could not instantiate an inventory slot")
			return
		button.name = "%s%d" % [name_prefix, buttons.size() + 1]
		button.custom_minimum_size = DISPLAY_SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		grid.add_child(button)
		var index := buttons.size()
		var storage_kind := "main" if grid == main_grid else "equipment"
		button.gui_input.connect(_on_storage_slot_input.bind(storage_kind, index))
		button.mouse_entered.connect(_on_storage_slot_hovered.bind(storage_kind, index))
		button.mouse_exited.connect(_on_storage_slot_exited.bind(storage_kind, index))
		buttons.append(button)
	while buttons.size() > required_size:
		var button: Button = buttons.pop_back()
		grid.remove_child(button)
		button.queue_free()

func _process(_delta: float) -> void:
	if _is_open and held_item != null:
		held_preview.visible = true
		held_preview.global_position = get_global_mouse_position() - held_preview.size * 0.5

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_I or key_event.physical_keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and key_event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif _is_open and key_event.physical_keycode == KEY_A:
		show_previous_window()
		get_viewport().set_input_as_handled()
	elif _is_open and key_event.physical_keycode == KEY_D:
		show_next_window()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open_player_only()

func open_player_only() -> void:
	if _is_open:
		return
	_find_player_inventory()
	if player_inventory == null:
		push_error("[InventoryUI] Player inventory could not be found")
		return
	if not visible:
		_was_paused_before_open = get_tree().paused
	_is_open = true
	visible = true
	get_tree().paused = true
	_refresh_ui()
	_start_window_transition(true)

func close() -> void:
	if not _is_open:
		return
	_return_held_item()
	_is_open = false
	hovered_kind = ""
	hovered_index = -1
	_start_window_transition(false)

func show_previous_window() -> void:
	_switch_window(-1)

func show_next_window() -> void:
	_switch_window(1)

func _switch_window(direction: int) -> void:
	if not _is_open or _is_transitioning or direction == 0:
		return
	_active_window_index = posmod(_active_window_index + signi(direction), WINDOW_NAMES.size())
	_start_window_transition(true)

func _update_window_position() -> void:
	var page_width := get_viewport_rect().size.x
	panels.position.x = -_active_window_index * page_width

func _start_window_transition(opening: bool) -> void:
	if _transition_tween != null and _transition_tween.is_running():
		_transition_tween.kill()
	_is_transitioning = true
	var target_y := 0.0 if opening else get_viewport_rect().size.y
	var target_alpha := _background_alpha if opening else 0.0
	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(
		panels,
		"position",
		Vector2(-_active_window_index * get_viewport_rect().size.x, target_y),
		TRANSITION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(
		drop_background,
		"modulate:a",
		target_alpha,
		TRANSITION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.set_parallel(false)
	_transition_tween.tween_callback(_on_window_transition_finished.bind(opening))

func _on_window_transition_finished(opening: bool) -> void:
	_is_transitioning = false
	if not opening and not _is_open:
		visible = false
		get_tree().paused = _was_paused_before_open

func _refresh_ui() -> void:
	if player_inventory == null:
		return
	_ensure_grid_capacity()
	_refresh_storage_grid(main_slot_buttons, player_inventory.slots)
	_refresh_storage_grid(
		equipment_slot_buttons,
		player_inventory.equipment_storage_slots
	)
	_refresh_physical_equipment_slots()
	_refresh_quick_consumables()

func _refresh_storage_grid(
	buttons: Array[Button],
	storage_slots: Array[InventorySlot]
) -> void:
	for index in range(buttons.size()):
		var button := buttons[index]
		button.visible = index < storage_slots.size()
		if not button.visible:
			continue
		button.icon = null
		button.text = ""
		button.tooltip_text = ""
		var count_label := button.get_node_or_null("CountLabel") as Label
		if count_label:
			count_label.text = ""
			count_label.visible = false
		var slot := storage_slots[index]
		if slot.is_empty():
			continue
		var item := slot.item
		button.icon = item.get_icon()
		if button.icon == null:
			button.text = item.item_name
		button.tooltip_text = "%s\n%s" % [item.item_name, item.description]
		if count_label and slot.quantity > 1:
			count_label.text = str(slot.quantity)
			count_label.visible = true

func _refresh_quick_consumables() -> void:
	for index in range(quick_consumable_buttons.size()):
		var button := quick_consumable_buttons[index]
		var item := player_inventory.get_equipment_item("consumable_%d" % index)
		button.icon = item.get_icon() if item else null
		button.text = item.item_name if item and button.icon == null else ""
		button.tooltip_text = "Слот %d" % (index + 1)
		if item:
			button.tooltip_text += ": %s" % item.item_name
		var count_label := button.get_node_or_null("CountLabel") as Label
		if count_label:
			var quantity := player_inventory.get_equipment_quantity(
				"consumable_%d" % index
			)
			count_label.text = str(quantity) if quantity > 1 else ""
			count_label.visible = quantity > 1

func _refresh_physical_equipment_slots() -> void:
	for slot_id in physical_equipment_buttons:
		var button: Button = physical_equipment_buttons[slot_id]
		var item := player_inventory.get_equipment_item(slot_id)
		button.icon = item.get_icon() if item else null
		button.text = item.item_name if item and button.icon == null else ""
		button.tooltip_text = "%s\n%s" % [item.item_name, item.description] \
			if item else _equipment_slot_label(slot_id)

func _equipment_slot_label(slot_id: String) -> String:
	match slot_id:
		"primary_weapon":
			return "Основное оружие"
		"primary_weapon_stone":
			return "Камень оружия"
		"backup_weapon":
			return "Запасное оружие"
		"backup_weapon_stone":
			return "Камень оружия"
		"accessory_0", "accessory_1", "accessory_2", "accessory_3", \
		"accessory_4", "accessory_5", "accessory_6":
			return "Аксессуар %d" % (int(slot_id.trim_prefix("accessory_")) + 1)
		"accessory_stone_0", "accessory_stone_1":
			return "Камень аксессуара"
	return "Слот экипировки"

func _storage_slots(storage_kind: String) -> Array[InventorySlot]:
	return player_inventory.equipment_storage_slots if storage_kind == "equipment" \
		else player_inventory.slots

func _accepts_item(storage_kind: String, item: ItemInstance) -> bool:
	var is_equipment_item := player_inventory.is_equipment_item(item)
	return is_equipment_item if storage_kind == "equipment" else not is_equipment_item

func _on_storage_slot_input(
	event: InputEvent,
	storage_kind: String,
	index: int
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(storage_kind, index)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(storage_kind, index)
	else:
		return
	_update_held_preview()
	_refresh_ui()
	accept_event()

func _handle_left_click(storage_kind: String, index: int) -> void:
	var storage_slots := _storage_slots(storage_kind)
	if index < 0 or index >= storage_slots.size():
		return
	var slot := storage_slots[index]
	if held_item == null:
		if slot.is_empty():
			return
		held_item = slot.item
		held_quantity = slot.quantity
		slot.clear()
		player_inventory.inventory_changed.emit()
		return
	if not _accepts_item(storage_kind, held_item):
		return
	if slot.is_empty():
		if _place_one(slot, held_item):
			held_quantity -= 1
			if held_quantity <= 0:
				_clear_held_item()
			player_inventory.inventory_changed.emit()
		return
	if slot.item.id == held_item.id and slot.item.stackable:
		var space := maxi(slot.item.max_stack - slot.quantity, 0)
		var transferred := mini(space, held_quantity)
		if transferred <= 0:
			return
		slot.quantity += transferred
		held_quantity -= transferred
		if held_quantity <= 0:
			_clear_held_item()
		player_inventory.inventory_changed.emit()
		return
	var previous_item := slot.item
	var previous_quantity := slot.quantity
	slot.set_slot(held_item, held_quantity)
	held_item = previous_item
	held_quantity = previous_quantity
	player_inventory.inventory_changed.emit()

func _handle_right_click(storage_kind: String, index: int) -> void:
	var storage_slots := _storage_slots(storage_kind)
	if index < 0 or index >= storage_slots.size():
		return
	var slot := storage_slots[index]
	if held_item == null:
		if slot.is_empty():
			return
		held_item = slot.item
		held_quantity = int(ceili(slot.quantity / 2.0))
		var left_quantity := slot.quantity - held_quantity
		if left_quantity <= 0:
			slot.clear()
		else:
			slot.quantity = left_quantity
		player_inventory.inventory_changed.emit()
		return
	if not _accepts_item(storage_kind, held_item):
		return
	if _place_one(slot, held_item):
		held_quantity -= 1
		if held_quantity <= 0:
			_clear_held_item()
		player_inventory.inventory_changed.emit()

func _place_one(slot: InventorySlot, item: ItemInstance) -> bool:
	if slot.is_empty():
		slot.set_slot(item.duplicate_instance(), 1)
		return true
	if slot.item.id == item.id and slot.item.stackable \
	and slot.quantity < slot.item.max_stack:
		slot.quantity += 1
		return true
	return false

func _on_storage_slot_hovered(storage_kind: String, index: int) -> void:
	hovered_kind = storage_kind
	hovered_index = index
	var storage_slots := _storage_slots(storage_kind)
	if index < storage_slots.size() and not storage_slots[index].is_empty():
		_show_description(storage_kind, storage_slots[index].item)
	else:
		_show_empty_description(storage_kind)

func _on_storage_slot_exited(storage_kind: String, index: int) -> void:
	if hovered_kind == storage_kind and hovered_index == index:
		hovered_kind = ""
		hovered_index = -1
		_show_empty_description(storage_kind)

func _on_physical_equipment_input(event: InputEvent, slot_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_handle_physical_equipment_click(slot_id)
	_update_held_preview()
	_refresh_ui()
	accept_event()

func _handle_physical_equipment_click(slot_id: String) -> void:
	if player_inventory == null:
		return
	var current_item := player_inventory.get_equipment_item(slot_id)
	if held_item == null:
		if current_item == null:
			return
		var current_quantity := player_inventory.get_equipment_quantity(slot_id)
		if player_inventory.set_equipment_item(slot_id, null):
			held_item = current_item
			held_quantity = current_quantity
		return
	if not player_inventory.is_item_valid_for_equipment_slot(slot_id, held_item):
		return
	if player_inventory.set_equipment_item(slot_id, held_item):
		held_item = current_item
		held_quantity = 1 if current_item != null else 0

func _on_physical_equipment_hovered(slot_id: String) -> void:
	var item := player_inventory.get_equipment_item(slot_id) if player_inventory else null
	if item:
		_show_description("equipment", item)
	else:
		_show_empty_description("equipment")

func _on_physical_equipment_exited(_slot_id: String) -> void:
	_show_empty_description("equipment")

func _show_description(storage_kind: String, item: ItemInstance) -> void:
	var title := equipment_description_title if storage_kind == "equipment" \
		else main_description_title
	var body := equipment_description_body if storage_kind == "equipment" \
		else main_description_body
	title.text = item.item_name
	body.text = item.description

func _show_empty_description(storage_kind: String) -> void:
	var title := equipment_description_title if storage_kind == "equipment" \
		else main_description_title
	var body := equipment_description_body if storage_kind == "equipment" \
		else main_description_body
	title.text = ""
	body.text = ""

func _on_quick_consumable_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		player_inventory.use_equipped_consumable(index)
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_transfer_quick_consumable(index)
	else:
		return
	_update_held_preview()
	_refresh_ui()
	accept_event()

func _transfer_quick_consumable(index: int) -> void:
	var slot_id := "consumable_%d" % index
	var equipped_item := player_inventory.get_equipment_item(slot_id)
	var equipped_quantity := player_inventory.get_equipment_quantity(slot_id)
	if held_item == null:
		if equipped_item != null \
		and player_inventory.set_equipment_item(slot_id, null):
			held_item = equipped_item
			held_quantity = equipped_quantity
		return
	if held_item.type != "consumable":
		return
	if equipped_item == null:
		if player_inventory.set_equipment_item(slot_id, held_item, held_quantity):
			_clear_held_item()
		return
	if equipped_item.id == held_item.id and equipped_item.stackable:
		var space := maxi(equipped_item.max_stack - equipped_quantity, 0)
		var transferred := mini(space, held_quantity)
		if transferred <= 0:
			return
		player_inventory.set_equipment_item(
			slot_id,
			equipped_item,
			equipped_quantity + transferred
		)
		held_quantity -= transferred
		if held_quantity <= 0:
			_clear_held_item()
		return
	if player_inventory.set_equipment_item(slot_id, held_item, held_quantity):
		held_item = equipped_item
		held_quantity = equipped_quantity

func _on_quick_consumable_hovered(index: int) -> void:
	var slot_id := "consumable_%d" % index
	var item := player_inventory.get_equipment_item(slot_id) if player_inventory else null
	if item:
		_show_description("equipment", item)
	else:
		_show_empty_description("equipment")

func _on_quick_consumable_exited(_index: int) -> void:
	_show_empty_description("equipment")

func _return_held_item() -> void:
	if held_item == null or held_quantity <= 0:
		_clear_held_item()
		return
	var leftover := player_inventory.add_item_instance(held_item, held_quantity)
	if leftover > 0:
		player_inventory.spawn_world_drop(held_item, leftover)
	_clear_held_item()

func _clear_held_item() -> void:
	held_item = null
	held_quantity = 0
	_update_held_preview()

func _update_held_preview() -> void:
	if held_preview == null:
		return
	held_preview.visible = held_item != null and held_quantity > 0
	if held_item != null and held_quantity > 0:
		held_icon.texture = held_item.get_icon()
		held_count.text = str(held_quantity) if held_quantity > 1 else ""
	else:
		held_icon.texture = null
		held_count.text = ""
