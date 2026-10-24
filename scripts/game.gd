extends Node3D

# Shadow Warrior: Egypt — self-contained playable prototype for Godot 4.2+
# All geometry and UI are generated at runtime; no external assets required.

const SPEED := 6.0
const PLAYER_MAX_HP := 100.0
const ENEMY_MAX_HP := 60.0
const ARENA_RADIUS := 21.0

var player: CharacterBody3D
var camera: Camera3D
var player_hp := PLAYER_MAX_HP
var enemies: Array[CharacterBody3D] = []
var enemy_data: Dictionary = {}
var attack_cooldown := 0.0
var attack_visual_time := 0.0
var invulnerable_time := 0.0
var sword: Node3D
var status_label: Label
var health_bar: ProgressBar
var movement := Vector2.ZERO
var joystick_touch := -1
var joystick_center := Vector2.ZERO
var joystick_area: Control
var joystick_knob: ColorRect
var touch_attack := false
var game_over := false
var kills := 0
var total_enemies := 3
var message_timer := 0.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_enemies()
	_build_ui()
	_update_ui()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and not game_over:
			status_label.text = "Defeat the temple guards!"
	if game_over:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_visual_time = maxf(0.0, attack_visual_time - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if sword:
		sword.rotation.z = -1.15 if attack_visual_time > 0.0 else 0.0
	if Input.is_key_pressed(KEY_SPACE) or touch_attack:
		_attack()
	_update_camera(delta)
	_update_enemies(delta)

func _physics_process(delta: float) -> void:
	if game_over or not is_instance_valid(player):
		return
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var axis := movement if movement.length() > 0.08 else keyboard
	var direction := Vector3(axis.x, 0, axis.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * SPEED
	player.velocity.z = direction.z * SPEED
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -ARENA_RADIUS, ARENA_RADIUS)
	player.position.z = clampf(player.position.z, -ARENA_RADIUS, ARENA_RADIUS)
	if direction.length() > 0.12:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 12.0))

func _build_world() -> void:
	RenderingServer.set_default_clear_color(Color("d6b78b"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	light.light_energy = 1.4
	light.shadow_enabled = false # better performance on mid-range Android
	add_child(light)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d6b78b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e8d8b7")
	environment.ambient_light_energy = 0.65
	env.environment = environment
	add_child(env)
	var sand := _material(Color("d8b678"))
	var stone := _material(Color("bba076"))
	var dark_stone := _material(Color("8d7354"))
	_make_box(self, Vector3(0, -0.55, 0), Vector3(90, 1, 90), sand, true)
	_make_box(self, Vector3(0, 0.03, -13), Vector3(25, 0.25, 8), stone, true)
	_make_box(self, Vector3(0, 0.15, -17), Vector3(13, 0.5, 4), dark_stone, true)
	for x in [-11.0, -6.0, 6.0, 11.0]:
		for z in [-12.0, -17.0]:
			_make_column(Vector3(x, 0, z), stone, dark_stone)
	_make_box(self, Vector3(0, 5.9, -17), Vector3(26, 1.2, 3), stone, false)
	for x in [-23.0, 23.0]:
		_make_box(self, Vector3(x, 1.5, 0), Vector3(1.5, 3, 46), stone, true)
	for z in [-23.0, 23.0]:
		_make_box(self, Vector3(0, 1.5, z), Vector3(46, 3, 1.5), stone, true)
	for x in [-16.0, 16.0]:
		for z in [-6.0, 7.0]:
			_make_box(self, Vector3(x, 0.7, z), Vector3(2.8, 1.4, 2.8), dark_stone, true)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Hero"
	player.position = Vector3(0, 0.2, 11)
	add_child(player)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.0
	player.add_child(collider)
	_make_fighter(player, Color("276477"), Color("c7a36d"), true)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	add_child(camera)
	camera.position = player.position + Vector3(0, 10, 13)
	camera.look_at(player.position + Vector3(0, 1, 0))

func _build_enemies() -> void:
	var locations := [Vector3(-7, 0.2, -5), Vector3(7, 0.2, -7), Vector3(0, 0.2, -15)]
	for location in locations:
		var enemy := CharacterBody3D.new()
		enemy.position = location
		add_child(enemy)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.42
		shape.height = 2.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 1.0
		enemy.add_child(collider)
		_make_fighter(enemy, Color("8b342b"), Color("c4aa76"), false)
		enemies.append(enemy)
		enemy_data[enemy] = {"hp": ENEMY_MAX_HP, "cooldown": 0.0}

func _make_fighter(body: Node3D, cloth: Color, skin: Color, hero: bool) -> void:
	var clothes := _material(cloth)
	var skin_mat := _material(skin)
	var metal := _material(Color("c8cbd0"))
	_make_box(body, Vector3(0, 1.25, 0), Vector3(0.85, 1.05, 0.52), clothes, false)
	_make_box(body, Vector3(0, 2.04, 0), Vector3(0.52, 0.58, 0.52), skin_mat, false)
	for x in [-0.27, 0.27]:
		_make_box(body, Vector3(x, 0.45, 0), Vector3(0.27, 0.9, 0.33), clothes, false)
	for x in [-0.57, 0.57]:
		_make_box(body, Vector3(x, 1.35, 0), Vector3(0.27, 0.85, 0.3), skin_mat, false)
	if hero:
		sword = Node3D.new()
		sword.position = Vector3(0.75, 1.08, -0.2)
		body.add_child(sword)
		_make_box(sword, Vector3(0, 0.45, 0), Vector3(0.13, 1.15, 0.13), metal, false)
		_make_box(sword, Vector3(0, -0.05, 0), Vector3(0.42, 0.1, 0.15), _material(Color("55432d")), false)
	else:
		_make_box(body, Vector3(0.7, 1.0, -0.12), Vector3(0.13, 1.2, 0.15), metal, false)

func _make_column(at: Vector3, stone: StandardMaterial3D, trim: StandardMaterial3D) -> void:
	_make_box(self, at + Vector3(0, 0.35, 0), Vector3(2.2, 0.7, 2.2), trim, true)
	_make_box(self, at + Vector3(0, 2.9, 0), Vector3(1.35, 4.6, 1.35), stone, true)
	_make_box(self, at + Vector3(0, 5.35, 0), Vector3(2.1, 0.5, 2.1), trim, true)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _make_box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material, collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	if collision:
		var static_body := StaticBody3D.new()
		static_body.position = at
		parent.add_child(static_body)
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var collider := CollisionShape3D.new()
		collider.shape = shape
		static_body.add_child(collider)

func _update_camera(delta: float) -> void:
	var target := player.position + Vector3(0, 9.5, 12.5)
	camera.position = camera.position.lerp(target, minf(1.0, delta * 5.0))
	camera.look_at(player.position + Vector3(0, 1.0, -2.0))

func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.52
	attack_visual_time = 0.24
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - player.global_position
		if offset.length() > 2.8:
			continue
		var forward := -player.global_transform.basis.z
		if forward.dot(offset.normalized()) < 0.1:
			continue
		var data: Dictionary = enemy_data[enemy]
		data["hp"] -= 30.0
		enemy_data[enemy] = data
		if data["hp"] <= 0.0:
			enemies.erase(enemy)
			enemy_data.erase(enemy)
			enemy.queue_free()
			kills += 1
			_update_ui()
			if kills >= total_enemies:
				_finish(true)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var data: Dictionary = enemy_data[enemy]
		data["cooldown"] = maxf(0.0, float(data["cooldown"]) - delta)
		var delta_pos := player.global_position - enemy.global_position
		delta_pos.y = 0
		var distance := delta_pos.length()
		if distance < 17.0 and distance > 1.5:
			enemy.position += delta_pos.normalized() * delta * 2.1
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
		elif distance <= 1.5 and float(data["cooldown"]) <= 0.0:
			data["cooldown"] = 1.4
			if invulnerable_time <= 0.0:
				player_hp = maxf(0.0, player_hp - 12.0)
				invulnerable_time = 0.45
				_update_ui()
				if player_hp <= 0.0:
					_finish(false)
		enemy_data[enemy] = data

func _finish(won: bool) -> void:
	game_over = true
	status_label.text = "VICTORY! Temple secured!" if won else "DEFEAT! Try again."
	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(150, 55)
	restart.set_anchors_preset(Control.PRESET_CENTER)
	restart.position = Vector2(-75, 35)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	get_node("HUD").add_child(restart)

func _update_ui() -> void:
	if health_bar:
		health_bar.value = player_hp
	if status_label and not game_over:
		status_label.text = "Guards defeated: %d / %d" % [kills, total_enemies]

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := VBoxContainer.new()
	top.position = Vector2(22, 15)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var title := Label.new()
	title.text = "SHADOW WARRIOR: EGYPT"
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(270, 23)
	health_bar.max_value = PLAYER_MAX_HP
	health_bar.value = player_hp
	top.add_child(health_bar)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	top.add_child(status_label)
	var help := Label.new()
	help.text = "WASD / arrows to move | SPACE to attack"
	help.position = Vector2(22, 122)
	root.add_child(help)
	# Mobile controls use anchors so they adapt to different screen sizes.
	joystick_area = Control.new()
	joystick_area.anchor_top = 1.0
	joystick_area.anchor_bottom = 1.0
	joystick_area.offset_left = 28
	joystick_area.offset_top = -215
	joystick_area.offset_right = 230
	joystick_area.offset_bottom = -13
	joystick_area.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(joystick_area)
	var base := ColorRect.new()
	base.color = Color(0.12, 0.14, 0.17, 0.45)
	base.position = Vector2(18, 18)
	base.size = Vector2(165, 165)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_area.add_child(base)
	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(0.9, 0.76, 0.45, 0.85)
	joystick_knob.size = Vector2(65, 65)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_area.add_child(joystick_knob)
	joystick_center = Vector2(100, 100)
	joystick_knob.position = joystick_center - joystick_knob.size / 2.0
	joystick_area.gui_input.connect(_on_joystick_input)
	var attack_button := Button.new()
	attack_button.text = "ATTACK"
	attack_button.add_theme_font_size_override("font_size", 25)
	attack_button.anchor_left = 1.0
	attack_button.anchor_right = 1.0
	attack_button.anchor_top = 1.0
	attack_button.anchor_bottom = 1.0
	attack_button.offset_left = -190
	attack_button.offset_right = -30
	attack_button.offset_top = -155
	attack_button.offset_bottom = -30
	attack_button.button_down.connect(func(): touch_attack = true)
	attack_button.button_up.connect(func(): touch_attack = false)
	root.add_child(attack_button)

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			joystick_touch = event.index
			_set_joystick(event.position)
		elif event.index == joystick_touch:
			joystick_touch = -1
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == joystick_touch:
		_set_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.pressed:
			_set_joystick(event.position)
		else:
			_reset_joystick()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_joystick(event.position)

func _set_joystick(point: Vector2) -> void:
	var offset := (point - joystick_center).limit_length(68.0)
	movement = Vector2(offset.x, offset.y) / 68.0
	joystick_knob.position = joystick_center + offset - joystick_knob.size / 2.0

func _reset_joystick() -> void:
	movement = Vector2.ZERO
	joystick_knob.position = joystick_center - joystick_knob.size / 2.0
