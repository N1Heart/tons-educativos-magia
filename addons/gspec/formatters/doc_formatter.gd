## Documentation formatter — nested, readable output like RSpec's --format doc.
##
## Output:
## [codeblock]
## SDamageProcessor
##   when attacker crits
##     ✓ multiplies damage by crit rate (2ms)
##     ✗ does not allow block (FAILED)
##   when defender blocks
##     ✓ reduces damage by 65% (1ms)
##     ○ handles shield (PENDING)
## [/codeblock]
class_name SpecDocFormatter
extends SpecBaseFormatter

var _printed_groups: Dictionary = {}  # track which groups have been printed

func on_suite_start() -> void:
	_printed_groups.clear()
	print("")

func on_spec_file_start(file_path: String) -> void:
	print(DIM + "# %s" % file_path + RESET)

func on_example_complete(example: SpecExample) -> void:
	_ensure_group_headers_printed(example.group)

	var indent: String = _indent(example.group.depth() + 1)

	match example.status:
		SpecExample.Status.PASSED:
			print("%s%s✓ %s%s %s(%dms)%s" % [
				indent, GREEN, example.description, RESET,
				DIM, int(example.duration_ms), RESET
			])
		SpecExample.Status.FAILED:
			print("%s%s✗ %s (FAILED)%s" % [indent, RED, example.description, RESET])
			for failure: SpecFailure in example.failures:
				print("%s  %s%s%s" % [indent, RED, failure.message, RESET])
		SpecExample.Status.PENDING:
			print("%s%s○ %s (PENDING)%s" % [indent, YELLOW, example.description, RESET])
		SpecExample.Status.ERROR:
			print("%s%s✗ %s (ERROR: %s)%s" % [
				indent, RED, example.description, example.error_message, RESET
			])

func on_suite_end(
	total: int,
	_passed: int,
	failed: int,
	pending: int,
	errors: int,
	duration_ms: float,
	all_failures: Array,
) -> void:
	print("")

	if not all_failures.is_empty():
		print(RED + BOLD + "Failures:" + RESET)
		print("")
		var idx: int = 1
		for failure: SpecFailure in all_failures:
			print("  %s%d) %s%s" % [RED, idx, failure.full_description(), RESET])
			print("     %s%s%s" % [RED, failure.message, RESET])
			print("")
			idx += 1

	var duration_s: float = duration_ms / 1000.0
	var color: String = GREEN if (failed == 0 and errors == 0) else RED

	var parts: Array[String] = ["%d examples" % total, "%d failures" % failed]
	if errors > 0:
		parts.append("%d errors" % errors)
	if pending > 0:
		parts.append("%d pending" % pending)

	print("%s%s%s%s %s(finished in %.3fs)%s" % [
		color, BOLD, ", ".join(parts), RESET,
		DIM, duration_s, RESET
	])

func _ensure_group_headers_printed(group: SpecGroup) -> void:
	if group == null:
		return
	var group_id: int = group.get_instance_id()
	if _printed_groups.has(group_id):
		return

	if group.parent != null:
		_ensure_group_headers_printed(group.parent)

	# Skip the empty root group — only named groups get a header line
	if not group.description.is_empty():
		var indent: String = _indent(group.depth())
		print("%s%s%s%s%s" % [indent, BOLD, CYAN, group.description, RESET])

	_printed_groups[group_id] = true

func _indent(depth: int) -> String:
	var result: String = ""
	for i: int in range(depth):
		result += "  "
	return result
