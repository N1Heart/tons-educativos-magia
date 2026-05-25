## Collection matchers: include, be_empty, have_size, contain_exactly, match_dict.

class_name SpecCollectionMatchers
extends RefCounted


class IncludeMatcher extends SpecMatcher:
	var _expected: Variant

	func _init(expected: Variant) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		if actual is Array:
			return actual.has(_expected)
		if actual is Dictionary:
			return actual.has(_expected)
		if actual is String:
			return actual.contains(str(_expected))
		return false

	func failure_message(actual: Variant) -> String:
		return "expected %s to include %s" % [_pp(actual), _pp(_expected)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to include %s" % [_pp(actual), _pp(_expected)]


class BeEmptyMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		if actual is Array or actual is Dictionary or actual is String:
			return actual.is_empty()
		return false

	func failure_message(actual: Variant) -> String:
		return "expected %s to be empty" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be empty" % _pp(actual)


class HaveSizeMatcher extends SpecMatcher:
	var _expected_size: int

	func _init(expected_size: int) -> void:
		_expected_size = expected_size

	func matches(actual: Variant) -> bool:
		if actual is Array:
			return actual.size() == _expected_size
		if actual is Dictionary:
			return actual.size() == _expected_size
		if actual is String:
			return actual.length() == _expected_size
		return false

	func failure_message(actual: Variant) -> String:
		var actual_size: int = _get_size(actual)
		return "expected %s to have size %d, but had size %d" % [_pp(actual), _expected_size, actual_size]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to have size %d" % [_pp(actual), _expected_size]

	func _get_size(value: Variant) -> int:
		if value is Array or value is Dictionary:
			return value.size()
		if value is String:
			return value.length()
		return -1

class ContainExactlyMatcher extends SpecMatcher:
	var _expected: Array

	func _init(expected: Array) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		if not actual is Array:
			return false
		if actual.size() != _expected.size():
			return false

		var actual_copy: Array = actual.duplicate()
		for item: Variant in _expected:
			var found_idx: int = -1
			for i: int in range(actual_copy.size()):
				# Deep equality check
				if typeof(actual_copy[i]) == typeof(item) and actual_copy[i] == item:
					found_idx = i
					break
			if found_idx == -1:
				return false
			actual_copy.remove_at(found_idx)

		return true

	func failure_message(actual: Variant) -> String:
		return "expected array to contain exactly %s, but got %s" % [_pp(_expected), _pp(actual)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected array NOT to contain exactly %s" % _pp(_expected)


class IncludeDictMatcher extends SpecMatcher:
	var _expected: Dictionary

	func _init(expected: Dictionary) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		if not actual is Dictionary:
			return false
			
		for key: Variant in _expected.keys():
			if not actual.has(key):
				return false
			if typeof(actual[key]) != typeof(_expected[key]) or actual[key] != _expected[key]:
				return false
				
		return true

	func failure_message(actual: Variant) -> String:
		return "expected dictionary to include key-value subset %s, but got %s" % [_pp(_expected), _pp(actual)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected dictionary NOT to include key-value subset %s" % _pp(_expected)
