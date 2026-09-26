class_name RollState
extends State

## Множитель скорости во время кувырка (1.0 = обычная скорость бега)
@export var roll_speed_multiplier: float = 1.0

var roll_direction: float = 1.0

func enter() -> void:
	if not player:
		return

	# Направление кувырка: по инерции, иначе по взгляду
	if absf(player.velocity.x) > 1.0:
		roll_direction = signf(player.velocity.x)
	elif player.body:
		roll_direction = -1.0 if player.body.scale.x < 0.0 else 1.0
	else:
		roll_direction = 1.0

	if player.body:
		player.body.scale.x = -1.0 if roll_direction < 0.0 else 1.0

	player.velocity.x = roll_direction * player.speed * roll_speed_multiplier

	if player.animated_sprite:
		player.animated_sprite.play("PlayerRoll")
		if not player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
			player.animated_sprite.animation_finished.connect(_on_roll_finished)

func exit() -> void:
	if player and player.animated_sprite:
		if player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
			player.animated_sprite.animation_finished.disconnect(_on_roll_finished)

func physics_update(_delta: float) -> void:
	if not player:
		return

	# Если ушли с края во время кувырка — обратно в воздух
	if not player.is_on_floor():
		state_machine.transition_to("JumpState")

func _on_roll_finished() -> void:
	if state_machine and state_machine.current_state == self:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0.0:
			state_machine.transition_to("RunState")
		else:
			state_machine.transition_to("IdleState")
