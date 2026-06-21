extends CanvasLayer

signal enter_laboratory_pressed
signal dialogue_finished

@onready var portrait = $Overlay/PortraitFrame/Portrait
@onready var portrait_frame = $Overlay/PortraitFrame
@onready var dialogue_box = $Overlay/DialogueBox
@onready var dialogue_text = $Overlay/DialogueBox/Margin/DialogueText
@onready var prompt = $Overlay/DialogueBox/Prompt
@onready var skip_btn = $Overlay/SkipButton
@onready var enter_lab_btn = $Overlay/EnterLabButton

var character_gender: String = "male"
var sentences = [
	"People say a creature created inside this laboratory escaped control...",
	"The scientists who created it mysteriously disappeared.",
	"Some believe the monster is still alive.",
	"No one has dared to enter this place again.",
	"I need to find out the truth.",
	"If the monster is still alive... I must survive and escape."
]

var current_sentence: String = ""
var current_char_index: int = 0
var current_sentence_index: int = 0
var is_typing: bool = false
var typing_speed: float = 0.04 # seconds per char
var typing_timer: float = 0.0

var typing_sfx: AudioStreamPlayer
var confirm_sfx: AudioStreamPlayer
var prompt_blink_time: float = 0.0

func _ready():
	# Configure portraits
	if character_gender == "female":
		portrait.texture = load("res://portrait_female.jpg")
	else:
		portrait.texture = load("res://portrait_male.jpg")
		
	# Setup audio players
	typing_sfx = AudioStreamPlayer.new()
	add_child(typing_sfx)
	typing_sfx.stream = load("res://typing.mp3")
	typing_sfx.volume_db = -6.0
	
	confirm_sfx = AudioStreamPlayer.new()
	add_child(confirm_sfx)
	confirm_sfx.stream = load("res://select_char.wav")
	confirm_sfx.volume_db = 0.0
	
	# Connect buttons
	skip_btn.pressed.connect(_on_skip_pressed)
	enter_lab_btn.pressed.connect(_on_enter_lab_pressed)
	
	# Setup UI styles (frosted glass)
	setup_styles()
	
	# Start dialogue
	start_dialogue()

func setup_styles():
	# Frosted glass dialogue box
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	box_style.border_width_left = 2
	box_style.border_width_top = 2
	box_style.border_width_right = 2
	box_style.border_width_bottom = 2
	box_style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	box_style.border_blend = true
	box_style.corner_radius_top_left = 15
	box_style.corner_radius_top_right = 15
	box_style.corner_radius_bottom_left = 15
	box_style.corner_radius_bottom_right = 15
	dialogue_box.add_theme_stylebox_override("panel", box_style)
	portrait_frame.add_theme_stylebox_override("panel", box_style)
	
	# Skip button style
	var skip_normal = StyleBoxFlat.new()
	skip_normal.bg_color = Color(0.08, 0.08, 0.1, 0.5)
	skip_normal.border_width_left = 1
	skip_normal.border_width_top = 1
	skip_normal.border_width_right = 1
	skip_normal.border_width_bottom = 1
	skip_normal.border_color = Color(0.5, 0.5, 0.5, 0.3)
	skip_normal.corner_radius_top_left = 5
	skip_normal.corner_radius_top_right = 5
	skip_normal.corner_radius_bottom_left = 5
	skip_normal.corner_radius_bottom_right = 5
	
	var skip_hover = skip_normal.duplicate() as StyleBoxFlat
	skip_hover.border_color = Color(1, 1, 1, 0.8)
	skip_hover.bg_color = Color(0.15, 0.15, 0.2, 0.7)
	
	skip_btn.add_theme_stylebox_override("normal", skip_normal)
	skip_btn.add_theme_stylebox_override("hover", skip_hover)
	skip_btn.add_theme_stylebox_override("focus", skip_hover)
	skip_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	# Enter Lab Button style (scary red glowing)
	var enter_normal = StyleBoxFlat.new()
	enter_normal.bg_color = Color(0.15, 0.02, 0.02, 0.6)
	enter_normal.border_width_left = 2
	enter_normal.border_width_top = 2
	enter_normal.border_width_right = 2
	enter_normal.border_width_bottom = 2
	enter_normal.border_color = Color(0.9, 0.1, 0.1, 0.6)
	enter_normal.corner_radius_top_left = 10
	enter_normal.corner_radius_top_right = 10
	enter_normal.corner_radius_bottom_left = 10
	enter_normal.corner_radius_bottom_right = 10
	
	var enter_hover = enter_normal.duplicate() as StyleBoxFlat
	enter_hover.border_color = Color(1.0, 0.0, 0.0, 1.0)
	enter_hover.bg_color = Color(0.25, 0.03, 0.03, 0.8)
	
	enter_lab_btn.add_theme_stylebox_override("normal", enter_normal)
	enter_lab_btn.add_theme_stylebox_override("hover", enter_hover)
	enter_lab_btn.add_theme_stylebox_override("focus", enter_hover)
	enter_lab_btn.pivot_offset = enter_lab_btn.custom_minimum_size / 2.0
	
	# Enter Lab hover effects
	enter_lab_btn.mouse_entered.connect(_on_enter_lab_hover)
	enter_lab_btn.focus_entered.connect(_on_enter_lab_hover)
	enter_lab_btn.mouse_exited.connect(_on_enter_lab_hover_exit)
	enter_lab_btn.focus_exited.connect(_on_enter_lab_hover_exit)

func _on_enter_lab_hover():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(enter_lab_btn, "scale:x", 1.05, 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(enter_lab_btn, "scale:y", 1.05, 0.2).set_trans(Tween.TRANS_QUAD)

func _on_enter_lab_hover_exit():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(enter_lab_btn, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(enter_lab_btn, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_QUAD)

func start_dialogue():
	current_sentence_index = 0
	show_sentence(sentences[0])

func show_sentence(text_content: String):
	current_sentence = text_content
	current_char_index = 0
	dialogue_text.text = ""
	prompt.visible = false
	is_typing = true
	typing_timer = 0.0
	# Start typing sound immediately when typing begins
	if typing_sfx and typing_sfx.stream:
		typing_sfx.play()

func _process(delta):
	# Dialogue text typing animation
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			current_char_index += 1
			dialogue_text.text = current_sentence.left(current_char_index)
			
			if current_char_index >= current_sentence.length():
				finish_typing()
				
	# Prompt flashing effect
	if prompt.visible:
		prompt_blink_time += delta * 4.0
		prompt.modulate.a = 0.3 + 0.7 * abs(sin(prompt_blink_time))

func finish_typing():
	is_typing = false
	dialogue_text.text = current_sentence
	prompt.visible = true
	prompt_blink_time = 0.0
	# Stop typing sound when typing finishes
	if typing_sfx and typing_sfx.playing:
		typing_sfx.stop()

func _input(event):
	# Keyboard & mouse click/touch to advance
	var key_press = event is InputEventKey and event.is_pressed() and not event.is_echo()
	var enter_or_space = key_press and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)
	var screen_click = event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT
	var screen_touch = event is InputEventScreenTouch and event.is_pressed()
	
	if enter_or_space or screen_click or screen_touch:
		# Don't advance if the skip button or enter lab button is being clicked
		if skip_btn.get_global_rect().has_point(get_viewport().get_mouse_position()) and skip_btn.visible:
			return
		if enter_lab_btn.visible and enter_lab_btn.get_global_rect().has_point(get_viewport().get_mouse_position()):
			return
			
		advance_dialogue()

func advance_dialogue():
	if is_typing:
		# Instant reveal of text
		finish_typing()
	else:
		current_sentence_index += 1
		if current_sentence_index < sentences.size():
			show_sentence(sentences[current_sentence_index])
		else:
			# Final sentence complete! Transition to enter lab button
			show_enter_lab_button()

func _on_skip_pressed():
	if confirm_sfx:
		confirm_sfx.play()
	show_enter_lab_button()

func show_enter_lab_button():
	is_typing = false
	dialogue_finished.emit()
	
	# Fade out dialogue box, portrait, and skip button
	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.4)
	fade_tween.tween_property(portrait_frame, "modulate:a", 0.0, 0.4)
	fade_tween.tween_property(skip_btn, "modulate:a", 0.0, 0.4)
	
	await fade_tween.finished
	dialogue_box.visible = false
	portrait_frame.visible = false
	skip_btn.visible = false
	
	# Show and fade in Enter Lab button
	enter_lab_btn.modulate.a = 0.0
	enter_lab_btn.visible = true
	
	var reveal_tween = create_tween()
	reveal_tween.tween_property(enter_lab_btn, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD)
	
	# Set focus on Enter Lab button for keyboard navigation
	enter_lab_btn.grab_focus()

func _on_enter_lab_pressed():
	if confirm_sfx:
		confirm_sfx.play()
	# Disable the button to prevent multiple clicks
	enter_lab_btn.disabled = true
	
	# Fade out enter lab button
	var fade_tween = create_tween()
	fade_tween.tween_property(enter_lab_btn, "modulate:a", 0.0, 0.4)
	
	await fade_tween.finished
	enter_lab_btn.visible = false
	
	enter_laboratory_pressed.emit()
