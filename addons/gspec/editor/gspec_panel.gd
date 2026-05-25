@tool
extends VBoxContainer

const _SPEC_DIR: String = "res://spec"

var _run_btn: Button = null
var _file_btn: Button = null
var _filter_input: LineEdit = null
var _tree: Tree = null
var _summary: Label = null
var _running: bool = false

func _ready() -> void:
	_build_ui()

#region UI

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 200)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Toolbar
	var toolbar: HBoxContainer = HBoxContainer.new()
	add_child(toolbar)

	_run_btn = Button.new()
	_run_btn.text = "▶  Run All"
	_run_btn.tooltip_text = "Run all specs under res://spec/"
	_run_btn.pressed.connect(_on_run_all)
	toolbar.add_child(_run_btn)

	_file_btn = Button.new()
	_file_btn.text = "▶  Run Current File"
	_file_btn.tooltip_text = "Run the *_spec.gd currently open in the script editor"
	_file_btn.pressed.connect(_on_run_file)
	toolbar.add_child(_file_btn)

	toolbar.add_child(VSeparator.new())

	var filter_label: Label = Label.new()
	filter_label.text = "Filter:"
	toolbar.add_child(filter_label)

	_filter_input = LineEdit.new()
	_filter_input.placeholder_text = "Run only tests whose name contains…"
	_filter_input.tooltip_text = "Case-insensitive substring match against the full test path.\nExample: \"crit\" runs every it(...) whose describe > context > it path contains \"crit\".\nLeave empty to run all tests."
	_filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_filter_input)

	# Tree — click the arrow to collapse/expand groups
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 150)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	add_child(_tree)

	# Summary bar
	_summary = Label.new()
	_summary.text = "Ready — press ▶ Run All to start."
	add_child(_summary)

#endregion

#region Handlers

func _on_run_all() -> void:
	if _running:
		return
	var runner: SpecRunner = _make_runner()
	runner.discover(_SPEC_DIR)
	await _execute(runner)

func _on_run_file() -> void:
	if _running:
		return
	var script: Script = EditorInterface.get_script_editor().get_current_script()
	if script == null or not script.resource_path.ends_with("_spec.gd"):
		_summary.text = "⚠  No *_spec.gd file open in the script editor."
		_summary.add_theme_color_override("font_color", Color.html("#fd971f"))
		return
	var runner: SpecRunner = _make_runner()
	runner.add_spec_file(script.resource_path)
	var success: bool = await _execute(runner)
	if not success and _filter_input.text.is_empty():
		_expand_all(_tree.get_root())

#endregion

#region Navigation

func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null or not item.has_meta("file"):
		return
	var file_path: String = item.get_meta("file")
	var script: GDScript = load(file_path) as GDScript
	if script == null:
		return
	var line: int = -1
	if item.has_meta("desc"):
		line = _find_line(script.source_code, item.get_meta("desc"))
	if line >= 0:
		EditorInterface.edit_script(script, line, 0)
	else:
		EditorInterface.edit_resource(script)

func _find_line(source: String, description: String) -> int:
	var lines: PackedStringArray = source.split("\n")
	var needle: String = '"%s"' % description
	for i: int in range(lines.size()):
		if needle in lines[i]:
			return i + 1
	return -1

#endregion

#region Helpers

func _make_runner() -> SpecRunner:
	var runner: SpecRunner = SpecRunner.new(GSpecEditorFormatter.new(_tree, _summary))
	if not _filter_input.text.is_empty():
		runner.set_filter(_filter_input.text)
	return runner

func _execute(runner: SpecRunner) -> bool:
	_running = true
	_run_btn.disabled = true
	_file_btn.disabled = true
	var success: bool = await runner.run()
	if not _filter_input.text.is_empty():
		_expand_all(_tree.get_root())
	_run_btn.disabled = false
	_file_btn.disabled = false
	_running = false
	return success

func _expand_all(item: TreeItem) -> void:
	if item == null:
		return
	item.collapsed = false
	var child: TreeItem = item.get_first_child()
	while child != null:
		_expand_all(child)
		child = child.get_next()

#endregion
