@tool
class_name GSpecEditorFormatter
extends SpecBaseFormatter

var _tree: Tree
var _summary: Label
var _current_file: String = ""

## Stack of TreeItems mirroring the current describe/context nesting.
var _item_stack: Array[TreeItem] = []

## Per-item stats: TreeItem.get_instance_id() → {passed, failed, pending}
var _stats: Dictionary = {}

func _init(tree: Tree, summary: Label) -> void:
	_tree = tree
	_summary = summary

#region Suite / file boundaries

func on_suite_start() -> void:
	_tree.clear()
	_tree.create_item() # hidden root required by hide_root = true
	_item_stack.clear()
	_stats.clear()
	_summary.text = "Running…"

func on_spec_file_start(file_path: String) -> void:
	_current_file = file_path
	var item: TreeItem = _tree.create_item(_tree.get_root())
	item.set_text(0, file_path.get_file())
	item.set_tooltip_text(0, file_path)
	item.set_meta("file", file_path)
	item.collapsed = true
	_item_stack.push_back(item)
	_stats[item.get_instance_id()] = {"passed": 0, "failed": 0, "pending": 0}

func on_spec_file_end(_file_path: String) -> void:
	var item: TreeItem = _item_stack.pop_back()
	var s: Dictionary = _stats.get(item.get_instance_id(), {"passed": 0, "failed": 0, "pending": 0})
	if s["passed"] == 0 and s["failed"] == 0 and s["pending"] == 0:
		item.visible = false
		return
	_refresh_label(item)

func on_suite_end(
	total: int,
	_passed: int,
	failed: int,
	pending: int,
	errors: int,
	duration_ms: float,
	_all_failures: Array,
) -> void:
	var ok: bool = failed == 0 and errors == 0
	var parts: Array[String] = ["%d examples" % total, "%d failures" % failed]
	if errors > 0:
		parts.append("%d errors" % errors)
	if pending > 0:
		parts.append("%d pending" % pending)
	_summary.text = "%s  (%.3fs)" % [", ".join(parts), duration_ms / 1000.0]
	_summary.add_theme_color_override(
		"font_color", Color.html("#a6e22e") if ok else Color.html("#f92672")
	)

#endregion

#region Group events

func on_group_start(group: SpecGroup) -> void:
	if group.description.is_empty():
		return # root group — file item is already the parent

	var parent: TreeItem = _item_stack.back()
	var item: TreeItem = _tree.create_item(parent)
	item.set_text(0, group.description)
	item.set_custom_color(0, Color.html("#66d9ef"))
	item.set_meta("file", _current_file)
	item.set_meta("desc", group.description)
	item.collapsed = true
	_item_stack.push_back(item)
	_stats[item.get_instance_id()] = {"passed": 0, "failed": 0, "pending": 0}

func on_group_end(group: SpecGroup) -> void:
	if group.description.is_empty():
		return

	var item: TreeItem = _item_stack.pop_back()
	var my: Dictionary = _stats[item.get_instance_id()]

	if my["passed"] == 0 and my["failed"] == 0 and my["pending"] == 0:
		item.visible = false
	else:
		_refresh_label(item)
		if my["failed"] > 0:
			item.collapsed = false

	var parent: TreeItem = _item_stack.back()
	var ps: Dictionary = _stats[parent.get_instance_id()]
	ps["passed"] += my["passed"]
	ps["failed"] += my["failed"]
	ps["pending"] += my["pending"]

#endregion

#region Example events

func on_example_complete(example: SpecExample) -> void:
	var parent: TreeItem = _item_stack.back()
	var item: TreeItem = _tree.create_item(parent)
	var my: Dictionary = _stats[parent.get_instance_id()]

	item.set_meta("file", _current_file)
	item.set_meta("desc", example.description)

	match example.status:
		SpecExample.Status.PASSED:
			item.set_text(0, "✓  %s  (%dms)" % [example.description, int(example.duration_ms)])
			item.set_custom_color(0, Color.html("#a6e22e"))
			my["passed"] += 1

		SpecExample.Status.FAILED:
			item.set_text(0, "✗  %s" % example.description)
			item.set_custom_color(0, Color.html("#f92672"))
			item.set_text(1, "→ Goto")
			item.set_custom_color(1, Color.html("#f92672"))
			my["failed"] += 1
			item.collapsed = false
			for failure: SpecFailure in example.failures:
				var detail: TreeItem = _tree.create_item(item)
				detail.set_text(0, "→  %s" % failure.message)
				detail.set_custom_color(0, Color.html("#f92672"))

		SpecExample.Status.PENDING:
			item.set_text(0, "○  %s" % example.description)
			item.set_custom_color(0, Color.html("#fd971f"))
			my["pending"] += 1

		SpecExample.Status.ERROR:
			item.set_text(0, "✗  %s  (error)" % example.description)
			item.set_custom_color(0, Color.html("#f92672"))
			my["failed"] += 1

#endregion

#region Helpers

func _refresh_label(item: TreeItem) -> void:
	var s: Dictionary = _stats.get(item.get_instance_id(), {"passed": 0, "failed": 0, "pending": 0})
	var base: String = item.get_meta("base_text") if item.has_meta("base_text") else item.get_text(0)
	item.set_meta("base_text", base)

	var has_issues: bool = s["failed"] > 0 or s["pending"] > 0

	var suffix: String
	if not has_issues:
		suffix = "  ---  OK"
		item.set_custom_color(0, Color.html("#a6e22e"))
	else:
		var parts: Array[String] = []
		if s["passed"] > 0:
			parts.append("%d Passed" % s["passed"])
		if s["failed"] > 0:
			parts.append("%d Failed" % s["failed"])
		if s["pending"] > 0:
			parts.append("%d Pending" % s["pending"])
		suffix = "  ---  " + ", ".join(parts)
		item.set_custom_color(0, Color.html("#f92672") if s["failed"] > 0 else Color.html("#fd971f"))

	item.set_text(0, base + suffix)

#endregion
