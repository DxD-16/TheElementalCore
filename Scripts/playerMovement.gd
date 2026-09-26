class_name Player
extends CharacterBody2D

@export_category("Movement Settings")
@export var speed: float = 3000.0
@export var jump_velocity: float = -4000.0

@export_category("Feel & Tuning")
@export var acceleration: float = 10000.0
@export var friction: float = 20000.0

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

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var remaining_air_jumps: int = 0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var body: Node2D = $Body
@onready var animated_sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

func _physics_process(delta: float) -> void:
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
		velocity.x = roll.roll_direction * speed * roll.roll_speed_multiplier
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
