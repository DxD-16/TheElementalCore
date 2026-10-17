class_name WeaponHitboxDefinition
extends Resource

@export var shape: Shape2D
@export var offset: Vector2 = Vector2.ZERO
@export var rotation_degrees: float = 0.0
@export_range(0.0, 1.0) var active_start_ratio: float = 0.0
@export_range(0.0, 1.0) var active_end_ratio: float = 1.0
