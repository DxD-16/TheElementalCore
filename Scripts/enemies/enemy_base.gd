class_name EnemyBase
extends CharacterBody2D

const EnemyDefinitionClass = preload("res://Scripts/enemies/enemy_definition.gd")
const EnemyAttackDefinitionClass = preload("res://Scripts/enemies/enemy_attack_definition.gd")
const EnemyStateMachineClass = preload("res://Scripts/enemies/enemy_state_machine.gd")
const EnemyStateClass = preload("res://Scripts/enemies/enemy_state.gd")
const EnemyDamageResolverClass = preload("res://Scripts/enemies/enemy_damage_resolver.gd")

var definition = null
var move_speed: float = 60.0
var horizontal_friction: float = 900.0
var target: Node2D = null
var status_effect_manager: StatusEffectManager = StatusEffectManager.new()
var attack_definitions: Array = []
var state_machine = null
var current_attack = null
var attack_cooldown: float = 0.0
var is_dead: bool = false
var health_component: HealthComponent = null
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var elemental_gauge: ElementalGauge = ElementalGauge.new()
var elemental_reaction_resolver: ElementalReactionResolver = ElementalReactionResolver.new()
var _resistance_reduction_effects: Array[Dictionary] = []
var _magnetic_overload_fields: Array[Dictionary] = []
var _deep_freeze_remaining: float = 0.0
var _deep_freeze_accumulated_damage: int = 0
var _deep_freeze_shatter_bonus_multiplier: float = 0.0
var _plasma_discharge_effects: Array[Dictionary] = []
var _stun_remaining: float = 0.0
var _ether_detonation_effects: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("Enemies")
	if ConfigManager:
		elemental_gauge.set_charge_threshold(
			ConfigManager.get_float("elemental_reactions", "charge.threshold_percent", 100.0)
		)
	if definition == null:
		definition = EnemyDefinitionClass.new("enemy")
	horizontal_friction = float(definition.horizontal_friction)
	if health_component == null:
		health_component = _ensure_health_component()
	if health_component:
		health_component.max_health = int(definition.max_health)
		health_component.current_health = int(definition.max_health)
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)
	if state_machine == null:
		state_machine = EnemyStateMachineClass.new()
		add_child(state_machine)
		state_machine.register_state("idle", _create_idle_state())
		state_machine.register_state("attack", _create_attack_state())
		state_machine.register_state("dead", _create_dead_state())
		state_machine.transition_to("idle")

func _ensure_health_component() -> HealthComponent:
	var current := get_node_or_null("HealthComponent") as HealthComponent
	if current == null:
		current = HealthComponent.new()
		current.name = "HealthComponent"
		add_child(current)
	return current

func _create_idle_state():
	var state = EnemyStateClass.new()
	state.enemy = self
	return state

func _create_attack_state():
	var state = EnemyStateClass.new()
	state.enemy = self
	return state

func _create_dead_state():
	var state = EnemyStateClass.new()
	state.enemy = self
	return state

func set_definition(p_definition) -> void:
	definition = p_definition
	if definition == null:
		definition = EnemyDefinitionClass.new("enemy")
	move_speed = float(definition.move_speed)
	horizontal_friction = float(definition.horizontal_friction)
	if health_component:
		health_component.max_health = int(definition.max_health)
		health_component.current_health = int(definition.max_health)
	_ensure_attack_definitions()

func _ensure_attack_definitions() -> void:
	attack_definitions.clear()
	if definition == null:
		return
	for entry in definition.attack_patterns:
		if entry is Dictionary:
			var attack = EnemyAttackDefinitionClass.new("attack", entry)
			attack_definitions.append(attack)

func get_definition():
	return definition

func _process(delta: float) -> void:
	elemental_gauge.advance_time(delta)
	_advance_resistance_reduction_effects(delta)
	_advance_deep_freeze(delta)
	_advance_stun(delta)
	_advance_plasma_discharge_effects(delta)
	_advance_ether_detonation_effects(delta)
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if state_machine != null and not is_deep_frozen() and not is_stunned():
		state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if is_deep_frozen() or is_stunned():
		velocity = Vector2.ZERO
		return
	_update_magnetic_overload_fields(delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	if state_machine != null:
		state_machine.physics_update(delta)
	velocity.x = move_toward(velocity.x, 0.0, horizontal_friction * delta)
	move_and_slide()

func apply_knockback(force: Vector2) -> void:
	var enemy_weight := float(definition.weight) if definition != null else 1.0
	velocity += force / enemy_weight

func apply_damage(amount: int, hit_position: Vector2 = Vector2.ZERO, damage_type: int = DamageTypes.Type.PHYSICAL, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	var final_damage: int = EnemyDamageResolverClass.calculate_damage(self, amount, damage_type)
	if is_deep_frozen():
		_deep_freeze_accumulated_damage += final_damage
		var config := _get_deep_freeze_config()
		if not config.is_empty() and _deep_freeze_accumulated_damage > int(config["shatter_threshold_damage"]):
			_release_deep_freeze_damage(1.0 + _deep_freeze_shatter_bonus_multiplier, hit_position)
		return
	_apply_final_damage(final_damage, hit_position, knockback)

func _apply_final_damage(final_damage: int, hit_position: Vector2, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	if health_component:
		health_component.take_damage(final_damage)
	if knockback.length() > 0.0:
		apply_knockback(knockback)
	CombatPresentation.show_hit(self, final_damage, hit_position if hit_position != Vector2.ZERO else global_position)
	if health_component and health_component.current_health <= 0:
		_on_died()

func apply_elemental_hit(
	amount: int,
	hit_position: Vector2,
	element: int,
	charge_amount: float,
	knockback: Vector2 = Vector2.ZERO,
	source: Node = null
) -> void:
	if is_dead:
		return

	var reaction := elemental_reaction_resolver.resolve(elemental_gauge, element)
	var reaction_entries: Array = reaction.get("reactions", [])
	var pre_applied_reactions: Array[String] = []
	for entry in reaction_entries:
		if not entry is Dictionary:
			continue
		var reaction_type := str(entry.get("reaction", "none"))
		if reaction_type == "deep_freeze":
			_start_deep_freeze(int(entry.get("strength", 0)))
			pre_applied_reactions.append(reaction_type)
		elif reaction_type == "ether_detonation":
			_start_ether_detonation(int(entry.get("strength", 0)))
			pre_applied_reactions.append(reaction_type)

	var damage := amount if DamageTypes.element_deals_damage(element) else 0
	apply_damage(damage, hit_position, DamageTypes.from_element(element), source, knockback)
	if reaction.get("triggered", false):
		if not is_dead:
			_apply_reaction_effects(reaction, pre_applied_reactions)
	elif not is_dead and element != ElementalTypes.ElementType.NONE and not (is_deep_frozen() and element == ElementalTypes.ElementType.ICE):
		var charge_duration := 10.0
		if ConfigManager:
			charge_duration = ConfigManager.get_float(
				"elemental_reactions",
				"timers.element_charge_seconds",
				charge_duration
			)
		elemental_gauge.add_value(element, charge_amount, charge_duration)

func is_deep_frozen() -> bool:
	return _deep_freeze_remaining > 0.0

func is_stunned() -> bool:
	return _stun_remaining > 0.0

func _apply_stun(duration: float) -> void:
	if not is_finite(duration) or duration <= 0.0:
		push_error("[EnemyBase] Stun duration must be finite and greater than zero")
		return
	_stun_remaining = maxf(_stun_remaining, duration)
	velocity = Vector2.ZERO

func _advance_stun(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		_stun_remaining = maxf(_stun_remaining - delta, 0.0)

func _start_plasma_discharge(strength: int) -> void:
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.plasma_discharge", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing plasma_discharge configuration")
		return

	_plasma_discharge_effects.append({
		"remaining": float(config["tick_interval_seconds"]),
		"tick_index": 0,
		"strength_scale": clampf(float(strength) / 100.0, 0.0, 1.0)
	})

func _advance_plasma_discharge_effects(delta: float) -> void:
	if _plasma_discharge_effects.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.plasma_discharge", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing plasma_discharge configuration")
		return

	var interval := float(config["tick_interval_seconds"])
	var stun_duration := float(config["stun_duration_seconds"])
	var ticks: Array = config["ticks"]
	for i in range(_plasma_discharge_effects.size() - 1, -1, -1):
		var effect := _plasma_discharge_effects[i]
		var time_until_tick := float(effect["remaining"]) - delta
		var tick_index := int(effect["tick_index"])
		while time_until_tick <= 0.0 and tick_index < ticks.size() and not is_dead:
			var tick: Dictionary = ticks[tick_index]
			var damage := int(round(float(tick["damage"]) * float(effect["strength_scale"])))
			var damage_type := DamageTypes.Type.PURE if str(tick["type"]) == "pure" else DamageTypes.Type.ELECTRIC
			apply_damage(damage, global_position, damage_type)
			if not is_dead:
				_apply_stun(stun_duration)
			tick_index += 1
			time_until_tick += interval

		if tick_index >= ticks.size() or is_dead:
			_plasma_discharge_effects.remove_at(i)
		else:
			effect["tick_index"] = tick_index
			effect["remaining"] = time_until_tick

func _start_ether_detonation(strength: int) -> void:
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.ether_detonation", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing ether_detonation configuration")
		return
	_ether_detonation_effects.append({
		"remaining": float(config["duration_seconds"]),
		"shockwave_scale": clampf(float(strength) / 100.0, 0.0, 1.0)
	})

func _advance_ether_detonation_effects(delta: float) -> void:
	if _ether_detonation_effects.is_empty() or is_dead or not is_finite(delta) or delta <= 0.0:
		return
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.ether_detonation", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing ether_detonation configuration")
		return
	for i in range(_ether_detonation_effects.size() - 1, -1, -1):
		var effect := _ether_detonation_effects[i]
		var remaining := float(effect["remaining"]) - delta
		if remaining <= 0.0:
			var damage := int(round(float(config["shockwave_fire_damage"]) * float(effect["shockwave_scale"])))
			_ether_detonation_effects.remove_at(i)
			_apply_ether_detonation_blast(
				damage,
				float(config["shockwave_radius_px"]),
				DamageTypes.Type.FIRE
			)
			if is_dead:
				return
		else:
			effect["remaining"] = remaining

func _apply_ether_detonation_blast(damage: int, radius: float, damage_type: int) -> void:
	if damage <= 0 or radius < 0.0 or not is_finite(radius):
		return
	var blast_position := global_position
	for node in get_tree().get_nodes_in_group("Enemies"):
		if node == self or not node is EnemyBase:
			continue
		var enemy := node as EnemyBase
		if enemy.is_dead or enemy.global_position.distance_squared_to(blast_position) > radius * radius:
			continue
		enemy.apply_damage(damage, enemy.global_position, damage_type, self)

func _get_deep_freeze_config() -> Dictionary:
	if not ConfigManager:
		return {}
	return ConfigManager.get_dict("elemental_reactions", "effects.deep_freeze", {})

func _start_deep_freeze(strength: int) -> void:
	var config := _get_deep_freeze_config()
	if config.is_empty():
		push_error("[EnemyBase] Missing deep_freeze configuration")
		return

	var scale := clampf(float(strength) / 100.0, 0.0, 1.0)
	_deep_freeze_remaining = float(config["freeze_duration_seconds"]) * scale
	_deep_freeze_accumulated_damage = 0
	_deep_freeze_shatter_bonus_multiplier = float(config["shatter_bonus_damage_multiplier"]) * scale
	velocity = Vector2.ZERO

func _advance_deep_freeze(delta: float) -> void:
	if not is_deep_frozen() or not is_finite(delta) or delta <= 0.0:
		return
	_deep_freeze_remaining = maxf(_deep_freeze_remaining - delta, 0.0)
	if _deep_freeze_remaining == 0.0:
		_release_deep_freeze_damage(1.0, global_position)

func _release_deep_freeze_damage(multiplier: float, hit_position: Vector2) -> void:
	var accumulated_damage := _deep_freeze_accumulated_damage
	_deep_freeze_remaining = 0.0
	_deep_freeze_accumulated_damage = 0
	_deep_freeze_shatter_bonus_multiplier = 0.0
	var released_damage := int(round(float(accumulated_damage) * multiplier))
	if released_damage > 0:
		_apply_final_damage(released_damage, hit_position)

func get_effective_resistance(damage_type: int, base_resistance: float) -> float:
	var strongest_reduction := 0.0
	for effect in _resistance_reduction_effects:
		var reductions: Dictionary = effect.get("resistances", {})
		strongest_reduction = maxf(strongest_reduction, float(reductions.get(DamageTypes.to_key(damage_type), 0.0)))
	return base_resistance * (1.0 - strongest_reduction / 100.0)

func _apply_reaction_effects(reaction: Dictionary, skip_reactions: Array[String] = []) -> void:
	var reactions: Array = reaction.get("reactions", [])
	if reactions.is_empty():
		reactions.append(reaction)
	for entry in reactions:
		if not entry is Dictionary:
			continue
		var reaction_type := str(entry.get("reaction", "none"))
		if skip_reactions.has(reaction_type):
			continue
		match reaction_type:
			"thermo_burst":
				_apply_thermo_burst(int(entry.get("strength", 0)))
			"magnetic_overload":
				_start_magnetic_overload(int(entry.get("strength", 0)))
			"plasma_discharge":
				_start_plasma_discharge(int(entry.get("strength", 0)))
			"ether_detonation":
				_start_ether_detonation(int(entry.get("strength", 0)))
			"hemorrhage":
				_apply_hemorrhage(int(entry.get("strength", 0)))
			"deep_freeze":
				_start_deep_freeze(int(entry.get("strength", 0)))

func _apply_hemorrhage(strength: int) -> void:
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.hemorrhage", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing hemorrhage configuration")
		return
	if health_component == null:
		push_error("[EnemyBase] Hemorrhage requires a HealthComponent")
		return

	var scale := clampf(float(strength) / 100.0, 0.0, 1.0)
	var damage_percent := float(config["pure_damage_max_health_percent"]) * scale
	var pure_damage := int(round(float(health_component.max_health) * damage_percent / 100.0))
	if pure_damage > 0:
		apply_damage(pure_damage, global_position, DamageTypes.Type.PURE)

func _start_magnetic_overload(strength: int) -> void:
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.magnetic_overload", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing magnetic_overload configuration")
		return

	var scale := clampf(float(strength) / 100.0, 0.0, 1.0)
	_magnetic_overload_fields.append({
		"remaining": float(config["attraction_duration_seconds"]),
		"attraction_radius": float(config["attraction_radius_px"]),
		"attraction_acceleration": float(config["attraction_acceleration_px_per_second_squared"]) * scale,
		"discharge_radius": float(config["discharge_radius_px"]),
		"discharge_damage": int(round(float(config["discharge_electric_damage"]) * scale)),
		"discharge_knockback": float(config["discharge_knockback"]) * scale
	})

func apply_magnetic_attraction(acceleration: Vector2, delta: float) -> void:
	if is_dead or not is_finite(delta) or delta <= 0.0:
		return
	var safe_weight := float(definition.weight) if definition != null else 1.0
	if not is_finite(safe_weight) or safe_weight <= 0.0:
		push_error("[EnemyBase] Enemy weight must be finite and greater than zero")
		return
	velocity += acceleration * delta / safe_weight

func _update_magnetic_overload_fields(delta: float) -> void:
	if _magnetic_overload_fields.is_empty() or not is_finite(delta) or delta <= 0.0:
		return

	var enemies := get_tree().get_nodes_in_group("Enemies")
	for i in range(_magnetic_overload_fields.size() - 1, -1, -1):
		var field := _magnetic_overload_fields[i]
		var attraction_radius := float(field["attraction_radius"])
		for node in enemies:
			if node == self or not node is EnemyBase:
				continue
			var enemy := node as EnemyBase
			if enemy.is_dead:
				continue
			var offset := global_position - enemy.global_position
			if offset.length_squared() > attraction_radius * attraction_radius:
				continue
			if offset.length_squared() > 0.0:
				enemy.apply_magnetic_attraction(
					offset.normalized() * float(field["attraction_acceleration"]),
					delta
				)

		var remaining := float(field["remaining"]) - delta
		if remaining <= 0.0:
			_discharge_magnetic_overload(field)
			_magnetic_overload_fields.remove_at(i)
		else:
			field["remaining"] = remaining

func _discharge_magnetic_overload(field: Dictionary) -> void:
	var radius := float(field["discharge_radius"])
	var damage := int(field["discharge_damage"])
	var knockback_strength := float(field["discharge_knockback"])
	if radius <= 0.0 or (damage <= 0 and knockback_strength <= 0.0):
		return

	for node in get_tree().get_nodes_in_group("Enemies"):
		if node == self or not node is EnemyBase:
			continue
		var enemy := node as EnemyBase
		if enemy.is_dead or enemy.global_position.distance_squared_to(global_position) > radius * radius:
			continue

		var knockback := Vector2.ZERO
		var offset := enemy.global_position - global_position
		if knockback_strength > 0.0:
			var direction := offset.normalized() if offset.length_squared() > 0.0 else Vector2.RIGHT
			knockback = direction * knockback_strength
		enemy.apply_damage(damage, enemy.global_position, DamageTypes.Type.ELECTRIC, self, knockback)

func _apply_thermo_burst(strength: int) -> void:
	var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.thermo_burst", {}) if ConfigManager else {}
	if config.is_empty():
		push_error("[EnemyBase] Missing thermo_burst configuration")
		return

	var scale := clampf(float(strength) / 100.0, 0.0, 1.0)
	var base_resistance_reduction := float(config["resistance_reduction_percent"])
	_resistance_reduction_effects.append({
		"resistances": {
			"physical": base_resistance_reduction * scale,
			"fire": base_resistance_reduction * scale,
			"electric": base_resistance_reduction * scale,
			"ether": base_resistance_reduction * scale,
			"ice": base_resistance_reduction * scale
		},
		"remaining": float(config["resistance_reduction_seconds"])
	})

	var burst_position := global_position
	var aoe_damage := int(config["aoe_fire_damage"])
	var aoe_radius := float(config["aoe_radius_px"])
	if aoe_damage <= 0 or aoe_radius <= 0.0:
		return
	for node in get_tree().get_nodes_in_group("Enemies"):
		if not node is EnemyBase:
			continue
		var enemy := node as EnemyBase
		if enemy.is_dead or enemy.global_position.distance_squared_to(burst_position) > aoe_radius * aoe_radius:
			continue
		enemy.apply_damage(aoe_damage, enemy.global_position, DamageTypes.Type.FIRE)

func _advance_resistance_reduction_effects(delta: float) -> void:
	for i in range(_resistance_reduction_effects.size() - 1, -1, -1):
		var effect := _resistance_reduction_effects[i]
		var remaining := float(effect.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			_resistance_reduction_effects.remove_at(i)
		else:
			effect["remaining"] = remaining

func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, knockback: Vector2 = Vector2.ZERO) -> void:
	apply_damage(amount, hit_pos, DamageTypes.Type.PHYSICAL, null, knockback)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	if not _ether_detonation_effects.is_empty():
		var config: Dictionary = ConfigManager.get_dict("elemental_reactions", "effects.ether_detonation", {}) if ConfigManager else {}
		if config.is_empty():
			push_error("[EnemyBase] Missing ether_detonation configuration")
		else:
			_ether_detonation_effects.clear()
			_apply_ether_detonation_blast(
				int(config["explosion_fire_damage"]),
				float(config["explosion_radius_px"]),
				DamageTypes.Type.FIRE
			)
	if state_machine != null:
		state_machine.transition_to("dead")
	_spawn_loot()
	queue_free()

func _spawn_loot() -> void:
	if definition == null or definition.drop_table.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for entry in definition.drop_table:
		if not entry is Dictionary:
			continue
		var chance: float = float(entry.get("chance", 1.0))
		if randf() > chance:
			continue
		var item_id: String = String(entry.get("item_id", ""))
		if item_id.is_empty():
			continue
		var min_count: int = int(entry.get("min_count", 1))
		var max_count: int = int(entry.get("max_count", 1))
		var count: int = randi_range(min_count, max_count)
		var dropped = load("res://Scenes/items/dropped_item.tscn").instantiate() as DroppedItem
		scene.add_child(dropped)
		dropped.global_position = global_position + Vector2(0, -10)
		var launch := Vector2(randf_range(-120.0, 120.0), randf_range(-250.0, -150.0))
		dropped.setup(item_id, count, launch)

func get_target() -> Node2D:
	return target

func set_target(value: Node2D) -> void:
	target = value

func get_attack_definitions() -> Array:
	return attack_definitions

func add_attack(attack) -> void:
	if attack == null:
		return
	attack_definitions.append(attack)

func get_definition_for_attack(attack_id: String):
	for attack in attack_definitions:
		if attack != null and attack.id == attack_id:
			return attack
	return null

func can_attack() -> bool:
	return attack_cooldown <= 0.0 and not is_dead

func start_attack(attack_id: String) -> bool:
	if not can_attack():
		return false
	current_attack = get_definition_for_attack(attack_id)
	if current_attack == null:
		return false
	attack_cooldown = current_attack.cooldown
	return true
