class_name DeathState
extends State

var _is_finished: bool = false

func enter() -> void:
	_is_finished = false
	if not player:
		_finish_death()
		return

	player.is_invulnerable = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_process_shortcut_input(false)

	if player.animated_sprite:
		if player.animated_sprite.animation_finished.is_connected(_on_animation_finished):
			player.animated_sprite.animation_finished.disconnect(_on_animation_finished)

		var frames := player.animated_sprite.sprite_frames
		if frames and frames.has_animation("PlayerDeath"):
			player.animated_sprite.play("PlayerDeath")
			player.animated_sprite.animation_finished.connect(_on_animation_finished)
			return

	_finish_death()

func _on_animation_finished() -> void:
	if player and player.animated_sprite and player.animated_sprite.animation_finished.is_connected(_on_animation_finished):
		player.animated_sprite.animation_finished.disconnect(_on_animation_finished)
	_finish_death()

func _finish_death() -> void:
	if _is_finished:
		return
	_is_finished = true

	if player:
		if player.body:
			player.body.visible = false
		if player.animated_sprite:
			player.animated_sprite.visible = false
		player.visible = false
		player.set_physics_process(false)
		player.set_process(false)
