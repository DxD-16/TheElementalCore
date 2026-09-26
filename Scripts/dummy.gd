
class_name Dummy
extends StaticBody2D

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/ui/damage_number.tscn")

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

var flash_tween: Tween

func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_died)

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
	
	sprite.modulate = Color.RED
	flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func spawn_damage_number(amount: int, base_pos: Vector2) -> void:
	if DAMAGE_NUMBER_SCENE:
		var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
		# Добавляем в сцену мира, чтобы цифра была неподвижна и не преследовала игрока
		get_tree().current_scene.add_child(dmg_num)
		
		# Разброс по X и Y над хитбоксом атаки, чтобы цифры не слипались
		var offset_x = randf_range(-35.0, 35.0)
		var offset_y = randf_range(-20.0, 20.0)
		var spawn_pos = base_pos + Vector2(offset_x, -70.0 + offset_y)
		
		dmg_num.start(amount, spawn_pos)
	else:
		print("ОШИБКА: Сцена DamageNumber не найдена!")

func _on_died() -> void:
	print("Манекен уничтожен!")
	queue_free()
