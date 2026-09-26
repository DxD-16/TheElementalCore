class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	# Автоматически находим все дочерние состояния
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.player = owner as Player
			child.state_machine = self
	
	# Откладываем запуск стартового состояния на один микрошаг,
	# чтобы родительский Player успел полностью инициализировать все @onready переменные
	if initial_state:
		call_deferred("_init_state")

func _init_state() -> void:
	transition_to(initial_state.name)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String) -> void:
	var target_state = states.get(target_state_name.to_lower())
	if not target_state:
		return
	
	if current_state:
		current_state.exit()
	
	current_state = target_state
	current_state.enter()
