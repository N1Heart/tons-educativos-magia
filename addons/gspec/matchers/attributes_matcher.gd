## Attributes matcher — checks that an object has all expected property key/value pairs.
## Usage: [code]expect(entity).to(have_attributes({"health": 100, "mana": 50}))[/code]
class_name SpecAttributesMatcher
extends SpecMatcher

var _expected: Dictionary

func _init(expected: Dictionary) -> void:
	_expected = expected

func matches(actual: Variant) -> bool:
	if actual == null or not (actual is Object):
		return false
	return _mismatched_attrs(actual).is_empty()

func failure_message(actual: Variant) -> String:
	var mismatches: Array[String] = _mismatched_attrs(actual)
	return "expected %s to have attributes:\n  %s" % [_pp(actual), "\n  ".join(mismatches)]

func negated_failure_message(actual: Variant) -> String:
	return "expected %s NOT to have all attributes %s" % [_pp(actual), _pp(_expected)]

func _mismatched_attrs(actual: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (actual is Object):
		result.append("actual is not an Object")
		return result
	for key: Variant in _expected.keys():
		var attr_name: String = str(key)
		var has_prop: bool = false
		for prop: Dictionary in actual.get_property_list():
			if prop["name"] == attr_name:
				has_prop = true
				break
		if not has_prop:
			result.append('missing property "%s"' % attr_name)
			continue
		var actual_val: Variant = actual.get(attr_name)
		if actual_val != _expected[key]:
			result.append('"%s": expected %s but got %s' % [attr_name, _pp(_expected[key]), _pp(actual_val)])
	return result
