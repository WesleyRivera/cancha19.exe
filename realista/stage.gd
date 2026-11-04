extends Node3D
# Primera reconstrucción del escenario: cancha encerrada por un barrio denso en ladera.
# Los edificios son módulos arquitectónicos, no una fila de cubos decorativos.

var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}

func build() -> void:
	rng.randomize()
	_make_materials()
	_build_ground()
	_build_pitch()
	_build_goals()
	_build_favela()
	_build_fences()
	_build_wires()
	_build_lamps()

func _material(name: String, color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.0
	mats[name] = m
	return m

func _make_materials() -> void:
	_material("asphalt", Color(0.075, 0.082, 0.078))
	_material("turf", Color(0.075, 0.19, 0.105))
	_material("line", Color(0.78, 0.78, 0.69))
	_material("concrete", Color(0.34, 0.32, 0.29))
	_material("brick", Color(0.37, 0.19, 0.13))
	_material("plaster1", Color(0.57, 0.43, 0.31))
	_material("plaster2", Color(0.31, 0.39, 0.39))
	_material("plaster3", Color(0.48, 0.36, 0.27))
	_material("plaster4", Color(0.38, 0.43, 0.30))
	_material("metal", Color(0.12, 0.14, 0.15), 0.48)
	_material("glass", Color(0.035, 0.065, 0.08), 0.22)
	_material("lit", Color(1.0, 0.57, 0.23), 0.35)
	_material("roof", Color(0.19, 0.18, 0.16), 0.58)

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.material_override = mat
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

func _build_ground() -> void:
	_box(self, Vector3(160, 0.5, 130), Vector3(0, -0.38, -12), mats.asphalt)
	_box(self, Vector3(40, 0.12, 24), Vector3(0, -0.05, 0), mats.turf)

func _build_pitch() -> void:
	var z0 := 0.0
	_box(self, Vector3(0.12, 0.018, 24), Vector3(-19.4, 0.025, z0), mats.line)
	_box(self, Vector3(0.12, 0.018, 24), Vector3(19.4, 0.025, z0), mats.line)
	_box(self, Vector3(38.8, 0.018, 0.12), Vector3(0, 0.025, -11.4), mats.line)
	_box(self, Vector3(38.8, 0.018, 0.12), Vector3(0, 0.025, 11.4), mats.line)
	_box(self, Vector3(0.08, 0.018, 22.8), Vector3(0, 0.027, 0), mats.line)
	var circle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.5
	torus.outer_radius = 3.58
	circle.mesh = torus
	circle.position.y = 0.035
	circle.rotation.x = PI / 2
	circle.material_override = mats.line
	add_child(circle)

func _build_goals() -> void:
	for x in [-19.0, 19.0]:
		for z in [-3.0, 3.0]:
			_box(self, Vector3(0.16, 2.1, 0.16), Vector3(x, 1.05, z), mats.metal)
		_box(self, Vector3(0.16, 0.16, 6.0), Vector3(x, 2.1, 0), mats.metal)
		_box(self, Vector3(1.8, 0.05, 6.0), Vector3(x + (0.9 if x < 0 else -0.9), 0.1, 0), mats.metal)

func _building(x: float, z: float, w: float, d: float, floors: int, base_y: float, front_dir: float) -> void:
	var h := float(floors) * 2.8
	var colors := ["plaster1", "plaster2", "plaster3", "plaster4", "brick"]
	var facade = mats[colors[rng.randi_range(0, colors.size() - 1)]]
	var b := Node3D.new()
	b.position = Vector3(x, base_y, z)
	add_child(b)
	_box(b, Vector3(w, h, d), Vector3.ZERO, facade)
	_box(b, Vector3(w + 0.25, 0.18, d + 0.25), Vector3(0, h * 0.5, 0), mats.concrete)
	# Plantas, losas expuestas y ampliaciones autoconstruidas.
	for f in range(1, floors):
		_box(b, Vector3(w + 0.32, 0.13, d + 0.28), Vector3(0, -h * 0.5 + f * 2.8, 0), mats.concrete)
	# Fachada orientada a la cancha: ventanas profundas, marcos y balcones.
	var front_z := -front_dir * (d * 0.5 + 0.055)
	for f in range(floors):
		var yy := -h * 0.5 + 1.35 + f * 2.8
		var columns := maxi(1, int(w / 1.65))
		for c in range(columns):
			var xx := -w * 0.5 + (float(c) + 0.5) * w / columns
			var ww := minf(0.92, w / columns * 0.58)
			_box(b, Vector3(ww + 0.18, 1.18, 0.13), Vector3(xx, yy, front_z), mats.concrete)
			var glassmat: Material = mats.lit if rng.randf() < 0.38 else mats.glass
			_box(b, Vector3(ww, 0.98, 0.08), Vector3(xx, yy, front_z - front_dir * 0.075), glassmat)
			# Rejas verticales.
			for bar in range(3):
				var bx := xx - ww * 0.38 + float(bar) * ww * 0.38
				_box(b, Vector3(0.025, 1.08, 0.045), Vector3(bx, yy, front_z - front_dir * 0.15), mats.metal)
			# Balcones salteados, no repetidos en todas las ventanas.
			if rng.randf() < 0.34:
				var balcony_z := front_z - front_dir * 0.65
				_box(b, Vector3(ww + 0.5, 0.12, 1.05), Vector3(xx, yy - 0.62, balcony_z), mats.concrete)
				_box(b, Vector3(ww + 0.5, 0.55, 0.055), Vector3(xx, yy - 0.33, balcony_z - front_dir * 0.5), mats.metal)
	# Azotea con tanques, antenas y láminas improvisadas.
	for i in range(rng.randi_range(1, 3)):
		var tx := rng.randf_range(-w * 0.36, w * 0.36)
		_cylinder(b, 0.42, 1.05, Vector3(tx, h * 0.5 + 0.6, rng.randf_range(-d * 0.25, d * 0.25)), mats.metal)
	_box(b, Vector3(w * 0.48, 0.08, d * 0.42), Vector3(w * 0.2, h * 0.5 + 0.25, 0), mats.roof, Vector3(deg_to_rad(-4), 0, 0))
	# Escalera exterior lateral.
	if floors > 2:
		for step in range(floors * 3):
			var sy := -h * 0.5 + 0.35 + step * 0.28
			var sz := d * 0.5 + 0.25 + step * 0.28
			_box(b, Vector3(0.9, 0.12, 0.65), Vector3(w * 0.5 + 0.48, sy, sz), mats.concrete)

func _build_favela() -> void:
	# Edificios de primer plano, laterales y fondo: la cancha queda hundida en el barrio.
	for side in [-1.0, 1.0]:
		for i in range(7):
			var x := side * (25.5 + float(i % 2) * 5.2)
			var z := -17.0 + float(i) * 5.8
			_building(x, z, rng.randf_range(5.0, 8.5), rng.randf_range(4.5, 7.0), rng.randi_range(2, 5), 0.0, 1.0)
		for row in range(5):
			var x := side * (18.0 + float(row) * 3.7)
			var z := -37.0 - float(row) * 5.2
			_building(x, z, rng.randf_range(7.0, 11.0), rng.randf_range(5.0, 8.0), rng.randi_range(3, 6), 1.5 + row * 1.6, 1.0)
	# Silueta de ladera densamente construida detrás de las porterías.
	for row in range(5):
		for col in range(12):
			var x := -42.0 + col * 7.6 + rng.randf_range(-1.0, 1.0)
			var z := -48.0 - row * 6.5
			var floors := rng.randi_range(2, 6)
			_building(x, z, rng.randf_range(5.5, 8.8), rng.randf_range(4.5, 7.0), floors, row * 1.9, 1.0)
	# Viviendas pequeñas y apretadas en los bordes de la cancha.
	for side in [-1.0, 1.0]:
		for i in range(4):
			_building(side * 23.0, -8.0 + i * 5.0, 4.0, 4.5, rng.randi_range(2, 3), 0.0, 1.0)

func _build_fences() -> void:
	for side in [-1.0, 1.0]:
		for i in range(21):
			var z := -11.5 + i * 1.15
			_cylinder(self, 0.035, 3.6, Vector3(side * 20.2, 1.8, z), mats.metal)
		_box(self, Vector3(0.07, 0.07, 24), Vector3(side * 20.2, 3.55, 0), mats.metal)
		_box(self, Vector3(0.07, 0.07, 24), Vector3(side * 20.2, 0.12, 0), mats.metal)
		for y in range(1, 12):
			_box(self, Vector3(0.035, 0.035, 24), Vector3(side * 20.2, y * 0.29, 0), mats.metal)
	for z in [-12.0, 12.0]:
		_box(self, Vector3(40, 3.6, 0.07), Vector3(0, 1.8, z), mats.metal)

func _build_wires() -> void:
	for i in range(18):
		var x := -38.0 + i * 4.5
		var cable := MeshInstance3D.new()
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(Vector3(x, 13.0 + rng.randf_range(-1.0, 1.0), -22))
		im.surface_add_vertex(Vector3(x + 10, 10.0, -35))
		im.surface_end()
		cable.mesh = im
		cable.material_override = mats.metal
		add_child(cable)

func _build_lamps() -> void:
	for x in [-22.0, 22.0]:
		var pole := _cylinder(self, 0.16, 12.0, Vector3(x, 6.0, -2), mats.metal)
		var head := _box(self, Vector3(1.8, 0.35, 0.55), Vector3(x, 12.0, -2), mats.lit)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 11.5, -2)
		light.light_color = Color(1.0, 0.76, 0.53)
		light.light_energy = 5.0
		light.omni_range = 30
		light.shadow_enabled = true
		add_child(light)
