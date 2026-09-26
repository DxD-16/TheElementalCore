class_name RunState
extends State

func enter() -> void:
	if player and player.animated_sprite:
		player.animated_sprite.play("PlayerRun")

func physics_update(_delta: float) -> void:
	if player and not player.is_on_floor():
		state_machine.transition_to("JumpState")
		return

	if Input.is_action_just_pressed("Normal_Attack"):
		state_machine.transition_to("AttackState")
		return

	# Если игрок отпустил клавиши движения — возвращаемся в покой
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction == 0:
		state_machine.transition_to("IdleState")
