class_name StatusEffect
extends RefCounted

var id: String = ""
var type: String = ""
var duration: float = 0.0
var strength: float = 1.0
var stacks: int = 1
var source: Node = null
var data: Dictionary = {}

func _init(
	p_id: String = "",
	p_type: String = "",
	p_duration: float = 0.0,
	p_strength: float = 1.0,
	p_stacks: int = 1,
	p_source: Node = null,
	p_data: Dictionary = {}
) -> void:
	id = p_id
	type = p_type
	duration = p_duration
	strength = p_strength
	stacks = maxi(p_stacks, 1)
	source = p_source
	data = p_data

func tick(delta: float) -> void:
	duration = maxf(duration - delta, 0.0)

func is_expired() -> bool:
	return duration <= 0.0

func clone() -> StatusEffect:
	var copy := StatusEffect.new(id, type, duration, strength, stacks, source, data.duplicate())
	return copy
