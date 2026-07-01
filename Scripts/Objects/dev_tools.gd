extends CanvasLayer
# ═══════════════════════════════════════════════════════════════════════
# DEV TOOLS — debug builds only. Auto-deletes itself in exported releases.
# ═══════════════════════════════════════════════════════════════════════

var _overlay: Label

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()      # never ships to players
		return
	layer = 99            # always on top
	_build_overlay()

# ─── Tiny live readout in the top-left + a cheat sheet of the keys
func _build_overlay() -> void:
	_overlay = Label.new()
	_overlay.position    = Vector2(20, 20)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eats taps
	_overlay.add_theme_font_size_override("font_size", 30)
	_overlay.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 4)
	add_child(_overlay)

func _process(_delta: float) -> void:
	if not _overlay or not _overlay.visible:
		return
	var enemy = EnemyColonies.get_current()
	var total = EnemyColonies.queens.size()
	_overlay.text = "DEV  ·  %d FPS  ·  x%s\n\nSucrose:  %d\nColony:   %d   (on screen: %d)\nEnemy:    %s   (%d/%d)\n\n1/2 +ants   3/4 +sucrose   5 clear ants\n7 next queen   F speed   S save   L load\nR  FULL RESET (wipe save)   D  hide" % [
		Engine.get_frames_per_second(),
		str(Engine.time_scale),
		int(GameManager.sucrose),
		GameManager.ant_count,
		GameManager.visual_ant_count,
		enemy.name,
		EnemyColonies.current_index + 1,
		total,
	]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		# ── RESOURCES ──────────────────────────────────────────────────
		KEY_1:
			GameManager.ant_count += 100
			EventBus.ant_spawned.emit(null)
			print("DEV: +100 ants → ", GameManager.ant_count)
		KEY_2:
			GameManager.ant_count += 1000
			EventBus.ant_spawned.emit(null)
			print("DEV: +1000 ants → ", GameManager.ant_count)
		KEY_3:
			GameManager.add_sucrose(500.0)
			print("DEV: +500 sucrose → ", GameManager.sucrose)
		KEY_4:
			GameManager.add_sucrose(10000.0)
			print("DEV: +10000 sucrose → ", GameManager.sucrose)

		# ── CLEAR ANTS (resets counts + frees the visual ants) ─────────
		KEY_5:
			GameManager.ant_count        = 0
			GameManager.visual_ant_count = 0
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.queue_free()
			EventBus.ant_spawned.emit(null)
			print("DEV: ants cleared")

		# ── CONSOLE STATE DUMP (copy-pasteable for bug notes) ──────────
		KEY_6:
			print("─── DEV STATE ───")
			print("Ants:    ", GameManager.ant_count)
			print("Visual:  ", GameManager.visual_ant_count)
			print("Sucrose: ", GameManager.sucrose)
			print("Colony:  ", GameManager.active_colony.colony_name if GameManager.active_colony else "none")
			print("Enemy:   ", EnemyColonies.get_current().name)
			print("─────────────────")

		# ── SKIP TO NEXT QUEEN ─────────────────────────────────────────
		KEY_7:
			EnemyColonies.advance()
			print("DEV: skipped to queen ", EnemyColonies.current_index + 1)

		# ── FAST-FORWARD: cycle 1 → 2 → 4 → 8 → 1 ──────────────────────
		KEY_F:
			var speeds := [1.0, 2.0, 4.0, 8.0]
			var idx := speeds.find(Engine.time_scale)
			Engine.time_scale = speeds[(idx + 1) % speeds.size()]
			print("DEV: speed x", Engine.time_scale)

		# ── SAVE / LOAD (test the save system you just built) ──────────
		KEY_S:
			SaveManager.save_game()
			print("DEV: saved")
		KEY_L:
			SaveManager.load_game()
			print("DEV: loaded")

		# ── TOGGLE THE OVERLAY ─────────────────────────────────────────
		KEY_D:
			if _overlay:
				_overlay.visible = not _overlay.visible

		# ── FULL RESET: delete save + wipe state + reload scene ────────
		KEY_R:
			print("DEV: R pressed — starting full reset")
			_full_reset()
		KEY_P:
			SaveManager.peek_save()
		KEY_8:
			var dropped = PerkManager.roll_reward()
			print("DEV: dropped artifact → ", dropped)

# ─── Nuke everything back to a fresh install — for testing from scratch
func _full_reset() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)   # delete the save file

	GameManager.sucrose             = 0.0
	GameManager.sucrose_per_sec     = 0.0
	GameManager.ant_count           = 0
	GameManager.visual_ant_count    = 0
	GameManager.spawn_multiplier    = 0.0
	GameManager.ant_click_influence = 1
	EnemyColonies.reset()
	UpgradeManager.reset_levels()
	PerkManager.clear_perks()
	PerkManager.clear_perks()
	HelperPanel.reset_seen()   # ← ADD: fresh game shows the intro again

	print("DEV: FULL RESET — save deleted, starting fresh")
	get_tree().reload_current_scene()
