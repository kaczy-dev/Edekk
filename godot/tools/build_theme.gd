extends SceneTree
## One-off/rerunnable tool that builds ui/theme/edek_theme.tres in code
## rather than hand-authoring the .tres text format from memory — same
## "verify, don't guess" discipline as god/godotassets.md's crop-and-view
## rule for sprite atlases, applied here to Theme/StyleBoxFlat/FontVariation
## syntax instead of pixel coordinates.
##
## Run: godot --headless -s res://tools/build_theme.gd
##
## Palette: warm storybook direction from docs/ROADMAP.md section 7.1 ("ciepła
## ilustracja / książka obrazkowa" — this is a game about a cat exploring
## real Szczecin, not a generic dark-mode UI). Fonts: Baloo 2 (display/
## headers, rounded and playful) + Nunito (body/HUD, soft and legible at
## small sizes) — both OFL, both verified via Google Fonts' own metadata API
## to fully cover Polish diacritics (ą ć ę ł ń ó ś ź ż) before download; see
## the commit that added assets/fonts/*.ttf for the verification trail.
## Fredoka was considered and REJECTED — confirmed missing ą ć ę ń ś ź ż in
## its latin-ext coverage.

func _init() -> void:
	var nunito := load("res://assets/fonts/Nunito-Variable.ttf") as FontFile
	var baloo := load("res://assets/fonts/Baloo2-Variable.ttf") as FontFile
	if nunito == null or baloo == null:
		push_error("build_theme: could not load base fonts — check assets/fonts/*.ttf are imported")
		quit(1)
		return

	var body_font := _variation(nunito, 500)
	var body_bold_font := _variation(nunito, 700)
	var caption_font := _variation(nunito, 500)
	var header_font := _variation(baloo, 600)
	var header_large_font := _variation(baloo, 700)

	# --- Palette -----------------------------------------------------
	var c_paper := Color(0.961, 0.937, 0.878)      # warm off-white page
	var c_panel := Color(0.925, 0.886, 0.792)      # panel background
	var c_text := Color(0.290, 0.216, 0.157)       # warm dark brown
	var c_text_muted := Color(0.45, 0.37, 0.29)
	var c_accent := Color(0.851, 0.557, 0.235)     # ochra
	var c_accent_hover := Color(0.91, 0.65, 0.33)
	var c_accent_pressed := Color(0.75, 0.47, 0.18)
	var c_border := Color(0.60, 0.47, 0.32)
	var c_disabled := Color(0.72, 0.68, 0.60)
	var c_on_accent := Color(1, 1, 1)

	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 18

	# --- Panel / PanelContainer ---------------------------------------
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = c_panel
	panel_style.set_corner_radius_all(14)
	panel_style.set_border_width_all(2)
	panel_style.border_color = c_border
	panel_style.set_content_margin_all(16)
	panel_style.shadow_color = Color(c_text.r, c_text.g, c_text.b, 0.18)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "Panel", panel_style)

	# --- Button --------------------------------------------------------
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = c_accent
	btn_normal.set_corner_radius_all(10)
	btn_normal.content_margin_left = 22
	btn_normal.content_margin_right = 22
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10

	var btn_hover: StyleBoxFlat = btn_normal.duplicate()
	btn_hover.bg_color = c_accent_hover
	var btn_pressed: StyleBoxFlat = btn_normal.duplicate()
	btn_pressed.bg_color = c_accent_pressed
	var btn_disabled: StyleBoxFlat = btn_normal.duplicate()
	btn_disabled.bg_color = c_disabled

	var btn_focus := StyleBoxFlat.new()
	btn_focus.draw_center = false
	btn_focus.set_corner_radius_all(10)
	btn_focus.set_border_width_all(3)
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
	theme.set_color("font_disabled_color", "Button", Color(c_on_accent.r, c_on_accent.g, c_on_accent.b, 0.7))

	# --- Label / base type variations -----------------------------------
	theme.set_font("font", "Label", body_font)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_color("font_color", "Label", c_text)

	_set_label_variation(theme, "HeaderLarge", header_large_font, 40, c_text)
	_set_label_variation(theme, "HeaderMedium", header_font, 26, c_text)
	_set_label_variation(theme, "Body", body_font, 18, c_text)
	_set_label_variation(theme, "Caption", caption_font, 14, c_text_muted)

	# --- OptionButton / CheckBox / HSlider — inherit Button-ish accent --
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_stylebox("disabled", "OptionButton", btn_disabled)
	theme.set_font("font", "OptionButton", body_bold_font)
	theme.set_font_size("font_size", "OptionButton", 18)
	theme.set_color("font_color", "OptionButton", c_on_accent)
	theme.set_color("font_hover_color", "OptionButton", c_on_accent)
	theme.set_color("font_pressed_color", "OptionButton", c_on_accent)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = c_panel
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = c_accent
	slider_fill.set_corner_radius_all(6)
	slider_fill.content_margin_top = 6
	slider_fill.content_margin_bottom = 6
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	var dir_err := DirAccess.make_dir_recursive_absolute("res://ui/theme")
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("build_theme: could not create res://ui/theme (%d)" % dir_err)
		quit(1)
		return

	var save_err := ResourceSaver.save(theme, "res://ui/theme/edek_theme.tres")
	if save_err != OK:
		push_error("build_theme: ResourceSaver.save failed (%d)" % save_err)
		quit(1)
		return

	print("build_theme: saved res://ui/theme/edek_theme.tres OK")
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
