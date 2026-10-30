class_name DroppedItem
extends CharacterBody2D

## Предмет, лежащий в мире. При контакте с игроком — подбирается.

const PICKUP_RADIUS: float = 58.0
const RARITY_COLORS: Dictionary = {
	"common": Color(1.00, 1.00, 1.00),
	"uncommon": Color(0.35, 0.9, 0.45),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.75, 0.4, 1.0),
	"legendary": Color(1.0, 0.9, 0.5),
}
@export var item_id: String = ""
@export var item_count: int = 1
@export var pick_up_timeout = 2

var item_instance: ItemInstance
var _picked_up: bool = false
var _pickup_enabled: bool = false
var _gravity: float = 650.0
var _on_ground: bool = false
var _bob_time: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var particles: GPUParticles2D = $Visuals/GPUParticles2D
@onready var rarity_glow: PointLight2D = $Visuals/GPUParticles2D/PointLight2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Задержка перед подбором (чтобы предмет успел красиво вылететь)
	await get_tree().create_timer(pick_up_timeout).timeout
	if is_instance_valid(self) and not _picked_up:
		_pickup_enabled = true

func setup(p_item_id: String, p_count: int = 1, launch_dir: Vector2 = Vector2.ZERO) -> void:
	item_id = p_item_id
	item_count = p_count
	var catalog := get_node_or_null("/root/ItemCatalogService") as ItemCatalog
	if catalog == null:
		push_error("[DroppedItem] ItemCatalogService autoload is unavailable")
		return
	var definition := catalog.get_definition(item_id)
	if definition == null:
		push_warning("[DroppedItem] Unknown item ID: %s" % item_id)
		return
	var instance := ItemInstance.new()
	instance.definition = definition
	setup_instance(instance, p_count, launch_dir)

func setup_instance(instance: ItemInstance, p_count: int = 1, launch_dir: Vector2 = Vector2.ZERO) -> void:
	if instance == null or instance.definition == null:
		push_error("[DroppedItem] Cannot initialize a drop without a valid item instance")
		return
	item_instance = instance.duplicate_instance()
	item_id = item_instance.id
	item_count = p_count

	# Начальная скорость вылета
	if launch_dir != Vector2.ZERO:
		velocity = launch_dir
	else:
		velocity = Vector2(randf_range(-100.0, 100.0), randf_range(-250.0, -150.0))

	if sprite:
		sprite.texture = item_instance.get_icon()
	var rarity_color: Color = RARITY_COLORS.get(item_instance.definition.rarity, Color.WHITE)
	particles.self_modulate = rarity_color
	rarity_glow.color = rarity_color

func _physics_process(delta: float) -> void:
	if _picked_up:
		return

	if not _on_ground:
		velocity.y += _gravity * delta
	else:
		_bob_time += delta * 3.0
		visuals.position.y = sin(_bob_time) * 3.0
	velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta)
	move_and_slide()
	if is_on_floor():
		_on_ground = true
		velocity.y = 0.0

	if _pickup_enabled:
		for player in get_tree().get_nodes_in_group("Player"):
			if player is Player and global_position.distance_to(player.global_position) <= PICKUP_RADIUS:
				_on_body_entered(player)
				if _picked_up:
					break

func _on_body_entered(body: Node2D) -> void:
	if _picked_up or not _pickup_enabled:
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

	if item_instance == null:
		push_error("[DroppedItem] Cannot pick up drop without an item instance")
		return
	var leftover := inventory.add_item_instance(item_instance, item_count)
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
