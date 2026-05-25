## All matcher — passes when every element in an Array satisfies the inner matcher.
## Usage: [code]expect([2, 4, 6]).to(all(satisfy(func(x): return x % 2 == 0, "be even")))[/code]
class_name SpecAllMatcher
extends SpecMatcher

var _inner: SpecMatcher

func _init(inner: SpecMatcher) -> void:
	_inner = inner

func matches(actual: Variant) -> bool:
	if not (actual is Array):
		return false
	for element: Variant in actual:
		if not _inner.matches(element):
			return false
	return true

func failure_message(actual: Variant) -> String:
	if not (actual is Array):
		return "expected an Array but got %s" % _pp(actual)
	for i: int in range((actual as Array).size()):
		var element: Variant = (actual as Array)[i]
		if not _inner.matches(element):
			return "expected all elements to match, but element at index %d failed: %s" % [
				i, _inner.failure_message(element)
			]
	return "expected all elements to match the given matcher"

func negated_failure_message(actual: Variant) -> String:
	return "expected NOT all elements of %s to match the given matcher" % _pp(actual)
