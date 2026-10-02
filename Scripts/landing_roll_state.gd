class_name LandingRollState
extends State

var inherited_velocity_x: float = 0.0
var roll_speed: float = 0.0

func enter() -> void:
	if not player:
		return

	roll_speed = inherited_velocity_x
	player.velocity.x = roll_speed
	player.is_invulnerable = true

	if player.body:
		player.body.scale.x = -absf(player.body.scale.x) if roll_speed < 0.0 else absf(player.body.scale.x)

	if player.animated_sprite:
		player.animated_sprite.play("PlayerRoll")
		if not player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
			player.animated_sprite.animation_finished.connect(_on_roll_finished)

func exit() -> void:
	if player:
		player.is_invulnerable = false
		if player.animated_sprite and player.animated_sprite.animation_finished.is_connected(_on_roll_finished):
			player.animated_sprite.animation_finished.disconnect(_on_roll_finished)

func _on_roll_finished() -> void:
	if not state_machine or state_machine.current_state != self:
		return

	if not player.is_on_floor():
		state_machine.transition_to("JumpState")
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		state_machine.transition_to("RunState")
	else:
		state_machine.transition_to("IdleState")