extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func open_panel() -> void:
	animation_player.play("SWOOP")

func close_panel() -> void:
	animation_player.play_backwards("SWOOP")

func _ready() -> void:
	pass  # MainUI controls open/close — don't auto-open here
