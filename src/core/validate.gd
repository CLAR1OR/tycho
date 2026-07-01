extends RefCounted
class_name DataValidator
## Lightweight schema validation for data/ content (godot-conventions.md: loud,
## early errors in debug instead of silent nulls). Pure — returns error strings,
## callers decide how loud to be. DataLoader owns the per-domain specs.
##
## A spec is {field_name: rule}; a rule is a Dictionary with:
##   "type"      "string" | "int" | "float" | "bool" | "dict" | "array"  (required)
##   "required"  bool (default false — absent optional fields are fine)
##   "nullable"  bool (default false — JSON null allowed, e.g. supersedes)
##   "one_of"    Array of allowed values (enums like resource roles)
##   "array_of"  element type name, for "array" fields
##
## Unknown fields are ERRORS — content typos ("nmae") must not pass silently.


static func validate(entry: Dictionary, spec: Dictionary, source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in spec:
		var rule: Dictionary = spec[field]
		if not entry.has(field):
			if rule.get("required", false):
				errors.append("%s: missing required field \"%s\"" % [source, field])
			continue
		var value: Variant = entry[field]
		if value == null:
			if not rule.get("nullable", false):
				errors.append("%s: field \"%s\" may not be null" % [source, field])
			continue
		if not _type_ok(value, rule["type"]):
			errors.append("%s: field \"%s\" should be %s, got %s" % [source, field, rule["type"], type_string(typeof(value))])
			continue
		if rule.has("one_of") and not (rule["one_of"] as Array).has(value):
			errors.append("%s: field \"%s\" = \"%s\" not in %s" % [source, field, value, rule["one_of"]])
			continue
		if rule["type"] == "array" and rule.has("array_of"):
			for i in (value as Array).size():
				if not _type_ok(value[i], rule["array_of"]):
					errors.append("%s: \"%s\"[%d] should be %s" % [source, field, i, rule["array_of"]])
	for field: Variant in entry:
		if not spec.has(field):
			errors.append("%s: unknown field \"%s\" (typo? or update the spec in data_loader.gd)" % [source, field])
	return errors


## JSON numbers always parse as float — "int" accepts a whole-valued float.
static func _type_ok(value: Variant, type_name: String) -> bool:
	match type_name:
		"string":
			return value is String
		"int":
			return value is int or (value is float and is_equal_approx(value, roundf(value)))
		"float":
			return value is float or value is int
		"bool":
			return value is bool
		"dict":
			return value is Dictionary
		"array":
			return value is Array
		_:
			push_error("DataValidator: unknown type name \"%s\" in a spec" % type_name)
			return false
