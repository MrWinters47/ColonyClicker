extends CanvasLayer

# ─── Only show in debug builds
func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 99  # always on top

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_1:
			# ─── Add 100 ants
			GameManager.ant_count += 100
			EventBus.ant_spawned.emit(null)
			print("DEV: +100 ants → ", GameManager.ant_count)

		KEY_2:
			# ─── Add 1000 ants
			GameManager.ant_count += 1000
			EventBus.ant_spawned.emit(null)
			print("DEV: +1000 ants → ", GameManager.ant_count)

		KEY_3:
			# ─── Add 500 sucrose
			GameManager.add_sucrose(500.0)
			print("DEV: +500 sucrose → ", GameManager.sucrose)

		KEY_4:
			# ─── Add 10000 sucrose
			GameManager.add_sucrose(10000.0)
			print("DEV: +10000 sucrose → ", GameManager.sucrose)

		KEY_5:
			# ─── Reset colony count
			GameManager.ant_count = 0
			GameManager.visual_ant_count = 0
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.queue_free()
			print("DEV: Colony reset")

		KEY_6:
			# ─── Print current state
			print("─── DEV STATE ───")
			print("Ants: ", GameManager.ant_count)
			print("Visual: ", GameManager.visual_ant_count)
			print("Sucrose: ", GameManager.sucrose)
			print("Colony: ", GameManager.active_colony.colony_name if GameManager.active_colony else "none")
			print("─────────────────")

		KEY_7:
			# ─── Force win battle (skip to prestige)
			EnemyColonies.advance()
			print("DEV: Skipped to queen ", EnemyColonies.current_index)
