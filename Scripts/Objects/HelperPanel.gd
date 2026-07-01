extends CanvasLayer
class_name HelperPanel

# ─── Which HPs the player has already seen.
# SAVE HOOK: when the save system lands, serialize this dict (or move it into
# GameManager) and "first-run only" survives restarts. For now it's session-only.
static var _seen: Dictionary = {}

var _backdrop: ColorRect
var _card: PanelContainer

# =============================================================================
# STATIC API — call from anywhere, no preload needed (thanks to class_name)
# =============================================================================



## Always shows the panel. Use this for an ⓘ info button.
static func show_panel(title: String, body: String) -> HelperPanel:
	var tree := Engine.get_main_loop() as SceneTree
	var hp := HelperPanel.new()
	tree.root.add_child(hp)
	hp._build(title, body)
	return hp

## Shows ONLY the first time this id appears. Use for first-run popups.
static func show_once(id: String, title: String, body: String) -> void:
	if _seen.get(id, false):
		return
	_seen[id] = true
	show_panel(title, body)

## Wipe seen flags — handy for testing ("replay the tutorials").
static func reset_seen() -> void:
	_seen.clear()

# =============================================================================
# BUILD — all UI made in code
# =============================================================================
func _build(title: String, body: String) -> void:
	layer = 50  # above gameplay + UI, below dev tools (99)

	# ─── Dark backdrop that blocks clicks to the game behind
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)              # alpha fades in below
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# ─── Centering wrapper
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# ─── The card
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(760, 0)
	_card.modulate = Color(1, 1, 1, 0)               # fades in
	center.add_child(_card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	# ─── Title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# ─── Body (wraps automatically)
	var body_label = Label.new()
	body_label.text = body
	body_label.add_theme_font_size_override("font_size", 28)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(body_label)

	# ─── Close button
	var close_btn = Button.new()
	close_btn.text = "Got it"
	close_btn.custom_minimum_size = Vector2(0, 64)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

	# ─── Fade in
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(_backdrop, "color:a", 0.6, 0.2)
	t.tween_property(_card, "modulate:a", 1.0, 0.2)


func _close() -> void:
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(_backdrop, "color:a", 0.0, 0.2)
	t.tween_property(_card, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(queue_free)

static func get_seen() -> Dictionary:
	return _seen.duplicate()

static func load_seen(d: Dictionary) -> void:
	for id in d:
		_seen[id] = bool(d[id])
