extends PanelContainer

# =============================================================================
# ACTIVITY LOG — shows real-time ant behaviour in a compact panel
# =============================================================================

# ─── How often the log refreshes (seconds)
const TICK_INTERVAL: float = 0.5

var _log_label: RichTextLabel
var _timer: float = 0.0

# =============================================================================
# READY — build the label dynamically, no scene needed
# =============================================================================
func _ready() -> void:
	_log_label                     = RichTextLabel.new()
	_log_label.bbcode_enabled      = true
	_log_label.fit_content         = true
	_log_label.scroll_active       = false
	_log_label.custom_minimum_size = Vector2(200, 80)
	add_child(_log_label)

# =============================================================================
# PROCESS — tick every TICK_INTERVAL seconds
# =============================================================================
func _process(delta: float) -> void:
	_timer += delta
	if _timer >= TICK_INTERVAL:
		_timer = 0.0
		_refresh()

# =============================================================================
# REFRESH — scan all ants and build the activity summary
# =============================================================================
func _refresh() -> void:
	var ants      = get_tree().get_nodes_in_group("ants")
	var foraging  = 0
	var returning = 0

	# ─── Group eating ants by food type they're consuming
	var eating_by_type: Dictionary = {}

	for ant in ants:
		match ant.state:
			ant.State.FORAGING:
				foraging += 1

			ant.State.RETURNING, ant.State.DEPOSITING:
				returning += 1

			ant.State.EATING:
				# ─── Only count if the food node is still valid
				if is_instance_valid(ant._target_food):
					var label  = ant._target_food.get_type_label()
					var health = ant._target_food.get_health_pct()

					if not eating_by_type.has(label):
						eating_by_type[label] = {"count": 0, "health": 1.0}

					eating_by_type[label].count += 1

					# ─── Track the most consumed food of this type
					eating_by_type[label].health = min(eating_by_type[label].health, health)

	# ==========================================================================
	# BUILD DISPLAY
	# ==========================================================================
	_log_label.clear()

	# ─── Foraging ants
	if foraging > 0:
		_log_label.append_text("[color=white]🐜 Foraging: " + str(foraging) + "[/color]\n")

	# ─── Eating ants grouped by food type with consumption bar
	for type_label in eating_by_type:
		var data   = eating_by_type[type_label]
		var count  = data.count
		var health = data.health
		_log_label.append_text("[color=yellow]" + type_label + " ×" + str(count) + "[/color]\n")
		_log_label.append_text("[color=gray]Consuming [/color]" + _make_bar(health) + "\n")

	# ─── Returning ants
	if returning > 0:
		_log_label.append_text("[color=green]↩ Returning: " + str(returning) + "[/color]\n")

	# ─── Empty colony fallback
	if ants.size() == 0:
		_log_label.append_text("[color=gray]Colony is quiet...[/color]")

# =============================================================================
# HELPERS
# =============================================================================
func _make_bar(pct: float, width: int = 8) -> String:
	# ─── Unicode block progress bar — green filled, gray empty
	var filled = int(pct * width)
	var empty  = width - filled
	return "[color=green]" + "█".repeat(filled) + "[/color][color=gray]" + "░".repeat(empty) + "[/color]"
