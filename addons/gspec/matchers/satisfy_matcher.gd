## Satisfy matcher — passes when a predicate Callable returns true.
## Usage: [code]expect(value).to(satisfy(func(x): return x > 0, "be positive"))[/code]
class_name SpecSatisfyMatcher
extends SpecMatcher

var _predicate: Callable
var _description: String

func _init(predicate: Callable, description: String = "") -> void:
	_predicate = predicate
	_description = description

func matches(actual: Variant) -> bool:
	return _predicate.call(actual)

func failure_message(actual: Variant) -> String:
	if not _description.is_empty():
		return "expected %s to satisfy: %s" % [_pp(actual), _description]
	return "expected %s to satisfy the given predicate" % _pp(actual)

func negated_failure_message(actual: Variant) -> String:
	if not _description.is_empty():
		return "expected %s NOT to satisfy: %s" % [_pp(actual), _description]
	return "expected %s NOT to satisfy the given predicate" % _pp(actual)
