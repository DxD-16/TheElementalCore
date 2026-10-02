class_name AttackState
extends State

@export var attack_duration: float = 0.3

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		attack_duration = ConfigManager.get_float("player", "states.attack.attack_duration", attack_duration)

func enter() -> void:
	if player:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction == 0:
			player.velocity.x = 0.0

	var fists = get_fists()
	if fists and fists.has_method("execute_attack"):
		if not fists.attack_finished.is_connected(_on_fists_attack_finished):
			fists.attack_finished.connect(_on_fists_attack_finished)
		if not fists.attack_step_started.is_connected(_on_attack_step_started):
			fists.attack_step_started.connect(_on_attack_step_started)
		fists.execute_attack()
	else:
		if player and player.animated_sprite:
			play_combo_animation(0)
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
	if not frames or not frames.has_animation(anim_name):
		anim_name = "PlayerAttack_1"
		if not frames or not frames.has_animation(anim_name):
			return

	var anim_speed := calculate_attack_anim_speed(anim_name, step)
	player.animated_sprite.play(anim_name, anim_speed)

func calculate_attack_anim_speed(anim_name: String, step: int) -> float:
	var fists = get_fists()
	if not fists:
		return 1.0

	var attack_spd: float = fists.attack_speed if ("attack_speed" in fists and fists.attack_speed > 0.001) else 1.0

	# Синхронизируем длительность анимации с временем текущего шага атаки
	if "attack_time_list" in fists and step >= 0 and step < fists.attack_time_list.size():
		var target_time: float = fists.attack_time_list[step] / attack_spd
		if target_time > 0.0 and player and player.animated_sprite and player.animated_sprite.sprite_frames:
			var frames: SpriteFrames = player.animated_sprite.sprite_frames
			var count := frames.get_frame_count(anim_name)
			var base_fps := frames.get_animation_speed(anim_name)
			if count > 0 and base_fps > 0.0:
				var natural_duration := float(count) / base_fps
				return natural_duration / target_time

	return attack_spd

func _on_fists_attack_finished() -> void:
	if state_machine and state_machine.current_state == self:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:
			state_machine.transition_to("RunState")
		else:
			state_machine.transition_to("IdleState")

func exit() -> void:
	if player and player.animated_sprite:
		player.animated_sprite.speed_scale = 1.0

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
