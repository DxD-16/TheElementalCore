class_name AttackState
extends State

@export var attack_duration: float = 0.3



func enter() -> void:
	if player:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction == 0:
			player.velocity.x = 0.0
		if player.animated_sprite:
			play_combo_animation(0)
	
	var fists = get_fists()
	if fists and fists.has_method("execute_attack"):
		if not fists.attack_finished.is_connected(_on_fists_attack_finished):
			fists.attack_finished.connect(_on_fists_attack_finished)
		if not fists.attack_step_started.is_connected(_on_attack_step_started):
			fists.attack_step_started.connect(_on_attack_step_started)
		fists.execute_attack()
	else:
		await get_tree().create_timer(attack_duration).timeout
		_on_fists_attack_finished()

func _on_attack_step_started(step: int) -> void:
	if player and player.animated_sprite:
		play_combo_animation(step)

func play_combo_animation(step: int) -> void:
	if not player or not player.animated_sprite:
		return
	var anim_name := "PlayerAttack_" + str(step + 1)
	var frames := player.animated_sprite.sprite_frames
	if frames and frames.has_animation(anim_name):
		player.animated_sprite.play(anim_name)
	else:
		# Fallback на первый удар если анимация не найдена
		player.animated_sprite.play("PlayerAttack_1")

func _on_fists_attack_finished() -> void:
	if state_machine and state_machine.current_state == self:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:
			state_machine.transition_to("RunState")
		else:
			state_machine.transition_to("IdleState")

func exit() -> void:
	var fists = get_fists()
	if fists:
		if fists.attack_finished.is_connected(_on_fists_attack_finished):
			fists.attack_finished.disconnect(_on_fists_attack_finished)
		if fists.attack_step_started.is_connected(_on_attack_step_started):
			fists.attack_step_started.disconnect(_on_attack_step_started)

func update(_delta: float) -> void:
	# Буферизация следующего удара комбо во время текущего
	if Input.is_action_just_pressed("Normal_Attack"):
		var fists = get_fists()
		if fists:
			fists.next_attack_buffered = true

func physics_update(_delta: float) -> void:
	# Физика обрабатывается в playerMovement.gd
	pass

func get_fists() -> Node2D:
	if not player:
		return null
	return player.get_node_or_null("Body/WeaponManager/Fists")
