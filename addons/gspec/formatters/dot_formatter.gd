## Dot formatter — compact one-character-per-example output.
##
## Output:
##   [code]..F.P..E.[/code]
##   [code]. = pass, F = fail, P = pending, E = error[/code]
class_name SpecDotFormatter
extends SpecBaseFormatter

var _output: String = ""

func on_suite_start() -> void:
	_output = ""

func on_example_complete(example: SpecExample) -> void:
	match example.status:
		SpecExample.Status.PASSED:
			_output += GREEN + "." + RESET
		SpecExample.Status.FAILED:
			_output += RED + "F" + RESET
		SpecExample.Status.PENDING:
			_output += YELLOW + "P" + RESET
		SpecExample.Status.ERROR:
			_output += RED + "E" + RESET

func on_suite_end(
	total: int,
	_passed: int,
	failed: int,
	pending: int,
	errors: int,
	duration_ms: float,
	all_failures: Array,
) -> void:
	# Print dots
	print(_output)
	print("")

	if not all_failures.is_empty():
		print(RED + "Failures:" + RESET)
		print("")
		var idx: int = 1
		for failure: SpecFailure in all_failures:
			print("  %d) %s" % [idx, failure.full_description()])
			print("     %s%s%s" % [RED, failure.message, RESET])
			print("")
			idx += 1

	# Summary line
	var summary: String = ""
	var duration_s: float = duration_ms / 1000.0

	if failed > 0 or errors > 0:
		summary += RED + BOLD
	else:
		summary += GREEN + BOLD

	summary += "%d examples, %d failures" % [total, failed]

	if errors > 0:
		summary += ", %d errors" % errors
	if pending > 0:
		summary += ", %d pending" % pending

	summary += RESET
	summary += DIM + " (finished in %.3fs)" % duration_s + RESET

	print(summary)
