class_name JumpState
extends State

## Сколько секунд падения нужно, прежде чем включить PlayerFalling
@export var fall_anim_delay: float = 0.25
## Landing/Roll только если падение длилось не меньше этого времени (короткие прыжки без recovery)
@export var recovery_min_fall_time: float = 0.5
## Горизонтальная скорость ниже этого порога = вертикальное приземление (Landing)
@export var horizontal_land_threshold: float = 2500.0
## Время падения, не причиняющее урон
@export var fall_damage_grace_time: float = 0.8
## Один дополнительный урон за каждые N секунд падения сверх безопасного времени
@export var fall_damage_interval: float = 0.01

enum Phase { ASCEND, FALLING, LANDING }

var phase: Phase = Phase.ASCEND
var fall_timer: float = 0.0
var last_air_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		fall_anim_delay = ConfigManager.get_float("player", "states.jump.fall_anim_delay", fall_anim_delay)
		recovery_min_fall_time = ConfigManager.get_float("player", "states.jump.recovery_min_fall_time", recovery_min_fall_time)
		fall_damage_grace_time = ConfigManager.get_float("player", "states.jump.fall_damage_grace_time", fall_damage_grace_time)
		fall_damage_interval = ConfigManager.get_float("player", "states.jump.fall_damage_interval", fall_damage_interval)

		var legacy_threshold := ConfigManager.get_float("player", "states.jump.vertical_land_threshold", -1.0)
		if legacy_threshold >= 0.0:
			horizontal_land_threshold = legacy_threshold
		else:
			horizontal_land_threshold = ConfigManager.get_float("player", "states.jump.horizontal_land_threshold", horizontal_land_threshold)

func enter() -> void:
	fall_timer = 0.0
	phase = Phase.ASCEND
	last_air_velocity = player.velocity if player else Vector2.ZERO
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

	if player.velocity.y < 0.0:
		fall_timer = 0.0
		if phase != Phase.ASCEND:
			phase = Phase.ASCEND
			_play("PlayerJump")
	elif player.velocity.y > 0.0:
		fall_timer += delta
		if fall_timer >= fall_anim_delay and phase != Phase.FALLING:
			phase = Phase.FALLING
			_play("PlayerFalling")

func _start_landing() -> void:
	var fall_damage := 0
	if fall_damage_interval > 0.0 and fall_timer > fall_damage_grace_time:
		fall_damage = int(floor((fall_timer - fall_damage_grace_time) / fall_damage_interval + 0.000001))
	if fall_damage > 0:
		player.take_damage(fall_damage, player.global_position)
		if player.is_dead:
			return

	# Короткие прыжки / паркур: сразу Idle или Run без Landing/Roll
	if fall_timer < recovery_min_fall_time:
		player.play_squash(player.landing_squash_x, player.landing_squash_y)
		_return_to_ground_state()
		return

	var horizontal_speed := absf(last_air_velocity.x)
	if horizontal_speed <= 0.0:
		horizontal_speed = absf(player.velocity.x)

	# Косое приземление → кувырок с продолжением движения
	if horizontal_speed > horizontal_land_threshold:
		var landing_roll := state_machine.get_node_or_null("LandingRollState") as LandingRollState
		if landing_roll:
			landing_roll.inherited_velocity_x = last_air_velocity.x
			state_machine.transition_to("LandingRollState")
			return

	player.play_squash(player.landing_squash_x, player.landing_squash_y)
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
