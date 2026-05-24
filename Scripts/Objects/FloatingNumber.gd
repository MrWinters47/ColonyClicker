extends Node2D

# ─── Float duration and height
const FLOAT_DURATION: float = 1.4
const FLOAT_HEIGHT: float   = 100.0

var _label: Label

func _ready() -> void:
	# ─── Create label dynamically
	_label                      = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position             = Vector2(-50, -20)
	add_child(_label)

func setup(amount: float, is_rare: bool = false) -> void:
	var text = "+" + str(int(amount))

	if is_rare:
		# ─── Rare drop — gold, large, sparkles
		text = "✨ +" + str(int(amount)) + " ✨"
		_label.add_theme_font_size_override("font_size", 62)
		_label.modulate = Color(1.0, 0.85, 0.0)
	else:
		# ─── Normal — white, smaller
		_label.add_theme_font_size_override("font_size", 42)
		_label.modulate = Color(1.0, 1.0, 1.0, 0.9)

	_label.text = text

	# ─── Apply custom font if available
	var font_path = "res://Assets/Fonts/Jenko-DEMO.ttf"
	if ResourceLoader.exists(font_path):
		_label.add_theme_font_override("font", load(font_path))

	# ─── Tween upward and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_HEIGHT, FLOAT_DURATION)
	tween.tween_property(_label, "modulate:a", 0.0, FLOAT_DURATION)
	tween.finished.connect(queue_free)
