class_name StatusEffectManager
extends RefCounted

var effects: Dictionary = {}

func apply(effect_id: String, strength: float = 1.0, duration: float = 1.0, source: Node = null, data: Dictionary = {}) -> void:
	var effect := StatusEffect.new(effect_id, effect_id, duration, strength, 1, source, data)
	effects[effect_id] = effect

func has_effect(effect_id: String) -> bool:
	return effects.has(effect_id) and effects[effect_id] != null

func get_effect(effect_id: String) -> StatusEffect:
	if not has_effect(effect_id):
		return null
	return effects[effect_id]

func remove(effect_id: String) -> void:
	effects.erase(effect_id)

func tick(delta: float) -> void:
	var keys := effects.keys()
	for key in keys:
		var effect: StatusEffect = effects[key]
		if effect == null:
			effects.erase(key)
			continue
		effect.tick(delta)
		if effect.is_expired():
			effects.erase(key)

func clear() -> void:
	effects.clear()
