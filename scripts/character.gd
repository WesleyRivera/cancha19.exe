extends Node3D
# Muñeco 3D armado con formas básicas (esferas, cápsulas, cajas...).
# El modelo mira hacia +Z y se gira con rotation.y.
# Cada "especie" es un personaje original con su propia cara y accesorios.
# Esqueleto: body > hips > (torso > cabeza y brazos) + piernas.

var species := "rana"
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

static var _outline: ShaderMaterial = null
static var _shadow_tex: GradientTexture2D = null


# ---------- materiales y formas ----------
static func outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode cull_front, unshaded;\nvoid vertex(){ VERTEX += NORMAL * 0.02; }\nvoid fragment(){ ALBEDO = vec3(0.07, 0.04, 0.03); }\n"
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline


static func shadow_tex() -> GradientTexture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 128
		_shadow_tex.height = 128
	return _shadow_tex


func _mat(c: Color, rough := 0.75, metal := 0.0, outline := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if outline:
		m.next_pass = outline_mat()
	return m


func _glow(c: Color, e := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 20
	c.rings = 6
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _cyl(rt: float, rb: float, h: float, seg := 18) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(0.0, r, h, 14)


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


# altura (z) de la superficie de una cabeza elipsoidal en el punto (x, y)
func _surf(hr: float, hs: Vector3, x: float, y: float) -> float:
	var v := 1.0 - pow(x / (hr * hs.x), 2.0) - pow(y / (hr * hs.y), 2.0)
	return hr * hs.z * sqrt(maxf(v, 0.0))


func _eye_pair(parent: Node3D, x: float, y: float, z: float, r: float, pr := 0.5) -> void:
	for s: int in [-1, 1]:
		_part(parent, _sphere(r), _mat(Color.WHITE, 0.3, 0.0, false), Vector3(s * x, y, z))
		_part(parent, _sphere(r * pr), _mat(Color("#15100c"), 0.3, 0.0, false), Vector3(s * x, y, z + r * 0.72))


# ---------- parámetros de cada especie ----------
func _params(sp: String) -> Dictionary:
	match sp:
		"rana":
			return {"skin": Color("#5ec24a"), "limb": Color("#6fd058"), "shoe": Color("#2b6e2a"), "head_r": 0.40, "head_s": Vector3(1.2, 0.82, 1.0)}
		"gato":
			return {"skin": Color("#e89a3c"), "limb": Color("#e89a3c"), "shoe": Color("#f2f2f2")}
		"cocodrilo":
			return {"skin": Color("#4f9a3f"), "limb": Color("#4f9a3f"), "shoe": Color("#4a2f1a"), "head_r": 0.36, "torso_r": 0.28, "leg_r": 0.115, "arm_r": 0.095}
		"pinguino":
			return {"skin": Color("#1f2433"), "limb": Color("#1f2433"), "shoe": Color("#f08a1c"), "head_r": 0.36, "arm_r": 0.07}
		"robot":
			return {"skin": Color("#b9c2cb"), "limb": Color("#8d96a0"), "shoe": Color("#555a62"), "head_r": 0.3, "metal": 0.75, "rough": 0.38, "head_box": Vector3(0.62, 0.52, 0.5)}
		"monstruo":
			return {"skin": Color("#8d52c8"), "limb": Color("#7b43b4"), "shoe": Color("#341a55"), "head_r": 0.42, "torso_r": 0.3, "arm_len": 0.58, "arm_r": 0.1}
		"fantasma":
			return {"skin": Color("#eef2ff"), "limb": Color("#eef2ff"), "shoe": Color("#eef2ff"), "head_r": 0.4, "float": 0.16, "arm_len": 0.38, "leg_len": 0.36, "rough": 0.3}
		"alien":
			return {"skin": Color("#55d6c5"), "limb": Color("#43bba9"), "shoe": Color("#1f5d56"), "head_r": 0.34, "head_s": Vector3(1.0, 1.28, 1.0), "arm_r": 0.07, "leg_r": 0.085}
		"papa":
			return {"skin": Color("#b8854f"), "limb": Color("#9c6d3c"), "shoe": Color("#3b2a1a"), "merged": true, "torso_r": 0.40, "torso_h": 0.5, "arm_x": 0.47, "arm_y": 0.72, "arm_r": 0.065, "leg_r": 0.08, "head_y": 0.92, "num_z": 0.3}
		"hotdog":
			return {"skin": Color("#e6b96a"), "limb": Color("#c8563a"), "shoe": Color("#f2d34a"), "custom_head": true, "head_y": 1.1, "arm_r": 0.075}
		"pina":
			return {"skin": Color("#e9b62f"), "limb": Color("#d29a1e"), "shoe": Color("#2f7d32"), "merged": true, "torso_r": 0.40, "torso_h": 0.5, "arm_x": 0.47, "arm_y": 0.72, "arm_r": 0.065, "leg_r": 0.08, "head_y": 0.92, "num_z": 0.3}
		"huevo":
			return {"skin": Color("#f8f6ee"), "limb": Color("#f0eee6"), "shoe": Color("#d93a3a"), "custom_head": true, "head_y": 1.05, "rough": 0.3, "arm_r": 0.07, "leg_r": 0.08}
	return {}


# ---------- construcción ----------
func build(sp: String, jersey_col: Color, shorts_col: Color, num: int, gk: bool, glove: Color = Color.WHITE) -> void:
	species = sp
	jersey = jersey_col
	shorts = shorts_col
	number = num
	is_gk = gk
	phase = randf() * 6.0
	_t = randf() * 10.0
	var P: Dictionary = _params(sp)
	var skin: Color = P.get("skin", Color("#e0ac80"))
	var limb: Color = P.get("limb", skin)
	var shoe: Color = P.get("shoe", Color("#222222"))
	var hr: float = P.get("head_r", 0.37)
	var hs: Vector3 = P.get("head_s", Vector3.ONE)
	var tr: float = P.get("torso_r", 0.25)
	var th: float = P.get("torso_h", 0.66)
	var leg_len: float = P.get("leg_len", 0.58)
	var arm_len: float = P.get("arm_len", 0.5)
	var arm_r: float = P.get("arm_r", 0.085)
	var leg_r: float = P.get("leg_r", 0.105)
	var merged: bool = P.get("merged", false)
	var custom_head: bool = P.get("custom_head", false)
	var metal: float = P.get("metal", 0.0)
	var rough: float = P.get("rough", 0.75)
	float_h = P.get("float", 0.0)

	body = Node3D.new()
	add_child(body)
	hips = Node3D.new()
	hips.position = Vector3(0, leg_len + 0.05, 0)
	body.add_child(hips)

	# piernas
	for s: int in [1, -1]:
		var leg := Node3D.new()
		leg.position = Vector3(s * 0.15, 0, 0)
		hips.add_child(leg)
		if sp != "fantasma":
			_part(leg, _capsule(leg_r, leg_len + 0.02), _mat(limb, rough, metal), Vector3(0, -leg_len * 0.5, 0))
			_part(leg, _cyl(leg_r + 0.015, leg_r + 0.015, 0.1), _mat(jersey.darkened(0.12), 0.8), Vector3(0, -leg_len * 0.42, 0))
			_part(leg, _box(0.25, 0.14, 0.38), _mat(shoe, 0.6, metal), Vector3(0, -leg_len + 0.02, 0.07))
		if s == 1:
			leg_p = leg
		else:
			leg_n = leg
	# pantaloneta
	_part(hips, _box(0.54, 0.24, 0.36), _mat(shorts_col, 0.8), Vector3(0, -0.02, 0))

	# torso
	torso = Node3D.new()
	hips.add_child(torso)
	var trim: Color = Color("#f4f4f4") if jersey.get_luminance() < 0.6 else Color("#1c1c1c")
	var num_y := th * 0.5 + 0.1
	var num_z := -tr - 0.012
	if not merged:
		_part(torso, _capsule(tr, th), _mat(jersey, 0.85), Vector3(0, th * 0.5 + 0.06, 0))
		_part(torso, _cyl(tr + 0.008, tr + 0.008, 0.07), _mat(trim, 0.85, 0.0, false), Vector3(0, th * 0.78, 0))
	else:
		num_y = 0.38
		num_z = -float(P.get("num_z", 0.3)) - 0.02
	var lb := Label3D.new()
	lb.text = str(num)
	lb.font_size = 96
	lb.pixel_size = 0.0034
	lb.modulate = Color.WHITE if jersey.get_luminance() < 0.5 else Color("#1a1a1a")
	lb.outline_size = 0
	lb.position = Vector3(0, num_y, num_z)
	lb.rotation_degrees = Vector3(0, 180, 0)
	torso.add_child(lb)

	# brazos
	var ax: float = P.get("arm_x", tr + 0.07)
	var ay: float = P.get("arm_y", th * 0.88)
	for s: int in [1, -1]:
		var arm := Node3D.new()
		arm.position = Vector3(s * ax, ay, 0)
		torso.add_child(arm)
		_part(arm, _capsule(arm_r, arm_len), _mat(limb, rough, metal), Vector3(0, -arm_len * 0.5 + 0.06, 0))
		if gk:
			_part(arm, _sphere(0.125), _mat(glove, 0.6), Vector3(0, -arm_len + 0.07, 0))
		else:
			var hand: Color = P.get("hand", limb)
			_part(arm, _sphere(0.09), _mat(hand, 0.6, metal), Vector3(0, -arm_len + 0.07, 0))
		if not merged and sp != "fantasma" and sp != "pinguino":
			_part(arm, _cyl(arm_r + 0.02, arm_r + 0.028, 0.16), _mat(jersey, 0.85), Vector3(0, -0.02, 0))
		if s == 1:
			arm_p = arm
		else:
			arm_n = arm

	# cabeza
	head = Node3D.new()
	var hy: float = P.get("head_y", th + 0.06 + hr * hs.y * 0.85)
	head.position = Vector3(0, hy, 0)
	torso.add_child(head)
	if P.has("head_box"):
		var hb: Vector3 = P["head_box"]
		_part(head, _box(hb.x, hb.y, hb.z), _mat(skin, rough, metal))
	elif not merged and not custom_head:
		_part(head, _sphere(hr), _mat(skin, rough, metal), Vector3.ZERO, Vector3.ZERO, hs)

	_decorate(sp, hr, hs, tr, th, skin)

	# sombra suave en el piso
	var qm := QuadMesh.new()
	qm.size = Vector2(1.7, 1.7)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = shadow_tex()
	_shadow = _part(self, qm, sm, Vector3(0.12, 0.015, 0.05), Vector3(-90, 0, 0))

	# marcador de jugador controlado (anillo, flecha y nombre)
	_top_y = hips.position.y + hy + (hr * hs.y if not merged else 0.3) + 0.2
	_marker = Node3D.new()
	_marker.visible = false
	add_child(_marker)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.78
	_part(_marker, ring, _glow(Color("#c8f169"), 1.6), Vector3(0, 0.03, 0))
	_arrow = Node3D.new()
	_marker.add_child(_arrow)
	_part(_arrow, _cyl(0.17, 0.0, 0.3), _glow(Color("#c8f169"), 1.6), Vector3(0, 0, 0))
	_tag = Label3D.new()
	_tag.text = char_name
	_tag.font_size = 54
	_tag.pixel_size = 0.0055
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.outline_size = 14
	_tag.modulate = Color("#e8ffb0")
	_marker.add_child(_tag)
	_arrow.position = Vector3(0, _top_y + 0.35, 0)
	_tag.position = Vector3(0, _top_y + 0.8, 0)


func set_name_tag(n: String) -> void:
	char_name = n
	if _tag:
		_tag.text = n


func set_controlled(on: bool) -> void:
	if _marker:
		_marker.visible = on


func kick() -> void:
	kick_t = 0.0


# ---------- aspecto de cada especie ----------
func _decorate(sp: String, hr: float, hs: Vector3, tr: float, th: float, skin: Color) -> void:
	match sp:
		"rana": _d_rana(hr, hs, skin)
		"gato": _d_gato(hr, hs, skin)
		"cocodrilo": _d_cocodrilo(hr, hs, skin, tr, th)
		"pinguino": _d_pinguino(hr, hs, th)
		"robot": _d_robot(th, tr)
		"monstruo": _d_monstruo(hr, hs)
		"fantasma": _d_fantasma(hr, hs)
		"alien": _d_alien(hr, hs)
		"papa": _d_papa()
		"hotdog": _d_hotdog()
		"pina": _d_pina()
		"huevo": _d_huevo()


func _dark() -> StandardMaterial3D:
	return _mat(Color("#15100c"), 0.4, 0.0, false)


func _d_rana(hr: float, hs: Vector3, skin: Color) -> void:
	var ty := hr * hs.y * 0.8
	for s: int in [-1, 1]:
		_part(head, _sphere(0.16), _mat(skin), Vector3(s * 0.23, ty, 0.1))
		_part(head, _sphere(0.12), _mat(Color.WHITE, 0.3, 0.0, false), Vector3(s * 0.23, ty + 0.02, 0.17))
		_part(head, _sphere(0.065), _dark(), Vector3(s * 0.23, ty + 0.02, 0.27))
		_part(head, _sphere(0.025), _mat(Color("#1d4a1c"), 0.5, 0.0, false), Vector3(s * 0.07, 0.04, _surf(hr, hs, s * 0.07, 0.04) + 0.01))
	_part(head, _box(0.66, 0.05, 0.06), _mat(Color("#7a1f26"), 0.5, 0.0, false), Vector3(0, -0.1, _surf(hr, hs, 0.0, -0.1)))
	_part(head, _sphere(0.07), _mat(Color("#ff9bb0"), 0.7, 0.0, false), Vector3(-0.33, -0.05, 0.22), Vector3.ZERO, Vector3(1, 0.8, 0.4))
	_part(head, _sphere(0.07), _mat(Color("#ff9bb0"), 0.7, 0.0, false), Vector3(0.33, -0.05, 0.22), Vector3.ZERO, Vector3(1, 0.8, 0.4))


func _d_gato(hr: float, hs: Vector3, skin: Color) -> void:
	for s: int in [-1, 1]:
		_part(head, _cone(0.13, 0.3), _mat(skin), Vector3(s * 0.21, hr * 0.95, -0.02), Vector3(0, 0, -s * 16))
		_part(head, _cone(0.07, 0.2), _mat(Color("#ff9bb0"), 0.8, 0.0, false), Vector3(s * 0.21, hr * 0.93, 0.03), Vector3(0, 0, -s * 16))
	# máscara de luchador
	_part(head, _cyl(hr + 0.012, hr + 0.012, 0.2), _mat(Color("#c1272d")), Vector3(0, 0.07, 0))
	for s: int in [-1, 1]:
		_part(head, _sphere(0.1), _mat(Color.WHITE, 0.3, 0.0, false), Vector3(s * 0.15, 0.07, hr), Vector3.ZERO, Vector3(1, 1.1, 0.5))
		_part(head, _sphere(0.05), _dark(), Vector3(s * 0.15, 0.07, hr + 0.04))
		for i: int in [-1, 0, 1]:
			_part(head, _cyl(0.007, 0.007, 0.36), _mat(Color("#f2f2f2"), 0.5, 0.0, false), Vector3(s * 0.34, -0.1 + i * 0.035, 0.2), Vector3(0, 0, 90 + i * s * 12))
	_part(head, _sphere(0.05), _mat(Color("#ff8fa3"), 0.6, 0.0, false), Vector3(0, -0.06, _surf(hr, hs, 0.0, -0.06) + 0.01))
	_part(head, _box(0.14, 0.025, 0.03), _dark(), Vector3(0, -0.15, _surf(hr, hs, 0.0, -0.15) + 0.01))
	# cola
	tail = Node3D.new()
	tail.position = Vector3(0, 0.0, -0.22)
	hips.add_child(tail)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(-70, 0, 0)
	tail.add_child(tilt)
	_part(tilt, _capsule(0.055, 0.75), _mat(skin), Vector3(0, 0.37, 0))
	_part(tilt, _sphere(0.065), _mat(Color("#3a2410")), Vector3(0, 0.72, 0))


func _d_cocodrilo(hr: float, hs: Vector3, skin: Color, tr: float, th: float) -> void:
	_part(head, _box(0.34, 0.17, 0.5), _mat(skin), Vector3(0, -0.08, 0.4))
	_part(head, _box(0.32, 0.07, 0.44), _mat(Color("#c9e8a0")), Vector3(0, -0.19, 0.36))
	for s: int in [-1, 1]:
		for i: int in 3:
			_part(head, _box(0.035, 0.07, 0.035), _mat(Color.WHITE, 0.4, 0.0, false), Vector3(s * 0.15, -0.16, 0.3 + i * 0.12))
		_part(head, _sphere(0.1), _mat(skin), Vector3(s * 0.17, 0.3, 0.14))
		_part(head, _sphere(0.07), _mat(Color("#f2e04a"), 0.4, 0.0, false), Vector3(s * 0.17, 0.31, 0.21))
		_part(head, _sphere(0.04), _dark(), Vector3(s * 0.17, 0.31, 0.27), Vector3.ZERO, Vector3(0.4, 1.2, 0.5))
		_part(head, _sphere(0.03), _dark(), Vector3(s * 0.07, -0.03, 0.65))
	for i: int in 3:
		_part(torso, _cone(0.08, 0.17), _mat(Color("#2f6e2a")), Vector3(0, th * 0.35 + i * 0.15, -tr * 0.95), Vector3(-35, 0, 0))
	tail = Node3D.new()
	tail.position = Vector3(0, 0.0, -0.2)
	hips.add_child(tail)
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(-100, 0, 0)
	tail.add_child(tilt)
	_part(tilt, _cyl(0.02, 0.17, 0.8), _mat(skin), Vector3(0, 0.4, 0))


func _d_pinguino(hr: float, hs: Vector3, th: float) -> void:
	_part(head, _sphere(0.28), _mat(Color.WHITE, 0.4), Vector3(0, -0.04, 0.2), Vector3.ZERO, Vector3(1, 0.9, 0.55))
	for s: int in [-1, 1]:
		_part(head, _sphere(0.05), _dark(), Vector3(s * 0.11, 0.06, 0.34))
		_part(head, _sphere(0.016), _mat(Color.WHITE, 0.3, 0.0, false), Vector3(s * 0.11 + 0.015, 0.08, 0.385))
	_part(head, _cyl(0.0, 0.1, 0.2), _mat(Color("#f08a1c")), Vector3(0, -0.06, 0.45), Vector3(90, 0, 0))
	var sc := TorusMesh.new()
	sc.inner_radius = 0.17
	sc.outer_radius = 0.29
	_part(torso, sc, _mat(Color("#e0302a"), 0.9), Vector3(0, th + 0.08, 0))
	_part(torso, _box(0.1, 0.3, 0.07), _mat(Color("#e0302a"), 0.9), Vector3(0.12, th - 0.08, 0.26), Vector3(0, 0, 8))


func _d_robot(th: float, tr: float) -> void:
	var metal_m := _mat(Color("#8d96a0"), 0.4, 0.7)
	for s: int in [-1, 1]:
		_part(head, _sphere(0.075), _glow(Color("#ffe14a"), 2.5), Vector3(s * 0.15, 0.05, 0.255))
		_part(head, _cyl(0.08, 0.08, 0.1), metal_m, Vector3(s * 0.33, 0, 0), Vector3(0, 0, 90))
		for q: int in [-1, 1]:
			_part(head, _sphere(0.03), _mat(Color("#40454c"), 0.5, 0.6, false), Vector3(s * 0.27, q * 0.19, 0.25))
	for i: int in [-1, 0, 1]:
		_part(head, _box(0.04, 0.12, 0.02), _mat(Color("#20242a"), 0.5, 0.0, false), Vector3(i * 0.08, -0.14, 0.255))
	_part(head, _cyl(0.02, 0.02, 0.26), metal_m, Vector3(0, 0.39, 0))
	_part(head, _sphere(0.055), _glow(Color("#ff3a2a"), 2.5), Vector3(0, 0.54, 0))
	var rust := _mat(Color("#9a5a2a"), 0.9, 0.0, false)
	_part(head, _box(0.18, 0.12, 0.02), rust, Vector3(-0.15, 0.12, 0.256), Vector3(0, 0, 10))
	_part(head, _box(0.1, 0.08, 0.02), rust, Vector3(0.2, -0.12, 0.256))
	_part(torso, _box(0.2, 0.12, 0.02), rust, Vector3(0.1, th * 0.4, tr * 0.97))


func _d_monstruo(hr: float, hs: Vector3) -> void:
	var xs := [-0.2, 0.0, 0.2]
	var ys := [0.1, 0.18, 0.1]
	for i: int in 3:
		var x: float = xs[i]
		var y: float = ys[i]
		var z := _surf(hr, hs, x, y) - 0.02
		_part(head, _sphere(0.095), _mat(Color.WHITE, 0.3, 0.0, false), Vector3(x, y, z))
		_part(head, _sphere(0.05), _mat(Color("#f2c21a"), 0.3, 0.0, false), Vector3(x, y, z + 0.06))
		_part(head, _sphere(0.028), _dark(), Vector3(x, y, z + 0.1))
	var mz := _surf(hr, hs, 0.0, -0.17)
	_part(head, _box(0.5, 0.08, 0.05), _mat(Color("#2a0f2e"), 0.5, 0.0, false), Vector3(0, -0.17, mz))
	for s: int in [-1, 1]:
		_part(head, _cyl(0.035, 0.0, 0.11), _mat(Color.WHITE, 0.4, 0.0, false), Vector3(s * 0.11, -0.2, mz + 0.01))
		_part(head, _cone(0.09, 0.3), _mat(Color("#f1e4c0")), Vector3(s * 0.25, hr * 0.9, 0), Vector3(0, 0, -s * 25))
	for i: int in 8:
		var a := i * 0.785
		_part(head, _cone(0.07, 0.16), _mat(Color("#a86be0")), Vector3(cos(a) * 0.28, 0.3 + 0.07 * sin(i * 2.3), sin(a) * 0.28), Vector3(sin(a) * 40.0, 0, -cos(a) * 40.0))


func _d_fantasma(hr: float, hs: Vector3) -> void:
	var white := _mat(Color("#eef2ff"), 0.3)
	_part(hips, _cyl(0.3, 0.5, 0.5), white, Vector3(0, -0.15, 0))
	for i: int in 9:
		var a := i * TAU / 9.0
		_part(hips, _sphere(0.12), white, Vector3(cos(a) * 0.45, -0.4, sin(a) * 0.45))
	for s: int in [-1, 1]:
		_part(head, _sphere(0.07), _dark(), Vector3(s * 0.14, 0.05, _surf(hr, hs, s * 0.14, 0.05) - 0.02), Vector3.ZERO, Vector3(0.8, 1.3, 0.5))
		_part(head, _sphere(0.06), _mat(Color("#ff9bb0"), 0.7, 0.0, false), Vector3(s * 0.24, -0.08, _surf(hr, hs, s * 0.24, -0.08) - 0.03), Vector3.ZERO, Vector3(1, 0.8, 0.3))
	_part(head, _sphere(0.04), _dark(), Vector3(0, -0.11, _surf(hr, hs, 0.0, -0.11)))
	_part(head, _sphere(hr), white, Vector3.ZERO)


func _d_alien(hr: float, hs: Vector3) -> void:
	for s: int in [-1, 1]:
		_part(head, _sphere(0.12), _mat(Color("#0b0d14"), 0.15, 0.0, false), Vector3(s * 0.16, 0.0, _surf(hr, hs, s * 0.16, 0.0) - 0.03), Vector3(0, 0, -s * 18), Vector3(0.85, 1.5, 0.5))
		_part(head, _sphere(0.025), _mat(Color.WHITE, 0.2, 0.0, false), Vector3(s * 0.16 + 0.03, 0.08, _surf(hr, hs, s * 0.16, 0.08)))
		_part(head, _cyl(0.015, 0.015, 0.3), _mat(Color("#43bba9")), Vector3(s * 0.14, hr * hs.y + 0.1, 0), Vector3(0, 0, -s * 20))
		_part(head, _sphere(0.06), _glow(Color("#ff7ad0"), 2.0), Vector3(s * 0.2, hr * hs.y + 0.25, 0))
	_part(head, _box(0.12, 0.02, 0.03), _dark(), Vector3(0, -0.2, _surf(hr, hs, 0.0, -0.2) + 0.005))


func _potato_face() -> void:
	_eye_pair(head, 0.13, 0.0, 0.335, 0.075, 0.5)
	for s: int in [-1, 1]:
		_part(head, _box(0.13, 0.025, 0.03), _dark(), Vector3(s * 0.13, 0.1, 0.345), Vector3(0, 0, -s * 14))
	_part(head, _box(0.17, 0.035, 0.04), _mat(Color("#5a2a20"), 0.5, 0.0, false), Vector3(0, -0.12, 0.34))


func _tunic() -> void:
	_part(torso, _cyl(0.43, 0.3, 0.42), _mat(jersey, 0.85), Vector3(0, 0.38, 0))


func _d_papa() -> void:
	_part(torso, _sphere(0.46), _mat(Color("#b8854f"), 0.9), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(1.0, 1.22, 0.92))
	var spots := [[-0.2, 0.9, 1.0], [0.25, 1.0, 0.8], [-0.3, 0.55, 0.7], [0.3, 0.6, 0.8], [0.0, 1.1, 0.9], [-0.1, 0.45, 1.0], [0.15, 0.85, 1.0]]
	for sp: Array in spots:
		var x: float = sp[0]
		var y: float = sp[1]
		var rz := 0.42 * sqrt(maxf(1.0 - pow(x / 0.46, 2.0) - pow((y - 0.62) / 0.56, 2.0), 0.0))
		_part(torso, _sphere(0.04), _mat(Color("#6e4a28"), 0.9, 0.0, false), Vector3(x, y, rz), Vector3.ZERO, Vector3(1, 1, 0.4))
	_tunic()
	_potato_face()
	for i: int in 3:
		_part(torso, _cone(0.05, 0.2), _mat(Color("#4aa03a")), Vector3((i - 1) * 0.08, 1.22 + (i % 2) * 0.03, 0.02 * i), Vector3(0, 0, (i - 1) * -18))


func _d_pina() -> void:
	_part(torso, _sphere(0.46), _mat(Color("#e9b62f"), 0.8), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(0.95, 1.22, 0.95))
	var dm := _mat(Color("#b8751a"), 0.9, 0.0, false)
	for row: int in 5:
		for col: int in 3:
			var x := (col - 1 + (row % 2) * 0.5 - 0.25) * 0.2
			var y := 0.62 + (row - 2) * 0.17
			var rz := 0.437 * sqrt(maxf(1.0 - pow(x / 0.437, 2.0) - pow((y - 0.62) / 0.561, 2.0), 0.0))
			_part(torso, _box(0.05, 0.05, 0.02), dm, Vector3(x, y, rz), Vector3(0, 0, 45))
	_tunic()
	_potato_face()
	for i: int in 7:
		var a := i * TAU / 7.0
		_part(torso, _cone(0.07, 0.42), _mat(Color("#2f9a3a")), Vector3(cos(a) * 0.1, 1.38, sin(a) * 0.1), Vector3(sin(a) * 30.0, 0, -cos(a) * 30.0))


func _d_hotdog() -> void:
	_part(head, _capsule(0.3, 0.95), _mat(Color("#e6b96a"), 0.8), Vector3(0, 0, -0.02))
	_part(head, _capsule(0.2, 1.1), _mat(Color("#c8563a"), 0.55), Vector3(0, 0.02, 0.14))
	var must := _mat(Color("#f2d21a"), 0.5, 0.0, false)
	for i: int in 5:
		_part(head, _box(0.1, 0.035, 0.03), must, Vector3(((i % 2) * 2 - 1) * 0.05, -0.2 + i * 0.1, 0.335), Vector3(0, 0, ((i % 2) * 2 - 1) * 25))
	_eye_pair(head, 0.09, 0.28, 0.3, 0.06, 0.55)
	_part(head, _box(0.14, 0.03, 0.03), _mat(Color("#5a2a20"), 0.5, 0.0, false), Vector3(0, 0.15, 0.335))


func _d_huevo() -> void:
	_part(head, _sphere(0.38), _mat(Color("#f8f6ee"), 0.3), Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 1.2, 0.9))
	_part(head, _sphere(0.22), _mat(Color("#f4a21e"), 0.25), Vector3(0, 0.42, 0.0), Vector3.ZERO, Vector3(1, 0.5, 1))
	_eye_pair(head, 0.12, 0.05, 0.32, 0.065, 0.5)
	_part(head, _box(0.16, 0.03, 0.03), _mat(Color("#5a2a20"), 0.5, 0.0, false), Vector3(0, -0.13, 0.335))
	for s: int in [-1, 1]:
		_part(head, _box(0.05, 0.03, 0.03), _mat(Color("#5a2a20"), 0.5, 0.0, false), Vector3(s * 0.09, -0.115, 0.33), Vector3(0, 0, -s * 35))


# ---------- animación ----------
# speed en m/s, face = dirección hacia donde mira (x, z)
func animate(delta: float, speed: float, face: Vector2) -> void:
	_t += delta
	kick_t += delta
	var mv := clampf(speed / 1.8, 0.0, 1.0)
	var run := clampf(speed / 4.8, 0.0, 1.0)
	phase += delta * (6.5 + speed * 1.15)
	var s := sin(phase) * mv
	var c := cos(phase) * mv
	var ke := clampf(1.0 - kick_t / 0.28, 0.0, 1.0)
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(face.x, face.y), clampf(delta * 14.0, 0.0, 1.0))
	# piernas
	leg_p.rotation.x = lerpf(s * 0.95, -1.35, ke)
	leg_n.rotation.x = -s * 0.95 + 0.25 * ke
	leg_p.position.y = maxf(0.0, -c) * 0.04
	leg_n.position.y = maxf(0.0, c) * 0.04
	# brazos
	var up := -2.9
	if celebrate:
		arm_p.rotation.x = up + sin(_t * 12.0) * 0.25
		arm_n.rotation.x = up - sin(_t * 12.0) * 0.25
		arm_p.rotation.z = 0.35
		arm_n.rotation.z = -0.35
	elif ready_pose:
		arm_p.rotation.x = lerpf(arm_p.rotation.x, -0.35, 0.25)
		arm_n.rotation.x = lerpf(arm_n.rotation.x, -0.35, 0.25)
		arm_p.rotation.z = lerpf(arm_p.rotation.z, 1.15, 0.25)
		arm_n.rotation.z = lerpf(arm_n.rotation.z, -1.15, 0.25)
	else:
		arm_p.rotation.x = lerpf(arm_p.rotation.x, -s * 0.85 + 0.35 * ke, 0.5)
		arm_n.rotation.x = lerpf(arm_n.rotation.x, s * 0.85 - 0.5 * ke, 0.5)
		arm_p.rotation.z = lerpf(arm_p.rotation.z, 0.14, 0.3)
		arm_n.rotation.z = lerpf(arm_n.rotation.z, -0.14, 0.3)
	# torso y cabeza
	torso.rotation.x = lerpf(torso.rotation.x, 0.12 * run - 0.2 * ke, 0.3)
	hips.rotation.y = s * 0.12
	head.rotation.x = -0.05 * run + sin(_t * 2.0) * 0.015
	# rebote al correr, respiración en reposo y saltos de festejo
	var jump := 0.0
	if celebrate:
		jump = absf(sin(_t * 8.0 + phase)) * 0.4
	body.position.y = float_h + absf(sin(phase)) * 0.055 * mv + sin(_t * 2.4) * 0.012 + jump
	if species == "fantasma":
		body.position.y += sin(_t * 3.0) * 0.06
		body.rotation.z = sin(_t * 2.0) * 0.06 + s * 0.05
	if tail:
		tail.rotation.y = sin(_t * 5.0) * (0.25 + 0.4 * mv)
	if _shadow:
		var k := 1.0 - jump * 0.8
		_shadow.scale = Vector3(k, k, 1.0)
	if _arrow and _marker.visible:
		_arrow.position.y = _top_y + 0.35 + sin(_t * 8.0) * 0.07
		_arrow.rotation.y = _t * 2.5
