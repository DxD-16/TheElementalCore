class_name EnemyStateMachine
extends Node

var current_state_name: String = "idle"
var states: Dictionary = {}

func register_state(state_name: String, state_node: Node) -> void:
	if state_node == null:
		return
	if state_node.get_parent() == null:
		add_child(state_node)
	states[state_name.to_lower()] = state_node
	if state_node.has_method("set_enemy"):
		state_node.set_enemy(owner)

func transition_to(target_state_name: String) -> void:
	if not states.has(target_state_name.to_lower()):
		return
	var target = states[target_state_name.to_lower()]
	if target == null:
		return
	if target.has_method("enter"):
		target.enter()
	current_state_name = target_state_name.to_lower()

func update(delta: float) -> void:
	var state = states.get(current_state_name)
	if state != null and state.has_method("update"):
		state.update(delta)

func physics_update(delta: float) -> void:
	var state = states.get(current_state_name)
	if state != null and state.has_method("physics_update"):
		state.physics_update(delta)
