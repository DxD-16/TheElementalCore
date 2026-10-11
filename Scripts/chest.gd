class_name Chest
extends StaticBody2D

## Сундук со своим инвентарём.
## При взаимодействии (E) открывает интерфейс сундука рядом с инвентарем игрока.

signal chest_opened
signal chest_closed

@export var loot_table: Array[Dictionary] = []
@export var interaction_hint_text: String = "[E] Open"
@export var chest_name: String = "Chest"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var hint_label: Label = $HintLabel
@onready var inventory_data: InventoryData = $InventoryData

var _player_nearby: bool = false
var _is_open: bool = false
var _loot_generated: bool = false

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	if hint_label:
		hint_label.text = interaction_hint_text
		hint_label.visible = false

	if loot_table.is_empty():
		_load_default_loot()

func _load_default_loot() -> void:
	loot_table = [
		{"item_id": "health_potion", "min_count": 2, "max_count": 5, "chance": 1.0},
		{"item_id": "big_health_potion", "min_count": 1, "max_count": 2, "chance": 0.5}
	]

func _populate_initial_loot() -> void:
	if _loot_generated:
		return
	_loot_generated = true
	if inventory_data == null:
		inventory_data = get_node_or_null("InventoryData") as InventoryData
	if inventory_data == null:
		return

	for entry in loot_table:
		var chance: float = entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var item_id: String = entry.get("item_id", "")
		if item_id.is_empty():
			continue
		var min_c: int = int(entry.get("min_count", 1))
		var max_c: int = int(entry.get("max_count", 1))
		var count: int = randi_range(min_c, max_c)
		inventory_data.add_item_by_id(item_id, count)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		toggle_chest()

func toggle_chest() -> void:
	if _is_open:
		close_chest()
	else:
		open_chest()

func open_chest() -> void:
	if _is_open:
		return
	_populate_initial_loot()
	_is_open = true
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 0.9, 1.0)
	if hint_label:
		hint_label.visible = false

	var inv_ui := _find_inventory_ui()
	if inv_ui and inv_ui.has_method("open_chest"):
		inv_ui.open_chest(self)

	chest_opened.emit()
	print("[Chest] Opened '%s'" % chest_name)

func close_chest() -> void:
	if not _is_open:
		return
	_is_open = false
	if sprite:
		sprite.modulate = Color(0.9, 0.75, 0.4, 1.0)
	if _player_nearby and hint_label:
		hint_label.visible = true

	var inv_ui := _find_inventory_ui()
	if inv_ui and inv_ui.has_method("close_chest"):
		inv_ui.close_chest()

	chest_closed.emit()
	print("[Chest] Closed '%s'" % chest_name)

func _find_inventory_ui() -> Control:
	var nodes := get_tree().get_nodes_in_group("InventoryUI")
	if not nodes.is_empty():
		return nodes[0] as Control
	return get_tree().root.find_child("InventoryUI", true, false) as Control

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_nearby = true
		if hint_label and not _is_open:
			hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_nearby = false
		if hint_label:
			hint_label.visible = false
		if _is_open:
			close_chest()
