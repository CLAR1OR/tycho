extends "res://tests/test_suite.gd"
## Unit tests for DataValidator (src/core/validate.gd).

const RESOURCE_SPEC: Dictionary = {
	"id": {"type": "string", "required": true},
	"role": {"type": "string", "required": true, "one_of": ["money", "material"]},
	"age_active": {"type": "int", "required": true},
	"supersedes": {"type": "string", "nullable": true},
	"sources": {"type": "array", "array_of": "string"},
}


func _valid_entry() -> Dictionary:
	return {"id": "gold", "role": "money", "age_active": 1.0, "supersedes": null, "sources": ["run-drop"]}


func test_valid_entry_passes() -> void:
	var errors := DataValidator.validate(_valid_entry(), RESOURCE_SPEC, "t")
	check_eq(errors.size(), 0, "valid entry produces no errors: %s" % ", ".join(errors))


func test_missing_required_field() -> void:
	var e := _valid_entry()
	e.erase("role")
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "missing required field is an error")


func test_optional_field_may_be_absent() -> void:
	var e := _valid_entry()
	e.erase("sources")
	check_eq(DataValidator.validate(e, RESOURCE_SPEC, "t").size(), 0, "absent optional field is fine")


func test_wrong_type() -> void:
	var e := _valid_entry()
	e["id"] = 5
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "wrong type is an error")


func test_json_float_accepted_as_int() -> void:
	var e := _valid_entry()
	e["age_active"] = 2.0   # JSON numbers parse as float
	check_eq(DataValidator.validate(e, RESOURCE_SPEC, "t").size(), 0, "whole-valued float passes as int")
	e["age_active"] = 2.5
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "fractional float fails as int")


func test_enum_membership() -> void:
	var e := _valid_entry()
	e["role"] = "vibes"
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "value outside one_of is an error")


func test_nullability() -> void:
	var e := _valid_entry()
	e["id"] = null
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "null on non-nullable field is an error")
	check_eq(DataValidator.validate(_valid_entry(), RESOURCE_SPEC, "t").size(), 0, "null on nullable field is fine")


func test_unknown_field_is_error() -> void:
	var e := _valid_entry()
	e["nmae"] = "typo"
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "unknown field (typo) is an error")


func test_bad_array_element() -> void:
	var e := _valid_entry()
	e["sources"] = ["ok", 7]
	check(DataValidator.validate(e, RESOURCE_SPEC, "t").size() > 0, "wrong-typed array element is an error")
