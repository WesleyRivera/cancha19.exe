extends Node3D

const Stage = preload("res://stage.gd")

var player: Node3D
var camera: Camera3D
var ball: RigidBody3D
var move_speed := 7.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ball()
	_build_camera()
	_build_lighting()

func _build_world() -> void:
	var stage := Stage.new()
	add_child(stage)
	stage.build()

func _mat(color: Color, rough := 0.82) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = material
	parent.add_child(n)
	return n

func _build_player() -> void:
	player = Node3D.new()
	player.position = Vector3(-5, 0, 0)
	add_child(player)
	var skin := _mat(Color(0.48, 0.29, 0.19))
	var shirt := _mat(Color(0.08, 0.22, 0.62))
	var shorts := _mat(Color(0.035, 0.045, 0.075))
	var body := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.29
	torso.height = 0.92
	body.mesh = torso
	body.position.y = 1.18
	body.material_override = shirt
	player.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.38
	head.mesh = sphere
	head.position.y = 1.88
	head.material_override = skin
	player.add_child(head)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CapsuleMesh.new()
		lm.radius = 0.105
		lm.height = 0.72
		leg.mesh = lm
		leg.position = Vector3(side * 0.14, 0.48, 0)
		leg.material_override = shorts
		player.add_child(leg)
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.085
		am.height = 0.66
		arm.mesh = am
		arm.position = Vector3(side * 0.37, 1.22, 0)
		arm.rotation.z = side * -0.18
		arm.material_override = skin
		player.add_child(arm)

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.position = Vector3(-2.8, 0.23, 0)
	ball.mass = 0.45
	ball.linear_damp = 0.35
	ball.angular_damp = 0.3
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.22
	shape.shape = sphere_shape
	ball.add_child(shape)
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	visual.mesh = sphere
	visual.material_override = _mat(Color(0.92, 0.91, 0.84), 0.48)
	ball.add_child(visual)
	add_child(ball)

func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.035, 0.055, 0.095)
	sky_mat.sky_horizon_color = Color(0.48, 0.24, 0.15)
	sky_mat.ground_bottom_color = Color(0.025, 0.025, 0.03)
	sky_mat.ground_horizon_color = Color(0.18, 0.12, 0.10)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.42, 0.52)
	e.ambient_light_energy = 0.48
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.35
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color(1.0, 0.66, 0.43)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 17, 28)
	camera.fov = 52
	add_child(camera)
	camera.look_at(Vector3(0, 2.0, -4), Vector3.UP)
	camera.current = true

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	input.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	input.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	if input.length() > 1.0:
		input = input.normalized()
	player.position.x += input.x * move_speed * delta
	player.position.z += input.y * move_speed * delta
	player.position.x = clampf(player.position.x, -18.5, 18.5)
	player.position.z = clampf(player.position.z, -10.5, 10.5)
	if input.length() > 0.05:
		player.rotation.y = atan2(input.x, input.y)
	if Input.is_key_pressed(KEY_SPACE) and player.global_position.distance_to(ball.global_position) < 2.0 and ball.linear_velocity.length() < 0.5:
		var direction := (ball.global_position - player.global_position).normalized()
		ball.apply_central_impulse(Vector3(direction.x, 0.18, direction.z) * 5.5)
