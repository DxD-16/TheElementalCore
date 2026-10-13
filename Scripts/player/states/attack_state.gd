class_name AttackState
extends State

var weapon_controller: WeaponController

func enter() -> void:
	if not player:
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction == 0:
		player.velocity.x = 0.0

	weapon_controller = player.get_weapon_controller()
	if weapon_controller == null:
		push_error("AttackState could not find the player's WeaponController")
		call_deferred("_return_to_movement_state")
		return

	if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.connect(_on_attack_finished)
	if not weapon_controller.attack_step_started.is_connected(_on_attack_step_started):
		weapon_controller.attack_step_started.connect(_on_attack_step_started)

	if not weapon_controller.start_attack():
		call_deferred("_return_to_movement_state")

func _on_attack_step_started(step: int) -> void:
	if not player or not player.animated_sprite or weapon_controller == null:
		return

	var frames := player.animated_sprite.sprite_frames
	var anim_name := "PlayerAttack_%d" % (step + 1)
	if frames == null or not frames.has_animation(anim_name):
		anim_name = "PlayerAttack_1"
		if frames == null or not frames.has_animation(anim_name):
			return

	var step_data := weapon_controller.get_current_attack()
	if weapon_controller.weapon_data == null:
		return
	var attack_speed := weapon_controller.weapon_data.base_attack_speed
	var target_duration := float(step_data.get("time", 0.4)) / attack_speed
	var frame_count := frames.get_frame_count(anim_name)
	var animation_fps := frames.get_animation_speed(anim_name)
	var animation_speed := attack_speed
	if frame_count > 0 and animation_fps > 0.0 and target_duration > 0.0:
		animation_speed = (float(frame_count) / animation_fps) / target_duration
	player.animated_sprite.play(anim_name, animation_speed)

func _on_attack_finished() -> void:
	if not state_machine or state_machine.current_state != self:
		return

	if player and not player.is_on_floor():
		state_machine.transition_to("JumpState")
		return

	if Input.get_axis("ui_left", "ui_right") != 0:
		state_machine.transition_to("RunState")
	else:
		state_machine.transition_to("IdleState")

func _return_to_movement_state() -> void:
	if not state_machine or state_machine.current_state != self:
		return
	if player and not player.is_on_floor():
		state_machine.transition_to("JumpState")
	elif Input.get_axis("ui_left", "ui_right") != 0:
		state_machine.transition_to("RunState")
	else:
		state_machine.transition_to("IdleState")

func exit() -> void:
	if player and player.animated_sprite:
		player.animated_sprite.speed_scale = 1.0
	if weapon_controller:
		weapon_controller.cancel_attack()
		if weapon_controller.attack_finished.is_connected(_on_attack_finished):
			weapon_controller.attack_finished.disconnect(_on_attack_finished)
		if weapon_controller.attack_step_started.is_connected(_on_attack_step_started):
			weapon_controller.attack_step_started.disconnect(_on_attack_step_started)

func update(_delta: float) -> void:
	if Input.is_action_just_pressed("Normal_Attack") and weapon_controller:
		weapon_controller.buffer_next_attack()

func physics_update(_delta: float) -> void:
	pass
