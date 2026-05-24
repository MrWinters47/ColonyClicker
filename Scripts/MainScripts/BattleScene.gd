extends PanelContainer

@onready var player_name    = $PlayerSide/HBoxContainer/VBoxContainer/PlayerName
@onready var player_bar     = $PlayerSide/HBoxContainer/VBoxContainer/PlayerBar
@onready var vs_label       = $PlayerSide/HBoxContainer/VsLabel
@onready var enemy_portrait = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyPortrait
@onready var enemy_name     = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyName
@onready var enemy_bar      = $PlayerSide/HBoxContainer/VBoxContainer2/EnemyBar
@onready var odds_bar       = $PlayerSide/OddsBar
@onready var battle_log     = $PlayerSide/RichTextLabel
@onready var fight_button   = $PlayerSide/FightButton
@onready var close_button   = $PlayerSide/CloseButton

var _log_entries: Array = []
var _log_index: int     = 0
var _max_player: int    = 1
var _max_enemy: int     = 1
var _timer: Timer

func _ready() -> void:
	fight_button.pressed.connect(_on_fight_pressed)
	close_button.pressed.connect(func(): hide())
	close_button.hide()
	_setup_timer()
	_show_enemy_info()

func _setup_timer() -> void:
	_timer          = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_show_next_log)
	add_child(_timer)

func _show_enemy_info() -> void:
	var enemy = EnemyColonies.get_current()
	var c     = GameManager.active_colony

	player_name.text = c.colony_name if c else "Your Colony"
	enemy_name.text  = enemy.name
	vs_label.text    = "VS"

	var p_force = max(GameManager.ant_count, 5) * 80
	var e_force = enemy.workers + enemy.soldiers

	player_bar.max_value = p_force
	player_bar.value     = p_force
	enemy_bar.max_value  = e_force
	enemy_bar.value      = e_force
	odds_bar.max_value   = p_force + e_force
	odds_bar.value       = p_force

	var portrait_tex = load(enemy.portrait) if ResourceLoader.exists(enemy.portrait) else null
	if portrait_tex:
		enemy_portrait.texture = portrait_tex

func _on_fight_pressed() -> void:
	fight_button.disabled = true
	battle_log.text       = ""
	_log_index            = 0

	var result   = BattleSystem.resolve(EnemyColonies.get_current())
	_log_entries = result.log
	_max_player  = result.max_player
	_max_enemy   = result.max_enemy
	_timer.start()

func _show_next_log() -> void:
	if _log_index >= _log_entries.size():
		_timer.stop()
		close_button.show()
		return

	var entry = _log_entries[_log_index]
	_log_index += 1

	# Update bars
	player_bar.value = entry.pf
	enemy_bar.value  = entry.ef

	# Show text
	battle_log.append_text("\n" + entry.text)

	# Handle result
	if entry.has("result") and entry.result == "player":
		EnemyColonies.advance()
		var next = EnemyColonies.get_current()
		if next.has("colony_stats") and ResourceLoader.exists(next.colony_stats):
			var new_stats = load(next.colony_stats)
			GameManager.prestige(new_stats)
		_show_victory_screen(EnemyColonies.queens[EnemyColonies.current_index - 1].name)
		fight_button.disabled = false

func _show_victory_screen(defeated_name: String) -> void:
	battle_log.append_text("\n\n[center][b]★ YOU ARE NOW " + defeated_name.to_upper() + " ★[/b][/center]")
	battle_log.append_text("\n[center]Upgrades reset. Colony transformed.[/center]")
	battle_log.append_text("\n[center]Perks carried forward.[/center]")
	battle_log.append_text("\n[center]The colony marches on.[/center]")
