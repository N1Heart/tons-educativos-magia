## Base formatter interface for GSpec output.
class_name SpecBaseFormatter
extends RefCounted

## Called when the entire suite starts.
func on_suite_start() -> void:
	pass

## Called when a spec file starts.
func on_spec_file_start(file_path: String) -> void:
	pass

## Called when a group (describe/context) is entered.
func on_group_start(group: SpecGroup) -> void:
	pass

## Called after each example finishes.
func on_example_complete(example: SpecExample) -> void:
	pass

## Called when a group is finished.
func on_group_end(group: SpecGroup) -> void:
	pass

## Called when a spec file finishes.
func on_spec_file_end(file_path: String) -> void:
	pass

## Called when the entire suite is done. Print summary here.
func on_suite_end(
	total: int,
	_passed: int,
	failed: int,
	pending: int,
	errors: int,
	duration_ms: float,
	all_failures: Array,
) -> void:
	pass

#region --- ANSI Colors ---
## ANSI escape codes for terminal coloring.
const GREEN: String = "\u001b[32m"
const RED: String = "\u001b[31m"
const YELLOW: String = "\u001b[33m"
const CYAN: String = "\u001b[36m"
const DIM: String = "\u001b[2m"
const BOLD: String = "\u001b[1m"
const RESET: String = "\u001b[0m"
#endregion
