class_name InventorySlot
extends RefCounted

## Один слот инвентаря: ссылка на предмет + количество.

var item: ItemInstance = null
var quantity: int = 0

func is_empty() -> bool:
	return item == null or quantity <= 0

func set_slot(p_item: ItemInstance, p_quantity: int) -> void:
	if p_item == null or p_quantity <= 0:
		clear()
	else:
		item = p_item
		quantity = p_quantity

func can_stack_with(new_item: ItemInstance) -> bool:
	if is_empty() or new_item == null:
		return false
	return item.id == new_item.id and item.stackable

func can_add(new_item: ItemInstance, amount: int = 1) -> bool:
	if is_empty():
		return true
	if item.id != new_item.id:
		return false
	if not item.stackable:
		return false
	return quantity + amount <= item.max_stack

func add(new_item: ItemInstance, amount: int = 1) -> int:
	## Добавляет предмет в слот. Возвращает остаток, который не поместился.
	if is_empty():
		item = new_item
		var can_fit := new_item.max_stack if new_item.stackable else 1
		var to_add := mini(amount, can_fit)
		quantity = to_add
		return amount - to_add

	if item.id != new_item.id or not item.stackable:
		return amount

	var space := item.max_stack - quantity
	var to_add := mini(amount, space)
	quantity += to_add
	return amount - to_add

func remove(amount: int = 1) -> int:
	## Убирает amount штук. Возвращает сколько реально убрано.
	var removed := mini(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		item = null
		quantity = 0
	return removed

func clear() -> void:
	item = null
	quantity = 0

func duplicate_slot() -> InventorySlot:
	var copy := InventorySlot.new()
	copy.item = item.duplicate_instance() if item != null else null
	copy.quantity = quantity
	return copy
