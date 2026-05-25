## SpecRunner — discovers spec files, executes them, and reports results.
##
## Usage (internal — called by run.gd):
## [codeblock]
## var runner: SpecRunner = SpecRunner.new()
## runner.add_spec_file("res://spec/system/damage/processor_spec.gd")
## runner.run()
## [/codeblock]
class_name SpecRunner
extends RefCounted

var _formatter: SpecBaseFormatter = null
var _spec_files: Array[String] = []
var _filter: String = ""

## Counters
var _total: int = 0
var _passed: int = 0
var _failed: int = 0
var _pending: int = 0
var _errors: int = 0
var _all_failures: Array[SpecFailure] = []

func _init(formatter: SpecBaseFormatter = null) -> void:
	if formatter != null:
		_formatter = formatter
	else:
		_formatter = SpecDocFormatter.new()

## Set a filter string — only examples whose full description contains
## this substring (case-insensitive) will be executed.
func set_filter(filter: String) -> void:
	_filter = filter.to_lower()

## Add a single spec file path (res:// format).
func add_spec_file(path: String) -> void:
	_spec_files.append(path)

## Discover all *_spec.gd files under a directory (recursive).
func discover(directory_path: String) -> void:
	_scan_directory(directory_path)

## Run all registered spec files and return true if all passed.
func run() -> bool:
	_total = 0
	_passed = 0
	_failed = 0
	_pending = 0
	_errors = 0
	_all_failures.clear()

	var suite_start: int = Time.get_ticks_msec()
	_formatter.on_suite_start()

	for file_path: String in _spec_files:
		await _run_spec_file(file_path)

	var suite_duration: float = float(Time.get_ticks_msec() - suite_start)

	_formatter.on_suite_end(
		_total, _passed, _failed, _pending, _errors,
		suite_duration, _all_failures
	)

	return _failed == 0 and _errors == 0

func _run_spec_file(file_path: String) -> void:
	_formatter.on_spec_file_start(file_path)

	var script: GDScript = load(file_path) as GDScript
	if script == null:
		push_error("GSpec: could not load spec file: %s" % file_path)
		return

	var spec_instance: GSpec = script.new() as GSpec
	if spec_instance == null:
		push_error("GSpec: %s does not extend GSpec" % file_path)
		return

	spec_instance._build_tree()

	var root_group: SpecGroup = spec_instance._get_root_group()
	var focus_mode: bool = _scan_for_focus(root_group)

	await _walk_group(root_group, spec_instance, focus_mode)

	_formatter.on_spec_file_end(file_path)

	# Clean up to prevent ObjectDB leaks
	spec_instance.clear()

func _scan_for_focus(group: SpecGroup) -> bool:
	if group.is_focused:
		return true
	for child: Variant in group.children:
		if child is SpecGroup:
			if _scan_for_focus(child as SpecGroup):
				return true
		elif child is SpecExample:
			if (child as SpecExample).is_focused:
				return true
	return false

func _walk_group(group: SpecGroup, spec_instance: GSpec, focus_mode: bool) -> void:
	_formatter.on_group_start(group)

	for hook: Callable in group.before_all_hooks:
		await hook.call()

	for child: Variant in group.children:
		if child is SpecGroup:
			await _walk_group(child, spec_instance, focus_mode)
		elif child is SpecExample:
			await _run_single_example(child, spec_instance, focus_mode)

	for hook: Callable in group.after_all_hooks:
		await hook.call()

	_formatter.on_group_end(group)

func _run_single_example(example: SpecExample, spec_instance: GSpec, focus_mode: bool) -> void:
	# In focus mode: skip examples that are not focused and not in a focused group
	if focus_mode:
		var in_focused_group: bool = example.group != null and (example.group as SpecGroup).is_focused_or_ancestor_focused()
		if not example.is_focused and not in_focused_group:
			return
	# Apply text filter (ignored when focus mode is active)
	elif not _filter.is_empty():
		if not example.full_description().to_lower().contains(_filter):
			return

	_total += 1

	await spec_instance._run_example(example)

	match example.status:
		SpecExample.Status.PASSED:
			_passed += 1
		SpecExample.Status.FAILED:
			_failed += 1
			for failure: SpecFailure in example.failures:
				failure.example_description = example.description
				failure.group_path = example.group.full_description() if example.group != null else ""
				_all_failures.append(failure)
		SpecExample.Status.PENDING:
			_pending += 1
		SpecExample.Status.ERROR:
			_errors += 1

	_formatter.on_example_complete(example)

func _scan_directory(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("GSpec: cannot open directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		var full_path: String = dir_path.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_directory(full_path)
		else:
			if file_name.ends_with("_spec.gd"):
				_spec_files.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
