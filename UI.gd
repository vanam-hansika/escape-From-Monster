extends CanvasLayer

@onready var stamina_bar: ProgressBar = $HUD/StaminaBar
@onready var sanity_bar: ProgressBar = $HUD/SanityBar
@onready var battery_bar: ProgressBar = $HUD/BatteryBar

@onready var win_label: Label = $WinLabel
@onready var lose_label: Label = $LoseLabel
@onready var restart_button: Button = $RestartButton
@onready var jumpscare_panel: ColorRect = $JumpscarePanel
@onready var pause_menu: ColorRect = $PauseMenu

var player: CharacterBody3D = null
var is_mobile: bool = false

func _ready():
	win_label.visible = false
	lose_label.visible = false
	restart_button.visible = false
	jumpscare_panel.visible = false
	pause_menu.visible = false
	battery_bar.visible = false
	
	restart_button.pressed.connect(_on_restart_pressed)
	$PauseMenu/ResumeButton.pressed.connect(toggle_pause)
	$PauseMenu/RestartPauseButton.pressed.connect(_on_restart_pressed)
	if has_node("HUD/PauseToggleButton"):
		$HUD/PauseToggleButton.pressed.connect(toggle_pause)
	
	setup_mobile_controls()
	call_deferred("find_player")



var hand_sway_time = 0.0

# Mobile touch look tracking (handled in _input for reliability)
var mobile_look_touch_id: int = -1

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and not win_label.visible and not lose_label.visible:
		toggle_pause()

func _input(event):
	# Show mobile controls on first touch
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if has_node("HUD/MobileControls") and not $HUD/MobileControls/Joystick.visible:
			$HUD/MobileControls/Joystick.visible = true
			$HUD/MobileControls/LookPad.visible = true
			$HUD/MobileControls/SprintButton.text = "SPRINT"
			$HUD/MobileControls/FlashlightButton.text = "LIGHT"
	
	# Mobile camera look: handle directly in _input (most reliable approach)
	# Tracks right-half drags and routes them to camera rotation
	if is_mobile and player and player.can_move:
		var screen_w = get_viewport().get_visible_rect().size.x
		if event is InputEventScreenTouch:
			if event.pressed and mobile_look_touch_id == -1 and event.position.x > screen_w * 0.4:
				mobile_look_touch_id = event.index
			elif not event.pressed and event.index == mobile_look_touch_id:
				mobile_look_touch_id = -1
		elif event is InputEventScreenDrag and event.index == mobile_look_touch_id:
			_on_look_vector_changed(event.relative)
			get_viewport().set_input_as_handled()

func toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Confine and hide cursor so it stays inside window and is invisible
		# CONFINED_HIDDEN works with touchpad slide (no click needed)
		if not is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		
func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func setup_mobile_controls():
	is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if OS.is_debug_build():
		if ProjectSettings.has_setting("input_devices/pointing/emulate_touch_from_mouse"):
			if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
				is_mobile = true
				
	if has_node("HUD/MobileControls"):
		$HUD/MobileControls.visible = true
		
		# Frosted Glass Aesthetic (Normal State)
		var glass_normal = StyleBoxFlat.new()
		glass_normal.bg_color = Color(0.05, 0.05, 0.08, 0.45)
		glass_normal.corner_radius_top_left = 35
		glass_normal.corner_radius_top_right = 35
		glass_normal.corner_radius_bottom_left = 35
		glass_normal.corner_radius_bottom_right = 35
		glass_normal.border_width_left = 2
		glass_normal.border_width_top = 2
		glass_normal.border_width_right = 2
		glass_normal.border_width_bottom = 2
		glass_normal.border_color = Color(1.0, 1.0, 1.0, 0.15)
		glass_normal.border_blend = true
		
		# Hover state StyleBox (Brighter background, glowing border)
		var glass_hover = glass_normal.duplicate() as StyleBoxFlat
		glass_hover.bg_color = Color(0.12, 0.12, 0.16, 0.65)
		glass_hover.border_color = Color(1.0, 1.0, 1.0, 0.6)
		
		# Pressed state StyleBox (Red tint for survival feedback)
		var glass_pressed = glass_normal.duplicate() as StyleBoxFlat
		glass_pressed.bg_color = Color(0.2, 0.05, 0.05, 0.8)
		glass_pressed.border_color = Color(0.85, 0.1, 0.1, 0.8)
		
		var buttons = [$HUD/MobileControls/SprintButton, $HUD/MobileControls/FlashlightButton]
		if has_node("HUD/PauseToggleButton"):
			buttons.append($HUD/PauseToggleButton)
			
		for btn in buttons:
			btn.add_theme_stylebox_override("normal", glass_normal)
			btn.add_theme_stylebox_override("hover", glass_hover)
			btn.add_theme_stylebox_override("pressed", glass_pressed)
			btn.add_theme_stylebox_override("focus", glass_hover)
			
			btn.pivot_offset = btn.custom_minimum_size / 2.0 if btn.custom_minimum_size != Vector2.ZERO else btn.size / 2.0
			
			btn.mouse_entered.connect(func():
				var tween = create_tween().set_parallel(true)
				tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_QUAD)
			)
			btn.mouse_exited.connect(func():
				var tween = create_tween().set_parallel(true)
				tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
			)
		
		if not is_mobile:
			# On PC, hide joysticks but keep the buttons visible as keyboard hints
			$HUD/MobileControls/Joystick.visible = false
			$HUD/MobileControls/LookPad.visible = false
			$HUD/MobileControls/SprintButton.text = "SPRINT [SHIFT]"
			$HUD/MobileControls/FlashlightButton.text = "LIGHT [F]"
			# Also un-capture the mouse if they want to click it? No, keep it captured, they just use keyboard.
			
		$HUD/MobileControls/Joystick.joystick_vector_changed.connect(_on_joystick_vector_changed)
		# LookPad signal kept for fallback; primary look handled via _input above
		if $HUD/MobileControls/LookPad.look_vector_changed.connect(_on_look_vector_changed) != OK:
			pass
		$HUD/MobileControls/SprintButton.button_down.connect(_on_sprint_button_down)
		$HUD/MobileControls/SprintButton.button_up.connect(_on_sprint_button_up)
		$HUD/MobileControls/FlashlightButton.pressed.connect(_on_flashlight_pressed)

func _process(delta):
	if not player:
		find_player()
		return
		
	# Update HUD progress bars
	if player.has_node("Stamina"):
		stamina_bar.value = player.get_node("Stamina").current_stamina
	if player.has_node("Sanity"):
		sanity_bar.value = player.get_node("Sanity").current_sanity
	if player.flashlight:
		battery_bar.value = player.flashlight.current_battery

	_update_bar_color(stamina_bar)
	_update_bar_color(sanity_bar)
	_update_bar_color(battery_bar)

	if not is_mobile:
		if Input.is_action_just_pressed("sprint"):
			var tween = create_tween().set_parallel(true)
			tween.tween_property($HUD/MobileControls/SprintButton, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_QUAD)
			$HUD/MobileControls/SprintButton.modulate = Color(1.5, 0.5, 0.5)
		elif Input.is_action_just_released("sprint"):
			var tween = create_tween().set_parallel(true)
			tween.tween_property($HUD/MobileControls/SprintButton, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
			$HUD/MobileControls/SprintButton.modulate = Color(1, 1, 1)

		if Input.is_action_just_pressed("toggle_flashlight"):
			var tween = create_tween().set_parallel(true)
			tween.tween_property($HUD/MobileControls/FlashlightButton, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_QUAD)
			$HUD/MobileControls/FlashlightButton.modulate = Color(1.5, 0.5, 0.5)
		elif Input.is_action_just_released("toggle_flashlight"):
			var tween = create_tween().set_parallel(true)
			tween.tween_property($HUD/MobileControls/FlashlightButton, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
			$HUD/MobileControls/FlashlightButton.modulate = Color(1, 1, 1)

func _update_bar_color(bar: ProgressBar):
	if not bar.has_theme_stylebox_override("fill"):
		var style = StyleBoxFlat.new()
		bar.add_theme_stylebox_override("fill", style)
	
	var fill = bar.get_theme_stylebox("fill") as StyleBoxFlat
	var percent = bar.value / 100.0
	fill.bg_color = Color(1.0 - percent, percent * 0.8 + 0.2, 0.2)


	# Vignette intensity based on low sanity
	if player.has_node("Sanity") and has_node("HUD/Vignette"):
		var sanity_val = player.get_node("Sanity").current_sanity
		if sanity_val < 50.0:
			$HUD/Vignette.visible = true
			$HUD/Vignette.modulate.a = (50.0 - sanity_val) / 50.0 * 0.75
		else:
			$HUD/Vignette.visible = false
			
	# Jumpscare flash effect if visible
	if jumpscare_panel.visible:
		var time = Time.get_ticks_msec() / 100.0
		if int(time) % 2 == 0:
			jumpscare_panel.color = Color(0.6, 0, 0)
			jumpscare_panel.get_node("ScaryFace").modulate = Color(1, 1, 1)
		else:
			jumpscare_panel.color = Color(0, 0, 0)
			jumpscare_panel.get_node("ScaryFace").modulate = Color(1, 0, 0)

func show_win():
	win_label.visible = true
	restart_button.visible = true
	if has_node("HUD/MobileControls"):
		$HUD/MobileControls.visible = false

# Called by main.gd when gameplay begins, to reset touch state
func on_gameplay_started():
	# Reset look touch tracking so tap-to-start doesn't get stuck as look drag
	mobile_look_touch_id = -1
	
	if is_mobile and has_node("HUD/MobileControls"):
		var look_pad = $HUD/MobileControls/LookPad
		var joystick = $HUD/MobileControls/Joystick
		look_pad.visible = true
		joystick.visible = true
		# Reset any stuck touch state from the objectives screen tap
		look_pad.dragging = false
		look_pad.touch_id = -1
		if joystick.has_method("reset"):
			joystick.reset()


func show_lose(is_jumpscare: bool):
	if has_node("HUD/MobileControls"):
		$HUD/MobileControls.visible = false
		
	if is_jumpscare:
		jumpscare_panel.visible = true
		await get_tree().create_timer(0.5).timeout
		jumpscare_panel.visible = false
		
	lose_label.visible = true
	restart_button.visible = true

func _on_restart_pressed():
	Main.is_replaying = true
	get_tree().reload_current_scene()

func _on_joystick_vector_changed(vector: Vector2):
	if is_instance_valid(player):
		player.mobile_movement_vector = vector

func _on_look_vector_changed(relative: Vector2):
	if is_instance_valid(player) and player.can_move:
		var sensitivity_scale = 0.6
		player.rotate_y(-relative.x * player.mouse_sensitivity * sensitivity_scale)
		if is_instance_valid(player.head):
			player.head.rotate_x(-relative.y * player.mouse_sensitivity * sensitivity_scale)
			player.head.rotation.x = clamp(player.head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
		player.sway_target_rot.y = -relative.x * 0.02
		player.sway_target_rot.x = -relative.y * 0.02


func _on_sprint_button_down():
	if player:
		player.mobile_sprint_active = true

func _on_sprint_button_up():
	if player:
		player.mobile_sprint_active = false

func _on_flashlight_pressed():
	if player and player.flashlight:
		player.flashlight.toggle()
