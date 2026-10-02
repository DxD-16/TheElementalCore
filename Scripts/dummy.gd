
class_name Dummy
extends StaticBody2D

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/ui/damage_number.tscn")

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

var flash_tween: Tween
var flash_duration: float = 0.15
var flash_color: Color = Color.RED
var spawn_offset_x: float = 35.0
var spawn_offset_y: float = 20.0
var base_offset_y: float = -70.0

## Урон при контакте с игроком (0 = не наносит урона)
var contact_damage: int = 0

## Защита от повторного урона при одном касании
var _contact_player: Player = null
var _contact_cooldown: float = 0.0

func _enter_tree() -> void:
	_load_config()

func _ready() -> void:
	_load_config()
	if health_component:
		health_component.died.connect(_on_died)

func _load_config() -> void:
	if ConfigManager:
		var max_hp = ConfigManager.get_int("entities", "dummy.max_health", 1000)
		var hc = get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.max_health = max_hp
			hc.current_health = max_hp

		flash_duration = ConfigManager.get_float("entities", "dummy.flash_duration", flash_duration)
		var fc_str: String = ConfigManager.get_string("entities", "dummy.flash_color", "")
		if fc_str.is_valid_html_color():
			flash_color = Color(fc_str)

		contact_damage = ConfigManager.get_int("entities", "dummy.contact_damage", contact_damage)

		spawn_offset_x = ConfigManager.get_float("ui_effects", "damage_number.spawn_offset_x_range", spawn_offset_x)
		spawn_offset_y = ConfigManager.get_float("ui_effects", "damage_number.spawn_offset_y_range", spawn_offset_y)
		base_offset_y = ConfigManager.get_float("ui_effects", "damage_number.base_offset_y", base_offset_y)

func _process(delta: float) -> void:
	# Тикаем кулдаун контактного урона
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
	# Наносим урон игроку при постоянном контакте
	if _contact_player and _contact_cooldown <= 0.0:
		_deal_contact_damage(_contact_player)

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
	# Получаем из конфига iframes, чтобы кулдаун совпадал
	var iframe_time: float = 0.2
	if ConfigManager:
		iframe_time = ConfigManager.get_float("player", "health.iframes_after_dmg", iframe_time)
	_contact_cooldown = iframe_time
	# Наносим урон (при contact_damage == 0 вызов take_damage(0) всё равно нужен для вспышки)
	player.take_damage(contact_damage, global_position)

# Метод, который вызывают чужие хитбоксы при ударе
func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount)

	# Визуальный эффект при ударе
	flash_effect()

	# Спавн цифры урона над хитбоксом атаки (или над манекеном, если hit_pos не задан)
	var base_pos: Vector2 = hit_pos if hit_pos != Vector2.ZERO else (global_position + Vector2(0, -60))
	spawn_damage_number(amount, base_pos)

func flash_effect() -> void:
	if not sprite:
		return
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()

	sprite.modulate = flash_color
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, flash_duration)

func spawn_damage_number(amount: int, base_pos: Vector2) -> void:
	if DAMAGE_NUMBER_SCENE:
		var scene := get_tree().current_scene
		if scene == null:
			return
		var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
		# Добавляем в сцену мира, чтобы цифра была неподвижна и не преследовала игрока
		scene.add_child(dmg_num)

		# Разброс по X и Y над хитбоксом атаки, чтобы цифры не слипались
		var offset_x = randf_range(-spawn_offset_x, spawn_offset_x)
		var offset_y = randf_range(-spawn_offset_y, spawn_offset_y)
		var spawn_pos = base_pos + Vector2(offset_x, base_offset_y + offset_y)

		dmg_num.start(amount, spawn_pos)
	else:
		print("ОШИБКА: Сцена DamageNumber не найдена!")

func _on_died() -> void:
	print("Манекен уничтожен!")
	queue_free()
