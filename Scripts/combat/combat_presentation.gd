extends Node

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/ui/damage_number.tscn")
const WHITE_FLASH_SHADER = preload("res://Scripts/combat/white_flash.gdshader")
const DEFAULT_FLASH_COLOR := Color.WHITE
const DEFAULT_FLASH_DURATION := 0.15

var hit_flash_color: Color = DEFAULT_FLASH_COLOR
var hit_flash_duration: float = DEFAULT_FLASH_DURATION
var _active_flash_tweens: Dictionary = {}
var _active_flash_materials: Dictionary = {}
var _previous_materials: Dictionary = {}

func _ready() -> void:
	if ConfigManager:
		hit_flash_duration = maxf(
			ConfigManager.get_float("ui_effects", "combat.hit_flash_duration", DEFAULT_FLASH_DURATION),
			0.0
		)
		var configured_color := ConfigManager.get_string("ui_effects", "combat.hit_flash_color", "#ffffff")
		if configured_color.is_valid_html_color():
			hit_flash_color = Color(configured_color)

func show_hit(target: Node, amount: int, hit_position: Vector2, number_color: Color = Color(-1, -1, -1)) -> void:
	if target == null or not is_instance_valid(target):
		return

	_play_hit_flash(target)
	if amount <= 0:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	scene.add_child(damage_number)
	damage_number.start(amount, hit_position, number_color)

func _play_hit_flash(target: Node) -> void:
	var visual := _find_visual(target)
	if visual == null:
		return

	var instance_id := visual.get_instance_id()
	var previous_tween: Tween = _active_flash_tweens.get(instance_id)
	if previous_tween and previous_tween.is_valid():
		previous_tween.kill()

	var flash_material: ShaderMaterial = _active_flash_materials.get(instance_id)
	if flash_material == null:
		_previous_materials[instance_id] = visual.material
		flash_material = ShaderMaterial.new()
		flash_material.shader = WHITE_FLASH_SHADER
		_active_flash_materials[instance_id] = flash_material
	visual.material = flash_material
	flash_material.set_shader_parameter("flash_color", hit_flash_color)
	flash_material.set_shader_parameter("flash_amount", 1.0)
	var tween := create_tween()
	_active_flash_tweens[instance_id] = tween
	tween.tween_property(flash_material, "shader_parameter/flash_amount", 0.0, hit_flash_duration)
	tween.finished.connect(_clear_flash.bind(instance_id, visual))

func _clear_flash(instance_id: int, visual: CanvasItem) -> void:
	if is_instance_valid(visual):
		visual.material = _previous_materials.get(instance_id)
	_active_flash_tweens.erase(instance_id)
	_active_flash_materials.erase(instance_id)
	_previous_materials.erase(instance_id)

func _find_visual(node: Node) -> CanvasItem:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node as CanvasItem
	for child in node.get_children():
		var visual := _find_visual(child)
		if visual != null:
			return visual
	return null
