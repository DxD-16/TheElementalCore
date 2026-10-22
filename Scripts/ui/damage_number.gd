extends Node2D

var amount: int = 0
@onready var label: RichTextLabel = $RichTextLabel

const DEFAULT_DAMAGE_COLORS := {
	"pure": Color.WHITE,
	"physical": Color.RED,
	"ether": Color("#A020F0"),
	"fire": Color("#FF8C00"),
	"ice": Color("#00BFFF"),
	"electric": Color.YELLOW,
	"player": Color("#8B0000")
}

@export_group("Animation Settings")
@export var rise_distance: float = 35.0  # На сколько пикселей поднимается вверх
@export var rise_duration: float = 0.2   # Время быстрого вылета
@export var hold_duration: float = 1.0   # Время статичной паузы на месте
@export var fade_duration: float = 0.25  # Время исчезновения

var drift_range_x: float = 25.0
var damage_colors: Dictionary = {}
var reaction_outline_color: Color = Color.WHITE
var reaction_outline_size: int = 2
var reaction_font_scale: float = 1.15

func _ready() -> void:
	damage_colors = DEFAULT_DAMAGE_COLORS.duplicate()
	_load_config()

func _load_config() -> void:
	if ConfigManager:
		rise_distance = ConfigManager.get_float("ui_effects", "damage_number.rise_distance", rise_distance)
		rise_duration = ConfigManager.get_float("ui_effects", "damage_number.rise_duration", rise_duration)
		hold_duration = ConfigManager.get_float("ui_effects", "damage_number.hold_duration", hold_duration)
		fade_duration = ConfigManager.get_float("ui_effects", "damage_number.fade_duration", fade_duration)
		drift_range_x = ConfigManager.get_float("ui_effects", "damage_number.drift_range_x", drift_range_x)
		var configured_colors := ConfigManager.get_dict("ui_effects", "damage_number.colors", {})
		for color_key in DEFAULT_DAMAGE_COLORS:
			var color_value: Variant = configured_colors.get(color_key, "")
			if color_value is String and color_value.is_valid_html_color():
				damage_colors[color_key] = Color(color_value)
		var configured_outline_color := ConfigManager.get_string(
			"ui_effects",
			"damage_number.reaction_style.outline_color",
			"#FFFFFF"
		)
		if configured_outline_color.is_valid_html_color():
			reaction_outline_color = Color(configured_outline_color)
		reaction_outline_size = maxi(
			ConfigManager.get_int(
				"ui_effects",
				"damage_number.reaction_style.outline_size",
				reaction_outline_size
			),
			0
		)
		reaction_font_scale = maxf(
			ConfigManager.get_float(
				"ui_effects",
				"damage_number.reaction_style.font_scale",
				reaction_font_scale
			),
			1.0
		)

## Запускает анимацию цифры урона.
func start(
	dmg_amount: int,
	spawn_pos: Vector2,
	damage_type: int = DamageTypes.Type.PHYSICAL,
	is_player_damage: bool = false,
	is_reaction_damage: bool = false
) -> void:
	amount = dmg_amount
	global_position = spawn_pos

	if not is_inside_tree():
		await ready

	if label:
		label.text = str(amount)
		var color_key := "player" if is_player_damage else DamageTypes.to_key(damage_type)
		var text_color: Color = damage_colors.get(color_key, damage_colors["physical"])
		label.add_theme_color_override(
			"default_color",
			text_color
		)
		if is_reaction_damage:
			label.add_theme_color_override("font_outline_color", reaction_outline_color)
			label.add_theme_constant_override("outline_size", reaction_outline_size)
			var base_font_size := label.get_theme_font_size("normal_font_size")
			label.add_theme_font_size_override(
				"normal_font_size",
				maxi(roundi(float(base_font_size) * reaction_font_scale), base_font_size)
			)
	modulate.a = 1.0

	var tween = create_tween()

	# 1. Быстрый вылет вверх на rise_distance с легким разлетом в стороны (дрифт)
	var drift_x = randf_range(-drift_range_x, drift_range_x)
	var target_pos = Vector2(global_position.x + drift_x, global_position.y - rise_distance)
	tween.tween_property(self, "global_position", target_pos, rise_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# 2. Статичная пауза на месте
	tween.tween_interval(hold_duration)

	# 3. Плавное растворение
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_LINEAR)

	# 4. Удаление после завершения всей анимации
	tween.tween_callback(queue_free)
