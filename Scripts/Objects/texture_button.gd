extends TextureButton

# --- Onready vars ---
# Store the button's original position and scale so we can return to them
@onready var original_position: Vector2 = position
@onready var original_scale: Vector2 = scale


func _ready() -> void:
	# Start the button off-screen to the left, then slide it in on load
	position.x -= 600
	_slide_in()


# --- Slide in from off-screen on scene load ---
func _slide_in() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_position, 0.6)


# --- Bounce/pulse when mouse hovers over the button ---
func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.3)


# --- Return to normal scale when mouse leaves ---
func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", original_scale, 0.2)


# --- Shake when pressed ---
# --- Press: squish down → pop out → drift right → fly off left → change scene ---
func _on_pressed() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Squish down slightly
	tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.10)

	# Pop back out satisfyingly
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12)

	# Settle back to normal scale
	tween.tween_property(self, "scale", original_scale, 0.10)

	# Drift right a little (anticipation)
	tween.tween_property(self, "position:x", original_position.x + 40, 0.18)

	# Blast off to the left and off-screen
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", original_position.x - 1200, 0.35)

	# Wait for the full animation to finish before switching scene
	await tween.finished

	get_tree().change_scene_to_file("res://Scenes/MainScenes/MainScene.tscn")
