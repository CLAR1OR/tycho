extends GdUnitTestSuite
class_name TestSuite
## Project test-suite base over gdUnit4 (godot-conventions.md → Testing).
##
## History: this began as the base class of a zero-dependency interim runner,
## because installing the gdUnit4 editor plugin needed a human in the loop —
## done 2026-07-03, and the interim runner (tests/test_runner.gd) is retired.
## The suites keep the compact check()/check_eq() helpers; both now report
## through real gdUnit4 asserts, so failures land in the editor test UI and
## the CLI runner alike. New tests may use the native assert_that(...) API
## directly — either style is fine.


func check(cond: bool, msg: String) -> void:
	assert_bool(cond).override_failure_message(msg).is_true()


## Equality with the original runner's exact semantics, preserved so the port
## changed zero checks: float pairs compare via is_equal_approx, everything
## else via `==` (Godot deep-compares Dictionaries/Arrays by value).
func check_eq(got: Variant, want: Variant, msg: String) -> void:
	var equal: bool
	if got is float and want is float:
		equal = is_equal_approx(got, want)
	else:
		equal = got == want
	assert_bool(equal).override_failure_message(
		"%s (got %s, want %s)" % [msg, got, want]).is_true()
