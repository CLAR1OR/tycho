extends "res://tests/test_suite.gd"
## Tests EmberTheme (src/core/ember_theme.gd) — the shared Godot `Theme` for the Ember
## screens that are Control trees (design/ui-hud.md § "Ember menu vocabulary").
##
## Why a test for what is "just style": Theme registration fails SILENTLY. The predecessor
## theme had a `MenuButton` variation that never registered for a day, because a type
## variation may not shadow a built-in Godot class name and nothing errored — the panels
## just quietly ignored it (found 2026-07-08; that theme is gone, the trap is not). These
## tests assert that each variation actually landed and that the one structural promise of
## the language holds.
##
## They assert STRUCTURE, never specific colours or sizes — every one of those is a human
## dial, and pinning a placeholder to a number would break the moment it is dialed.


func test_theme_builds_and_is_cached() -> void:
	var a := EmberTheme.get_theme()
	check(a != null, "the theme builds")
	check(EmberTheme.get_theme() == a, "and is cached, not rebuilt per screen")


func test_every_type_variation_registered() -> void:
	var t := EmberTheme.get_theme()
	var expected := {
		"EmberTitle": "Label", "EmberHead": "Label", "EmberDim": "Label",
		"EmberNum": "Label", "EmberProse": "Label", "EmberAction": "Button",
	}
	for name: String in expected.keys():
		check(t.is_type_variation(name, expected[name]),
			"%s registered as a variation of %s (silent failure otherwise)" % [name, expected[name]])


func test_no_variation_shadows_a_builtin_class() -> void:
	# The rule that cost the predecessor theme a day: a variation named after a real Godot
	# class is rejected by set_type_variation without an error.
	for name: String in ["EmberTitle", "EmberHead", "EmberDim", "EmberNum", "EmberProse",
			"EmberAction"]:
		check(not ClassDB.class_exists(name),
			"%s must not collide with a built-in class name" % name)


func test_panels_are_transparent() -> void:
	# THE inversion, and the whole language: Ember has no panels. If this ever becomes a
	# StyleBoxFlat, every screen in the game silently grows boxes.
	var t := EmberTheme.get_theme()
	for type: String in ["Panel", "PanelContainer"]:
		var sb := t.get_stylebox("panel", type)
		check(sb is StyleBoxEmpty, "%s paints nothing (it only groups and pads)" % type)


func test_panels_still_pad() -> void:
	var sb := EmberTheme.get_theme().get_stylebox("panel", "Panel")
	check(sb.content_margin_left > 0.0, "a transparent panel still contributes padding")


func test_buttons_are_frames_not_filled_chips() -> void:
	var t := EmberTheme.get_theme()
	for type: String in ["Button", "EmberAction"]:
		var normal := t.get_stylebox("normal", type)
		check(normal is StyleBoxFlat, "%s has a real stylebox" % type)
		check((normal as StyleBoxFlat).bg_color.a == 0.0,
			"%s rests as a frame over nothing, never a filled chip" % type)
		check((normal as StyleBoxFlat).border_width_left > 0, "%s has its hairline" % type)


func test_all_five_button_states_registered() -> void:
	var t := EmberTheme.get_theme()
	for type: String in ["Button", "EmberAction"]:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			check(t.has_stylebox(state, type), "%s has a %s box" % [type, state])


func test_the_action_button_rests_gold_and_a_plain_button_does_not() -> void:
	# Gold is reserved for state. The one primary action wears it at rest; nothing else does.
	var t := EmberTheme.get_theme()
	var action := t.get_stylebox("normal", "EmberAction") as StyleBoxFlat
	var plain := t.get_stylebox("normal", "Button") as StyleBoxFlat
	check(action.border_color == EmberHud.COL_ACCENT, "EmberAction rests gold-framed")
	check(plain.border_color != EmberHud.COL_ACCENT, "a plain Button rests on the hairline ring")


func test_default_font_is_the_ui_voice() -> void:
	# Under Ember most text on a screen is a label, not prose — so the sans is the default
	# and Garamond is opted into via EmberProse. (Slate defaulted the other way round.)
	var t := EmberTheme.get_theme()
	check(t.default_font != null, "a default font is set")
	check((t.default_font as FontVariation).base_font == EmberHud.FONT_UI_FILE,
		"the interface sans is the default; EmberProse opts into Garamond")


func test_fonts_carry_a_fallback() -> void:
	# Every font goes through EmberHud._with_fallback so a missing glyph never renders as
	# a box — and so the shared imported resource is never mutated.
	var t := EmberTheme.get_theme()
	for variation: String in ["EmberTitle", "EmberNum", "EmberProse", "EmberHead"]:
		var f := t.get_font("font", variation)
		check(f is FontVariation, "%s takes a FontVariation wrapper" % variation)
		check(not (f as FontVariation).fallbacks.is_empty(), "%s has a fallback" % variation)


func test_reads_its_palette_off_ember_hud() -> void:
	# One dial source: the human tunes EmberHud and both the _draw screens and these
	# Control-tree screens move together. A literal copied in here would break that.
	var t := EmberTheme.get_theme()
	check(t.get_color("font_color", "Label") == EmberHud.COL_INK, "Label ink is EmberHud's")
	check(t.get_color("font_color", "EmberDim") == EmberHud.COL_INK_DIM, "dim ink is EmberHud's")
	check(t.get_color("font_disabled_color", "Button") == EmberHud.COL_DISABLED,
		"the disabled colour is EmberHud's")
