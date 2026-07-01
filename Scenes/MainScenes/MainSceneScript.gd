extends Node2D

const AntScene        = preload("res://Scenes/MainScenes/BaseAnt.tscn")
const MainUI          = preload("res://Scenes/MainScenes/MainUI.tscn")
const CarpenterColony = preload("res://Data/Colonies/carpenter_ant.tres")
const RallyMarker     = preload("res://Scripts/Objects/RallyMarker.gd")

var colony_manager    = ColonyManager.new()
var _rally_marker: Node2D = null
var _overlay: ColorRect
var _overlay_label: Label
var _birth_sfx: AudioStreamPlayer

const SPAWN_TIERS = [
	{"threshold": 20,   "interval": 30.0,  "batch": 1},
	{"threshold": 50,   "interval": 15.0,  "batch": 1},
	{"threshold": 100,  "interval": 8.0,   "batch": 1},
	{"threshold": 500,  "interval": 3.0,   "batch": 1},
	{"threshold": 1000, "interval": 1.0,   "batch": 2},
	{"threshold": 5000, "interval": 0.5,   "batch": 3},
]
var _auto_spawn_timer: float = 0.0

const STARTER_ANTS: int     = 1
const VISUAL_ANT_COUNT: int = 120
const RAMP_MIDPOINT: float  = 1500.0
const RAMP_STEEPNESS: float = 2.5


func _ready() -> void:
	colony_manager.load_colony(CarpenterColony)      # default colony + seeds upgrade levels
	add_child(colony_manager)
	add_child(MainUI.instantiate())                  # UI only — it no longer loads
	EventBus.ant_spawned.connect(_on_ant_spawned)
	EventBus.prestige_triggered.connect(_on_prestige)
	_setup_overlay()
	_setup_birth_sfx()
	GameManager.colony_position = $ColonyEntrance.position

	# ─── Load AFTER UI + upgrade defs exist. false = fresh install.
	var had_save: bool = SaveManager.load_game()

	# ─── Fresh game only seeds the starter colony. A loaded game KEEPS its count.
	if not had_save:
		GameManager.ant_count = STARTER_ANTS

	EventBus.colony_loaded.emit(GameManager.active_colony)
	for i in STARTER_ANTS:
		_spawn_visual_ant()

	var cover_layer = get_tree().root.get_node_or_null("TransitionCover")
	if cover_layer:
		var rect = cover_layer.get_child(0)
		var t = create_tween()
		t.tween_property(rect, "modulate:a", 0.0, 0.4)
		t.finished.connect(cover_layer.queue_free)

	# show_once checks HelperPanel._seen, which load_game() just restored —
	# so returning players never see this again; fresh/reset players do.
	HelperPanel.show_once("INTRO", "WELCOME TO THE COLONY!", "TAP TO SPAWN ANTS.")


func _process(delta: float) -> void:
	_auto_spawn_timer += delta
	var interval = _get_auto_spawn_interval()
	if interval > 0 and _auto_spawn_timer >= interval:
		_auto_spawn_timer = 0.0
		_auto_spawn_batch()
	_maintain_visual_ants()


func _get_auto_spawn_interval() -> float:
	var count    = GameManager.ant_count
	var interval = -1.0
	for tier in SPAWN_TIERS:
		if count >= tier.threshold:
			interval = tier.interval
	return interval


func _auto_spawn_batch() -> void:
	var count = GameManager.ant_count
	var batch = 0
	for tier in SPAWN_TIERS:
		if count >= tier.threshold:
			batch = tier.batch
	GameManager.ant_count += batch
	EventBus.ant_spawned.emit(null)


func _get_visual_target() -> int:
	var c   = float(max(GameManager.ant_count, 1))
	var x   = log(c) / log(10.0)
	var mid = log(RAMP_MIDPOINT) / log(10.0)
	var t   = (x - mid) * RAMP_STEEPNESS
	var osa = float(VISUAL_ANT_COUNT) / (1.0 + exp(-t))
	return min(int(round(osa)), VISUAL_ANT_COUNT)


func _maintain_visual_ants() -> void:
	var target  = _get_visual_target()
	var current = GameManager.visual_ant_count
	if current < target:
		_spawn_visual_ant()


func _spawn_visual_ant() -> void:
	var ant = AntScene.instantiate()
	ant.position = GameManager.colony_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	add_child(ant)
	ant.setup(colony_manager)
	ant.scale = Vector2.ZERO
	var pop = create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(ant, "scale", Vector2.ONE, 0.35)
	_spawn_birth_puff(ant.position)
	_play_birth_sfx()
	EventBus.ant_spawned.emit(null)


func _spawn_birth_puff(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.position             = pos
	p.one_shot             = true
	p.explosiveness        = 1.0
	p.amount               = 10
	p.lifetime             = 0.5
	p.direction            = Vector2(0, -1)
	p.spread               = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity              = Vector2(0, 200)
	p.scale_amount_min     = 2.0
	p.scale_amount_max     = 4.0
	p.color                = Color(0.85, 0.7, 0.45)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _setup_birth_sfx() -> void:
	_birth_sfx = AudioStreamPlayer.new()
	add_child(_birth_sfx)
	var sfx_path = "res://Assets/Audio/399934__waveplaysfx__perc-short-clicksnap-perc.wav"
	if ResourceLoader.exists(sfx_path):
		_birth_sfx.stream = load(sfx_path)


func _play_birth_sfx() -> void:
	if _birth_sfx and _birth_sfx.stream:
		_birth_sfx.pitch_scale = randf_range(0.9, 1.15)
		_birth_sfx.play()


func _on_ant_spawned(_data) -> void:
	pass
	print("ANT SPAWNED")


func _setup_overlay() -> void:
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
	var tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.6)
	await tween.finished

	for ant in get_tree().get_nodes_in_group("ants"):
		ant.queue_free()

	GameManager.visual_ant_count = 0
	colony_manager.load_colony(GameManager.active_colony)

	GameManager.ant_count = STARTER_ANTS
	for i in STARTER_ANTS:
		_spawn_visual_ant()

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
