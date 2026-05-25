## Type-check matcher.
## Usage: [code]expect(obj).to(be_instance_of(SDamageResult))[/code]

class_name SpecTypeMatcher
extends SpecMatcher

var _expected_type: Variant

func _init(expected_type: Variant) -> void:
	_expected_type = expected_type

func matches(actual: Variant) -> bool:
	if actual == null:
		return false
	return is_instance_of(actual, _expected_type)

func failure_message(actual: Variant) -> String:
	var actual_class: String = _get_class_name(actual)
	var expected_class: String = str(_expected_type)
	return "expected %s to be an instance of %s, but was %s" % [_pp(actual), expected_class, actual_class]

func negated_failure_message(actual: Variant) -> String:
	var expected_class: String = str(_expected_type)
	return "expected %s NOT to be an instance of %s" % [_pp(actual), expected_class]

func _get_class_name(value: Variant) -> String:
	if value is Object:
		return value.get_class()
	return type_string(typeof(value))
