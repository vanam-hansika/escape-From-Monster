extends CanvasLayer

signal character_selected(gender: String)

@onready var male_panel = $CenterContainer/MalePanel
@onready var female_panel = $CenterContainer/FemalePanel
@onready var male_portrait = $CenterContainer/MalePanel/VBox/Portrait
@onready var female_portrait = $CenterContainer/FemalePanel/VBox/Portrait
@onready var male_button = $CenterContainer/MalePanel/VBox/MaleButton
@onready var female_btn = $CenterContainer/FemalePanel/VBox/FemaleButton

var sfx_player: AudioStreamPlayer
var select_sound: AudioStream

# Stored styles for hover effects
var male_default_style: StyleBoxFlat
var female_default_style: StyleBoxFlat
var male_hover_style: StyleBoxFlat
var female_hover_style: StyleBoxFlat

func _ready():
	# Load portraits
	male_portrait.texture = load("res://portrait_male.jpg")
	female_portrait.texture = load("res://portrait_female.jpg")
	
	# Load select sound
	select_sound = load("res://select_char.wav")
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.stream = select_sound
	sfx_player.volume_db = 0.0

	# Ensure mouse mode is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Create theme styles
	setup_styles()
	
	# Connect buttons
	male_button.pressed.connect(_on_male_pressed)
	female_btn.pressed.connect(_on_female_pressed)
	
	# Setup hover/focus effects
	setup_button_effects()
	
	# Set initial focus for keyboard navigation
	male_button.grab_focus()

func _on_male_pressed():
	select_character("male")

func _on_female_pressed():
	select_character("female")

func setup_styles():
	# Frosted glass panel backgrounds
	male_default_style = StyleBoxFlat.new()
	male_default_style.bg_color = Color(0.05, 0.05, 0.08, 0.6)
	male_default_style.border_width_left = 2
	male_default_style.border_width_top = 2
	male_default_style.border_width_right = 2
	male_default_style.border_width_bottom = 2
	male_default_style.border_color = Color(0.53, 0.81, 0.98, 0.3)
	male_default_style.corner_radius_top_left = 15
	male_default_style.corner_radius_top_right = 15
	male_default_style.corner_radius_bottom_left = 15
	male_default_style.corner_radius_bottom_right = 15
	male_panel.add_theme_stylebox_override("panel", male_default_style)
	
	male_hover_style = male_default_style.duplicate()
	male_hover_style.border_color = Color(0.53, 0.81, 0.98, 1.0)
	male_hover_style.border_width_left = 4
	male_hover_style.border_width_top = 4
	male_hover_style.border_width_right = 4
	male_hover_style.border_width_bottom = 4
	
	female_default_style = StyleBoxFlat.new()
	female_default_style.bg_color = Color(0.05, 0.05, 0.08, 0.6)
	female_default_style.border_width_left = 2
	female_default_style.border_width_top = 2
	female_default_style.border_width_right = 2
	female_default_style.border_width_bottom = 2
	female_default_style.border_color = Color(1.0, 0.75, 0.8, 0.3)
	female_default_style.corner_radius_top_left = 15
	female_default_style.corner_radius_top_right = 15
	female_default_style.corner_radius_bottom_left = 15
	female_default_style.corner_radius_bottom_right = 15
	female_panel.add_theme_stylebox_override("panel", female_default_style)
	
	female_hover_style = female_default_style.duplicate()
	female_hover_style.border_color = Color(1.0, 0.75, 0.8, 1.0)
	female_hover_style.border_width_left = 4
	female_hover_style.border_width_top = 4
	female_hover_style.border_width_right = 4
	female_hover_style.border_width_bottom = 4
	
	# Button styles - Male
	var btn_normal_male = StyleBoxFlat.new()
	btn_normal_male.bg_color = Color(0.08, 0.15, 0.25, 0.5)
	btn_normal_male.border_width_left = 1
	btn_normal_male.border_width_top = 1
	btn_normal_male.border_width_right = 1
	btn_normal_male.border_width_bottom = 1
	btn_normal_male.border_color = Color(0.53, 0.81, 0.98, 0.5)
	btn_normal_male.corner_radius_top_left = 8
	btn_normal_male.corner_radius_top_right = 8
	btn_normal_male.corner_radius_bottom_left = 8
	btn_normal_male.corner_radius_bottom_right = 8
	
	var btn_hover_male = btn_normal_male.duplicate()
	btn_hover_male.bg_color = Color(0.12, 0.25, 0.4, 0.8)
	btn_hover_male.border_width_left = 2
	btn_hover_male.border_width_top = 2
	btn_hover_male.border_width_right = 2
	btn_hover_male.border_width_bottom = 2
	btn_hover_male.border_color = Color(0.53, 0.81, 0.98, 1.0)
	
	male_button.add_theme_stylebox_override("normal", btn_normal_male)
	male_button.add_theme_stylebox_override("hover", btn_hover_male)
	male_button.add_theme_stylebox_override("focus", btn_hover_male)
	male_button.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	male_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	male_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	
	# Button styles - Female
	var btn_normal_female = StyleBoxFlat.new()
	btn_normal_female.bg_color = Color(0.25, 0.1, 0.2, 0.5)
	btn_normal_female.border_width_left = 1
	btn_normal_female.border_width_top = 1
	btn_normal_female.border_width_right = 1
	btn_normal_female.border_width_bottom = 1
	btn_normal_female.border_color = Color(1.0, 0.75, 0.8, 0.5)
	btn_normal_female.corner_radius_top_left = 8
	btn_normal_female.corner_radius_top_right = 8
	btn_normal_female.corner_radius_bottom_left = 8
	btn_normal_female.corner_radius_bottom_right = 8
	
	var btn_hover_female = btn_normal_female.duplicate()
	btn_hover_female.bg_color = Color(0.4, 0.15, 0.3, 0.8)
	btn_hover_female.border_width_left = 2
	btn_hover_female.border_width_top = 2
	btn_hover_female.border_width_right = 2
	btn_hover_female.border_width_bottom = 2
	btn_hover_female.border_color = Color(1.0, 0.75, 0.8, 1.0)
	
	female_btn.add_theme_stylebox_override("normal", btn_normal_female)
	female_btn.add_theme_stylebox_override("hover", btn_hover_female)
	female_btn.add_theme_stylebox_override("focus", btn_hover_female)
	female_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.95))
	female_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	female_btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))

func setup_button_effects():
	# Setup pivots for scaling from center
	male_panel.pivot_offset = male_panel.custom_minimum_size / 2.0
	female_panel.pivot_offset = female_panel.custom_minimum_size / 2.0

	male_button.mouse_entered.connect(_on_male_hover_enter)
	male_button.focus_entered.connect(_on_male_hover_enter)
	male_button.mouse_exited.connect(_on_male_hover_exit)
	male_button.focus_exited.connect(_on_male_hover_exit)

	female_btn.mouse_entered.connect(_on_female_hover_enter)
	female_btn.focus_entered.connect(_on_female_hover_enter)
	female_btn.mouse_exited.connect(_on_female_hover_exit)
	female_btn.focus_exited.connect(_on_female_hover_exit)

func _on_male_hover_enter():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(male_panel, "scale:x", 1.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(male_panel, "scale:y", 1.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	male_panel.add_theme_stylebox_override("panel", male_hover_style)

func _on_male_hover_exit():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(male_panel, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(male_panel, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	male_panel.add_theme_stylebox_override("panel", male_default_style)

func _on_female_hover_enter():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(female_panel, "scale:x", 1.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(female_panel, "scale:y", 1.05, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	female_panel.add_theme_stylebox_override("panel", female_hover_style)

func _on_female_hover_exit():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(female_panel, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(female_panel, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	female_panel.add_theme_stylebox_override("panel", female_default_style)

var is_selecting = false
func select_character(gender: String):
	if is_selecting:
		return
	is_selecting = true
	
	# Play selection sound
	if sfx_player:
		sfx_player.play()
	
	# Flash selected panel
	var panel = male_panel if gender == "male" else female_panel
	var flash_tween = create_tween()
	flash_tween.tween_property(panel, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	flash_tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	flash_tween.tween_property(panel, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	flash_tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.1)

	# Disable buttons
	male_button.disabled = true
	female_btn.disabled = true
	
	# Fade out whole screen
	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property($Background, "color", Color(0, 0, 0, 1), 0.5)
	fade_tween.tween_property($Title, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property($CenterContainer, "modulate:a", 0.0, 0.5)
	
	await fade_tween.finished
	
	emit_signal("character_selected", gender)
	queue_free()
