extends Node2D


const AntScene        = preload("res://Scenes/MainScenes/BaseAnt.tscn")
const MainUI          = preload("res://Scenes/MainScenes/MainUI.tscn")
const CarpenterColony = preload("res://Data/Colonies/carpenter_ant.tres")
const RallyMarker     = preload("res://Scripts/Objects/RallyMarker.gd")

var colony_manager    = ColonyManager.new()
var _rally_marker: Node2D = null
var _overlay: ColorRect
var _overlay_label: Label


# ─── Auto-spawn tiers — once colony hits threshold, auto-add this batch every interval
const SPAWN_TIERS = [
	{"threshold": 20,   "interval": 30.0,  "batch": 1},
	{"threshold": 50,   "interval": 15.0,  "batch": 1},
	{"threshold": 100,  "interval": 8.0,   "batch": 1},
	{"threshold": 500,  "interval": 3.0,   "batch": 1},
	{"threshold": 1000, "interval": 1.0,   "batch": 2},
	{"threshold": 5000, "interval": 0.5,   "batch": 3},
]
var _auto_spawn_timer: float = 0.0

# ─── Visual ant threshold config — tune these 3 values to control pacing
const VISUAL_ANT_COUNT: int   = 150    # max ants ever shown on screen
const THRESHOLD_BASE: float   = 50.0  # real ant count to unlock the 1st visual ant
const THRESHOLD_SCALE: float  = 2  # curve steepness — try 1.25 to 1.5

var visual_thresholds: Array = []

func _build_thresholds() -> void:
	# ─── Generate thresholds mathematically instead of hardcoding 25 values
	visual_thresholds.clear()
	for i in range(VISUAL_ANT_COUNT):
		var t = int(THRESHOLD_BASE * pow(THRESHOLD_SCALE, i))
		visual_thresholds.append(t)


func _ready() -> void:
	colony_manager.load_colony(CarpenterColony)
	add_child(colony_manager)
	add_child(MainUI.instantiate())
	EventBus.ant_spawned.connect(_on_ant_spawned)
	EventBus.prestige_triggered.connect(_on_prestige)
	_setup_overlay()
	EventBus.colony_loaded.emit(GameManager.active_colony)
	GameManager.colony_position = $ColonyEntrance.position
	_build_thresholds()


func _process(delta: float) -> void:
	# ─── Auto-spawn ticker — adds to real count only
	_auto_spawn_timer += delta
	var interval = _get_auto_spawn_interval()
	if interval > 0 and _auto_spawn_timer >= interval:
		_auto_spawn_timer = 0.0
		_auto_spawn_batch()

	# ─── Keep visual ants in sync with thresholds
	_maintain_visual_ants()


func _get_auto_spawn_interval() -> float:
	# ─── Find highest matching tier for current colony size
	var count    = GameManager.ant_count
	var interval = -1.0
	for tier in SPAWN_TIERS:
		if count >= tier.threshold:
			interval = tier.interval
	return interval


func _auto_spawn_batch() -> void:
	# ─── Add ants to real count — visual maintenance handles the rest
	var count = GameManager.ant_count
	var batch = 0
	for tier in SPAWN_TIERS:
		if count >= tier.threshold:
			batch = tier.batch
	GameManager.ant_count += batch
	EventBus.ant_spawned.emit(null)


func _get_visual_target() -> int:
	# ─── Count how many thresholds the colony has passed
	# FIX: was referencing VISUAL_THRESHOLDS (old const) — now uses visual_thresholds (the built array)
	var count  = GameManager.ant_count
	var target = 0
	for threshold in visual_thresholds:
		if count >= threshold:
			target += 1
		else:
			break
	return min(target, VISUAL_ANT_COUNT)


func _maintain_visual_ants() -> void:
	# ─── Spawn a visual ant if colony has unlocked more than are on screen
	var target  = _get_visual_target()
	var current = GameManager.visual_ant_count
	if current < target:
		_spawn_visual_ant()


func _spawn_visual_ant() -> void:
	var ant = AntScene.instantiate()
	ant.position = GameManager.colony_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	add_child(ant)
	ant.setup(colony_manager)
	EventBus.ant_spawned.emit(null)


func _on_ant_spawned(_data) -> void:
	# ─── Signal received — visual maintenance in _process handles spawning
	pass


func _setup_overlay() -> void:
	# ─── Full screen fade overlay for prestige transition
	var layer               = CanvasLayer.new()
	layer.layer             = 10
	_overlay                = ColorRect.new()
	_overlay.color          = Color(0, 0, 0, 0)
	_overlay.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_label          = Label.new()
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 32)
	_overlay_label.modulate = Color(1, 1, 1, 0)
	layer.add_child(_overlay)
	layer.add_child(_overlay_label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		var world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_show_rally_marker(world_pos)
		var forage_ants = get_tree().get_nodes_in_group("ants").filter(
			func(a): return a.state == a.State.FORAGING
		)
		forage_ants.sort_custom(func(a, b):
			return a.global_position.distance_to(world_pos) < b.global_position.distance_to(world_pos)
		)
		for ant in forage_ants.slice(0, GameManager.ant_click_influence):
			ant.command_to_pos(world_pos)


func _show_rally_marker(pos: Vector2) -> void:
	# ─── Orange ring at click position
	if is_instance_valid(_rally_marker):
		_rally_marker.queue_free()
	var marker = Node2D.new()
	marker.set_script(RallyMarker)
	marker.position = pos
	add_child(marker)
	_rally_marker = marker


func _on_prestige(new_colony) -> void:
	colony_manager.reset()
	_run_transition(new_colony.colony_name)


func _run_transition(species_name: String) -> void:
	# ─── Fade to black, show new species name, reset world
	var tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.6)
	await tween.finished

	for ant in get_tree().get_nodes_in_group("ants"):
		ant.queue_free()

	# ─── Reset visual count so threshold system starts fresh after prestige
	GameManager.visual_ant_count = 0

	colony_manager.load_colony(GameManager.active_colony)

	_overlay_label.text = "YOU ARE NOW\n" + species_name.to_upper()
	var label_tween = create_tween()
	label_tween.tween_property(_overlay_label, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(2.0).timeout

	label_tween = create_tween()
	label_tween.tween_property(_overlay_label, "modulate:a", 0.0, 0.3)
	await label_tween.finished

	EventBus.colony_loaded.emit(GameManager.active_colony)

	tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.6)
