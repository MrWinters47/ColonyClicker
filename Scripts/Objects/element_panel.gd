extends Node2D


@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Play the "swoop_in" animation forward to open the panel
func open_panel() -> void:
	animation_player.play("SWOOP")

# Play the same animation backwards to close the panel
func close_panel() -> void:
	animation_player.play_backwards("SWOOP")
	

func _ready() -> void:
	open_panel()
