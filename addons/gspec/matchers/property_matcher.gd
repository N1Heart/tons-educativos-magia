## Property matcher — checks an object has a property, optionally with a value.
## Usage:
##   [code]expect(entity).to(have_property("health"))[/code]
##   [code]expect(entity).to(have_property("health", 100))[/code]

class_name SpecPropertyMatcher
extends SpecMatcher

var _property_name: String
var _expected_value: Variant
var _check_value: bool

func _init(property_name: String, expected_value: Variant = null, check_value: bool = false) -> void:
	_property_name = property_name
	_expected_value = expected_value
	_check_value = check_value

func matches(actual: Variant) -> bool:
	if actual == null or not (actual is Object):
		return false

	var value: Variant = actual.get(_property_name)
	# get() returns null for non-existent properties too,
	# so we verify via property list
	var has_prop: bool = false
	for prop: Dictionary in actual.get_property_list():
		if prop["name"] == _property_name:
			has_prop = true
			break

	if not has_prop:
		return false

	if _check_value:
		return value == _expected_value

	return true

func failure_message(actual: Variant) -> String:
	if _check_value:
		var actual_val: Variant = null
		if actual is Object:
			actual_val = actual.get(_property_name)
		return "expected %s to have property \"%s\" == %s, but was %s" % [
			_pp(actual), _property_name, _pp(_expected_value), _pp(actual_val)
		]
	return "expected %s to have property \"%s\"" % [_pp(actual), _property_name]

func negated_failure_message(actual: Variant) -> String:
	if _check_value:
		return "expected %s NOT to have property \"%s\" == %s" % [
			_pp(actual), _property_name, _pp(_expected_value)
		]
	return "expected %s NOT to have property \"%s\"" % [_pp(actual), _property_name]
