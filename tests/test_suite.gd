extends RefCounted
class_name TestSuite
## Minimal test-suite base for the interim runner (tests/test_runner.gd).
##
## INTERIM: godot-conventions.md mandates gdUnit4, but installing an editor plugin
## needs a human in the loop (Godot editor → AssetLib → "gdUnit4" → install/enable).
## Until then this zero-dependency harness keeps the required coverage real: suites
## in tests/core/ extend this, name methods test_*, and use the check helpers.
## Porting to gdUnit4 later = mechanical (check → assert_that).

var failures: PackedStringArray = []
var checks: int = 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func check_eq(got: Variant, want: Variant, msg: String) -> void:
	var equal: bool
	if got is float and want is float:
		equal = is_equal_approx(got, want)
	else:
		equal = got == want
	checks += 1
	if not equal:
		failures.append("%s (got %s, want %s)" % [msg, got, want])
