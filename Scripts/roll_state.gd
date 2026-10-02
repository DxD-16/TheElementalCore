class_name RollState
extends State

@export_category("Roll Settings")
## Множитель начальной скорости рывка относительно базовой скорости игрока
@export var initial_speed_multiplier: float = 2.4
## Множитель конечной скорости рывка (к концу анимации)
@export var final_speed_multiplier: float = 1.0
## Перезарядка рывка в секундах
@export var cooldown_duration: float = 4.0

var roll_direction: float = 1.0
var current_roll_speed: float = 0.0
var cooldown_timer: float = 0.0
var roll_elapsed_time: float = 0.0
var roll_duration: float = 0.66

var roll_speed_multiplier: float:
	get:
		return (current_roll_speed / player.speed) if (player and player.speed > 0.0) else 1.0

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		initial_speed_multiplier = ConfigManager.get_float("player", "states.roll.initial_speed_multiplier", initial_speed_multiplier)
		final_speed_multiplier = ConfigManager.get_float("player", "states.roll.final_speed_multiplier", final_speed_multiplier)
		cooldown_duration = ConfigManager.get_float("player", "states.roll.cooldown_duration", cooldown_duration)

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)

## Готов ли рывок к использованию
func can_roll() -> bool:
	return cooldown_timer <= 0.0 and player != null and player.is_on_floor()

func enter() -> void:
	if not player:
		return

	# Перезарядка применяется только к ручному кувырку
	cooldown_timer = cooldown_duration

	# Неуязвимость персонажа во время рывка
	player.is_invulnerable = true

	# Определение направления рывка:
	# 1. Зажатый пользовательский ввод
	# 2. Инерция / текущая скорость
	# 3. Поворот тела персонажа
	var input_dir := Input.get_axis("ui_left", "ui_right")
	if input_dir != 0.0:
		roll_direction = signf(input_dir)
	elif absf(player.velocity.x) > 1.0:
		roll_direction = signf(player.velocity.x)
	elif player.body:
		roll_direction = -1.0 if player.body.scale.x < 0.0 else 1.0
	else:
		roll_direction = 1.0

	if player.body:
		player.body.scale.x = -1.0 if roll_direction < 0.0 else 1.0

	# Вычисляем длительность анимации PlayerRoll
	roll_duration = _calculate_roll_duration()
	roll_elapsed_time = 0.0

	# Начальная резкая скорость рывка
	current_roll_speed = player.speed * initial_speed_multiplier
	player.velocity.x = roll_direction * current_roll_speed

	if player.animated_sprite:
		player.animated_sprite.play("PlayerRoll")
		if not player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
			player.animated_sprite.animation_finished.connect(_on_roll_finished)

func exit() -> void:
	if player:
		player.is_invulnerable = false
		if player.animated_sprite:
			if player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
				player.animated_sprite.animation_finished.disconnect(_on_roll_finished)

func physics_update(delta: float) -> void:
	if not player:
		return

	roll_elapsed_time += delta

	# Плавный спад ускорения от стартового значения до конца анимации кувырка
	var t := clampf(roll_elapsed_time / roll_duration, 0.0, 1.0) if roll_duration > 0.0 else 1.0
	var ease_t := 1.0 - pow(1.0 - t, 2.0)
	var start_speed := player.speed * initial_speed_multiplier
	var end_speed := player.speed * final_speed_multiplier
	current_roll_speed = lerpf(start_speed, end_speed, ease_t)

	# Игрок не останавливается до окончания анимации
	player.velocity.x = roll_direction * current_roll_speed

func _on_roll_finished() -> void:
	if state_machine and state_machine.current_state == self:
		if not player.is_on_floor():
			state_machine.transition_to("JumpState")
			return

		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0.0:
			state_machine.transition_to("RunState")
		else:
			state_machine.transition_to("IdleState")

func _calculate_roll_duration() -> float:
	if player and player.animated_sprite and player.animated_sprite.sprite_frames:
		var frames: SpriteFrames = player.animated_sprite.sprite_frames
		if frames.has_animation("PlayerRoll"):
			var count := frames.get_frame_count("PlayerRoll")
			var fps := frames.get_animation_speed("PlayerRoll")
			if fps > 0.0:
				return float(count) / fps
	return 0.66
