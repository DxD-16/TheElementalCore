class_name JumpState
extends State

## Сколько секунд падения нужно, прежде чем включить PlayerFalling
@export var fall_anim_delay: float = 0.25
## Landing/Roll только если падение длилось не меньше этого времени (короткие прыжки без recovery)
@export var recovery_min_fall_time: float = 0.5
## Горизонтальная скорость ниже этого порога = вертикальное приземление (Landing)
@export var vertical_land_threshold: float = 2500.0

enum Phase { ASCEND, FALLING, LANDING }

var phase: Phase = Phase.ASCEND
var fall_timer: float = 0.0
var last_air_velocity: Vector2 = Vector2.ZERO
var last_height_y: float = 0.0

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		fall_anim_delay = ConfigManager.get_float("player", "states.jump.fall_anim_delay", fall_anim_delay)
		recovery_min_fall_time = ConfigManager.get_float("player", "states.jump.recovery_min_fall_time", recovery_min_fall_time)
		vertical_land_threshold = ConfigManager.get_float("player", "states.jump.vertical_land_threshold", vertical_land_threshold)

func enter() -> void:
	fall_timer = 0.0
	phase = Phase.ASCEND
	last_air_velocity = player.velocity if player else Vector2.ZERO
	last_height_y = player.global_position.y if player else 0.0
	_play("PlayerJump")

func exit() -> void:
	_disconnect_landing()

func physics_update(delta: float) -> void:
	if not player:
		return

	if phase == Phase.LANDING:
		return

	if player.is_on_floor():
		_start_landing()
		return

	last_air_velocity = player.velocity

	var current_y := player.global_position.y
	var is_descending := current_y > last_height_y
	var is_gaining_height := current_y < last_height_y
	last_height_y = current_y

	if is_gaining_height:
		fall_timer = 0.0
		if phase != Phase.ASCEND:
			phase = Phase.ASCEND
			_play("PlayerJump")
	elif is_descending:
		fall_timer += delta
		if fall_timer >= fall_anim_delay and phase != Phase.FALLING:
			phase = Phase.FALLING
			_play("PlayerFalling")

func _start_landing() -> void:
	# Короткие прыжки / паркур: сразу Idle или Run без Landing/Roll
	if fall_timer < recovery_min_fall_time:
		_return_to_ground_state()
		return

	var horizontal_speed := absf(last_air_velocity.x)
	if horizontal_speed <= 0.0:
		horizontal_speed = absf(player.velocity.x)

	# Косое приземление → кувырок с продолжением движения
	if horizontal_speed > vertical_land_threshold:
		var roll := state_machine.get_node_or_null("RollState") as RollState
		if roll:
			roll.is_landing_roll = true
		state_machine.transition_to("RollState")
		return

	phase = Phase.LANDING
	player.velocity.x = 0.0
	_play("PlayerLanding")
	if player.animated_sprite:
		if not player.animated_sprite.animation_finished.is_connected(_on_landing_finished):
			player.animated_sprite.animation_finished.connect(_on_landing_finished)

func _on_landing_finished() -> void:
	_disconnect_landing()
	if state_machine and state_machine.current_state == self:
		_return_to_ground_state()

func _return_to_ground_state() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		state_machine.transition_to("RunState")
	else:
		state_machine.transition_to("IdleState")

func _play(anim_name: String) -> void:
	if player and player.animated_sprite:
		player.animated_sprite.play(anim_name)

func _disconnect_landing() -> void:
	if player and player.animated_sprite:
		if player.animated_sprite.animation_finished.is_connected(_on_landing_finished):
			player.animated_sprite.animation_finished.disconnect(_on_landing_finished)

func is_landing() -> bool:
	return phase == Phase.LANDING
