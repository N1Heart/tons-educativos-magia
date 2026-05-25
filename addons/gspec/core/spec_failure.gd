## Data class representing a single test failure.
class_name SpecFailure
extends RefCounted

var message: String
var spec_file: String
var example_description: String
var group_path: String  # "SDamageProcessor > when attacker crits"

func _init(
	_message: String,
	_example_description: String = "",
	_group_path: String = "",
	_spec_file: String = "",
) -> void:
	message = _message
	example_description = _example_description
	group_path = _group_path
	spec_file = _spec_file

func full_description() -> String:
	if group_path.is_empty():
		return example_description
	return "%s %s" % [group_path, example_description]
