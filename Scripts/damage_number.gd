extends Node2D

var amount: int = 0
@onready var label: RichTextLabel = $RichTextLabel

@export_group("Animation Settings")
@export var rise_distance: float = 35.0  # На сколько пикселей поднимается вверх
@export var rise_duration: float = 0.2   # Время быстрого вылета
@export var hold_duration: float = 1.0   # Время статичной паузы на месте
@export var fade_duration: float = 0.25  # Время исчезновения

func start(dmg_amount: int, spawn_pos: Vector2) -> void:
	amount = dmg_amount
	global_position = spawn_pos
	
	if not is_inside_tree():
		await ready
	
	if label:
		label.text = str(amount)
	modulate.a = 1.0
	
	var tween = create_tween()
	
	# 1. Быстрый вылет вверх на rise_distance с легким разлетом в стороны (дрифт)
	var drift_x = randf_range(-25.0, 25.0)
	var target_pos = Vector2(global_position.x + drift_x, global_position.y - rise_distance)
	tween.tween_property(self, "global_position", target_pos, rise_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	# 2. Статичная пауза на 1 секунду на этой позиции
	tween.tween_interval(hold_duration)
	
	# 3. Плавное растворение
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	# 4. Удаление после завершения всей анимации
	tween.tween_callback(queue_free)
