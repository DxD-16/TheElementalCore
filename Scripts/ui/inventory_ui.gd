class_name InventoryUI
extends Control

## Полнофункциональный интерфейс инвентаря игрока и сундуков.
## Поддерживает:
## - Перекладывание предметов (ЛКМ / клик-перенос)
## - Разделение стаков (ПКМ берет половину, ПКМ раскладывает по 1)
## - Быстрое перемещение между сундуком и инвентарем (Shift+ЛКМ)
## - Выбрасывание предметов в мир (клик вне окна или клавиша Q)
## - Подсветку рамок: обычная, наведение (Hover) и выделенный слот (Selected)

const JERSEY_FONT = preload("res://Fonts/jersey15-regular.ttf")

@export var slot_size: Vector2 = Vector2(52, 52)
@export var player_columns: int = 5
@export var chest_columns: int = 5

var player_inventory: InventoryData = null
var chest_inventory: InventoryData = null
var current_chest: Chest = null

var _is_open: bool = false

# Удерживаемый на курсоре предмет
var held_item: ItemData = null
var held_quantity: int = 0
var held_source_inv: InventoryData = null
var held_source_index: int = -1

# Текущий слот под курсором
var hovered_inv: InventoryData = null
var hovered_index: int = -1

# Ссылки на ноды UI
@onready var drop_background: ColorRect = $DropBackground
@onready var chest_panel: PanelContainer = $CenterContainer/PanelsBox/ChestPanel
@onready var chest_title: Label = $CenterContainer/PanelsBox/ChestPanel/Margin/VBox/Title
@onready var chest_grid: GridContainer = $CenterContainer/PanelsBox/ChestPanel/Margin/VBox/Grid
@onready var player_panel: PanelContainer = $CenterContainer/PanelsBox/PlayerPanel
@onready var player_title: Label = $CenterContainer/PanelsBox/PlayerPanel/Margin/VBox/Title
@onready var player_grid: GridContainer = $CenterContainer/PanelsBox/PlayerPanel/Margin/VBox/Grid
@onready var held_preview: Control = $HeldItemPreview
@onready var held_icon: TextureRect = $HeldItemPreview/Icon
@onready var held_count: Label = $HeldItemPreview/Count
@onready var close_button: Button = $CloseButton

# Кеш созданных слотов: inv -> Array[PanelContainer]
var _slot_panels: Dictionary = {}

# Стили для подсветки рамок слотов
var style_normal: StyleBoxFlat
var style_hover: StyleBoxFlat
var style_selected: StyleBoxFlat

func _ready() -> void:
	add_to_group("InventoryUI")
	visible = false
	_is_open = false

	_init_styles()
	_setup_input()

	if close_button:
		close_button.pressed.connect(close)

	if drop_background:
		drop_background.gui_input.connect(_on_drop_background_input)

	call_deferred("_find_player_inventory")

func _init_styles() -> void:
	# Обычный слот
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.13, 0.19, 0.9)
	style_normal.border_color = Color(0.3, 0.34, 0.45, 0.7)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)

	# Наведение (Hover)
	style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.2, 0.28, 0.95)
	style_hover.border_color = Color(0.7, 0.8, 1.0, 0.95)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)

	# Выделенный предмет / источник (Selected)
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.24, 0.22, 0.14, 0.95)
	style_selected.border_color = Color(1.0, 0.82, 0.2, 1.0) # Яркое золото
	style_selected.set_border_width_all(2)
	style_selected.set_corner_radius_all(6)

func _setup_input() -> void:
	if not InputMap.has_action("toggle_inventory"):
		InputMap.add_action("toggle_inventory")
		var ev_tab := InputEventKey.new()
		ev_tab.physical_keycode = KEY_TAB
		InputMap.action_add_event("toggle_inventory", ev_tab)
		var ev_i := InputEventKey.new()
		ev_i.physical_keycode = KEY_I
		InputMap.action_add_event("toggle_inventory", ev_i)

	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev_e := InputEventKey.new()
		ev_e.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev_e)

func _find_player_inventory() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player:
		player_inventory = player.get_node_or_null("InventoryData") as InventoryData
	if player_inventory:
		if not player_inventory.inventory_changed.is_connected(_refresh_ui):
			player_inventory.inventory_changed.connect(_refresh_ui)
		_build_grid(player_inventory, player_grid, player_columns)

func _process(_delta: float) -> void:
	if not _is_open:
		return

	# Обновление позиции удерживаемого предмета за курсором мыши
	if held_item != null:
		held_preview.visible = true
		held_preview.global_position = get_global_mouse_position() - held_preview.size * 0.5
	else:
		held_preview.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		if event.is_action_pressed("toggle_inventory"):
			toggle()
			get_viewport().set_input_as_handled()
		return

	# Закрытие по Tab, I или Esc
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	# Выбрасывание по клавише Q
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
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
	_is_open = true
	visible = true
	_set_player_controls_locked(true)
	if chest_panel:
		chest_panel.visible = false
	chest_inventory = null
	current_chest = null

	_refresh_ui()

func open_chest(chest: Chest) -> void:
	if player_inventory == null:
		_find_player_inventory()
	current_chest = chest
	chest_inventory = chest.inventory_data
	_is_open = true
	visible = true
	_set_player_controls_locked(true)

	if chest_panel:
		chest_panel.visible = true
		if chest_title:
			chest_title.text = chest.chest_name

	if chest_inventory:
		if not chest_inventory.inventory_changed.is_connected(_refresh_ui):
			chest_inventory.inventory_changed.connect(_refresh_ui)
		_build_grid(chest_inventory, chest_grid, chest_columns)

	_refresh_ui()

func close_chest() -> void:
	if current_chest != null:
		current_chest = null
	chest_inventory = null
	if chest_panel:
		chest_panel.visible = false
	if _is_open:
		# Если был открыт сундук, при закрытии закрываем и UI
		close()

func close() -> void:
	_return_or_drop_held_item()

	_is_open = false
	visible = false
	_set_player_controls_locked(false)
	hovered_inv = null
	hovered_index = -1

	if current_chest != null:
		var c := current_chest
		current_chest = null
		chest_inventory = null
		if is_instance_valid(c):
			c.close_chest()

	if chest_panel:
		chest_panel.visible = false

func _set_player_controls_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Player
	if player:
		player.set_controls_locked(locked)

func _return_or_drop_held_item() -> void:
	if held_item == null or held_quantity <= 0:
		held_item = null
		held_quantity = 0
		_update_held_preview()
		return

	# Сначала пытаемся вернуть в исходный инвентарь
	var target_inv := held_source_inv if held_source_inv != null else player_inventory
	if target_inv != null:
		var leftover := target_inv.add_item(held_item, held_quantity)
		if leftover > 0:
			# Если не поместилось, выбрасываем остаток в мир
			target_inv.spawn_world_drop(held_item, leftover)
	else:
		if player_inventory:
			player_inventory.spawn_world_drop(held_item, held_quantity)

	held_item = null
	held_quantity = 0
	held_source_inv = null
	held_source_index = -1
	_update_held_preview()

func _build_grid(inv: InventoryData, grid: GridContainer, cols: int) -> void:
	if inv == null or grid == null:
		return

	# Очистка старых слотов
	for child in grid.get_children():
		child.queue_free()

	grid.columns = cols
	var panels: Array[PanelContainer] = []

	for i in inv.slots.size():
		var slot_ui := _create_slot_panel(inv, i)
		grid.add_child(slot_ui)
		panels.append(slot_ui)

	_slot_panels[inv] = panels

func _create_slot_panel(inv: InventoryData, index: int) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = slot_size
	slot_panel.name = "Slot_%d" % index
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_panel.add_theme_stylebox_override("panel", style_normal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(margin)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(icon)

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.anchors_preset = Control.PRESET_FULL_RECT
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_override("font", JERSEY_FONT)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	count_label.add_theme_constant_override("outline_size", 2)
	margin.add_child(count_label)

	# Сигналы ввода и наведения
	slot_panel.gui_input.connect(_on_slot_gui_input.bind(inv, index))
	slot_panel.mouse_entered.connect(_on_slot_mouse_entered.bind(inv, index, slot_panel))
	slot_panel.mouse_exited.connect(_on_slot_mouse_exited.bind(inv, index, slot_panel))

	return slot_panel

func _on_slot_mouse_entered(inv: InventoryData, index: int, slot_panel: PanelContainer) -> void:
	hovered_inv = inv
	hovered_index = index
	_update_slot_style(inv, index, slot_panel, true)

func _on_slot_mouse_exited(inv: InventoryData, index: int, slot_panel: PanelContainer) -> void:
	if hovered_inv == inv and hovered_index == index:
		hovered_inv = null
		hovered_index = -1
	_update_slot_style(inv, index, slot_panel, false)

func _update_slot_style(inv: InventoryData, index: int, slot_panel: PanelContainer, is_hover: bool) -> void:
	# Выделенный слот (когда взят на курсор)
	if held_item != null and held_source_inv == inv and held_source_index == index:
		slot_panel.add_theme_stylebox_override("panel", style_selected)
	elif is_hover:
		slot_panel.add_theme_stylebox_override("panel", style_hover)
	else:
		slot_panel.add_theme_stylebox_override("panel", style_normal)

func _on_slot_gui_input(event: InputEvent, inv: InventoryData, index: int) -> void:
	if not event is InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)

	# 1. Левый клик (ЛКМ)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if is_shift:
			# Shift+ЛКМ: Быстрое перемещение (Quick Transfer)
			_handle_shift_click(inv, index)
		else:
			# Обычный ЛКМ: Взять / положить / объединить / поменять
			_handle_left_click(inv, index)

	# 2. Правый клик (ПКМ)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Обычный ПКМ: Разделение стака (взять 1/2) или положить ровно 1
		_handle_right_click(inv, index)

func _handle_left_click(inv: InventoryData, index: int) -> void:
	if held_item == null:
		# Рука пуста -> забираем весь слот
		var taken := inv.take_all(index)
		if taken.item != null:
			held_item = taken.item
			held_quantity = taken.quantity
			held_source_inv = inv
			held_source_index = index
	else:
		# В руке есть предмет -> кладём / объединяем / меняем
		var res := inv.place_or_merge(index, held_item, held_quantity)
		held_item = res.item
		held_quantity = res.quantity
		if held_item == null:
			held_source_inv = null
			held_source_index = -1

	_update_held_preview()
	_refresh_ui()

func _handle_right_click(inv: InventoryData, index: int) -> void:
	if held_item == null:
		# Рука пуста:
		# Если это расходуемый предмет и сундук закрыт — используем его
		var slot := inv.slots[index]
		if not slot.is_empty() and slot.item.type == "consumable" and chest_inventory == null:
			inv.use_item(index)
		else:
			# Иначе забираем половину стака (Разделение стака)
			var taken := inv.take_half(index)
			if taken.item != null:
				held_item = taken.item
				held_quantity = taken.quantity
				held_source_inv = inv
				held_source_index = index
	else:
		# В руке есть предмет -> кладём ровно 1 штуку в слот
		if inv.place_one(index, held_item):
			held_quantity -= 1
			if held_quantity <= 0:
				held_item = null
				held_source_inv = null
				held_source_index = -1

	_update_held_preview()
	_refresh_ui()

func _handle_shift_click(inv: InventoryData, index: int) -> void:
	# Быстрое перемещение между инвентарем игрока и сундуком
	if chest_inventory != null and player_inventory != null:
		if inv == player_inventory:
			inv.quick_transfer(index, chest_inventory)
		elif inv == chest_inventory:
			inv.quick_transfer(index, player_inventory)
	else:
		# Если сундук не открыт, Shift+клик по зелью использует его
		var slot := inv.slots[index]
		if not slot.is_empty() and slot.item.type == "consumable":
			inv.use_item(index)

	_refresh_ui()

func _handle_q_drop(drop_all: bool) -> void:
	# Выбрасывание в мир
	if held_item != null and held_quantity > 0:
		var amount := held_quantity if drop_all else 1
		held_quantity -= amount
		if player_inventory:
			player_inventory.spawn_world_drop(held_item, amount)
		if held_quantity <= 0:
			held_item = null
			held_source_inv = null
			held_source_index = -1
		_update_held_preview()
		_refresh_ui()
	elif hovered_inv != null and hovered_index >= 0:
		var amount := -1 if drop_all else 1
		hovered_inv.drop_item(hovered_index, amount)
		_refresh_ui()

func _on_drop_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Клик по пустому пространству вне окон инвентаря
			if held_item != null and held_quantity > 0:
				# Выбрасываем предмет в мир!
				if player_inventory:
					player_inventory.spawn_world_drop(held_item, held_quantity)
				held_item = null
				held_quantity = 0
				held_source_inv = null
				held_source_index = -1
				_update_held_preview()
				_refresh_ui()

func _update_held_preview() -> void:
	if held_item != null and held_quantity > 0:
		held_preview.visible = true
		held_preview.global_position = get_global_mouse_position() - held_preview.size * 0.5
		if held_icon:
			held_icon.texture = held_item.get_icon()
		if held_count:
			held_count.text = str(held_quantity) if held_quantity > 1 else ""
	else:
		held_preview.visible = false
		if held_icon:
			held_icon.texture = null
		if held_count:
			held_count.text = ""

func _refresh_ui() -> void:
	if player_inventory:
		_refresh_grid(player_inventory)
	if chest_inventory:
		_refresh_grid(chest_inventory)

func _refresh_grid(inv: InventoryData) -> void:
	var panels: Array[PanelContainer] = _slot_panels.get(inv, [])
	for i in panels.size():
		if i >= inv.slots.size():
			break
		var slot_panel := panels[i]
		var slot := inv.slots[i]
		var icon: TextureRect = slot_panel.find_child("Icon", true, false) as TextureRect
		var count_label: Label = slot_panel.find_child("Count", true, false) as Label

		var is_hover := (hovered_inv == inv and hovered_index == i)
		_update_slot_style(inv, i, slot_panel, is_hover)

		if slot.is_empty():
			slot_panel.tooltip_text = ""
			if icon:
				icon.texture = null
			if count_label:
				count_label.text = ""
		else:
			var tip := "%s\n%s" % [slot.item.item_name, slot.item.description]
			if slot.item.type == "consumable" and chest_inventory == null:
				tip += "\n[RMB: Use]"
			slot_panel.tooltip_text = tip

			if icon:
				icon.texture = slot.item.get_icon()
			if count_label:
				count_label.text = str(slot.quantity) if slot.quantity > 1 else ""
