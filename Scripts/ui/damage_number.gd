extends Node2D

var amount: int = 0
@onready var label: RichTextLabel = $RichTextLabel

@export_group("Animation Settings")
@export var rise_distance: float = 35.0  # На сколько пикселей поднимается вверх
@export var rise_duration: float = 0.2   # Время быстрого вылета
@export var hold_duration: float = 1.0   # Время статичной паузы на месте
@export var fade_duration: float = 0.25  # Время исчезновения

var drift_range_x: float = 25.0

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		rise_distance = ConfigManager.get_float("ui_effects", "damage_number.rise_distance", rise_distance)
		rise_duration = ConfigManager.get_float("ui_effects", "damage_number.rise_duration", rise_duration)
		hold_duration = ConfigManager.get_float("ui_effects", "damage_number.hold_duration", hold_duration)
		fade_duration = ConfigManager.get_float("ui_effects", "damage_number.fade_duration", fade_duration)
		drift_range_x = ConfigManager.get_float("ui_effects", "damage_number.drift_range_x", drift_range_x)

## Запускает анимацию цифры урона.
## custom_color — опциональный цвет текста (передаётся игроком для оранжевых цифр)
func start(dmg_amount: int, spawn_pos: Vector2, custom_color: Color = Color(-1, -1, -1)) -> void:
	amount = dmg_amount
	global_position = spawn_pos

	if not is_inside_tree():
		await ready

	if label:
		label.text = str(amount)
		# Применяем кастомный цвет только если он передан явно (не дефолтный Color(-1,-1,-1))
		if custom_color.r >= 0.0:
			label.add_theme_color_override("default_color", custom_color)
	modulate.a = 1.0

	var tween = create_tween()

	# 1. Быстрый вылет вверх на rise_distance с легким разлетом в стороны (дрифт)
	var drift_x = randf_range(-drift_range_x, drift_range_x)
	var target_pos = Vector2(global_position.x + drift_x, global_position.y - rise_distance)
	tween.tween_property(self, "global_position", target_pos, rise_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# 2. Статичная пауза на месте
	tween.tween_interval(hold_duration)

	# 3. Плавное растворение
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_LINEAR)

	# 4. Удаление после завершения всей анимации
	tween.tween_callback(queue_free)
