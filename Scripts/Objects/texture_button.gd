extends TextureButton

const MAIN_SCENE := "res://Scenes/MainScenes/MainScene.tscn"

@onready var original_position: Vector2 = position
@onready var original_scale: Vector2 = scale

func _ready() -> void:
	position.x -= 600
	_slide_in()
	ResourceLoader.load_threaded_request(MAIN_SCENE)

func _slide_in() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_position, 0.6)

func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.3)

func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", original_scale, 0.2)

func _on_pressed() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.10)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12)
	tween.tween_property(self, "scale", original_scale, 0.10)
	tween.tween_property(self, "position:x", original_position.x + 40, 0.18)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", original_position.x - 1200, 0.35)
	await tween.finished

	# ─── Cover the rendering gap — named so MainScene can remove it
	var layer = CanvasLayer.new()
	layer.layer = 99
	layer.name = "TransitionCover"
	var cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cover)
	get_tree().root.add_child(layer)

	var packed = ResourceLoader.load_threaded_get(MAIN_SCENE)
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)
