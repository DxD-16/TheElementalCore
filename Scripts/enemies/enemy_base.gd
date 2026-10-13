class_name EnemyBase
extends CharacterBody2D

const EnemyDefinitionClass = preload("res://Scripts/enemies/enemy_definition.gd")
const EnemyAttackDefinitionClass = preload("res://Scripts/enemies/enemy_attack_definition.gd")
const EnemyStateMachineClass = preload("res://Scripts/enemies/enemy_state_machine.gd")
const EnemyStateClass = preload("res://Scripts/enemies/enemy_state.gd")
const EnemyDamageResolverClass = preload("res://Scripts/enemies/enemy_damage_resolver.gd")

var definition = null
var move_speed: float = 60.0
var target: Node2D = null
var status_effect_manager: StatusEffectManager = StatusEffectManager.new()
var attack_definitions: Array = []
var state_machine = null
var current_attack = null
var attack_cooldown: float = 0.0
var is_dead: bool = false
var health_component: HealthComponent = null
var sprite: Sprite2D = null
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	if definition == null:
		definition = EnemyDefinitionClass.new("enemy")
	if health_component == null:
		health_component = _ensure_health_component()
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
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
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if state_machine != null:
		state_machine.update(delta)
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	velocity.y = move_toward(velocity.y, 0.0, 120.0 * delta)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if state_machine != null:
		state_machine.physics_update(delta)
	move_and_slide()

func apply_knockback(force: Vector2) -> void:
	var enemy_weight := float(definition.weight) if definition != null else 1.0
	velocity += force / enemy_weight

func apply_damage(amount: int, hit_position: Vector2 = Vector2.ZERO, element: int = ElementalTypes.ElementType.NONE, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	var final_damage: int = EnemyDamageResolverClass.calculate_damage(self, amount, element)
	if health_component:
		health_component.take_damage(final_damage)
	if knockback.length() > 0.0:
		apply_knockback(knockback)
	flash_effect()
	spawn_damage_number(final_damage, hit_position if hit_position != Vector2.ZERO else global_position)
	if health_component and health_component.current_health <= 0:
		_on_died()

func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, knockback: Vector2 = Vector2.ZERO) -> void:
	apply_damage(amount, hit_pos, ElementalTypes.ElementType.NONE, null, knockback)

func flash_effect() -> void:
	if sprite == null:
		return
	if sprite.modulate != Color.WHITE:
		sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func spawn_damage_number(amount: int, base_pos: Vector2) -> void:
	var damage_scene = load("res://Scenes/ui/damage_number.tscn")
	if damage_scene == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var text = damage_scene.instantiate()
	scene.add_child(text)
	text.start(amount, base_pos)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
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
		var dropped = load("res://Scenes/dropped_item.tscn").instantiate() as DroppedItem
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
