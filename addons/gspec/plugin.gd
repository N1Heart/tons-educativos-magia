@tool
extends EditorPlugin

var _panel: Control = null

func _enter_tree() -> void:
	var plugin_dir: String = get_script().resource_path.get_base_dir()
	var PanelClass: GDScript = load(plugin_dir.path_join("editor/gspec_panel.gd")) as GDScript
	_panel = PanelClass.new() as Control
	add_control_to_bottom_panel(_panel, "GSpec")

func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
