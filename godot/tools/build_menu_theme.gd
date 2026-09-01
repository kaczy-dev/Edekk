extends SceneTree
## rpg.md section 11a — second Theme variant for the new main menu, built
## the same way as build_theme.gd (code, not hand-authored .tres text) and
## for the same reason: verify Theme/StyleBoxFlat/FontVariation syntax
## against the real API instead of guessing.
##
## Deliberately a SEPARATE theme from edek_theme.tres, not a palette swap of
## it — edek_theme.tres is still the theme for the rest of the game's UI
## (unchanged, still storybook-toned) per rpg.md 5d's own note that L1-L7
## and existing UI stay as historical/untouched content. This is scoped to
## the new main menu only.
##
## Direction (user, 2026-08-31): "stonowana miejska z dodatkiem cyberpunk
## nowoczesnej technologii" — a grounded, muted urban dark palette (NOT
## neon-overload cyberpunk, see godotagent.md's own "not neon-cyberpunk"
## note) with ONE cyan/teal "tech" accent color reserved for interactive
## elements (buttons, focus), the same restraint AtmosphereFX.gd already
## applies to lighting elsewhere in this project.
##
## Run: godot --headless -s res://tools/build_menu_theme.gd

func _init() -> void:
	var nunito := load("res://assets/fonts/Nunito-Variable.ttf") as FontFile
	var baloo := load("res://assets/fonts/Baloo2-Variable.ttf") as FontFile
	if nunito == null or baloo == null:
		push_error("build_menu_theme: could not load base fonts")
		quit(1)
		return

	var body_font := _variation(nunito, 500)
	var body_bold_font := _variation(nunito, 700)
	var caption_font := _variation(nunito, 500)
	var header_font := _variation(baloo, 600)
	var header_large_font := _variation(baloo, 700)

	# --- Palette: muted urban dark + one cyan tech accent -------------
	var c_bg := Color(0.098, 0.114, 0.137)        # dark slate street-at-night
	var c_panel := Color(0.153, 0.173, 0.204)     # panel surface, slightly lifted
	var c_text := Color(0.878, 0.898, 0.914)      # cool near-white
	var c_text_muted := Color(0.53, 0.58, 0.64)
	var c_accent := Color(0.196, 0.749, 0.847)    # cyan "tech" accent — the one splash of color
	var c_accent_hover := Color(0.32, 0.85, 0.93)
	var c_accent_pressed := Color(0.13, 0.55, 0.63)
	var c_border := Color(0.28, 0.42, 0.46)       # subdued teal-grey, not glowing
	var c_disabled := Color(0.30, 0.32, 0.35)
	var c_on_accent := Color(0.04, 0.06, 0.07)    # dark text on the bright accent, console-readout feel

	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 18

	# --- Panel / PanelContainer ---------------------------------------
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = c_panel
	panel_style.set_corner_radius_all(10)
	panel_style.set_border_width_all(1)
	panel_style.border_color = c_border
	panel_style.set_content_margin_all(18)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "Panel", panel_style)

	# --- Button --------------------------------------------------------
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = c_accent
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 26
	btn_normal.content_margin_right = 26
	btn_normal.content_margin_top = 12
	btn_normal.content_margin_bottom = 12

	var btn_hover: StyleBoxFlat = btn_normal.duplicate()
	btn_hover.bg_color = c_accent_hover
	var btn_pressed: StyleBoxFlat = btn_normal.duplicate()
	btn_pressed.bg_color = c_accent_pressed
	var btn_disabled: StyleBoxFlat = btn_normal.duplicate()
	btn_disabled.bg_color = c_disabled

	var btn_focus := StyleBoxFlat.new()
	btn_focus.draw_center = false
	btn_focus.set_corner_radius_all(6)
	btn_focus.set_border_width_all(2)
	btn_focus.border_color = c_text

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_font("font", "Button", body_bold_font)
	theme.set_font_size("font_size", "Button", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", c_on_accent)
	theme.set_color("font_disabled_color", "Button", Color(c_on_accent.r, c_on_accent.g, c_on_accent.b, 0.6))

	# --- Label / type variations -----------------------------------
	theme.set_font("font", "Label", body_font)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_color("font_color", "Label", c_text)

	_set_label_variation(theme, "HeaderLarge", header_large_font, 44, c_text)
	_set_label_variation(theme, "HeaderMedium", header_font, 26, c_accent)
	_set_label_variation(theme, "Body", body_font, 18, c_text)
	_set_label_variation(theme, "Caption", caption_font, 14, c_text_muted)

	var save_err := ResourceSaver.save(theme, "res://ui/theme/menu_theme.tres")
	if save_err != OK:
		push_error("build_menu_theme: ResourceSaver.save failed (%d)" % save_err)
		quit(1)
		return

	print("build_menu_theme: saved res://ui/theme/menu_theme.tres OK")
	quit(0)

func _variation(base: FontFile, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": float(weight)}
	return v

func _set_label_variation(theme: Theme, type_name: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)
