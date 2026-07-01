extends ColorRect # Change this to TextureButton or whatever your ant node is

func _ready():
	# CRITICAL: Make the material unique so clicking one ant 
	# doesn't trigger the shine on EVERY ant on the screen.
	material = material.duplicate()

# Call this function whenever your click logic registers a hit
func _on_ant_clicked():
	# 1. Reset the shine to the starting position (left side)
	material.set_shader_parameter("sweep_position", -0.5)
	
	# 2. Create the Tween
	var tween = get_tree().create_tween()
	
	# 3. Animate the parameter
	# Target: the material
	# Property: "shader_parameter/sweep_position"
	# Final Value: 2.5 (right side)
	# Duration: 0.4 seconds
	tween.tween_property(material, "shader_parameter/sweep_position", 2.5, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _on_spawn_button_pressed() -> void:
	_on_ant_clicked()
