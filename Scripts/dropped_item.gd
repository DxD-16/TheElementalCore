class_name DroppedItem
extends Area2D

## Предмет, лежащий в мире. При контакте с игроком — подбирается.

@export var item_id: String = ""
@export var item_count: int = 1
@export var pick_up_timeout = 2

var _picked_up: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _gravity: float = 650.0
var _on_ground: bool = false
var _bob_time: float = 0.0
var _floor_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Задержка перед подбором (чтобы предмет успел красиво вылететь)
	collision.set_deferred("disabled", true)
	await get_tree().create_timer(pick_up_timeout).timeout
	if is_instance_valid(self) and not _picked_up:
		collision.set_deferred("disabled", false)
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func setup(p_item_id: String, p_count: int = 1, launch_dir: Vector2 = Vector2.ZERO) -> void:
	item_id = p_item_id
	item_count = p_count

	# Находим уровень пола с помощью RayCast вниз
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 300), 1)
	var result := space_state.intersect_ray(query)
	if result:
		_floor_y = result.position.y - 4.0
	else:
		_floor_y = global_position.y + 10.0

	# Начальная скорость вылета
	if launch_dir != Vector2.ZERO:
		_velocity = launch_dir
	else:
		_velocity = Vector2(randf_range(-100.0, 100.0), randf_range(-250.0, -150.0))

	# Иконка предмета из конфига
	if ConfigManager:
		var icon_path: String = ConfigManager.get_string("items", "%s.icon" % item_id, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tex := load(icon_path) as Texture2D
			if tex and sprite:
				sprite.texture = tex

func _physics_process(delta: float) -> void:
	if _picked_up:
		return

	if not _on_ground:
		_velocity.y += _gravity * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 150.0 * delta)
		global_position += _velocity * delta

		if _velocity.y > 0.0 and global_position.y >= _floor_y:
			global_position.y = _floor_y
			_on_ground = true
			_velocity = Vector2.ZERO
	else:
		_bob_time += delta * 3.0
		if sprite:
			sprite.position.y = sin(_bob_time) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if _picked_up:
		return
	if not body is Player:
		return

	var player := body as Player
	var inventory: InventoryData = player.inventory_data
	if inventory == null:
		inventory = player.get_node_or_null("InventoryData") as InventoryData
	if inventory == null:
		inventory = _find_inventory()
	if inventory == null:
		return

	var leftover := inventory.add_item_by_id(item_id, item_count)
	if leftover < item_count:
		var picked_amount := item_count - leftover
		item_count = leftover
		print("[DroppedItem] Picked up: %s x%d" % [item_id, picked_amount])

		if item_count <= 0:
			_picked_up = true
			if collision:
				collision.set_deferred("disabled", true)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "global_position", player.global_position, 0.2)
			tween.tween_property(self, "modulate:a", 0.0, 0.2)
			tween.chain().tween_callback(queue_free)

func _find_inventory() -> InventoryData:
	var nodes := get_tree().get_nodes_in_group("Player")
	for n in nodes:
		var inv := n.get_node_or_null("InventoryData") as InventoryData
		if inv:
			return inv
	return null
