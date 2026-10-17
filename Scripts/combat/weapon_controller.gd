class_name WeaponController
extends Node

signal attack_started(step_name: String, step_index: int)
signal attack_step_started(step_index: int)
signal attack_finished

@export var attack_area_path: NodePath = ^"Body/WeaponManager/WeaponHitboxes/AttackArea"
@export var weapon_visual_root_path: NodePath = ^"Body/WeaponManager"

var weapon_data: WeaponData
var runtime: WeaponRuntime
var source: Node
var attack_area: Area2D
var weapon_visual_root: Node2D
var weapon_visual_instance: Node
var hit_shapes: Array[CollisionShape2D] = []
var combo_reset_time: float = 1.0
var combo_reset_timer: float = 0.0
var hit_targets: Array[Node2D] = []
var attack_elapsed: float = 0.0
var attack_duration: float = 0.0
var pending_weapon_data: WeaponData

func _ready() -> void:
	if source == null:
		push_error("WeaponController requires a source actor")
		return

	attack_area = source.get_node_or_null(attack_area_path) as Area2D
	if attack_area == null:
		push_error("WeaponController could not find the weapon AttackArea")
		return

	weapon_visual_root = source.get_node_or_null(weapon_visual_root_path) as Node2D
	if weapon_visual_root == null:
		push_error("WeaponController could not find the weapon visual root")
		return

	for child in attack_area.get_children():
		if child is CollisionShape2D:
			hit_shapes.append(child as CollisionShape2D)
	disable_all_hitboxes()
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	if pending_weapon_data:
		var initial_weapon := pending_weapon_data
		pending_weapon_data = null
		if not equip_weapon(initial_weapon):
			push_error("WeaponController could not equip its configured weapon")

func configure(p_weapon_data: WeaponData, p_source: Node = null) -> bool:
	if p_source != null:
		source = p_source
	if p_weapon_data == null:
		push_error("WeaponController cannot be configured without a weapon definition")
		return false
	if not is_node_ready():
		if not _validate_weapon(p_weapon_data):
			return false
		pending_weapon_data = p_weapon_data
		return true
	return equip_weapon(p_weapon_data)

func equip_weapon(p_weapon_data: WeaponData) -> bool:
	if p_weapon_data == null:
		push_error("WeaponController cannot equip a null weapon definition")
		return false
	if runtime and runtime.is_attacking:
		return false
	if attack_area == null or weapon_visual_root == null:
		push_error("WeaponController is not ready to equip a weapon")
		return false

	var runtime_weapon := _make_runtime_weapon_data(p_weapon_data)
	if not _validate_weapon(runtime_weapon):
		return false

	disable_all_hitboxes()
	_clear_attack_hitboxes()
	if weapon_visual_instance and is_instance_valid(weapon_visual_instance):
		weapon_visual_instance.queue_free()
		weapon_visual_instance = null

	weapon_data = runtime_weapon
	combo_reset_time = weapon_data.combo_reset_time
	combo_reset_timer = 0.0
	hit_targets.clear()
	attack_elapsed = 0.0
	attack_duration = 0.0
	runtime = WeaponRuntime.new(weapon_data)
	if weapon_data.weapon_scene:
		weapon_visual_instance = weapon_data.weapon_scene.instantiate()
		weapon_visual_instance.name = "EquippedWeapon"
		weapon_visual_root.add_child(weapon_visual_instance)
	_configure_attack_hitboxes(weapon_data.get_attack_step(0))
	return true

func _make_runtime_weapon_data(definition: WeaponData) -> WeaponData:
	var runtime_weapon := definition.duplicate() as WeaponData
	var runtime_attacks: Array[AttackDefinition] = []
	for attack in definition.attacks:
		runtime_attacks.append(attack.duplicate() as AttackDefinition)
	runtime_weapon.attacks = runtime_attacks

	var config_manager := get_node_or_null("/root/ConfigManager")
	if config_manager == null:
		return runtime_weapon
	var config: Variant = config_manager.call("get_value", "weapons", definition.id, {})
	if not config is Dictionary:
		return runtime_weapon

	runtime_weapon.base_attack_speed = _get_config_float(
		config_manager, "%s.attack_speed" % definition.id, runtime_weapon.base_attack_speed
	)
	runtime_weapon.combo_reset_time = maxf(
		_get_config_float(config_manager, "%s.combo_reset_time" % definition.id, runtime_weapon.combo_reset_time),
		0.0
	)
	var damage_values := _get_config_array(config_manager, "%s.damage_list" % definition.id)
	var knockback_values := _get_config_array(config_manager, "%s.knockback_list" % definition.id)
	var duration_values := _get_config_array(config_manager, "%s.attack_time_list" % definition.id)
	var element_charge_values := _get_config_array(config_manager, "%s.element_charge_list" % definition.id)
	for index in range(runtime_weapon.attacks.size()):
		var attack := runtime_weapon.attacks[index]
		if index < damage_values.size() and (damage_values[index] is int or damage_values[index] is float):
			var damage_value := float(damage_values[index])
			if is_finite(damage_value):
				attack.damage = maxi(int(damage_value), 0)
		if index < knockback_values.size() and (knockback_values[index] is int or knockback_values[index] is float):
			var knockback_value := float(knockback_values[index])
			if is_finite(knockback_value):
				attack.knockback = maxf(knockback_value, 0.0)
		if index < duration_values.size() and (duration_values[index] is int or duration_values[index] is float):
			var duration_value := float(duration_values[index])
			if is_finite(duration_value) and duration_value > 0.0:
				attack.duration = duration_value
		var has_element_charge := (
			index < element_charge_values.size()
			and (element_charge_values[index] is int or element_charge_values[index] is float)
		)
		if has_element_charge:
			var charge_value := float(element_charge_values[index])
			if is_finite(charge_value):
				attack.element_charge = maxf(charge_value, 0.0)
	return runtime_weapon

func _get_config_float(config_manager: Node, path: String, fallback: float) -> float:
	var value: Variant = config_manager.call("get_float", "weapons", path, fallback)
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback

func _get_config_array(config_manager: Node, path: String) -> Array:
	var value: Variant = config_manager.call("get_array", "weapons", path, [])
	if value is Array:
		return value
	return []

func _validate_weapon(weapon: WeaponData) -> bool:
	if weapon.attacks.is_empty():
		push_error("Weapon '%s' must define at least one attack" % weapon.id)
		return false
	if not is_finite(weapon.base_attack_speed) or weapon.base_attack_speed <= 0.001:
		push_error("Weapon '%s' must have a positive attack speed" % weapon.id)
		return false
	if not is_finite(weapon.combo_reset_time) or weapon.combo_reset_time < 0.0:
		push_error("Weapon '%s' must have a non-negative combo reset time" % weapon.id)
		return false
	for attack_index in range(weapon.attacks.size()):
		var attack := weapon.attacks[attack_index]
		if attack == null or not is_finite(attack.duration) or attack.duration <= 0.0:
			push_error("Weapon '%s' attack %d must have a positive duration" % [weapon.id, attack_index + 1])
			return false
		var invalid_combat_values := (
			attack.damage < 0
			or not is_finite(attack.knockback)
			or attack.knockback < 0.0
			or not is_finite(attack.element_charge)
			or attack.element_charge < 0.0
		)
		if invalid_combat_values:
			push_error("Weapon '%s' attack %d has invalid combat values" % [weapon.id, attack_index + 1])
			return false
		if attack.hitboxes.is_empty():
			push_error("Weapon '%s' attack %d must define at least one hitbox" % [weapon.id, attack_index + 1])
			return false
		for zone_index in range(attack.hitboxes.size()):
			var zone := attack.hitboxes[zone_index]
			if zone == null or zone.shape == null:
				push_error("Weapon '%s' attack %d hitbox %d must define a shape" % [weapon.id, attack_index + 1, zone_index + 1])
				return false
			if not is_finite(zone.offset.x) or not is_finite(zone.offset.y) or not is_finite(zone.rotation_degrees):
				push_error("Weapon '%s' attack %d hitbox %d has an invalid transform" % [weapon.id, attack_index + 1, zone_index + 1])
				return false
			var invalid_window := (
				not is_finite(zone.active_start_ratio)
				or not is_finite(zone.active_end_ratio)
				or zone.active_start_ratio < 0.0
				or zone.active_end_ratio > 1.0
				or zone.active_start_ratio > zone.active_end_ratio
			)
			if invalid_window:
				push_error("Weapon '%s' attack %d hitbox %d has an invalid active window" % [weapon.id, attack_index + 1, zone_index + 1])
				return false
	return true

func _clear_attack_hitboxes() -> void:
	for hit_shape in hit_shapes:
		hit_shape.set_deferred("disabled", true)
		hit_shape.queue_free()
	hit_shapes.clear()

func _configure_attack_hitboxes(attack: AttackDefinition) -> void:
	_clear_attack_hitboxes()
	if attack == null or attack_area == null:
		return
	for index in range(attack.hitboxes.size()):
		var definition := attack.hitboxes[index]
		var hit_shape := CollisionShape2D.new()
		hit_shape.name = "Hitbox_%d" % (index + 1)
		hit_shape.shape = definition.shape
		hit_shape.position = definition.offset
		hit_shape.rotation_degrees = definition.rotation_degrees
		hit_shape.disabled = true
		attack_area.add_child(hit_shape)
		hit_shapes.append(hit_shape)

func _process(delta: float) -> void:
	if runtime == null:
		return
	if runtime.is_attacking:
		attack_elapsed += delta
		runtime.attack_timer = maxf(attack_duration - attack_elapsed, 0.0)
		var progress := clampf(attack_elapsed / attack_duration, 0.0, 1.0)
		_update_hitbox_activity(weapon_data.get_attack_step(runtime.combo_index), progress)
		if runtime.attack_timer <= 0.0:
			_finish_attack_step()
	elif combo_reset_timer > 0.0:
		combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
		if combo_reset_timer == 0.0:
			runtime.reset_combo()

func start_attack() -> bool:
	if runtime == null or runtime.is_attacking:
		return false
	if source and source.has_method("can_perform_action") and not source.can_perform_action("attack"):
		return false
	return _begin_attack_step()

func _begin_attack_step() -> bool:
	var step := get_current_attack()
	if step == null:
		return false

	var step_index := runtime.combo_index
	combo_reset_timer = 0.0
	runtime.is_attacking = true
	runtime.next_attack_buffered = false
	var attack_speed := weapon_data.base_attack_speed
	attack_duration = step.duration / attack_speed
	attack_elapsed = 0.0
	runtime.attack_timer = attack_duration
	hit_targets.clear()
	_configure_attack_hitboxes(step)
	disable_all_hitboxes()
	_update_hitbox_activity(step, 0.0)
	attack_started.emit(step.attack_name, step_index)
	attack_step_started.emit(step_index)
	return true

func _finish_attack_step() -> void:
	disable_all_hitboxes()
	runtime.is_attacking = false
	runtime.attack_timer = 0.0
	attack_elapsed = 0.0
	attack_duration = 0.0
	hit_targets.clear()
	runtime.advance_combo()

	if runtime.next_attack_buffered and runtime.combo_index > 0:
		if _begin_attack_step():
			return

	runtime.next_attack_buffered = false
	combo_reset_timer = combo_reset_time if runtime.combo_index > 0 else 0.0
	attack_finished.emit()

func finish_attack() -> void:
	if runtime and runtime.is_attacking:
		_finish_attack_step()

func cancel_attack() -> void:
	if runtime == null or not runtime.is_attacking:
		return
	disable_all_hitboxes()
	runtime.reset_combo()
	combo_reset_timer = 0.0
	attack_elapsed = 0.0
	attack_duration = 0.0
	hit_targets.clear()

func buffer_next_attack() -> void:
	if runtime and runtime.is_attacking:
		runtime.next_attack_buffered = true

func get_current_attack() -> AttackDefinition:
	if runtime == null:
		return null
	return runtime.get_attack_step()

func get_weapon_data() -> WeaponData:
	return weapon_data

func disable_all_hitboxes() -> void:
	for hit_shape in hit_shapes:
		hit_shape.set_deferred("disabled", true)

func _update_hitbox_activity(attack: AttackDefinition, progress: float) -> void:
	if attack == null:
		disable_all_hitboxes()
		return
	for index in range(mini(hit_shapes.size(), attack.hitboxes.size())):
		var definition := attack.hitboxes[index]
		var active := progress >= definition.active_start_ratio and progress <= definition.active_end_ratio
		if hit_shapes[index].disabled == active:
			hit_shapes[index].set_deferred("disabled", not active)

func _on_attack_area_body_entered(target: Node2D) -> void:
	if runtime == null or not runtime.is_attacking or target == source or target in hit_targets:
		return
	hit_targets.append(target)
	if not target.has_method("take_damage"):
		return

	var step := get_current_attack()
	if step == null:
		return
	var hit_position := _get_attack_hit_position(target)

	var knockback_strength := step.knockback
	var knockback_direction := Vector2.ZERO
	var source_direction := 1.0
	if knockback_strength > 0.0 and source != null:
		if source.has_method("get_global_position"):
			var source_facing := 1.0
			if source.has_node("Body"):
				var body := source.get_node("Body") as Node2D
				if body and body.scale.x < 0.0:
					source_facing = -1.0
			if source.has_method("get_facing_direction"):
				source_facing = source.get_facing_direction()
			source_direction = source_facing
		var aim := Vector2(source_direction, -0.1)
		knockback_direction = aim.normalized() * knockback_strength

	var damage := maxi(step.damage, 0)
	var element := weapon_data.element if step.element < 0 else step.element
	var element_charge := maxf(step.element_charge, 0.0)
	if target.has_method("apply_elemental_hit"):
		target.apply_elemental_hit(damage, hit_position, element, element_charge, knockback_direction, source)
	else:
		target.take_damage(damage, hit_position, knockback_direction)
	if knockback_strength > 0.0 and source != null and source.has_method("apply_attack_recoil"):
		source.apply_attack_recoil(source_direction, knockback_strength)

func _get_hit_position(target: Node2D, hit_shape: CollisionShape2D) -> Vector2:
	if hit_shape == null or hit_shape.shape == null:
		return target.global_position

	var contact_points := _get_hit_contacts(hit_shape)
	if contact_points.size() < 2:
		return target.global_position

	var best_position := target.global_position
	var best_distance := INF
	for i in range(0, contact_points.size() - 1, 2):
		var contact_position: Vector2 = (contact_points[i] + contact_points[i + 1]) * 0.5
		var distance := contact_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best_position = contact_position
	return best_position

func _get_hit_contacts(hit_shape: CollisionShape2D) -> PackedVector2Array:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hit_shape.shape
	query.transform = hit_shape.global_transform
	query.collision_mask = attack_area.collision_mask
	if source is CollisionObject2D:
		query.exclude = [source.get_rid()]
	return attack_area.get_world_2d().direct_space_state.collide_shape(query, 32)

func _get_attack_hit_position(target: Node2D) -> Vector2:
	var best_position := target.global_position
	var best_distance := INF
	for hit_shape in hit_shapes:
		if hit_shape.disabled:
			continue
		var contact_points := _get_hit_contacts(hit_shape)
		for index in range(0, contact_points.size() - 1, 2):
			var contact_position: Vector2 = (contact_points[index] + contact_points[index + 1]) * 0.5
			var distance := contact_position.distance_squared_to(target.global_position)
			if distance < best_distance:
				best_distance = distance
				best_position = contact_position
	return best_position
