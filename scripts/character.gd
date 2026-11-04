extends Node3D
# Futbolista humano estilizado-realista para Cancha 19.
# Mantiene la API usada por main.gd: build, animate, kick, set_name_tag y set_controlled.

var species := "player"
var is_gk := false
var jersey := Color.WHITE
var shorts := Color.WHITE
var number := 1
var char_name := ""
var body: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_p: Node3D
var arm_n: Node3D
var leg_p: Node3D
var leg_n: Node3D
var tail: Node3D = null
var float_h := 0.0
var phase := 0.0
var kick_t := 99.0
var celebrate := false
var ready_pose := false
var _t := 0.0
var _marker: Node3D
var _arrow: Node3D
var _tag: Label3D
var _shadow: MeshInstance3D
var _top_y := 1.9

static var _shadow_tex: GradientTexture2D = null

func _mat(c: Color, rough := 0.82, metal := 0.0, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission:
		m.emission_enabled = true
		m.emission = c
	return m

func _sphere(r: float, h := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = 24
	m.rings = 16
	return m

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0 + 0.01)
	m.radial_segments = 16
	m.rings = 8
	return m

func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.rotation_degrees = rot
	n.scale = scale
	parent.add_child(n)
	return n

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	return m

static func shadow_tex() -> GradientTexture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0,0,0,0.48), Color(0,0,0,0)])
		g.offsets = PackedFloat32Array([0.0,1.0])
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.width = 96
		_shadow_tex.height = 96
	return _shadow_tex

func build(sp: String, jersey_col: Color, shorts_col: Color, num: int, gk: bool, glove: Color = Color.WHITE) -> void:
	species = sp
	jersey = jersey_col
	shorts = shorts_col
	number = num
	is_gk = gk
	phase = randf() * TAU
	_t = randf() * 10.0

	# Variedad humana natural: tonos de piel y cabello según el personaje original.
	var skin_palette: Array[Color] = [
		Color("#8a573b"), Color("#a96e4b"), Color("#70442f"),
		Color("#c18a65"), Color("#956044"), Color("#d0a07a"),
		Color("#5e392b"), Color("#b77c58")
	]
	var hair_palette: Array[Color] = [
		Color("#171412"), Color("#29201b"), Color("#493326"),
		Color("#17191d"), Color("#60442e")
	]
	var seed_value := absi(sp.hash() + num * 71)
	var skin: Color = skin_palette[seed_value % skin_palette.size()]
	var hair: Color = hair_palette[(seed_value / 3) % hair_palette.size()]
	var skin_m := _mat(skin, 0.88)
	var hair_m := _mat(hair, 0.95)
	var kit_m := _mat(jersey, 0.78)
	var shorts_m := _mat(shorts, 0.88)
	var dark_m := _mat(Color("#17191d"), 0.82)
	var sock_m := _mat(Color("#e9e8df"), 0.9)
	var shoe_m := _mat(Color("#17191c"), 0.58)
	var trim := _mat(Color("#e9e7df") if jersey.get_luminance() < 0.55 else Color("#222326"), 0.8)

	body = Node3D.new()
	add_child(body)
	hips = Node3D.new()
	hips.position.y = 0.91
	body.add_child(hips)

	# Piernas separadas, rodillas, medias y botines.
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(float(side) * 0.145, 0.0, 0.0)
		hips.add_child(leg)
		_part(leg, _capsule(0.105, 0.70), skin_m, Vector3(0,-0.34,0))
		_part(leg, _capsule(0.108, 0.37), shorts_m, Vector3(0,-0.045,0))
		_part(leg, _capsule(0.082, 0.31), sock_m, Vector3(0,-0.62,0.015))
		_part(leg, _box_mesh(Vector3(0.22,0.115,0.34)), shoe_m, Vector3(0,-0.82,0.075))
		_part(leg, _box_mesh(Vector3(0.225,0.025,0.29)), _mat(Color("#777b7d"),0.65), Vector3(0,-0.875,0.075))
		if side == 1: leg_p = leg
		else: leg_n = leg

	# Cadera y torso humano, con camiseta y cuello.
	_part(hips, _box_mesh(Vector3(0.43,0.22,0.28)), shorts_m, Vector3(0,0.0,0))
	torso = Node3D.new()
	hips.add_child(torso)
	_part(torso, _capsule(0.245,0.69), kit_m, Vector3(0,0.43,0))
	_part(torso, _cylinder(0.105,0.10), skin_m, Vector3(0,0.83,0))
	# Paneles laterales y ribetes de la camiseta.
	for side in [-1,1]:
		_part(torso, _box_mesh(Vector3(0.035,0.52,0.30)), trim, Vector3(float(side)*0.215,0.43,0))
	# dorsal y pequeño escudo en el pecho, orientados a la cámara frontal (+Z).
	var badge := _part(torso, _box_mesh(Vector3(0.09,0.11,0.018)), trim, Vector3(-0.13,0.60,0.245))
	var num_label := Label3D.new()
	num_label.text = str(num)
	num_label.font_size = 72
	num_label.pixel_size = 0.0035
	num_label.modulate = Color("#f7f5ed") if jersey.get_luminance() < 0.48 else Color("#202020")
	num_label.position = Vector3(0.0,0.48,0.251)
	num_label.rotation_degrees.y = 180
	num_label.outline_size = 3
	torso.add_child(num_label)

	# Brazos con mangas, antebrazos y manos; portero con guantes.
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.position = Vector3(float(side)*0.285,0.70,0)
		torso.add_child(arm)
		_part(arm,_capsule(0.105,0.30),kit_m,Vector3(0,-0.11,0))
		_part(arm,_capsule(0.073,0.37),skin_m,Vector3(0,-0.42,0))
		_part(arm,_sphere(0.078),_mat(glove,0.75) if gk else skin_m,Vector3(0,-0.64,0.015))
		if side == 1: arm_p = arm
		else: arm_n = arm

	# Cabeza, orejas, pelo, cejas, ojos discretos y nariz.
	head = Node3D.new()
	head.position = Vector3(0,0.91,0)
	torso.add_child(head)
	_part(head,_sphere(0.205,0.49),skin_m,Vector3(0,0,0),Vector3.ZERO,Vector3(0.82,1.0,0.88))
	_part(head,_sphere(0.174,0.22),hair_m,Vector3(0,0.115,-0.012),Vector3.ZERO,Vector3(1.02,0.60,0.95))
	# Pelo corto con volumen irregular arriba y nuca.
	_part(head,_sphere(0.15),hair_m,Vector3(0,0.145,-0.025),Vector3.ZERO,Vector3(1.0,0.55,1.0))
	for side in [-1,1]:
		_part(head,_sphere(0.045),skin_m,Vector3(float(side)*0.166,-0.015,0))
		_part(head,_sphere(0.025),_mat(Color("#211a17"),0.55),Vector3(float(side)*0.073,0.025,0.166),Vector3.ZERO,Vector3(1,0.75,0.45))
		_part(head,_box_mesh(Vector3(0.065,0.018,0.025)),hair_m,Vector3(float(side)*0.073,0.065,0.16),Vector3(0,0,float(side)*-7))
	_part(head,_sphere(0.025),skin_m,Vector3(0,-0.035,0.188),Vector3.ZERO,Vector3(0.8,1.3,0.8))
	_part(head,_box_mesh(Vector3(0.075,0.012,0.018)),_mat(Color("#694638")),Vector3(0,-0.105,0.174))

	# Sombra suave para anclar el jugador al césped.
	var qm := QuadMesh.new()
	qm.size = Vector2(1.25,1.25)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = shadow_tex()
	_shadow = _part(self,qm,sm,Vector3(0.08,0.012,0.04),Vector3(-90,0,0))

	_top_y = 2.02
	_marker = Node3D.new()
	_marker.visible = false
	add_child(_marker)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.58
	ring.outer_radius = 0.68
	_part(_marker,ring,_mat(Color("#c8f169"),0.5,0.0,true),Vector3(0,0.025,0))
	_arrow = Node3D.new()
	_marker.add_child(_arrow)
	_part(_arrow,_cylinder(0.10,0.22),_mat(Color("#c8f169"),0.4,0.0,true),Vector3(0,0,0))
	_tag = Label3D.new()
	_tag.text = char_name
	_tag.font_size = 42
	_tag.pixel_size = 0.005
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.outline_size = 10
	_tag.modulate = Color("#e8ffb0")
	_marker.add_child(_tag)
	_arrow.position.y = _top_y + 0.22
	_tag.position.y = _top_y + 0.58

func set_name_tag(n: String) -> void:
	char_name = n
	if _tag: _tag.text = n

func set_controlled(on: bool) -> void:
	if _marker: _marker.visible = on

func kick() -> void:
	kick_t = 0.0

func animate(delta: float, speed: float, face: Vector2) -> void:
	_t += delta
	kick_t += delta
	var mv := clampf(speed/1.8,0.0,1.0)
	var s := sin(phase) * mv
	var c := cos(phase) * mv
	var ke := clampf(1.0-kick_t/0.28,0.0,1.0)
	phase += delta * (6.5 + speed*1.15)
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y,atan2(face.x,face.y),clampf(delta*14.0,0.0,1.0))
	leg_p.rotation.x = lerpf(s*0.95,-1.35,ke)
	leg_n.rotation.x = -s*0.95 + 0.25*ke
	leg_p.position.y = maxf(0.0,-c)*0.045
	leg_n.position.y = maxf(0.0,c)*0.045
	if celebrate:
		arm_p.rotation.x = lerpf(arm_p.rotation.x,-2.8,0.22)
		arm_n.rotation.x = lerpf(arm_n.rotation.x,-2.8,0.22)
		arm_p.rotation.z = 0.55
		arm_n.rotation.z = -0.55
	elif ready_pose:
		arm_p.rotation.z = lerpf(arm_p.rotation.z,0.85,0.2)
		arm_n.rotation.z = lerpf(arm_n.rotation.z,-0.85,0.2)
	else:
		arm_p.rotation.x = lerpf(arm_p.rotation.x,-s*0.8+0.3*ke,0.45)
		arm_n.rotation.x = lerpf(arm_n.rotation.x,s*0.8-0.4*ke,0.45)
		arm_p.rotation.z = lerpf(arm_p.rotation.z,0.10,0.3)
		arm_n.rotation.z = lerpf(arm_n.rotation.z,-0.10,0.3)
	torso.rotation.x = lerpf(torso.rotation.x,0.12*mv-0.18*ke,0.3)
	hips.rotation.y = s*0.10
	head.rotation.x = -0.04*mv + sin(_t*2.0)*0.012
	var jump := absf(sin(_t*8.0+phase))*0.32 if celebrate else 0.0
	body.position.y = absf(sin(phase))*0.045*mv + jump
	if _shadow:
		var k := 1.0-jump*0.7
		_shadow.scale = Vector3(k,k,1.0)
	if _arrow and _marker.visible:
		_arrow.position.y = _top_y+0.22+sin(_t*8.0)*0.05
		_arrow.rotation.y = _t*2.5
