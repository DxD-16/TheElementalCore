class_name Player
extends CharacterBody2D

@export_category("Movement Settings")
@export var speed: float = 300.0
@export var jump_velocity: float = -420.0

@export_category("Feel & Tuning")
@export var acceleration: float = 1000.0
@export var friction: float = 2000.0

@export_category("Jump Tweaks")
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15
@export var jump_cut_multiplier: float = 0.5

@export_category("Double Jump")
@export var DoubleJumpAvailable: bool = false
## Сколько прыжков можно сделать в воздухе после coyote
@export var air_jumps: int = 1
## 1 = как обычный прыжок, 0.5 = половина силы
@export var air_jump_strength: float = 1.0

@export var attack_move_speed_multiplier: float = 0.85 # Скорость перемещения во время удара

## Неуязвимость персонажа (включается, например, во время рывка)
@export var is_invulnerable: bool = false

## Параметры здоровья и реакции на урон (из player.json > health)
var iframes_after_dmg: float = 0.2
var flash_color: Color = Color.WHITE
var flash_duration: float = 0.15

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var remaining_air_jumps: int = 0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

## Таймер неуязвимости после получения урона
var _iframe_timer: float = 0.0
var _flash_tween: Tween
var is_dead: bool = false

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/ui/damage_number.tscn")
## Цвет цифр урона игрока — оранжевый #de9e41
const PLAYER_DAMAGE_COLOR := Color(0.871, 0.620, 0.255)

@onready var body: Node2D = $Body
@onready var animated_sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	add_to_group("Player")
	_load_config()
	_setup_dash_input()

	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)

func _load_config() -> void:
	if ConfigManager:
		speed = ConfigManager.get_float("player", "movement.speed", speed)
		jump_velocity = ConfigManager.get_float("player", "movement.jump_velocity", jump_velocity)
		acceleration = ConfigManager.get_float("player", "movement.acceleration", acceleration)
		friction = ConfigManager.get_float("player", "movement.friction", friction)
		coyote_time = ConfigManager.get_float("player", "movement.coyote_time", coyote_time)
		jump_buffer_time = ConfigManager.get_float("player", "movement.jump_buffer_time", jump_buffer_time)
		jump_cut_multiplier = ConfigManager.get_float("player", "movement.jump_cut_multiplier", jump_cut_multiplier)
		DoubleJumpAvailable = ConfigManager.get_bool("player", "movement.double_jump_available", DoubleJumpAvailable)
		air_jumps = ConfigManager.get_int("player", "movement.air_jumps", air_jumps)
		air_jump_strength = ConfigManager.get_float("player", "movement.air_jump_strength", air_jump_strength)
		attack_move_speed_multiplier = ConfigManager.get_float("player", "movement.attack_move_speed_multiplier", attack_move_speed_multiplier)
		# Параметры здоровья
		iframes_after_dmg = ConfigManager.get_float("player", "health.iframes_after_dmg", iframes_after_dmg)
		flash_duration = ConfigManager.get_float("player", "health.flash_duration", flash_duration)
		var fc_str: String = ConfigManager.get_string("player", "health.flash_color", "")
		if fc_str.is_valid_html_color():
			flash_color = Color(fc_str)
		# Загружаем max_health и применяем к HealthComponent
		var max_hp: int = ConfigManager.get_int("player", "health.max_health", 200)
		var hc := get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.max_health = max_hp
			hc.current_health = max_hp

func _setup_dash_input() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)

func _process(delta: float) -> void:
	# Тикаем таймер i-frames
	if _iframe_timer > 0.0:
		_iframe_timer -= delta

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	is_invulnerable = true
	velocity = Vector2.ZERO

	if state_machine and not state_machine.current_state is DeathState:
		state_machine.transition_to("DeathState")

func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO) -> void:
	# Неуязвимость во время рывка или i-frames после урона
	if is_invulnerable or _iframe_timer > 0.0:
		return
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.take_damage(amount)
	# Запустить i-frames
	_iframe_timer = iframes_after_dmg
	# Вспышка спрайта
	_play_flash_effect()
	# Спавн оранжевых цифр урона
	if amount > 0:
		_spawn_player_damage_number(amount, hit_pos)

func _play_flash_effect() -> void:
	if not animated_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	animated_sprite.modulate = flash_color
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, flash_duration)

func _spawn_player_damage_number(amount: int, hit_pos: Vector2) -> void:
	if not DAMAGE_NUMBER_SCENE:
		return
	var dmg_num = DAMAGE_NUMBER_SCENE.instantiate()
	get_tree().current_scene.add_child(dmg_num)
	var spawn_pos: Vector2
	if hit_pos != Vector2.ZERO:
		spawn_pos = hit_pos + Vector2(randf_range(-15.0, 15.0), -50.0)
	else:
		spawn_pos = global_position + Vector2(randf_range(-15.0, 15.0), -80.0)
	dmg_num.start(amount, spawn_pos, PLAYER_DAMAGE_COLOR)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var is_attacking: bool = state_machine and state_machine.current_state is AttackState
	var is_rolling: bool = state_machine and state_machine.current_state is RollState
	var is_landing: bool = (
		state_machine
		and state_machine.current_state is JumpState
		and (state_machine.current_state as JumpState).is_landing()
	)

	# Графика, койот-тайм и заряд воздушных прыжков
	if is_on_floor():
		coyote_timer = coyote_time
		remaining_air_jumps = air_jumps
	else:
		velocity.y += gravity * delta
		coyote_timer -= delta

	# Буфер прыжка (блокируется во время атаки / кувырка / приземления)
	if not is_attacking and not is_rolling and not is_landing and Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	var jump_locked := is_rolling or is_landing
	if jump_buffer_timer > 0 and not jump_locked:
		if coyote_timer > 0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif DoubleJumpAvailable and remaining_air_jumps > 0:
			velocity.y = jump_velocity * air_jump_strength
			jump_buffer_timer = 0.0
			remaining_air_jumps -= 1

	if Input.is_action_just_released("ui_up") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

	# Горизонтальное движение
	if is_rolling:
		var roll := state_machine.current_state as RollState
		velocity.x = roll.roll_direction * roll.current_roll_speed
	elif is_landing:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:
			var target_speed = speed * attack_move_speed_multiplier if is_attacking else speed
			velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
			body.scale.x = -1 if direction < 0 else 1
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
