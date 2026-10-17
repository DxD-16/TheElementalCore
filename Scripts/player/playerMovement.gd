class_name Player
extends CharacterBody2D

@export_category("Movement Settings")
@export var speed: float = 300.0
@export var jump_velocity: float = -420.0

@export_category("Feel & Tuning")
@export var acceleration: float = 1000.0
@export var friction: float = 2000.0
@export var weight: float = 1.0

@export_category("Jump Tweaks")
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15
@export var jump_cut_multiplier: float = 0.5

@export_category("Double Jump")
@export var DoubleJumpAvailable: bool = false
## Сколько прыжков можно сделать в воздухе после coyote
@export var air_jumps: int = 1
## 1 = как обычный прыжок, 0.5 = половина силы
@export var air_jump_strength: float = 1.0

@export var attack_move_speed_multiplier: float = 0.85 # Скорость перемещения во время удара

## Неуязвимость персонажа (включается, например, во время рывка)
@export var is_invulnerable: bool = false

## Параметры здоровья и реакции на урон (из player.json > health)
var iframes_after_dmg: float = 0.2

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var remaining_air_jumps: int = 0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var max_fall_speed: float = 1200.0

## Таймер неуязвимости после получения урона
var _iframe_timer: float = 0.0
var _hit_stop_id: int = 0
var _hit_stop_active: bool = false
var _hit_stop_previous_scale: float = 1.0
var _squash_tween: Tween
var is_dead: bool = false
var controls_locked: bool = false
var status_effect_manager: StatusEffectManager = StatusEffectManager.new()
var weapon_controller: WeaponController

var jump_stretch_x: float = 0.94
var jump_stretch_y: float = 1.08
var landing_squash_x: float = 1.08
var landing_squash_y: float = 0.92
var squash_duration: float = 0.1
var squash_recovery_duration: float = 0.14

const HIT_STOP_DURATION: float = 0.2
const ATTACK_RECOIL_RATIO: float = 0.1
## Цвет цифр урона игрока — оранжевый #de9e41
const PLAYER_DAMAGE_COLOR := Color(0.871, 0.620, 0.255)

@onready var body: Node2D = $Body
@onready var animated_sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var inventory_data: InventoryData
@export var starting_weapon: WeaponData = preload("res://Resources/Weapons/light_sword.tres")

var _dash_collision_shape: CapsuleShape2D
var _standing_collision_height: float = 0.0
var _standing_collision_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("Player")
	if inventory_data == null:
		inventory_data = get_node_or_null("InventoryData") as InventoryData
	status_effect_manager = StatusEffectManager.new()
	weapon_controller = WeaponController.new()
	weapon_controller.source = self
	weapon_controller.name = "WeaponController"
	add_child(weapon_controller)
	if not weapon_controller.equip_weapon(starting_weapon):
		push_error("Player could not equip its starting weapon")
	if inventory_data and not inventory_data.equipment_changed.is_connected(_on_equipment_changed):
		inventory_data.equipment_changed.connect(_on_equipment_changed)
	_sync_equipped_weapon()
	_cache_dash_collision_shape()
	_load_config()
	_setup_dash_input()

	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)

func _cache_dash_collision_shape() -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape2D:
		push_warning("Player collision shape must be a CapsuleShape2D to reduce it during a dash")
		return

	_dash_collision_shape = (collision_shape.shape as CapsuleShape2D).duplicate() as CapsuleShape2D
	collision_shape.shape = _dash_collision_shape
	_standing_collision_height = _dash_collision_shape.height
	_standing_collision_position = collision_shape.position

func set_dash_hitbox_reduced(reduced: bool) -> void:
	if not _dash_collision_shape:
		return

	if reduced:
		_dash_collision_shape.height = _standing_collision_height * 0.5
		collision_shape.position = _standing_collision_position + Vector2(
			0.0, (_standing_collision_height - _dash_collision_shape.height) * 0.5
		)
	else:
		_dash_collision_shape.height = _standing_collision_height
		collision_shape.position = _standing_collision_position

func _exit_tree() -> void:
	if _hit_stop_active:
		Engine.time_scale = _hit_stop_previous_scale
		_hit_stop_active = false
		_hit_stop_id += 1

func _load_config() -> void:
	if ConfigManager:
		gravity = ConfigManager.get_float("physics", "gravity", gravity)
		var configured_max_fall_speed := ConfigManager.get_float("physics", "max_fall_speed", max_fall_speed)
		if configured_max_fall_speed > 0.0:
			max_fall_speed = configured_max_fall_speed
		else:
			push_warning("physics.max_fall_speed must be greater than zero; using %.1f" % max_fall_speed)
		speed = ConfigManager.get_float("player", "movement.speed", speed)
		jump_velocity = ConfigManager.get_float("player", "movement.jump_velocity", jump_velocity)
		acceleration = ConfigManager.get_float("player", "movement.acceleration", acceleration)
		friction = ConfigManager.get_float("player", "movement.friction", friction)
		var configured_weight := ConfigManager.get_float("player", "combat.weight", weight)
		if configured_weight > 0.0:
			weight = configured_weight
		else:
			push_warning("player.combat.weight must be greater than zero; using %.2f" % weight)
		coyote_time = ConfigManager.get_float("player", "movement.coyote_time", coyote_time)
		jump_buffer_time = ConfigManager.get_float("player", "movement.jump_buffer_time", jump_buffer_time)
		jump_cut_multiplier = ConfigManager.get_float("player", "movement.jump_cut_multiplier", jump_cut_multiplier)
		DoubleJumpAvailable = ConfigManager.get_bool("player", "movement.double_jump_available", DoubleJumpAvailable)
		air_jumps = ConfigManager.get_int("player", "movement.air_jumps", air_jumps)
		air_jump_strength = ConfigManager.get_float("player", "movement.air_jump_strength", air_jump_strength)
		attack_move_speed_multiplier = ConfigManager.get_float("player", "movement.attack_move_speed_multiplier", attack_move_speed_multiplier)
		jump_stretch_x = ConfigManager.get_float("player", "visuals.jump_stretch_x", jump_stretch_x)
		jump_stretch_y = ConfigManager.get_float("player", "visuals.jump_stretch_y", jump_stretch_y)
		landing_squash_x = ConfigManager.get_float("player", "visuals.landing_squash_x", landing_squash_x)
		landing_squash_y = ConfigManager.get_float("player", "visuals.landing_squash_y", landing_squash_y)
		squash_duration = ConfigManager.get_float("player", "visuals.squash_duration", squash_duration)
		squash_recovery_duration = ConfigManager.get_float("player", "visuals.squash_recovery_duration", squash_recovery_duration)
		# Параметры здоровья
		iframes_after_dmg = ConfigManager.get_float("player", "health.iframes_after_dmg", iframes_after_dmg)
		# Загружаем max_health и применяем к HealthComponent
		var max_hp: int = ConfigManager.get_int("player", "health.max_health", 200)
		var hc := get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.max_health = max_hp
			hc.current_health = max_hp

func _setup_dash_input() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)

func _process(delta: float) -> void:
	# Тикаем таймер i-frames
	if _iframe_timer > 0.0:
		_iframe_timer -= delta

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	is_invulnerable = true
	velocity = Vector2.ZERO

	if state_machine and not state_machine.current_state is DeathState:
		state_machine.transition_to("DeathState")

func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, knockback: Vector2 = Vector2.ZERO) -> void:
	# Неуязвимость во время рывка или i-frames после урона
	if is_invulnerable or _iframe_timer > 0.0:
		return
	if knockback.length() > 0.0:
		velocity += knockback
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.take_damage(amount)
	# Запустить i-frames
	_iframe_timer = iframes_after_dmg
	CombatPresentation.show_hit(self, amount, hit_pos, PLAYER_DAMAGE_COLOR)
	if amount > 0:
		_start_hit_stop()

func apply_attack_recoil(attack_direction: float, knockback_strength: float) -> void:
	if is_dead or not is_finite(attack_direction) or not is_finite(knockback_strength):
		return
	var safe_weight := weight if is_finite(weight) and weight > 0.0 else 1.0
	var recoil_strength := maxf(knockback_strength, 0.0) * ATTACK_RECOIL_RATIO / safe_weight
	velocity.x -= signf(attack_direction) * recoil_strength

func _start_hit_stop() -> void:
	if not _hit_stop_active:
		_hit_stop_previous_scale = Engine.time_scale
		_hit_stop_active = true

	_hit_stop_id += 1
	Engine.time_scale = 0.0
	_finish_hit_stop_after_delay(_hit_stop_id)

func _finish_hit_stop_after_delay(hit_stop_id: int) -> void:
	await get_tree().create_timer(HIT_STOP_DURATION, true, false, true).timeout
	if hit_stop_id != _hit_stop_id:
		return

	Engine.time_scale = _hit_stop_previous_scale
	_hit_stop_active = false

func play_squash(scale_x: float, scale_y: float) -> void:
	if not body:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()

	var facing := -1.0 if body.scale.x < 0.0 else 1.0
	_squash_tween = create_tween()
	_squash_tween.tween_property(
		body,
		"scale",
		Vector2(facing * scale_x, scale_y),
		squash_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(
		body,
		"scale",
		Vector2(facing, 1.0),
		squash_recovery_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if controls_locked:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
		return

	var is_attacking: bool = state_machine and state_machine.current_state is AttackState
	var is_rolling: bool = state_machine and state_machine.current_state is RollState
	var is_landing_rolling: bool = state_machine and state_machine.current_state is LandingRollState
	var is_landing: bool = (
		state_machine
		and state_machine.current_state is JumpState
		and (state_machine.current_state as JumpState).is_landing()
	)

	# Графика, койот-тайм и заряд воздушных прыжков
	if is_on_floor():
		coyote_timer = coyote_time
		remaining_air_jumps = air_jumps
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		coyote_timer -= delta

	# Буфер прыжка (блокируется во время атаки / кувырка / приземления)
	if not is_attacking and not is_rolling and not is_landing_rolling and not is_landing and Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	var jump_locked := is_rolling or is_landing_rolling or is_landing
	if jump_buffer_timer > 0 and not jump_locked:
		if coyote_timer > 0:
			velocity.y = jump_velocity
			play_squash(jump_stretch_x, jump_stretch_y)
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif DoubleJumpAvailable and remaining_air_jumps > 0:
			velocity.y = jump_velocity * air_jump_strength
			play_squash(jump_stretch_x, jump_stretch_y)
			jump_buffer_timer = 0.0
			remaining_air_jumps -= 1

	if Input.is_action_just_released("ui_up") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

	# Горизонтальное движение
	if is_rolling:
		var roll := state_machine.current_state as RollState
		velocity.x = roll.roll_direction * roll.current_roll_speed
	elif is_landing_rolling:
		var landing_roll := state_machine.current_state as LandingRollState
		velocity.x = landing_roll.roll_speed
	elif is_landing:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:
			var target_speed = speed * attack_move_speed_multiplier if is_attacking else speed
			velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
			body.scale.x = absf(body.scale.x) * (-1.0 if direction < 0 else 1.0)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()

func set_controls_locked(locked: bool) -> void:
	if controls_locked == locked:
		return

	controls_locked = locked
	jump_buffer_timer = 0.0
	velocity.x = 0.0
	if state_machine and not is_dead:
		state_machine.transition_to("IdleState" if is_on_floor() else "JumpState")

func get_weapon_controller() -> WeaponController:
	return weapon_controller

func equip_weapon(weapon: WeaponData) -> bool:
	if weapon_controller == null:
		push_error("Player cannot equip a weapon before its WeaponController is ready")
		return false
	return weapon_controller.equip_weapon(weapon)

func _on_equipment_changed() -> void:
	_sync_equipped_weapon()

func _sync_equipped_weapon() -> void:
	if weapon_controller == null:
		return
	var weapon_item: ItemData
	if inventory_data:
		weapon_item = inventory_data.backup_weapon if inventory_data.active_weapon_slot == "backup" else inventory_data.primary_weapon
	var weapon := weapon_item.weapon_definition if weapon_item else starting_weapon
	if weapon != null and (
		weapon_controller.weapon_data == null or weapon_controller.weapon_data.id != weapon.id
	) and not weapon_controller.equip_weapon(weapon):
		push_warning("Player could not switch to the selected equipped weapon")

func has_status(effect_id: String) -> bool:
	return status_effect_manager != null and status_effect_manager.has_effect(effect_id)

func is_controls_locked() -> bool:
	return controls_locked

func can_perform_action(action_name: String) -> bool:
	var gate := ActionGate.new()
	return gate.can_perform_action(self, action_name)
