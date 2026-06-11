extends Node2D
# element_panel.gd — Perk collection + equip screen
# Tap any perk → detail card → Equip / Unequip.
# Locked perks are visible but greyed (Egg Inc style — show the player the future).

const DEBUG_FILL := true   # true = unlock + equip test perks on launch

const RARITY_COLORS := {
	PerkDef.Rarity.COMMON:    Color(0.78, 0.78, 0.78),
	PerkDef.Rarity.RARE:      Color(0.35, 0.65, 1.0),
	PerkDef.Rarity.EPIC:      Color(0.75, 0.45, 1.0),
	PerkDef.Rarity.LEGENDARY: Color(1.0, 0.65, 0.2),
}

const RARITY_NAMES := {
	PerkDef.Rarity.COMMON:    "COMMON",
	PerkDef.Rarity.RARE:      "RARE",
	PerkDef.Rarity.EPIC:      "EPIC",
	PerkDef.Rarity.LEGENDARY: "LEGENDARY",
}

const STAT_LABELS := {
	"sucrose_gain":   "Sucrose Gain",
	"forage_speed":   "Forage Speed",
	"spawn_speed":    "Spawn Speed",
	"battle_attack":  "Battle Attack",
	"battle_defense": "Battle Defense",
}

@onready var panel: Panel = $Panel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var slots_box: VBoxContainer
var collection_box: VBoxContainer
var equipped_label: Label

# ─── Detail card nodes
var detail_card: PanelContainer
var detail_name: Label
var detail_rarity: Label
var detail_desc: Label
var detail_stat: Label
var detail_action: Button
var _detail_perk: PerkDef = null

func _ready() -> void:
	_build_layout()
	_build_detail_card()
	EventBus.perks_changed.connect(_refresh)
	if DEBUG_FILL:
		PerkManager.unlock_perk_by_id("strong_mandibles")
		PerkManager.unlock_perk_by_id("chitin_plating")
		PerkManager.activate_perk_by_id("strong_mandibles")
	_refresh()

func open_panel() -> void:
	animation_player.play("SWOOP")

func close_panel() -> void:
	detail_card.hide()
	animation_player.play_backwards("SWOOP")

# =============================================================================
# LAYOUT
# =============================================================================
func _build_layout() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "PERKS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	root_box.add_child(title)

	# ─── Equipped section
	equipped_label = Label.new()
	equipped_label.add_theme_font_size_override("font_size", 22)
	equipped_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root_box.add_child(equipped_label)

	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 10)
	root_box.add_child(slots_box)

	# ─── Collection section
	var coll_title := Label.new()
	coll_title.text = "COLLECTION"
	coll_title.add_theme_font_size_override("font_size", 22)
	coll_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root_box.add_child(coll_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(scroll)

	collection_box = VBoxContainer.new()
	collection_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_box.add_theme_constant_override("separation", 10)
	scroll.add_child(collection_box)

# =============================================================================
# REFRESH — rebuild slots + collection from PerkManager state
# =============================================================================
func _refresh() -> void:
	for child in slots_box.get_children():
		slots_box.remove_child(child)
		child.queue_free()
	for child in collection_box.get_children():
		collection_box.remove_child(child)
		child.queue_free()

	var active: Array = PerkManager.get_active_list()
	equipped_label.text = "EQUIPPED  %d / %d" % [active.size(), PerkManager.MAX_PERKS]

	# ─── Equipped slots
	for i in PerkManager.MAX_PERKS:
		if i < active.size():
			slots_box.add_child(_make_perk_row(active[i], true))
		else:
			slots_box.add_child(_make_empty_slot())

	# ─── Full collection — locked perks shown greyed
	for id in PerkManager.perk_registry:
		var perk: PerkDef = PerkManager.perk_registry[id]
		collection_box.add_child(_make_perk_row(perk, false))

# =============================================================================
# ROW BUILDERS
# =============================================================================
func _make_perk_row(perk: PerkDef, is_slot: bool) -> PanelContainer:
	var row := _make_slot_base()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(perk))

	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(box)

	var name_label := Label.new()
	name_label.text = perk.display_name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", RARITY_COLORS[perk.rarity])
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = perk.description
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc_label)

	# ─── Status tag on the right
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not PerkManager.is_unlocked(perk.id):
		status.text = "🔒"
		row.modulate = Color(0.55, 0.55, 0.55, 1.0)
	elif PerkManager.is_active(perk.id) and not is_slot:
		status.text = "EQUIPPED"
		status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	hbox.add_child(status)

	return row

func _make_empty_slot() -> PanelContainer:
	var slot := _make_slot_base()
	var empty_label := Label.new()
	empty_label.text = "—  empty slot  —"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	slot.add_child(empty_label)
	return slot

func _make_slot_base() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	return pc

# =============================================================================
# DETAIL CARD — the "what does this do" popup
# =============================================================================
func _build_detail_card() -> void:
	detail_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.97)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(24)
	detail_card.add_theme_stylebox_override("panel", sb)
	detail_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_card.visible = false
	panel.add_child(detail_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	detail_card.add_child(box)

	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 34)
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail_name)

	detail_rarity = Label.new()
	detail_rarity.add_theme_font_size_override("font_size", 20)
	detail_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail_rarity)

	detail_desc = Label.new()
	detail_desc.add_theme_font_size_override("font_size", 24)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail_desc)

	detail_stat = Label.new()
	detail_stat.add_theme_font_size_override("font_size", 20)
	detail_stat.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	detail_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail_stat)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	detail_action = Button.new()
	detail_action.add_theme_font_size_override("font_size", 26)
	detail_action.pressed.connect(_on_detail_action)
	box.add_child(detail_action)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func(): detail_card.hide())
	box.add_child(close_btn)

func _open_detail(perk: PerkDef) -> void:
	_detail_perk = perk
	detail_name.text = perk.display_name
	detail_name.add_theme_color_override("font_color", RARITY_COLORS[perk.rarity])
	detail_rarity.text = RARITY_NAMES[perk.rarity]
	detail_rarity.add_theme_color_override("font_color", RARITY_COLORS[perk.rarity])
	detail_desc.text = perk.description
	detail_stat.text = "%s  ×%.2f" % [STAT_LABELS.get(perk.stat_target, perk.stat_target), perk.multiplier]

	# ─── Action button reflects current state
	if not PerkManager.is_unlocked(perk.id):
		detail_action.text = "🔒 DEFEAT QUEENS TO UNLOCK"
		detail_action.disabled = true
	elif PerkManager.is_active(perk.id):
		detail_action.text = "UNEQUIP"
		detail_action.disabled = false
	elif PerkManager.get_active_list().size() >= PerkManager.MAX_PERKS:
		detail_action.text = "SLOTS FULL"
		detail_action.disabled = true
	else:
		detail_action.text = "EQUIP"
		detail_action.disabled = false

	detail_card.show()

func _on_detail_action() -> void:
	if _detail_perk == null:
		return
	if PerkManager.is_active(_detail_perk.id):
		PerkManager.remove_perk(_detail_perk.id)
	else:
		PerkManager.activate_perk_by_id(_detail_perk.id)
	detail_card.hide()

# =============================================================================
# INPUT — tap a row to open its detail card
# =============================================================================
func _on_row_input(event: InputEvent, perk: PerkDef) -> void:
	if event is InputEventMouseButton and event.pressed:
		_open_detail(perk)
