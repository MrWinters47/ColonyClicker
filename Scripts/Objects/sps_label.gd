extends Label

var _shown_sps: float = 0.0

func _process(delta: float) -> void:
	_shown_sps = lerp(_shown_sps, GameManager.sucrose_per_sec, 5.0 * delta)
	text = "%.1f /s" % _shown_sps
