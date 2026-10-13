class_name WeaponController
extends Node

signal attack_started(step_name: String, step_index: int)
signal attack_step_started(step_index: int)
signal attack_finished

const DEFAULT_DAMAGE := [10, 18, 20, 40]
const DEFAULT_KNOCKBACK := [100.0, 150.0, 200.0, 400.0]
const DEFAULT_ATTACK_TIME := [0.4, 0.4, 0.4, 0.4]

@export var weapon_config_id: String = "fists"
@export var attack_area_path: NodePath = ^"Body/WeaponManager/WeaponHitboxes/AttackArea"

var weapon_data: WeaponData
var runtime: WeaponRuntime
var source: Node
var attack_area: Area2D
var hit_shapes: Array[CollisionShape2D] = []
var combo_reset_time: float = 1.0
var combo_reset_timer: float = 0.0
var hit_targets: Array[Node2D] = []

func _ready() -> void:
	if source == null:
		push_error("WeaponController requires a source actor")
		return

	attack_area = source.get_node_or_null(attack_area_path) as Area2D
	if attack_area == null:
		push_error("WeaponController could not find the weapon AttackArea")
		return

	for child in attack_area.get_children():
		if child is CollisionShape2D:
			hit_shapes.append(child as CollisionShape2D)
	disable_all_hitboxes()
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	if weapon_data == null:
		_load_weapon_data()

func configure(p_weapon_data: WeaponData, p_source: Node = null) -> void:
	if p_weapon_data == null:
		push_error("WeaponController cannot be configured without weapon data")
		return
	weapon_data = p_weapon_data
	runtime = WeaponRuntime.new(weapon_data)
	if p_source != null:
		source = p_source

func _load_weapon_data() -> void:
	var attack_speed := 1.0
	var damage_values: Array = DEFAULT_DAMAGE.duplicate()
	var knockback_values: Array = DEFAULT_KNOCKBACK.duplicate()
	var attack_times: Array = DEFAULT_ATTACK_TIME.duplicate()

	if ConfigManager:
		combo_reset_time = maxf(ConfigManager.get_float("weapons", "%s.combo_reset_time" % weapon_config_id, combo_reset_time), 0.0)
		attack_speed = ConfigManager.get_float("weapons", "%s.attack_speed" % weapon_config_id, attack_speed)
		damage_values = ConfigManager.get_array("weapons", "%s.damage_list" % weapon_config_id, damage_values)
		knockback_values = ConfigManager.get_array("weapons", "%s.knockback_list" % weapon_config_id, knockback_values)
		attack_times = ConfigManager.get_array("weapons", "%s.attack_time_list" % weapon_config_id, attack_times)

	var step_count := maxi(damage_values.size(), maxi(knockback_values.size(), attack_times.size()))
	if step_count == 0:
		push_error("WeaponController requires at least one combo step")
		return

	weapon_data = WeaponData.new(weapon_config_id, weapon_config_id)
	weapon_data.base_attack_speed = attack_speed if is_finite(attack_speed) and attack_speed > 0.001 else 1.0
	weapon_data.combo_steps.clear()
	for i in range(step_count):
		var damage := _read_non_negative_int(damage_values, i, DEFAULT_DAMAGE[i % DEFAULT_DAMAGE.size()])
		var knockback := _read_non_negative_float(knockback_values, i, DEFAULT_KNOCKBACK[i % DEFAULT_KNOCKBACK.size()])
		var duration := _read_positive_float(attack_times, i, DEFAULT_ATTACK_TIME[i % DEFAULT_ATTACK_TIME.size()])
		weapon_data.combo_steps.append({
			"name": "Strike %d" % (i + 1),
			"damage": damage,
			"knockback": knockback,
			"time": duration,
			"element": weapon_data.element,
			"status": []
		})
	runtime = WeaponRuntime.new(weapon_data)

func _read_non_negative_int(values: Array, index: int, fallback: int) -> int:
	if index >= values.size() or not (values[index] is int or values[index] is float):
		return fallback
	return maxi(int(values[index]), 0)

func _read_non_negative_float(values: Array, index: int, fallback: float) -> float:
	if index >= values.size() or not (values[index] is int or values[index] is float):
		return fallback
	var value := float(values[index])
	return maxf(value, 0.0) if is_finite(value) else fallback

func _read_positive_float(values: Array, index: int, fallback: float) -> float:
	if index >= values.size() or not (values[index] is int or values[index] is float):
		return fallback
	var value := float(values[index])
	return value if is_finite(value) and value > 0.0 else fallback

func _process(delta: float) -> void:
	if runtime == null:
		return
	if runtime.is_attacking:
		runtime.attack_timer -= delta
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
	if step.is_empty():
		return false

	var step_index := runtime.combo_index
	if step_index >= hit_shapes.size():
		push_error("Weapon combo step %d has no matching hitbox" % (step_index + 1))
		return false

	combo_reset_timer = 0.0
	runtime.is_attacking = true
	runtime.next_attack_buffered = false
	var attack_speed := weapon_data.base_attack_speed
	if not is_finite(attack_speed) or attack_speed <= 0.001:
		attack_speed = 1.0
	runtime.attack_timer = _read_positive_float([step.get("time", 0.4)], 0, 0.4) / attack_speed
	hit_targets.clear()
	disable_all_hitboxes()
	hit_shapes[step_index].set_deferred("disabled", false)
	attack_started.emit(str(step.get("name", "Strike")), step_index)
	attack_step_started.emit(step_index)
	return true

func _finish_attack_step() -> void:
	disable_all_hitboxes()
	runtime.is_attacking = false
	runtime.attack_timer = 0.0
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
	hit_targets.clear()

func buffer_next_attack() -> void:
	if runtime and runtime.is_attacking:
		runtime.next_attack_buffered = true

func get_current_attack() -> Dictionary:
	if runtime == null:
		return {}
	return runtime.get_attack_step()

func get_weapon_data() -> WeaponData:
	return weapon_data

func disable_all_hitboxes() -> void:
	for hit_shape in hit_shapes:
		hit_shape.set_deferred("disabled", true)

func _on_attack_area_body_entered(target: Node2D) -> void:
	if runtime == null or not runtime.is_attacking or target == source or target in hit_targets:
		return
	hit_targets.append(target)
	if not target.has_method("take_damage"):
		return

	var step := get_current_attack()
	var index := runtime.combo_index
	var hit_position := attack_area.global_position
	if index < hit_shapes.size():
		hit_position = hit_shapes[index].global_position

	var knockback_strength := float(step.get("knockback", 0.0))
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

	target.take_damage(maxi(int(step.get("damage", 0)), 0), hit_position, knockback_direction)
	if knockback_strength > 0.0 and source != null and source.has_method("apply_attack_recoil"):
		source.apply_attack_recoil(source_direction, knockback_strength)
