class_name AirDashState
extends State

var direction: float = 0.0
var elapsed: float = 0.0

func enter() -> void:
	elapsed = 0.0
	direction = player.air_dash_direction if player else 0.0
	if player and player.animated_sprite:
		player.animated_sprite.play("PlayerDash")

func physics_update(delta: float) -> void:
	if not player:
		return

	if player.is_on_floor():
		state_machine.transition_to("RunState" if Input.get_axis("ui_left", "ui_right") != 0.0 else "IdleState")
		return

	if not player.can_perform_action("dash"):
		state_machine.transition_to("JumpState")
		return

	elapsed += delta
	var duration := maxf(player.air_dash_duration, 0.001)
	var movement_multiplier := player.get_status_multiplier("movement_speed")
	player.velocity.x = direction * maxf(player.air_dash_speed, 0.0) * movement_multiplier
	player.velocity.y = 0.0

	if elapsed >= duration:
		state_machine.transition_to("JumpState")
