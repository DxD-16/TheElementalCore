class_name Dummy
extends EnemyBase

const DROPPED_ITEM_SCENE = preload("res://Scenes/items/dropped_item.tscn")

## Таблица дропа: [{item_id, min_count, max_count, chance}]
var drop_table: Array[Dictionary] = [
	{"item_id": "health_potion", "min_count": 1, "max_count": 2, "chance": 0.8},
	{"item_id": "big_health_potion", "min_count": 1, "max_count": 1, "chance": 0.25}
]

## Урон при контакте с игроком (0 = не наносит урона)
var contact_damage: int = 0
var _contact_player: Player = null
var _contact_cooldown: float = 0.0

func _enter_tree() -> void:
	_load_config()

func _ready() -> void:
	var dummy_weight := 1.0
	if ConfigManager:
		dummy_weight = ConfigManager.get_float("entities", "dummy.weight", dummy_weight)
	definition = EnemyDefinitionClass.new("dummy", {
		"display_name": "Dummy",
		"max_health": 1000,
		"move_speed": 0.0,
		"weight": dummy_weight,
		"detection_range": 0.0,
		"attack_range": 0.0,
		"drop_table": drop_table
	})
	set_definition(definition)
	super._ready()
	_load_config()
	if health_component:
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

func _load_config() -> void:
	if ConfigManager:
		var max_hp = ConfigManager.get_int("entities", "dummy.max_health", 1000)
		var hc = get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.max_health = max_hp
			hc.current_health = max_hp
		contact_damage = ConfigManager.get_int("entities", "dummy.contact_damage", contact_damage)

func _process(delta: float) -> void:
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
	if _contact_player and _contact_cooldown <= 0.0:
		_deal_contact_damage(_contact_player)
	super._process(delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_contact_player = body as Player
		_deal_contact_damage(_contact_player)

func _on_body_exited(body: Node2D) -> void:
	if body == _contact_player:
		_contact_player = null
		_contact_cooldown = 0.0

func _deal_contact_damage(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		_contact_player = null
		return
	var iframe_time: float = 0.2
	if ConfigManager:
		iframe_time = ConfigManager.get_float("player", "health.iframes_after_dmg", iframe_time)
	_contact_cooldown = iframe_time
	player.take_damage(contact_damage, global_position)

func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, knockback: Vector2 = Vector2.ZERO) -> void:
	apply_damage(amount, hit_pos, ElementalTypes.ElementType.NONE, null, knockback)

func _on_died() -> void:
	print("Dummy destroyed!")
	_spawn_loot()
	queue_free()

func _spawn_loot() -> void:
	if not DROPPED_ITEM_SCENE:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for entry in drop_table:
		var chance: float = entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var item_id: String = entry.get("item_id", "")
		if item_id.is_empty():
			continue
		var min_c: int = int(entry.get("min_count", 1))
		var max_c: int = int(entry.get("max_count", 1))
		var count: int = randi_range(min_c, max_c)
		var dropped = DROPPED_ITEM_SCENE.instantiate() as DroppedItem
		scene.add_child(dropped)
		dropped.global_position = global_position + Vector2(0, -10)
		var launch := Vector2(randf_range(-120.0, 120.0), randf_range(-250.0, -150.0))
		dropped.setup(item_id, count, launch)
