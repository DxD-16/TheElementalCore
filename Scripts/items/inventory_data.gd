class_name InventoryData
extends Node

## Инвентарь (для игрока или сундука).
## Хранит массив слотов и реестр всех предметов из items.json.

signal inventory_changed
signal item_used(item: ItemData)

const DROPPED_ITEM_SCENE = preload("res://Scenes/items/dropped_item.tscn")

@export var slot_count: int = 20

var slots: Array[InventorySlot] = []

## Реестр всех известных предметов (id → ItemData)
var item_registry: Dictionary = {}

func _ready() -> void:
	_init_slots()
	_load_item_registry()

func _init_slots() -> void:
	slots.clear()
	for i in slot_count:
		slots.append(InventorySlot.new())

func _load_item_registry() -> void:
	item_registry.clear()
	if not ConfigManager:
		return
	var items_dict: Dictionary = ConfigManager.get_value("items", "", {})
	for item_id in items_dict:
		var data: Dictionary = items_dict[item_id]
		if data is Dictionary:
			item_registry[item_id] = ItemData.from_config(item_id, data)
	print("[InventoryData] Loaded items: %d" % item_registry.size())

func get_item_data(item_id: String) -> ItemData:
	return item_registry.get(item_id, null)

func add_item_by_id(item_id: String, amount: int = 1) -> int:
	## Adds item by ID. Returns leftover amount that did not fit.
	var data := get_item_data(item_id)
	if data == null:
		push_warning("[InventoryData] Unknown item: %s" % item_id)
		return amount
	return add_item(data, amount)

func add_item(item: ItemData, amount: int = 1) -> int:
	## Добавляет предмет. Сначала заполняет существующие стаки, потом пустые слоты.
	## Возвращает количество, которое не поместилось.
	var remaining := amount

	# Сначала заполняем уже существующие стаки
	if item.stackable:
		for slot in slots:
			if remaining <= 0:
				break
			if not slot.is_empty() and slot.item.id == item.id:
				remaining = slot.add(item, remaining)

	# Затем пустые слоты
	for slot in slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			remaining = slot.add(item, remaining)

	if remaining < amount:
		inventory_changed.emit()
	return remaining

func remove_item(item_id: String, amount: int = 1) -> int:
	## Убирает предмет. Возвращает сколько реально убрано.
	var to_remove := amount
	var removed_total := 0
	for slot in slots:
		if to_remove <= 0:
			break
		if not slot.is_empty() and slot.item.id == item_id:
			var removed := slot.remove(to_remove)
			to_remove -= removed
			removed_total += removed
	if removed_total > 0:
		inventory_changed.emit()
	return removed_total

func has_item(item_id: String, amount: int = 1) -> bool:
	var count := get_item_count(item_id)
	return count >= amount

func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.quantity
	return total

func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= slots.size() or idx_b < 0 or idx_b >= slots.size():
		return
	var temp_item := slots[idx_a].item
	var temp_qty := slots[idx_a].quantity
	slots[idx_a].set_slot(slots[idx_b].item, slots[idx_b].quantity)
	slots[idx_b].set_slot(temp_item, temp_qty)
	inventory_changed.emit()

func take_all(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {"item": null, "quantity": 0}
	var slot := slots[slot_index]
	if slot.is_empty():
		return {"item": null, "quantity": 0}
	var res := {"item": slot.item, "quantity": slot.quantity}
	slot.clear()
	inventory_changed.emit()
	return res

func take_half(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {"item": null, "quantity": 0}
	var slot := slots[slot_index]
	if slot.is_empty():
		return {"item": null, "quantity": 0}
	var half := int(ceili(slot.quantity / 2.0))
	var remaining := slot.quantity - half
	var taken_item := slot.item
	if remaining <= 0:
		slot.clear()
	else:
		slot.quantity = remaining
	inventory_changed.emit()
	return {"item": taken_item, "quantity": half}

func place_or_merge(slot_index: int, held_item: ItemData, held_qty: int) -> Dictionary:
	## Кладёт удерживаемый предмет в слот.
	## Возвращает остаток для руки: {"item": ItemData/null, "quantity": int}
	if slot_index < 0 or slot_index >= slots.size() or held_item == null or held_qty <= 0:
		return {"item": held_item, "quantity": held_qty}

	var slot := slots[slot_index]

	# Если целевой слот пуст
	if slot.is_empty():
		slot.set_slot(held_item, held_qty)
		inventory_changed.emit()
		return {"item": null, "quantity": 0}

	# Если тот же предмет и стакается
	if slot.item.id == held_item.id and slot.item.stackable:
		var space := slot.item.max_stack - slot.quantity
		if space > 0:
			var to_add := mini(held_qty, space)
			slot.quantity += to_add
			var leftover := held_qty - to_add
			inventory_changed.emit()
			if leftover > 0:
				return {"item": held_item, "quantity": leftover}
			else:
				return {"item": null, "quantity": 0}

	# Если другой предмет или стак полон — меняем местами (swap)
	var old_item := slot.item
	var old_qty := slot.quantity
	slot.set_slot(held_item, held_qty)
	inventory_changed.emit()
	return {"item": old_item, "quantity": old_qty}

func place_one(slot_index: int, held_item: ItemData) -> bool:
	## Кладёт ровно 1 предмет из руки в слот. Возвращает true при успехе.
	if slot_index < 0 or slot_index >= slots.size() or held_item == null:
		return false
	var slot := slots[slot_index]
	if slot.is_empty():
		slot.set_slot(held_item, 1)
		inventory_changed.emit()
		return true
	elif slot.item.id == held_item.id and slot.item.stackable and slot.quantity < slot.item.max_stack:
		slot.quantity += 1
		inventory_changed.emit()
		return true
	return false

func quick_transfer(slot_index: int, target_inv: InventoryData) -> bool:
	## Быстрое перемещение предмета из slot_index в целевой инвентарь (Shift+Click).
	if slot_index < 0 or slot_index >= slots.size() or target_inv == null:
		return false
	var slot := slots[slot_index]
	if slot.is_empty():
		return false

	var leftover := target_inv.add_item(slot.item, slot.quantity)
	if leftover < slot.quantity:
		if leftover <= 0:
			slot.clear()
		else:
			slot.quantity = leftover
		inventory_changed.emit()
		return true
	return false

func drop_item(slot_index: int, amount: int = -1, drop_pos: Vector2 = Vector2.ZERO) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot := slots[slot_index]
	if slot.is_empty():
		return false

	var to_drop := slot.quantity if amount <= 0 else mini(amount, slot.quantity)
	var item := slot.item
	slot.remove(to_drop)
	inventory_changed.emit()

	spawn_world_drop(item, to_drop, drop_pos)
	return true

func spawn_world_drop(item: ItemData, amount: int, drop_pos: Vector2 = Vector2.ZERO) -> void:
	if not DROPPED_ITEM_SCENE or item == null or amount <= 0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	if drop_pos == Vector2.ZERO:
		var player := get_tree().get_first_node_in_group("Player") as Node2D
		if player:
			drop_pos = player.global_position + Vector2(0, -10)
		else:
			drop_pos = Vector2(100, 260)

	var dropped := DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	scene.add_child(dropped)
	dropped.global_position = drop_pos
	var launch := Vector2(randf_range(-90.0, 90.0), randf_range(-240.0, -160.0))
	dropped.setup(item.id, amount, launch)
	print("[InventoryData] Dropped item: %s x%d" % [item.item_name, amount])

func use_item(slot_index: int) -> bool:
	## Uses item from specified slot. Returns true on success.
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot := slots[slot_index]
	if slot.is_empty():
		return false
	var item := slot.item
	if item.type != "consumable":
		return false

	# Apply effect
	_apply_item_effect(item)
	slot.remove(1)
	item_used.emit(item)
	inventory_changed.emit()
	return true

func _apply_item_effect(item: ItemData) -> void:
	if item.use_effects.has("heal"):
		var heal_amount := int(item.use_effects["heal"])
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player:
			var hc := player.get_node_or_null("HealthComponent") as HealthComponent
			if hc:
				hc.heal(heal_amount)
				print("[InventoryData] Used '%s': +%d HP" % [item.item_name, heal_amount])
