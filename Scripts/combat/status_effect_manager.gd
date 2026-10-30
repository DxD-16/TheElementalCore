class_name StatusEffectManager
extends RefCounted

const FREEZE_SHADER = preload("res://Scripts/combat/freeze.gdshader")

signal status_applied(effect: StatusEffect)
signal status_removed(effect: StatusEffect, reason: String)

var effects: Dictionary = {}
var owner: Node
var duration_overrides: Dictionary = {}
var _visual_states: Dictionary = {}
var _animation_states: Dictionary = {}

func configure(p_owner: Node, p_duration_overrides: Dictionary = {}) -> void:
	owner = p_owner
	duration_overrides = p_duration_overrides.duplicate()
	_sync_visuals()

func apply(
	effect_id: String,
	strength: float = 1.0,
	duration: float = -1.0,
	source: Node = null,
	data: Dictionary = {}
) -> void:
	var definition := StatusCatalog.get_definition(effect_id)
	if definition.is_empty():
		return
	if not _can_apply_to_owner(effect_id, definition):
		return
	if not is_finite(strength) or strength < 0.0:
		push_error("[StatusEffectManager] Status strength must be finite and non-negative")
		return
	if not is_finite(duration):
		push_error("[StatusEffectManager] Status duration must be finite")
		return

	var resolved_duration := _resolve_duration(effect_id, duration)
	if not is_finite(resolved_duration) or resolved_duration <= 0.0:
		push_error("[StatusEffectManager] Status duration must be finite and greater than zero")
		return

	var incoming_data := data.duplicate(true)
	var effect: StatusEffect = effects.get(effect_id)
	if effect_id == "freeze" and effect == null:
		incoming_data["damage_accumulated"] = 0
		if not incoming_data.has("shatter_threshold_damage"):
			incoming_data["shatter_threshold_damage"] = int(definition.get("shatter_threshold_damage", 1000))
		if not incoming_data.has("shatter_bonus_damage_multiplier"):
			incoming_data["shatter_bonus_damage_multiplier"] = float(definition.get("shatter_bonus_damage_multiplier", 1.0))

	if effect == null:
		effect = StatusEffect.new(effect_id, effect_id, resolved_duration, strength, 1, source, incoming_data)
		effects[effect_id] = effect
	else:
		var repeat_policy := StatusCatalog.get_repeat_policy()
		if repeat_policy.is_empty():
			return
		match repeat_policy:
			"refresh":
				effect.duration = resolved_duration
			"keep_longest":
				effect.duration = maxf(effect.duration, resolved_duration)
			"add_duration":
				effect.duration += resolved_duration
			_:
				push_error("[StatusEffectManager] Unknown status repeat policy")
				return
		effect.strength = strength
		effect.source = source
		effect.data.merge(incoming_data, true)

	_sync_visuals()
	status_applied.emit(effect)
	_sync_visuals()

func has_effect(effect_id: String) -> bool:
	return effects.has(effect_id) and effects[effect_id] != null

func get_effect(effect_id: String) -> StatusEffect:
	if not has_effect(effect_id):
		return null
	return effects[effect_id]

func remove(effect_id: String, reason: String = "removed") -> void:
	if not has_effect(effect_id):
		return
	var effect: StatusEffect = effects[effect_id]
	effects.erase(effect_id)
	_sync_visuals()
	status_removed.emit(effect, reason)

func can_perform_action(action_name: String) -> bool:
	for effect_id in effects:
		var definition := StatusCatalog.get_definition(str(effect_id))
		if definition.get("blocked_actions", []).has(action_name):
			return false
	return true

func can_receive_healing() -> bool:
	for effect_id in effects:
		var definition := StatusCatalog.get_definition(str(effect_id))
		if bool(definition.get("blocks_healing", false)):
			return false
	return true

func is_physics_disabled() -> bool:
	for effect_id in effects:
		var definition := StatusCatalog.get_definition(str(effect_id))
		if str(definition.get("physics", "enabled")) == "disabled":
			return true
	return false

func get_multiplier(modifier: String) -> float:
	var multiplier := 1.0
	for effect_id in effects:
		var definition := StatusCatalog.get_definition(str(effect_id))
		var modifiers: Dictionary = definition.get("modifiers", {})
		var value: Variant = modifiers.get(modifier, 1.0)
		if value is int or value is float:
			var factor := float(value)
			if is_finite(factor) and factor >= 0.0:
				multiplier *= factor
	return multiplier

func get_configured_duration(status_id: String, fallback: float) -> float:
	if duration_overrides.has(status_id):
		var override: Variant = duration_overrides[status_id]
		if (override is int or override is float) and is_finite(float(override)) and float(override) > 0.0:
			return float(override)
		push_error("[StatusEffectManager] Invalid duration override for status '%s'" % status_id)
	return fallback

func defer_damage_until_thawed(amount: int) -> bool:
	var effect := get_effect("freeze")
	if effect == null:
		return false
	effect.data["damage_accumulated"] = int(effect.data.get("damage_accumulated", 0)) + maxi(amount, 0)
	var threshold := int(effect.data.get("shatter_threshold_damage", 1000))
	if int(effect.data["damage_accumulated"]) > threshold:
		remove("freeze", "shattered")
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for effect_id in effects.keys():
		var effect: StatusEffect = effects.get(effect_id)
		if effect == null:
			effects.erase(effect_id)
			continue
		effect.tick(delta)
		if effect.is_expired():
			remove(str(effect_id), "expired")
	_sync_visuals()

func clear() -> void:
	var active_effects: Array = effects.values()
	effects.clear()
	_sync_visuals()
	for effect in active_effects:
		if effect is StatusEffect:
			status_removed.emit(effect, "cleared")

func _resolve_duration(effect_id: String, requested: float) -> float:
	if requested > 0.0:
		return requested
	var default_duration := StatusCatalog.get_default_duration(effect_id)
	return get_configured_duration(effect_id, default_duration)

func _can_apply_to_owner(effect_id: String, definition: Dictionary) -> bool:
	var allowed_roles: Array = definition.get("applies_to", [])
	var role := ""
	if owner != null and owner.is_in_group("Player"):
		role = "player"
	elif owner != null and owner.is_in_group("Enemies"):
		role = "enemy"
	if role.is_empty() or not allowed_roles.has(role):
		push_warning("[StatusEffectManager] Status cannot be applied to this actor")
		return false
	if owner != null:
		for property in owner.get_property_list():
			if str(property.get("name", "")) != "definition":
				continue
			var enemy_definition: Variant = owner.get("definition")
			if enemy_definition is Object:
				var immunities: Variant = enemy_definition.get("status_immunities")
				if immunities is Array and immunities.has(effect_id):
					return false
	return true

func _sync_visuals() -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var freeze_active := has_effect("freeze")
	var animation_multiplier := get_multiplier("animation_speed")
	for node in _get_visual_nodes(owner):
		var instance_id := node.get_instance_id()
		if not _visual_states.has(instance_id):
			_visual_states[instance_id] = {"material": node.material, "freeze_material": null}
		var state: Dictionary = _visual_states[instance_id]
		if freeze_active and state["freeze_material"] == null:
			var material := ShaderMaterial.new()
			material.shader = FREEZE_SHADER
			state["freeze_material"] = material
			node.material = material
		elif not freeze_active and state["freeze_material"] != null:
			node.material = state.get("material") as Material
			state["freeze_material"] = null
	for node in _get_animation_nodes(owner):
		var instance_id := node.get_instance_id()
		if not _animation_states.has(instance_id):
			_animation_states[instance_id] = {"speed_scale": node.get("speed_scale")}
		var base_speed := float(_animation_states[instance_id].get("speed_scale", 1.0))
		node.set("speed_scale", 0.0 if freeze_active else base_speed * animation_multiplier)

func _get_visual_nodes(root: Node) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	for child in root.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child as CanvasItem)
		result.append_array(_get_visual_nodes(child))
	return result

func _get_animation_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if child is AnimatedSprite2D or child is AnimationPlayer:
			result.append(child)
		result.append_array(_get_animation_nodes(child))
	return result
