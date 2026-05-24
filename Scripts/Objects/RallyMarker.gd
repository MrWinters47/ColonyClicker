extends Node2D

var _timer: float = 0.8
var _radius: float = 20.0

func _process(delta: float) -> void:
	_timer -= delta
	_radius = lerp(_radius, 0.0, 8.0 * delta)
	queue_redraw()
	if _timer <= 0:
		queue_free()

func _draw() -> void:
	var alpha = clamp(_timer / 0.8, 0.0, 1.0)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 32, Color(1.0, 0.6, 0.0, alpha), 2.0)
