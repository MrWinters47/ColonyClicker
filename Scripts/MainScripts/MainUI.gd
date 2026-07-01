extends CanvasLayer

# =============================================================================
# NODE REFERENCES
# =============================================================================
@onready var sucrose_label  = $TopBar/Control/SucroseLabel
@onready var ant_label      = $TopBar/Control/AntsLabel
@onready var upgrade_btn    = $UpgradeButton
@onready var upgrade_panel  = $UpgradePanel
@onready var spawn_button   = $SpawnButton
@onready var spawn_progress = $SpawnProgress
@onready var battle_panel   = $BattleScene
@onready var battle_button  = $BattleButton
@onready var perk_panel     = $ElementPanel
@onready var perks_button   = $PerksButton
@onready var battle_meter   = $TopBar/Control/BattleMeterProgress

# =============================================================================
# SPAWN SETTINGS
# =============================================================================
const SPAWN_TIME_BASE: float = 2.0
const SPAWN_TIME_MIN:  float = 0.1
var _spawning: bool = false
@export var base_spawn: int = 1
var _spawn_remainder: float = 0.0

var _perks_open: bool = false
var _prev_osa: int = 0

# =============================================================================
# ⚙️ BATTLE READINESS — the ONE knob to tune
# =============================================================================
# Threshold = current enemy's total force × this ratio (floored at MIN).
# Fire Ant has 1000 force → 0.15 means you need 150 colony ants to fight it.
#   • Lower  = battles unlock SOONER
#   • Higher = you must build a bigger army first
const BATTLE_READINESS_RATIO: float = 0.15
const MIN_BATTLE_THRESHOLD:   float = 30.0

var _meter_target: float = 0.0   # 0..max_value; the bar lerps toward this
var _was_ready: bool     = false # so we flash the unlock only ONCE

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	EventBus.sucrose_changed.connect(_on_sucrose_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.colony_loaded.connect(func(_c): _update_ant_label())
	EventBus.ant_spawned.connect(func(_a): _update_ant_label())
	EventBus.ant_died.connect(func(_a): _update_ant_label())

	upgrade_btn.pressed.connect(_on_upgrade_btn_pressed)
	spawn_button.pressed.connect(_on_spawn_pressed)
	battle_button.pressed.connect(_on_battle_btn_pressed)
	perks_button.pressed.connect(_on_perks_btn_pressed)

	upgrade_panel.hide()
	battle_panel.hide()
	perk_panel.hide()
	spawn_progress.value     = 0
	spawn_progress.max_value = 100
	sucrose_label.text       = "Sucrose: 0"
	_prev_osa = GameManager.visual_ant_count
	_update_ant_label()

	_refresh_battle_state()
	battle_meter.value = _meter_target
	EventBus.game_loaded.connect(_update_ant_label)

# =============================================================================
# PROCESS — glide the meter toward its target (cheap, smooth, no tween stacking)
# =============================================================================
func _process(delta: float) -> void:
	battle_meter.value = lerp(battle_meter.value, _meter_target, 8.0 * delta)

# =============================================================================
# PANEL MANAGEMENT — single source of truth
# =============================================================================
func _close_all_panels() -> void:
	if upgrade_panel.visible:
		upgrade_panel.hide()
	if battle_panel.visible:
		battle_panel.hide()
	if _perks_open:
		_close_perks_immediate()

func _close_perks_immediate() -> void:
	_perks_open = false
	if perk_panel.has_method("close_panel"):
		perk_panel.close_panel()
	perk_panel.hide()

# =============================================================================
# PANEL TOGGLES
# =============================================================================
func _on_upgrade_btn_pressed() -> void:
	if upgrade_panel.visible:
		upgrade_panel.hide()
	else:
		_close_all_panels()
		upgrade_panel.show()

func _on_battle_btn_pressed() -> void:
	# ─── Button is disabled until the meter's full, so this only fires when ready
	if battle_panel.visible:
		battle_panel.hide()
	else:
		_close_all_panels()
		battle_panel.show()

func _on_perks_btn_pressed() -> void:
	if _perks_open:
		_perks_open = false
		if perk_panel.has_method("close_panel"):   # ★ NEW guard
			perk_panel.close_panel()
		await get_tree().create_timer(0.5).timeout
		perk_panel.hide()
	else:
		_close_all_panels()
		perk_panel.show()
		if perk_panel.has_method("open_panel"):     # ★ NEW guard
			perk_panel.open_panel()
		_perks_open = true

# =============================================================================
# SPAWN BUTTON
# =============================================================================
func _on_spawn_pressed() -> void:
	if _spawning:
		return
	_spawning             = true
	spawn_button.disabled = true
	var tween = create_tween()
	tween.tween_property(spawn_progress, "value", 100.0, _current_spawn_time())
	tween.finished.connect(_on_spawn_complete)

func _current_spawn_time() -> float:
	var def = UpgradeManager.get_def("faster_hatchery")
	if not def:
		return SPAWN_TIME_BASE
	var lvl  = UpgradeManager.get_level("faster_hatchery")
	var maxl = max(def.max_level, 1)
	return lerp(SPAWN_TIME_BASE, SPAWN_TIME_MIN, float(lvl) / float(maxl))

func _on_spawn_complete() -> void:
	var reward: int = base_spawn

	_spawn_remainder += base_spawn * GameManager.spawn_multiplier
	if _spawn_remainder >= 1.0:
		var bonus: int = int(_spawn_remainder)
		reward += bonus
		_spawn_remainder -= bonus

	GameManager.ant_count += reward
	EventBus.ant_spawned.emit(null)

	spawn_progress.value  = 0
	spawn_button.disabled = false
	_spawning             = false
	_update_ant_label()
	play_sfx($Click)

func play_sfx(player: AudioStreamPlayer2D) -> void:
	player.pitch_scale = randf_range(0.85, 1.15)
	player.play()

# =============================================================================
# LABEL UPDATES
# =============================================================================
func _on_sucrose_changed(amount: float) -> void:
	sucrose_label.text = "Sucrose: " + str(int(amount))
	$Sugar_fx.play()

func _update_ant_label() -> void:
	var colony = GameManager.active_colony
	var cname  = colony.colony_name if colony else "Colony"
	ant_label.text = "%s\nColony %s  •  %d on the surface" % [
		cname,
		_abbrev(GameManager.ant_count),
		GameManager.visual_ant_count,
	]

	if GameManager.visual_ant_count > _prev_osa:
		_flash_osa()
	_prev_osa = GameManager.visual_ant_count

	# ─── Colony changed → re-evaluate battle readiness
	_refresh_battle_state()

func _flash_osa() -> void:
	ant_label.modulate = Color(1.4, 1.2, 0.4)
	var t = create_tween()
	t.tween_property(ant_label, "modulate", Color(1, 1, 1, 1), 0.4)

func _abbrev(n: int) -> String:
	if n < 1000:
		return str(n)
	var f = float(n)
	var units = ["K", "M", "B", "T"]
	var idx = -1
	while f >= 1000.0 and idx < units.size() - 1:
		f /= 1000.0
		idx += 1
	var s = "%.2f" % f
	s = s.rstrip("0").rstrip(".")
	return s + units[idx]

# =============================================================================
# BATTLE METER + LOCK
# =============================================================================
func _battle_threshold() -> float:
	# ─── How big your colony must be to fight the CURRENT enemy
	var enemy = EnemyColonies.get_current()
	var force = float(enemy.workers + enemy.soldiers)
	return max(force * BATTLE_READINESS_RATIO, MIN_BATTLE_THRESHOLD)

func _refresh_battle_state() -> void:
	var threshold = _battle_threshold()
	var ready     = GameManager.ant_count >= threshold

	# ─── Set the bar's target (0..max_value) — _process glides to it
	var pct = clamp(float(GameManager.ant_count) / threshold, 0.0, 1.0)
	_meter_target = pct * battle_meter.max_value

	# ─── Lock / unlock the battle button
	battle_button.disabled = not ready
	battle_button.modulate = Color(1, 1, 1, 1) if ready else Color(0.55, 0.55, 0.55, 1.0)

	# ─── Flash gold the moment it first unlocks — make it an EVENT
	if ready and not _was_ready:
		_flash_battle_ready()
	_was_ready = ready

func _flash_battle_ready() -> void:
	battle_button.modulate = Color(1.6, 1.4, 0.5)
	var t = create_tween()
	t.tween_property(battle_button, "modulate", Color(1, 1, 1, 1), 0.5)

# =============================================================================
# UPGRADE EFFECTS
# =============================================================================
func _on_upgrade_purchased(id: String) -> void:
	_apply_upgrade(id)

func _apply_upgrade(id: String) -> void:
	match id:
		"faster_legs":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.10, 300.0)
		"sprinter_genes":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.speed = min(ant.speed * 1.05, 350.0)
		"royal_pheromones":
			GameManager.spawn_multiplier += 0.10
		"better_nose":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.5
		"hawk_eyes":
			for ant in get_tree().get_nodes_in_group("ants"):
				ant.food_awareness_radius *= 1.25
		"click_influence":
			GameManager.ant_click_influence += 1
		"bigger_colony":
			GameManager.ant_count += 20
			EventBus.ant_spawned.emit(null)

# =============================================================================
# ANIMATION HOOKS
# =============================================================================
func _on_battle_button_pressed() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("fullscreen_for_battle")

func _on_return_ui_button_pressed() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play_backwards("fullscreen_for_battle")
