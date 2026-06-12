extends PanelContainer

# =============================================================================
# COLOR PALETTE — change once, applies everywhere
# =============================================================================
const COL_PLAYER   = Color(0.35, 0.65, 1.00)   # blue
const COL_ENEMY    = Color(0.95, 0.35, 0.30)   # red
const COL_BG       = Color(0.04, 0.04, 0.07)
const COL_PANEL    = Color(0.10, 0.10, 0.14)
const COL_TEXT     = Color(0.92, 0.92, 0.96)
const COL_DIM      = Color(0.92, 0.92, 0.96, 0.55)
const COL_GOLD     = Color(1.00, 0.78, 0.20)
const COL_VICTORY  = Color(0.35, 0.95, 0.45)
const COL_DEFEAT   = Color(0.95, 0.30, 0.30)

# =============================================================================
# REFERENCES — built in _build_ui, not from scene
# =============================================================================
var player_name_label:  Label
var enemy_name_label:   Label
var player_force_label: Label
var enemy_force_label:  Label
var enemy_portrait:     TextureRect
var momentum_bar:       ProgressBar
var momentum_label:     Label
var stat_grid:          GridContainer
var stat_chips: Dictionary = {}    # "player_atk" → Label
var battle_log:         RichTextLabel
var fight_button:       Button
var close_button:       Button
var speed_buttons:      HBoxContainer
var screen_tint:        ColorRect

# Pre-fight intro overlay
var intro_overlay:      PanelContainer
var intro_name:         Label
var intro_lore:         Label
var intro_perk:         Label
var intro_skip:         Label

# Big text flash
var flash_label:        Label
var _flash_tween:       Tween

# Results overlay
var results_overlay:    PanelContainer
var results_title:      Label
var results_stats:      Label
var results_perk:       Label
var prestige_button:    Button
var continue_button:    Button

# =============================================================================
# STATE
# =============================================================================
var _signals_connected: bool = false
var _shake_intensity: float  = 0.0
var _shake_timer: float      = 0.0
var _base_position: Vector2  = Vector2.ZERO
var _battle_in_progress: bool = false

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	_build_ui()
	_build_intro_overlay()
	_build_results_overlay()
	_connect_battle_signals()
	_show_enemy_info()
	_base_position = position

func _process(delta: float) -> void:
	# ─── Screen shake decay
	if _shake_timer > 0:
		_shake_timer -= delta
		var s = _shake_intensity * (_shake_timer / 0.4)
		position = _base_position + Vector2(randf_range(-s, s), randf_range(-s, s))
		if _shake_timer <= 0:
			position = _base_position

func _connect_battle_signals() -> void:
	if _signals_connected:
		return
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.tick_resolved.connect(_on_tick_resolved)
	BattleSystem.narrative_line.connect(_on_narrative_line)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	BattleSystem.crit_landed.connect(_on_crit)
	BattleSystem.queen_killed.connect(_on_queen_killed)
	_signals_connected = true

# =============================================================================
# UI BUILDER — full screen layout in code
# =============================================================================
func _build_ui() -> void:
	# ─── Clear any existing children from old scene
	for child in get_children():
		child.queue_free()

	# ─── Background style
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	add_theme_stylebox_override("panel", sb)

	# ─── Screen tint layer (sits behind everything else)
	screen_tint = ColorRect.new()
	screen_tint.color = Color(0, 0, 0, 0)
	screen_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_tint)

	# ─── Margin wrapper
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	root.add_child(_build_combatants_banner())
	root.add_child(_build_momentum_section())
	root.add_child(_build_stat_grid())
	root.add_child(_build_log_section())
	root.add_child(_build_bottom_bar())

	# ─── Flash label sits on top of everything
	flash_label = Label.new()
	flash_label.text = ""
	flash_label.add_theme_font_size_override("font_size", 64)
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash_label.set_anchors_preset(Control.PRESET_CENTER)
	flash_label.modulate.a = 0.0
	flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_label)

# ─── Combatants — portraits and force counts facing off
func _build_combatants_banner() -> PanelContainer:
	var panel := _make_panel()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	# Left: player
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(left)

	player_name_label = Label.new()
	player_name_label.add_theme_font_size_override("font_size", 22)
	player_name_label.add_theme_color_override("font_color", COL_PLAYER)
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(player_name_label)

	player_force_label = Label.new()
	player_force_label.add_theme_font_size_override("font_size", 36)
	player_force_label.add_theme_color_override("font_color", COL_TEXT)
	player_force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(player_force_label)

	# Center: VS badge
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 32)
	vs.add_theme_color_override("font_color", COL_GOLD)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(vs)

	# Right: enemy
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(right)

	enemy_name_label = Label.new()
	enemy_name_label.add_theme_font_size_override("font_size", 22)
	enemy_name_label.add_theme_color_override("font_color", COL_ENEMY)
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(enemy_name_label)

	enemy_force_label = Label.new()
	enemy_force_label.add_theme_font_size_override("font_size", 36)
	enemy_force_label.add_theme_color_override("font_color", COL_TEXT)
	enemy_force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(enemy_force_label)

	return panel

# ─── Momentum bar — THE heartbeat
func _build_momentum_section() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	momentum_label = Label.new()
	momentum_label.text = "MOMENTUM"
	momentum_label.add_theme_font_size_override("font_size", 16)
	momentum_label.add_theme_color_override("font_color", COL_DIM)
	momentum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(momentum_label)

	momentum_bar = ProgressBar.new()
	momentum_bar.show_percentage = false
	momentum_bar.custom_minimum_size.y = 28
	momentum_bar.max_value = 100
	momentum_bar.value = 50
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_ENEMY.darkened(0.3)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = COL_PLAYER
	fg.set_corner_radius_all(8)
	momentum_bar.add_theme_stylebox_override("background", bg)
	momentum_bar.add_theme_stylebox_override("fill", fg)
	box.add_child(momentum_bar)

	return panel

# ─── Stat grid — ATK / DEF / SPD / MORALE × 2 sides
func _build_stat_grid() -> PanelContainer:
	var panel := _make_panel()
	stat_grid = GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(stat_grid)

	var stats = ["ATK", "DEF", "SPD", "MORALE"]
	# Header row
	for s in stats:
		var lbl = _make_stat_header(s)
		stat_grid.add_child(lbl)
	# Player row
	for s in stats:
		var chip = _make_stat_chip(COL_PLAYER)
		stat_chips["player_" + s.to_lower()] = chip
		stat_grid.add_child(chip)
	# Enemy row
	for s in stats:
		var chip = _make_stat_chip(COL_ENEMY)
		stat_chips["enemy_" + s.to_lower()] = chip
		stat_grid.add_child(chip)

	return panel

func _make_stat_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", COL_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _make_stat_chip(color: Color) -> Label:
	var l := Label.new()
	l.text = "—"
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# ─── Battle log
func _build_log_section() -> PanelContainer:
	var panel := _make_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log = RichTextLabel.new()
	battle_log.bbcode_enabled = true
	battle_log.scroll_following = true
	battle_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log.add_theme_font_size_override("normal_font_size", 18)
	panel.add_child(battle_log)
	return panel

# ─── Bottom — fight button, speed, close
func _build_bottom_bar() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	fight_button = Button.new()
	fight_button.text = "⚔  FIGHT"
	fight_button.add_theme_font_size_override("font_size", 24)
	fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight_button.pressed.connect(_on_fight_pressed)
	box.add_child(fight_button)

	speed_buttons = HBoxContainer.new()
	speed_buttons.add_theme_constant_override("separation", 4)
	for label in ["1x", "2x", "4x"]:
		var b := Button.new()
		b.text = label
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_speed_pressed.bind(label))
		speed_buttons.add_child(b)
	box.add_child(speed_buttons)

	close_button = Button.new()
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(func(): hide())
	box.add_child(close_button)

	return box

func _make_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	return pc

# =============================================================================
# INTRO OVERLAY — shows enemy queen + lore, tap to skip
# =============================================================================
func _build_intro_overlay() -> void:
	intro_overlay = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.92)
	intro_overlay.add_theme_stylebox_override("panel", sb)
	intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_overlay.visible = false
	intro_overlay.gui_input.connect(_on_intro_tapped)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	intro_overlay.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var challenger := Label.new()
	challenger.text = "A CHALLENGER APPROACHES"
	challenger.add_theme_font_size_override("font_size", 18)
	challenger.add_theme_color_override("font_color", COL_GOLD)
	challenger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(challenger)

	intro_name = Label.new()
	intro_name.add_theme_font_size_override("font_size", 44)
	intro_name.add_theme_color_override("font_color", COL_ENEMY)
	intro_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro_name)

	intro_lore = Label.new()
	intro_lore.add_theme_font_size_override("font_size", 22)
	intro_lore.add_theme_color_override("font_color", COL_TEXT)
	intro_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro_lore)

	intro_perk = Label.new()
	intro_perk.add_theme_font_size_override("font_size", 18)
	intro_perk.add_theme_color_override("font_color", COL_GOLD)
	intro_perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro_perk)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	box.add_child(spacer)

	intro_skip = Label.new()
	intro_skip.text = "tap to continue"
	intro_skip.add_theme_font_size_override("font_size", 16)
	intro_skip.add_theme_color_override("font_color", COL_DIM)
	intro_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro_skip)

func _show_intro() -> void:
	var queen = EnemyColonies.get_current()
	intro_name.text = queen.name.to_upper()
	intro_lore.text = queen.get("lore", "")
	intro_perk.text = "Reward: " + queen.get("perk", "")
	intro_overlay.modulate.a = 0.0
	intro_overlay.show()
	var tween = create_tween()
	tween.tween_property(intro_overlay, "modulate:a", 1.0, 0.35)

func _on_intro_tapped(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_intro_and_fight()

func _close_intro_and_fight() -> void:
	var tween = create_tween()
	tween.tween_property(intro_overlay, "modulate:a", 0.0, 0.25)
	await tween.finished
	intro_overlay.hide()
	_start_battle_for_real()

# =============================================================================
# RESULTS OVERLAY
# =============================================================================
func _build_results_overlay() -> void:
	results_overlay = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.97)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(28)
	results_overlay.add_theme_stylebox_override("panel", sb)
	results_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_overlay.visible = false
	add_child(results_overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	results_overlay.add_child(box)

	results_title = Label.new()
	results_title.add_theme_font_size_override("font_size", 48)
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_title)

	results_stats = Label.new()
	results_stats.add_theme_font_size_override("font_size", 22)
	results_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(results_stats)

	results_perk = Label.new()
	results_perk.add_theme_font_size_override("font_size", 22)
	results_perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_perk.add_theme_color_override("font_color", COL_GOLD)
	box.add_child(results_perk)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	prestige_button = Button.new()
	prestige_button.add_theme_font_size_override("font_size", 26)
	prestige_button.pressed.connect(_on_prestige_pressed)
	box.add_child(prestige_button)

	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.pressed.connect(func(): results_overlay.hide())
	box.add_child(continue_button)

# =============================================================================
# ENEMY INFO REFRESH
# =============================================================================
func _show_enemy_info() -> void:
	var enemy = EnemyColonies.get_current()
	var c = GameManager.active_colony
	player_name_label.text = c.colony_name if c else "Your Colony"
	enemy_name_label.text = enemy.name

	var p_force = int(max(GameManager.ant_count, 5) * BattleSystem.ANT_FORCE_MULT)
	var e_force = enemy.workers + enemy.soldiers
	player_force_label.text = _fmt(p_force)
	enemy_force_label.text  = _fmt(e_force)

	# ─── Stat chips preview
	if c:
		stat_chips["player_atk"].text    = str(int(c.base_attack))
		stat_chips["player_def"].text    = str(int(c.base_defense))
		stat_chips["player_spd"].text    = "%.1f" % c.base_speed
		stat_chips["player_morale"].text = "100"
	stat_chips["enemy_atk"].text    = str(int(enemy.worker_dmg))
	stat_chips["enemy_def"].text    = str(int(enemy.armor))
	stat_chips["enemy_spd"].text    = "%.1f" % enemy.speed
	stat_chips["enemy_morale"].text = "100"

	# ─── Momentum starts based on force ratio
	var total = p_force + e_force
	momentum_bar.value = (float(p_force) / total) * 100.0 if total > 0 else 50.0

# =============================================================================
# FIGHT FLOW
# =============================================================================
func _on_fight_pressed() -> void:
	if _battle_in_progress:
		return
	_show_intro()

func _start_battle_for_real() -> void:
	_battle_in_progress = true
	fight_button.disabled = true
	results_overlay.hide()
	battle_log.text = ""
	_log_styled("⚔ THE BATTLE BEGINS ⚔", COL_GOLD, true)
	var enemy = EnemyColonies.get_current()
	_log_line("Your colony charges the %s colony!" % enemy.name)
	BattleSystem.start_battle(enemy)

func _on_speed_pressed(label: String) -> void:
	match label:
		"1x": BattleSystem.set_speed(1.0)
		"2x": BattleSystem.set_speed(2.0)
		"4x": BattleSystem.set_speed(4.0)

# =============================================================================
# BATTLE SIGNAL HANDLERS
# =============================================================================
func _on_battle_started(player: Dictionary, enemy: Dictionary) -> void:
	var p = player.workers + player.soldiers
	var e = enemy.workers + enemy.soldiers
	player_force_label.text = _fmt(p)
	enemy_force_label.text  = _fmt(e)

func _on_tick_resolved(snapshot: Dictionary) -> void:
	var p = snapshot.player.workers + snapshot.player.soldiers
	var e = snapshot.enemy.workers + snapshot.enemy.soldiers
	player_force_label.text = _fmt(p)
	enemy_force_label.text  = _fmt(e)

	# ─── Momentum bar — pure force ratio
	var total = p + e
	var target = (float(p) / total) * 100.0 if total > 0 else 50.0
	momentum_bar.value = lerp(momentum_bar.value, target, 0.25)

	# ─── Live morale
	stat_chips["player_morale"].text = str(int(snapshot.player.morale))
	stat_chips["enemy_morale"].text  = str(int(snapshot.enemy.morale))

	# ─── Screen tint — drifts red when losing, green when winning
	var lead = (float(p) / total) - 0.5 if total > 0 else 0.0
	var tint_a = clamp(abs(lead) * 0.4, 0.0, 0.3)
	var tint_c = COL_VICTORY if lead > 0 else COL_DEFEAT
	screen_tint.color = Color(tint_c.r, tint_c.g, tint_c.b, tint_a)

func _on_narrative_line(text: String) -> void:
	_log_line(text)

func _on_crit(side: String, text: String) -> void:
	_shake(8.0, 0.4)
	_flash("CRIT!", COL_GOLD)
	_log_styled(text, COL_GOLD, false)

func _on_queen_killed(side: String) -> void:
	_shake(14.0, 0.6)
	if side == "enemy":
		_flash("QUEEN DOWN!", COL_VICTORY)
	else:
		_flash("YOUR QUEEN!", COL_DEFEAT)

func _on_battle_ended(result: Dictionary) -> void:
	_battle_in_progress = false
	fight_button.disabled = false
	if result.winner == "player":
		_flash("VICTORY", COL_VICTORY)
		_shake(20.0, 0.8)
		await get_tree().create_timer(1.2).timeout
		_show_victory(result)
	else:
		_flash("DEFEAT", COL_DEFEAT)
		_shake(20.0, 0.8)
		await get_tree().create_timer(1.2).timeout
		_show_defeat(result)

# =============================================================================
# VICTORY / DEFEAT / PRESTIGE
# =============================================================================
func _show_victory(result: Dictionary) -> void:
	var queen = EnemyColonies.get_current()
	PerkManager.unlock_perk_by_id(queen.get("perk_id", ""))

	results_title.text = "★ VICTORY ★"
	results_title.add_theme_color_override("font_color", COL_VICTORY)
	results_stats.text = "Won by %s\nYour losses: %d%%   Enemy losses: %d%%" % [
		result.method, int(result.player_loss * 100), int(result.enemy_loss * 100)
	]

	var perk = PerkManager.perk_registry.get(queen.get("perk_id", ""), null)
	if perk:
		results_perk.text = "✦ NEW PERK UNLOCKED ✦\n%s — %s" % [perk.display_name, perk.description]
	else:
		results_perk.text = ""

	prestige_button.text = "👑 BECOME THE %s QUEEN" % queen.name.to_upper()
	prestige_button.show()
	results_overlay.show()

func _show_defeat(result: Dictionary) -> void:
	results_title.text = "DEFEAT"
	results_title.add_theme_color_override("font_color", COL_DEFEAT)
	results_stats.text = "Your losses: %d%%   Enemy losses: %d%%\nGrow the colony and try again." % [
		int(result.player_loss * 100), int(result.enemy_loss * 100)
	]
	results_perk.text = ""
	prestige_button.hide()
	results_overlay.show()

func _on_prestige_pressed() -> void:
	var queen = EnemyColonies.get_current()
	var new_stats = EnemyColonies.build_colony_stats(queen)
	GameManager.prestige(new_stats)
	EnemyColonies.advance()
	results_overlay.hide()
	screen_tint.color = Color(0, 0, 0, 0)
	battle_log.text = ""
	_log_styled("A new reign begins — %s." % queen.colony_name, COL_GOLD, true)
	_show_enemy_info()

# =============================================================================
# EFFECTS
# =============================================================================
func _shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _flash(text: String, color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.modulate.a = 0.0
	flash_label.scale = Vector2(0.7, 0.7)
	_flash_tween = create_tween().set_parallel(true)
	_flash_tween.tween_property(flash_label, "modulate:a", 1.0, 0.15)
	_flash_tween.tween_property(flash_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.chain().tween_property(flash_label, "modulate:a", 0.0, 0.4).set_delay(0.5)

func _log_line(text: String) -> void:
	battle_log.append_text("\n" + text)

func _log_styled(text: String, color: Color, big: bool) -> void:
	var hex = color.to_html(false)
	if big:
		battle_log.append_text("\n[center][b][color=#%s]%s[/color][/b][/center]" % [hex, text])
	else:
		battle_log.append_text("\n[color=#%s]%s[/color]" % [hex, text])

func _fmt(n: int) -> String:
	# Comma formatting for big numbers — 12,500 not 12500
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result
