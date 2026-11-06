class_name Chest
extends StaticBody2D

signal chest_opened

const DROPPED_ITEM_SCENE: PackedScene = preload("res://Scenes/items/dropped_item.tscn")
const OPENED_TEXTURE: Texture2D = preload("res://Sprites/world/chest/chest_opened.svg")
const DROP_INTERVAL: float = 0.25

@export var loot_table: Array[Dictionary] = []
@export var interaction_hint_text: String = "[E] Open"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var hint_label: Label = $HintLabel
@onready var opening_animation: AnimationPlayer = $AnimationPlayer

var _player_nearby: bool = false
var _is_open: bool = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	hint_label.text = interaction_hint_text
	hint_label.visible = false

	if loot_table.is_empty():
		_load_default_loot()

func _load_default_loot() -> void:
	loot_table = [
		{"item_id": "health_potion", "min_count": 2, "max_count": 5, "chance": 1.0},
		{"item_id": "big_health_potion", "min_count": 1, "max_count": 2, "chance": 0.5},
		{"item_id": "light_sword", "min_count": 1, "max_count": 1, "chance": 1.0},
		{"item_id": "great_sword", "min_count": 1, "max_count": 1, "chance": 1.0}
	]

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		open_chest()

func open_chest() -> void:
	if _is_open:
		return

	_is_open = true
	hint_label.visible = false
	opening_animation.play("open")
	await opening_animation.animation_finished
	if not is_inside_tree():
		return

	sprite.texture = OPENED_TEXTURE
	chest_opened.emit()
	await _spawn_loot()

func _spawn_loot() -> void:
	var drops: Array[Dictionary] = []
	for entry in loot_table:
		if randf() > float(entry.get("chance", 1.0)):
			continue

		var item_id: String = str(entry.get("item_id", ""))
		if item_id.is_empty():
			continue

		var count := randi_range(
			int(entry.get("min_count", 1)),
			int(entry.get("max_count", 1))
		)
		drops.append({"item_id": item_id, "count": count})

	var scene := get_tree().current_scene
	if scene == null:
		push_error("[Chest] Cannot spawn loot without an active scene")
		return

	for index in range(drops.size()):
		if index > 0:
			await get_tree().create_timer(DROP_INTERVAL).timeout
			if not is_inside_tree():
				return

		var drop: Dictionary = drops[index]
		var dropped_item := DROPPED_ITEM_SCENE.instantiate() as DroppedItem
		if dropped_item == null:
			push_error("[Chest] Failed to instantiate a dropped item")
			return

		scene.add_child(dropped_item)
		dropped_item.global_position = global_position + Vector2(0, -10)
		var launch := Vector2(randf_range(-120.0, 120.0), randf_range(-250.0, -150.0))
		dropped_item.setup(str(drop["item_id"]), int(drop["count"]), launch)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_nearby = true
		if not _is_open:
			hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_nearby = false
		hint_label.visible = false
