## CLI entry point for GSpec.
##
## Run from terminal:
## [codeblock]
## # Run all specs (auto-discover res://spec/)
## godot --headless res://addons/gspec/runner.tscn
##
## # Run a single file
## godot --headless res://addons/gspec/runner.tscn -- res://spec/system/damage/processor_spec.gd
##
## # Run with filter
## godot --headless res://addons/gspec/runner.tscn -- --filter "crit"
##
## # Use dot format
## godot --headless res://addons/gspec/runner.tscn -- --format dot
##
## # Combine options
## godot --headless res://addons/gspec/runner.tscn -- --format doc --filter "block" res://spec/my_spec.gd
## [/codeblock]
extends Node

const SPEC_DIR: String = "res://spec"

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()

	var format: String = "doc"
	var filter: String = ""
	var spec_files: Array[String] = []

	# Parse args
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		if arg == "--format" and i + 1 < args.size():
			format = args[i + 1]
			i += 2
		elif arg == "--filter" and i + 1 < args.size():
			filter = args[i + 1]
			i += 2
		elif arg == "--help" or arg == "-h":
			_print_help()
			get_tree().quit(0)
			return
		elif not arg.begins_with("--"):
			spec_files.append(arg)
			i += 1
		else:
			print("Unknown option: %s" % arg)
			_print_help()
			get_tree().quit(1)
			return

	# Select formatter
	var formatter: SpecBaseFormatter = null
	match format:
		"dot":
			formatter = SpecDotFormatter.new()
		"doc", "documentation":
			formatter = SpecDocFormatter.new()
		_:
			print("Unknown format: %s (available: dot, doc)" % format)
			get_tree().quit(1)
			return

	var runner: SpecRunner = SpecRunner.new(formatter)

	if not filter.is_empty():
		runner.set_filter(filter)

	# Add spec files or auto-discover
	if spec_files.is_empty():
		print("\u001b[36m\u001b[1mGSpec\u001b[0m — discovering specs in %s" % SPEC_DIR)
		print("")
		runner.discover(SPEC_DIR)
	else:
		for path: String in spec_files:
			runner.add_spec_file(path)

	var success: bool = await runner.run()

	print("")
	get_tree().quit(0 if success else 1)

func _print_help() -> void:
	print("")
	print("\u001b[36m\u001b[1mGSpec\u001b[0m — RSpec-style testing for Godot 4")
	print("")
	print("Usage:")
	print("  godot --headless res://addons/gspec/runner.tscn [-- OPTIONS] [SPEC_FILES]")
	print("")
	print("Options:")
	print("  --format FORMAT    Output format: doc (default), dot")
	print("  --filter PATTERN   Only run examples matching PATTERN")
	print("  --help, -h         Show this help")
	print("")
	print("Examples:")
	print("  godot --headless res://addons/gspec/runner.tscn")
	print("  godot --headless res://addons/gspec/runner.tscn -- res://spec/damage_spec.gd")
	print("  godot --headless res://addons/gspec/runner.tscn -- --format dot --filter crit")
	print("")
