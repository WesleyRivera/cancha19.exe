extends Node3D
# Cancha de favela al atardecer: piso de cemento gastado con líneas, paredes azules con graffiti,
# rejas, porterías con red, casas de ladrillo con ventanas encendidas, cerros con luces y postes de luz.
# Todo se genera por código (shaders), no usa imágenes.
# Medidas (metros): cancha de x = -20..20 y z = -12..12. Cámara mirando hacia -z (el fondo es z negativo).

const HX := 20.0
const HZ := 12.0
const GZ := 3.0

var rng := RandomNumberGenerator.new()
var _house_shader: Shader
var _wall_shader: Shader


const COMMON := """
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++){ s += a * vn(p); p *= 2.03; a *= 0.5; }
	return s;
}
"""

const FLOOR_SHADER := """
shader_type spatial;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
//COMMON
void fragment(){
	vec2 p = wp.xz;
	vec3 green = vec3(0.17, 0.42, 0.27);
	vec3 grey = vec3(0.42, 0.43, 0.44);
	vec3 blue = vec3(0.16, 0.42, 0.68);
	vec3 orange = vec3(0.78, 0.52, 0.14);
	float in_area = step(14.0, abs(p.x)) * step(abs(p.y), 7.0);
	float circ = step(length(p), 3.6);
	vec3 base = mix(green, orange, in_area * 0.9);
	base = mix(base, blue, circ);
	float n1 = fbm(p * 0.35);
	float n2 = fbm(p * 1.7 + 7.0);
	base *= 0.8 + 0.5 * n1;
	float wear = smoothstep(0.55, 0.72, fbm(p * 0.9 + 11.0) + 0.15 * n2);
	base = mix(base, grey * (0.8 + 0.4 * n2), wear * 0.85);
	vec2 sj = abs(fract(p / 4.0 + 0.5) - 0.5) * 4.0;
	float joint = 1.0 - smoothstep(0.0, 0.05, min(sj.x, sj.y));
	base *= 1.0 - joint * 0.45;
	float cr = abs(fbm(p * 0.6 + 31.0) - 0.5);
	base *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.01, cr));
	base *= 1.0 - 0.25 * smoothstep(0.6, 0.9, fbm(p * 0.5 + 50.0));
	float w = 0.075;
	float ax = abs(p.x); float az = abs(p.y);
	float l = 0.0;
	l = max(l, step(abs(ax - 19.925), w) * step(az, 12.0));
	l = max(l, step(abs(az - 11.925), w) * step(ax, 20.0));
	l = max(l, step(ax, w) * step(az, 12.0));
	l = max(l, step(abs(length(p) - 3.6), w));
	l = max(l, step(abs(ax - 14.0), w) * step(az, 7.0));
	l = max(l, step(abs(az - 7.0), w) * step(14.0, ax) * step(ax, 20.0));
	l = max(l, step(length(vec2(ax - 16.5, p.y)), 0.13));
	l = max(l, step(length(p), 0.13));
	float paint = l * (1.0 - wear * 0.55 * smoothstep(0.4, 0.7, fbm(p * 3.0)));
	vec3 col = mix(base, vec3(0.93, 0.93, 0.9), paint * 0.95);
	ALBEDO = col;
	ROUGHNESS = 0.88;
	SPECULAR = 0.2;
}
"""

const WALL_SHADER := """
shader_type spatial;
varying vec3 wpos;
varying vec3 wnrm;
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
//COMMON
void fragment(){
	if (abs(wnrm.y) > 0.5){ ALBEDO = vec3(0.45, 0.45, 0.47); ROUGHNESS = 0.95; }
	else {
		float u = abs(wnrm.z) > abs(wnrm.x) ? wpos.x : wpos.z;
		float v = wpos.y;
		vec3 col = vec3(0.14, 0.33, 0.66) * (0.85 + 0.25 * vn(vec2(u, v) * 1.3));
		float peel = smoothstep(0.62, 0.72, fbm(vec2(u * 0.8, v * 1.6) + 3.0));
		col = mix(col, vec3(0.55, 0.55, 0.57), peel * 0.8);
		col *= mix(0.55, 1.0, smoothstep(0.0, 1.2, v));
		col = mix(col, vec3(0.8, 0.8, 0.82), step(3.05, v) * step(v, 3.3));
		vec2 gcell = vec2(u / 2.2, v / 1.1);
		vec2 gc = floor(gcell);
		vec2 gf = fract(gcell);
		float gm = step(0.78, h21(gc)) * step(0.4, v) * step(v, 2.9);
		float shape = smoothstep(0.5, 0.35, length((gf - 0.5) * vec2(1.0, 1.6)));
		vec3 gcol = vec3(h21(gc + 1.0), h21(gc + 2.0), h21(gc + 3.0));
		gcol = mix(gcol, vec3(1.0, 0.8, 0.1), 0.3);
		col = mix(col, gcol, gm * shape * 0.85 * (1.0 - peel * 0.5));
		ALBEDO = col;
		ROUGHNESS = 0.9;
	}
}
"""

const HOUSE_SHADER := """
shader_type spatial;
uniform vec4 base : source_color = vec4(0.7, 0.3, 0.3, 1.0);
uniform float brick_mix = 0.0;
uniform float seed = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
//COMMON
void fragment(){
	if (abs(wnrm.y) > 0.5){
		ALBEDO = vec3(0.35, 0.34, 0.33) * (0.8 + 0.4 * vn(wpos.xz * 3.0));
		ROUGHNESS = 0.95;
	} else {
		float u = abs(wnrm.z) > abs(wnrm.x) ? wpos.x : wpos.z;
		float v = wpos.y;
		vec2 bp = vec2(u / 0.5, v / 0.16);
		bp.x += mod(floor(bp.y), 2.0) * 0.5;
		vec2 bf = fract(bp);
		vec2 bid = floor(bp);
		float mortar = clamp(step(bf.x, 0.06) + step(bf.y, 0.12), 0.0, 1.0);
		vec3 brick = mix(vec3(0.55, 0.24, 0.15), vec3(0.72, 0.36, 0.22), h21(bid + seed));
		brick = mix(brick, vec3(0.45, 0.38, 0.34), mortar);
		float patch_n = vn(vec2(u, v) * 0.7 + seed * 7.0);
		float m = smoothstep(0.42, 0.55, patch_n + ((1.0 - brick_mix) - 0.5) * 0.9);
		vec3 plaster = base.rgb * (0.85 + 0.3 * vn(vec2(u, v) * 3.0));
		plaster *= 1.0 - 0.25 * vn(vec2(u * 4.0, v * 0.5));
		vec3 col = mix(brick, plaster, m);
		vec2 cell = vec2(2.6, 3.0);
		vec2 cuv = vec2(u, v) / cell;
		vec2 cid = floor(cuv);
		vec2 cf = fract(cuv);
		float hasw = step(0.18, h21(cid + vec2(seed * 3.1, 1.7)));
		vec2 lo = vec2(0.28, 0.32);
		vec2 hi = vec2(0.72, 0.82);
		float above = step(1.2, v);
		float inner = step(lo.x + 0.04, cf.x) * step(cf.x, hi.x - 0.04) * step(lo.y + 0.04, cf.y) * step(cf.y, hi.y - 0.04) * hasw * above;
		float outer = step(lo.x, cf.x) * step(cf.x, hi.x) * step(lo.y, cf.y) * step(cf.y, hi.y) * hasw * above;
		float lit = step(0.7, h21(cid + vec2(seed, 9.1)));
		vec3 glass = mix(vec3(0.06, 0.08, 0.12), vec3(1.0, 0.74, 0.4), lit);
		col = mix(col, vec3(0.1, 0.08, 0.07), outer);
		col = mix(col, glass, inner);
		float bar = step(0.46, cf.x) * step(cf.x, 0.54) * inner;
		col = mix(col, vec3(0.05, 0.04, 0.04), bar * 0.8);
		col *= mix(0.6, 1.0, smoothstep(0.0, 3.0, v));
		ALBEDO = col;
		ROUGHNESS = 0.9;
		EMISSION = glass * lit * inner * (1.0 - bar) * 1.5;
	}
}
"""

const FENCE_SHADER := """
shader_type spatial;
render_mode cull_disabled, unshaded;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 uv = vec2(wp.x + wp.z, wp.y) * 2.2;
	float d1 = abs(fract(uv.x + uv.y) - 0.5);
	float d2 = abs(fract(uv.x - uv.y) - 0.5);
	float a = max(1.0 - smoothstep(0.0, 0.06, min(d1, d2) * 2.0 - 0.0) , 0.0);
	float lines = 1.0 - smoothstep(0.0, 0.07, min(d1, d2));
	ALBEDO = vec3(0.62, 0.64, 0.66);
	ALPHA = lines * 0.55;
}
"""

const NET_SHADER := """
shader_type spatial;
render_mode cull_disabled, unshaded;
varying vec3 wp;
varying vec3 wn;
void vertex(){
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	vec2 g;
	if (abs(wn.y) > 0.5) g = wp.xz * 6.0; else g = vec2(wp.x + wp.z, wp.y) * 6.0;
	vec2 f = abs(fract(g) - 0.5);
	float l = 1.0 - smoothstep(0.0, 0.08, min(f.x, f.y) );
	ALBEDO = vec3(0.95);
	ALPHA = l * 0.7;
}
"""

const BALLISH_SKY_LIGHTS := 380


func build() -> void:
	rng.seed = 1919
	var cmn := COMMON
	_house_shader = Shader.new()
	_house_shader.code = HOUSE_SHADER.replace("//COMMON", cmn)
	_wall_shader = Shader.new()
	_wall_shader.code = WALL_SHADER.replace("//COMMON", cmn)
	_build_environment()
	_build_floor()
	_build_walls()
	_build_goals()
	_build_houses()
	_build_far_lights()
	_build_lamps()
	_build_laundry()


# ---------- utilidades ----------
func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _std(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, e := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _smat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code.replace("//COMMON", COMMON)
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# ---------- cielo, luces y niebla ----------
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#101a3d")
	sky_mat.sky_horizon_color = Color("#f08a5a")
	sky_mat.ground_horizon_color = Color("#3a2a3a")
	sky_mat.ground_bottom_color = Color("#120e18")
	sky_mat.sky_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.78)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color("#7a5a78")
	env.fog_density = 0.0045
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)


# ---------- piso ----------
func _build_floor() -> void:
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(44.0, 24.6)
	fl.mesh = pm
	fl.material_override = _smat(FLOOR_SHADER)
	add_child(fl)
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(400.0, 400.0)
	outer.mesh = om
	outer.material_override = _std(Color("#2a2528"), 0.95)
	outer.position = Vector3(0, -0.03, 0)
	add_child(outer)


# ---------- paredes, rejas y letreros ----------
func _build_walls() -> void:
	var wm := ShaderMaterial.new()
	wm.shader = _wall_shader
	# fondo
	_box(Vector3(0, 1.7, -12.3), Vector3(45.2, 3.4, 0.6), wm)
	# lados de las porterías
	for s: int in [-1, 1]:
		var seg_len := 12.6 - (GZ + 0.1)
		var cz := GZ + 0.1 + seg_len * 0.5
		_box(Vector3(s * 21.0, 1.7, cz), Vector3(2.0, 3.4, seg_len), wm)
		_box(Vector3(s * 21.0, 1.7, -cz), Vector3(2.0, 3.4, seg_len), wm)
		_box(Vector3(s * 21.0, 2.85, 0), Vector3(2.0, 1.1, (GZ + 0.1) * 2.0), wm)
		_box(Vector3(s * 21.8, 1.7, 0), Vector3(0.4, 3.4, (GZ + 0.1) * 2.0), wm)
	# borde del lado de la cámara
	_box(Vector3(0, 0.3, 12.3), Vector3(45.2, 0.6, 0.6), wm)
	# rejas
	var fm := _smat(FENCE_SHADER)
	var near := MeshInstance3D.new()
	var q1 := QuadMesh.new()
	q1.size = Vector2(45.2, 3.8)
	near.mesh = q1
	near.material_override = fm
	near.position = Vector3(0, 2.5, 12.4)
	add_child(near)
	var top_back := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(45.2, 2.4)
	top_back.mesh = q2
	top_back.material_override = fm
	top_back.position = Vector3(0, 4.6, -12.2)
	add_child(top_back)
	for s: int in [-1, 1]:
		var side := MeshInstance3D.new()
		var q3 := QuadMesh.new()
		q3.size = Vector2(25.0, 2.4)
		side.mesh = q3
		side.material_override = fm
		side.position = Vector3(s * 22.05, 4.6, 0)
		side.rotation_degrees = Vector3(0, 90, 0)
		add_child(side)
	# postes de la reja
	var pole_m := _std(Color("#4a4f55"), 0.6, 0.5)
	var x := -20.0
	while x <= 20.1:
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 4.4
		p.mesh = cm
		p.material_override = pole_m
		p.position = Vector3(x, 2.2 + 0.4, 12.4)
		add_child(p)
		x += 5.0
	# letreros en la pared del fondo
	_sign("CANCHA 19", Vector3(0, 1.75, -11.97), 190, Color("#ffd23a"))
	_sign("FAVELA FC", Vector3(-12.5, 1.5, -11.97), 110, Color("#ffffff"))
	_sign("VAMOS!", Vector3(12.5, 1.5, -11.97), 110, Color("#ff6a3a"))


func _sign(text: String, pos: Vector3, size: int, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.008
	lb.modulate = col
	lb.outline_size = 22
	lb.outline_modulate = Color(0.05, 0.05, 0.1)
	lb.position = pos
	lb.shaded = false
	add_child(lb)


# ---------- porterías ----------
func _build_goals() -> void:
	var post_m := _std(Color("#f2f2f2"), 0.5, 0.2)
	var net_m := _smat(NET_SHADER)
	for s: int in [-1, 1]:
		var gx: float = s * HX
		for z: int in [-1, 1]:
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.06
			cm.height = 2.2
			p.mesh = cm
			p.material_override = post_m
			p.position = Vector3(gx, 1.1, z * GZ)
			add_child(p)
		var bar := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.06
		bm.bottom_radius = 0.06
		bm.height = GZ * 2.0
		bar.mesh = bm
		bar.material_override = post_m
		bar.position = Vector3(gx, 2.2, 0)
		bar.rotation_degrees = Vector3(90, 0, 0)
		add_child(bar)
		var depth := 1.6
		# red del fondo
		var back := MeshInstance3D.new()
		var qb := QuadMesh.new()
		qb.size = Vector2(GZ * 2.0, 2.2)
		back.mesh = qb
		back.material_override = net_m
		back.position = Vector3(s * (HX + depth - 0.05), 1.1, 0)
		back.rotation_degrees = Vector3(0, 90, 0)
		add_child(back)
		# red de arriba
		var top := MeshInstance3D.new()
		var qt := QuadMesh.new()
		qt.size = Vector2(depth, GZ * 2.0)
		top.mesh = qt
		top.material_override = net_m
		top.position = Vector3(s * (HX + depth * 0.5), 2.2, 0)
		top.rotation_degrees = Vector3(-90, 0, 0)
		add_child(top)
		# redes laterales
		for z: int in [-1, 1]:
			var sd := MeshInstance3D.new()
			var qs := QuadMesh.new()
			qs.size = Vector2(depth, 2.2)
			sd.mesh = qs
			sd.material_override = net_m
			sd.position = Vector3(s * (HX + depth * 0.5), 1.1, z * GZ)
			add_child(sd)


# ---------- casas ----------
func _house(x: float, z: float, w: float, h: float, d: float) -> void:
	var pal := [Color("#c24a8a"), Color("#e8c23a"), Color("#d8452f"), Color("#2fa39a"), Color("#e8e2d6"), Color("#7a52c8"), Color("#4aa0e0"), Color("#e88a3a")]
	var m := ShaderMaterial.new()
	m.shader = _house_shader
	m.set_shader_parameter("base", pal[rng.randi() % pal.size()])
	m.set_shader_parameter("brick_mix", 1.0 if rng.randf() < 0.55 else rng.randf_range(0.0, 0.4))
	m.set_shader_parameter("seed", rng.randf() * 20.0)
	_box(Vector3(x, h * 0.5, z), Vector3(w, h, d), m)
	# cosas del techo: tanque de agua y varillas
	if rng.randf() < 0.5:
		var t := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7
		cm.bottom_radius = 0.7
		cm.height = 1.3
		t.mesh = cm
		t.material_override = _std(Color("#2a6fb8"), 0.5)
		t.position = Vector3(x + rng.randf_range(-w * 0.3, w * 0.3), h + 0.65, z + rng.randf_range(-d * 0.3, d * 0.3))
		add_child(t)
	for i: int in 4:
		var r := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.025
		rm.bottom_radius = 0.025
		rm.height = 1.2
		r.mesh = rm
		r.material_override = _std(Color("#5a4a40"), 0.8)
		r.position = Vector3(x + (i % 2 * 2 - 1) * (w * 0.5 - 0.3), h + 0.6, z + (i / 2 * 2 - 1) * (d * 0.5 - 0.3))
		add_child(r)


func _build_houses() -> void:
	# filas del fondo (cerro hacia atrás)
	for row: int in 6:
		var z0 := -15.6 - row * 6.2
		var x := -48.0
		while x < 48.0:
			var w := rng.randf_range(5.0, 9.0)
			var h := rng.randf_range(8.0, 12.0) + row * 5.0 + absf(x) * 0.06
			_house(x + w * 0.5, z0, w, h, 6.0)
			x += w - rng.randf_range(0.0, 1.0)
	# columnas a los lados
	for s: int in [-1, 1]:
		for col: int in 2:
			var x0: float = s * (22.3 + 3.0 + col * 6.4)
			var z := -14.0
			while z < 22.0:
				var d := rng.randf_range(5.0, 9.0)
				var h := rng.randf_range(7.0, 12.0) + col * 5.0
				_house(x0, z + d * 0.5, 6.0, h, d)
				z += d - rng.randf_range(0.0, 1.0)


# ---------- luces lejanas del cerro ----------
func _build_far_lights() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	mm.mesh = qm
	mm.instance_count = BALLISH_SKY_LIGHTS
	for i: int in BALLISH_SKY_LIGHTS:
		var pos := Vector3(rng.randf_range(-90.0, 90.0), rng.randf_range(10.0, 48.0), rng.randf_range(-62.0, -50.0))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		var warm := rng.randf()
		mm.set_instance_color(i, Color(1.0, 0.78 + warm * 0.2, 0.45 + warm * 0.4))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	# cerro oscuro detrás de todo
	_box(Vector3(0, 30, -72), Vector3(240, 90, 14), _std(Color("#141822"), 1.0))


# ---------- postes de luz ----------
func _build_lamps() -> void:
	var pole := _std(Color("#4a4f55"), 0.6, 0.5)
	var spots := [Vector3(-21.4, 0.0, 12.9), Vector3(21.4, 0.0, 12.9), Vector3(-8.0, 3.4, -12.4), Vector3(8.0, 3.4, -12.4)]
	for pos: Vector3 in spots:
		var h := 9.0 if pos.z > 0.0 else 5.0
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.12
		cm.height = h
		p.mesh = cm
		p.material_override = pole
		p.position = pos + Vector3(0, h * 0.5, 0)
		add_child(p)
		var head := _box(pos + Vector3(0, h + 0.1, 0), Vector3(1.1, 0.18, 0.5), _glow(Color("#fff0c8"), 2.4))
		head.rotation_degrees = Vector3(0, 0, 0)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.62)
		lamp.light_energy = 2.4
		lamp.omni_range = 30.0
		lamp.position = pos + Vector3(0, h - 0.4, 0)
		add_child(lamp)


# ---------- ropa tendida ----------
func _build_laundry() -> void:
	var colors := [Color("#e0302a"), Color("#f2f2f2"), Color("#2f7bff"), Color("#ffd23a"), Color("#2fa39a"), Color("#c24a8a")]
	for k: int in 6:
		var x0 := rng.randf_range(-30.0, 22.0)
		var span := rng.randf_range(6.0, 9.0)
		var y := rng.randf_range(6.5, 9.5)
		var z := -12.55
		var cord := _box(Vector3(x0 + span * 0.5, y, z), Vector3(span, 0.02, 0.02), _std(Color("#2a2a2a")))
		cord.name = "cord"
		var n := int(span / 0.9)
		for i: int in n:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.55, rng.randf_range(0.7, 1.1))
			q.mesh = qm
			var cm := _std(colors[rng.randi() % colors.size()], 0.95)
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			q.material_override = cm
			q.position = Vector3(x0 + 0.5 + i * 0.9, y - qm.size.y * 0.5, z)
			add_child(q)
