# SaveManager.gd — Autoload
# Thin orchestrator. Each system writes/reads its OWN slice via save_data()/load_data().
# Add a saved value? Edit that system's two methods. This file barely ever changes.
extends Node

const SAVE_PATH        := "user://colony_save.json"
const SAVE_VERSION     := 1
const AUTOSAVE_SECONDS := 15.0

# Autoload systems that get saved. Add a brand-new SYSTEM here once. (Tutorials
# are handled separately below because HelperPanel is static, not a node.)
func _systems() -> Dictionary:
	return {
		"game":     GameManager,
		"upgrades": UpgradeManager,
		"enemies":  EnemyColonies,
		"perks":    PerkManager,
	}

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.timeout.connect(_auto_save)
	add_child(timer)
	timer.start()
	EventBus.prestige_triggered.connect(func(_c): save_game())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
	or what == NOTIFICATION_WM_GO_BACK_REQUEST \
	or what == NOTIFICATION_APPLICATION_PAUSED:
		_auto_save()

func _auto_save() -> void:
	if GameManager.ant_count <= 0 and GameManager.sucrose <= 0.0:
		return
	save_game(true)   # true → flash the "Auto-saved" toast

# =============================================================================
# SAVE
# =============================================================================
func save_game(is_auto: bool = false) -> void:
	var data := {"version": SAVE_VERSION}
	for key in _systems():
		var sys = _systems()[key]
		if sys and sys.has_method("save_data"):
			data[key] = sys.save_data()
	data["tutorials"] = HelperPanel.get_seen()   # static, called directly

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[Save] open failed: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if is_auto:
		_toast("Auto-saved")
	if OS.is_debug_build():
		print("[Save] written")
	EventBus.game_saved.emit()

# =============================================================================
# LOAD — call ONCE from Main._ready(). Returns true if a save existed.
# =============================================================================
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		if OS.is_debug_build(): print("[Save] no file — fresh start")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[Save] corrupt — ignoring")
		return false

	for key in _systems():
		var sys = _systems()[key]
		if sys and sys.has_method("load_data") and data.has(key):
			sys.load_data(data[key])
	if data.has("tutorials"):
		HelperPanel.load_seen(data["tutorials"])

	# Repaint the UI — labels already listen for these.
	EventBus.sucrose_changed.emit(GameManager.sucrose)
	EventBus.ant_spawned.emit(null)
	EventBus.game_loaded.emit()
	if OS.is_debug_build(): print("[Save] loaded")
	return true

# =============================================================================
# AUTO-SAVE TOAST — self-contained, needs zero scene setup
# =============================================================================
func _toast(msg: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var label := Label.new()
	label.text = "✓ " + msg
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 40
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1, 1, 1, 0)
	layer.add_child(label)
	get_tree().root.add_child(layer)

	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.2)
	t.tween_interval(0.9)
	t.tween_property(label, "modulate:a", 0.0, 0.4)
	t.tween_callback(layer.queue_free)

# =============================================================================
# DEV HELPERS
# =============================================================================
func peek_save() -> void:
	print("[Save] folder: ", OS.get_user_data_dir())
	if not FileAccess.file_exists(SAVE_PATH):
		print("[Save] NO FILE YET"); return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	print("[Save] contents:\n", file.get_as_text())
	file.close()

func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[Save] wiped")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
