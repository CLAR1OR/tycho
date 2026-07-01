extends SceneTree
## Interim headless test runner (see tests/test_suite.gd for why not gdUnit4 yet).
##
## Run:  /path/to/godot --headless -s tests/test_runner.gd
## On a FRESH CLONE (or after adding class_names), refresh the class cache first:
##        /path/to/godot --headless --editor --quit
## (class_name resolution reads .godot/global_script_class_cache.cfg — standard
## Godot CI does the same import step before testing.)
##
## Discovers every *_test.gd under tests/core/, instantiates it, runs all test_*
## methods, prints a summary, exits 0 on green / 1 on any failure (CI-friendly).
## Agents: run this before every commit that touches src/ (working agreement).

const TEST_DIR := "res://tests/core"

# Preloaded by path (not class_name) so tests run on a fresh clone before any
# editor scan has built the global class cache.
const TestSuiteScript := preload("res://tests/test_suite.gd")


func _initialize() -> void:
	var suites := _find_suites()
	var total_checks := 0
	var total_failures := 0
	var total_tests := 0
	for path in suites:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			printerr("    FAIL: %s does not compile" % path)
			total_failures += 1
			continue
		var suite: TestSuiteScript = script.new()
		for m in suite.get_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			total_tests += 1
			var before: int = suite.failures.size()
			suite.call(method)
			var status := "ok" if suite.failures.size() == before else "FAIL"
			print("  %-50s %s" % [path.get_file() + "::" + method, status])
		total_checks += suite.checks
		total_failures += suite.failures.size()
		for f in suite.failures:
			printerr("    FAIL: " + f)
	print("---")
	print("%d tests, %d checks, %d failures" % [total_tests, total_checks, total_failures])
	quit(0 if total_failures == 0 else 1)


func _find_suites() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("test_runner: missing " + TEST_DIR)
		quit(1)
		return out
	for file in dir.get_files():
		if file.ends_with("_test.gd"):
			out.append(TEST_DIR + "/" + file)
	out.sort()
	return out
