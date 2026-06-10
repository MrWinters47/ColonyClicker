extends PanelContainer

func _ready() -> void:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(label)
	label.append_text("[color=white]OSENSIOUS SPECIES[/color]")
