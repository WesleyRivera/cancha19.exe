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
	float n = fbm(p * 2.8);
	float fine = vn(p * 38.0);
	float fibers = 0.94 + 0.06 * sin(p.x * 115.0 + fine * 8.0);
	float stripe = 0.94 + 0.06 * sin(p.x * 0.72);
	vec3 turf_a = vec3(0.035, 0.19, 0.075);
	vec3 turf_b = vec3(0.075, 0.31, 0.12);
	vec3 base = mix(turf_a, turf_b, smoothstep(0.2, 0.8, n));
	base *= stripe * fibers;
	float worn = smoothstep(0.68, 0.86, fbm(p * 1.3 + 17.0));
	base = mix(base, vec3(0.16, 0.18, 0.12), worn * 0.35);
	float outside = step(14.0, abs(p.x)) * step(abs(p.y), 7.0);
	base = mix(base, vec3(0.12, 0.13, 0.12), outside);
	float line = 0.0;
	float w = 0.065;
	float ax = abs(p.x); float az = abs(p.y);
	line = max(line, step(abs(ax - 19.925), w) * step(az, 12.0));
	line = max(line, step(abs(az - 11.925), w) * step(ax, 20.0));
	line = max(line, step(ax, w) * step(az, 12.0));
	line = max(line, step(abs(length(p) - 3.6), w));
	line = max(line, step(abs(ax - 14.0), w) * step(az, 7.0));
	line = max(line, step(abs(az - 7.0), w) * step(14.0, ax) * step(ax, 20.0));
	line = max(line, step(length(vec2(ax - 16.5, p.y)), 0.12));
	line = max(line, step(length(p), 0.12));
	float penalty_spot = step(length(vec2(ax - 16.5, p.y)), 0.13);
	line = max(line, penalty_spot);
	ALBEDO = mix(base, vec3(0.88, 0.9, 0.82), line);
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
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
		vec2 p = vec2(u, v);
		float noise = vn(p * 2.1);
		vec3 concrete = vec3(0.34, 0.32, 0.30) * (0.82 + noise * 0.28);
		vec3 faded_paint = mix(vec3(0.18, 0.30, 0.37), vec3(0.48, 0.25, 0.19), vn(p * 0.32));
		float paint_mask = smoothstep(0.35, 0.78, fbm(p * vec2(0.42, 0.9) + 4.0));
		vec3 col = mix(concrete, faded_paint, paint_mask * 0.78);
		float peel = smoothstep(0.48, 0.72, fbm(p * vec2(1.3, 2.2) + 3.0));
		col = mix(col, concrete * 1.35, peel * 0.72);
		float damp = smoothstep(0.52, 0.78, fbm(vec2(u * 0.55, v * 0.22) + 19.0)) * (1.0 - smoothstep(0.0, 2.8, v));
		col = mix(col, vec3(0.12, 0.16, 0.15), damp * 0.55);
		float crack = smoothstep(0.92, 0.98, vn(p * vec2(8.0, 13.0)));
		col = mix(col, vec3(0.12, 0.12, 0.12), crack * 0.28);
		col = mix(col, vec3(0.75, 0.69, 0.57), step(3.05, v) * step(v, 3.3) * 0.55);
		vec2 gcell = vec2(u / 3.4, v / 1.7);
		vec2 gc = floor(gcell);
		vec2 gf = fract(gcell);
		float gm = step(0.84, h21(gc)) * step(0.45, v) * step(v, 2.85);
		float shape = smoothstep(0.5, 0.28, length((gf - 0.5) * vec2(1.0, 1.6)));
		vec3 gcol = mix(vec3(0.86, 0.28, 0.12), vec3(0.95, 0.68, 0.18), h21(gc + 2.0));
		col = mix(col, gcol, gm * shape * 0.62 * (1.0 - peel * 0.5));
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
		vec3 plaster = base.rgb * (0.78 + 0.34 * vn(vec2(u, v) * 3.0));
		plaster *= 1.0 - 0.32 * vn(vec2(u * 4.0, v * 0.5));
		float damp = smoothstep(0.5, 0.82, fbm(vec2(u * 0.6, v * 0.22) + seed)) * (1.0 - smoothstep(0.0, 3.2, v));
		plaster = mix(plaster, vec3(0.16, 0.19, 0.17), damp * 0.42);
		float chipped = smoothstep(0.72, 0.9, fbm(vec2(u * 2.0, v * 1.7) + seed * 4.0));
		plaster = mix(plaster, brick * 0.82, chipped * 0.22);
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
		EMISSION = glass * lit * inner * (1.0 - bar) * 2.2;
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
	_build_neighborhood_details()
	_build_far_lights()
	_build_lamps()
	_build_laundry()
	_build_crowd_and_stands()
	_build_street_props()
	_build_rooftop_details()
	_build_rooftop_antennas()
	_build_neighborhood_laundry()


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
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color("#7a5a78")
	env.fog_density = 0.0032
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 0.38
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
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
	# Estructura de la malla: postes y travesaños visibles en los cuatro lados.
	var pole_m := _std(Color("#4a4f55"), 0.6, 0.5)
	for x: float in range(-22, 23, 4):
		for z_side: int in [-1, 1]:
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.055
			cm.bottom_radius = 0.07
			cm.height = 4.6
			p.mesh = cm
			p.material_override = pole_m
			p.position = Vector3(x, 2.45, z_side * 12.4)
			add_child(p)
	for side: int in [-1, 1]:
		for z: float in range(-12, 13, 4):
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.055
			cm.bottom_radius = 0.07
			cm.height = 4.6
			p.mesh = cm
			p.material_override = pole_m
			p.position = Vector3(side * 22.0, 2.45, z)
			add_child(p)
	# Tubos horizontales que tensan y rematan la malla.
	for z_side: int in [-1, 1]:
		for y: float in [0.55, 4.65]:
			var rail := MeshInstance3D.new()
			var rail_mesh := CylinderMesh.new()
			rail_mesh.top_radius = 0.045
			rail_mesh.bottom_radius = 0.045
			rail_mesh.height = 45.0
			rail.mesh = rail_mesh
			rail.material_override = pole_m
			rail.position = Vector3(0.0, y, z_side * 12.4)
			trail.rotation_degrees.z = 90.0
			add_child(rail)
	for side: int in [-1, 1]:
		for y: float in [0.55, 4.65]:
			var rail := MeshInstance3D.new()
			var rail_mesh := CylinderMesh.new()
			rail_mesh.top_radius = 0.045
			rail_mesh.bottom_radius = 0.045
			rail_mesh.height = 25.0
			rail.mesh = rail_mesh
			rail.material_override = pole_m
			rail.position = Vector3(side * 22.0, y, 0.0)
			trail.rotation_degrees.x = 90.0
			add_child(rail)
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
		# Refuerzos traseros y pequeños anclajes de la red.
		for side_z: int in [-1, 1]:
			var brace := _box(Vector3(s * (HX + depth * 0.72), 1.05, side_z * (GZ + 0.1)), Vector3(depth * 1.45, 0.07, 0.07), post_m)
			brace.rotation_degrees.z = -s * 42.0
		var base_left := _box(Vector3(gx, 0.08, -GZ), Vector3(0.18, 0.16, 0.18), _std(Color("#777b80"), 0.6, 0.4))
		var base_right := _box(Vector3(gx, 0.08, GZ), Vector3(0.18, 0.16, 0.18), _std(Color("#777b80"), 0.6, 0.4))


# ---------- casas ----------
func _house(x: float, z: float, w: float, h: float, d: float) -> void:
	var pal := [Color("#c24a8a"), Color("#e8c23a"), Color("#d8452f"), Color("#2fa39a"), Color("#e8e2d6"), Color("#7a52c8"), Color("#4aa0e0"), Color("#e88a3a")]
	var m := ShaderMaterial.new()
	m.shader = _house_shader
	m.set_shader_parameter("base", pal[rng.randi() % pal.size()])
	m.set_shader_parameter("brick_mix", 1.0 if rng.randf() < 0.55 else rng.randf_range(0.0, 0.4))
	m.set_shader_parameter("seed", rng.randf() * 20.0)
	_box(Vector3(x, h * 0.5, z), Vector3(w, h, d), m)
	_house_front_details(x, z, w, h, d)
	_house_roof(x, z, w, h, d)
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
	# Filas escalonadas: el barrio sube por la ladera y se pierde en el fondo.
	for row: int in 8:
		var z0 := -15.8 - row * 5.5
		var x := -58.0 + (2.2 if row % 2 == 0 else 0.0)
		while x < 58.0:
			var w := rng.randf_range(5.2, 8.6)
			var h := rng.randf_range(7.5, 11.5) + row * 3.7 + absf(x) * 0.045
			_house(x + w * 0.5, z0, w, h, rng.randf_range(5.4, 7.0))
			x += w - rng.randf_range(0.15, 0.75)
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
	# Silueta irregular de las montañas: evita que el horizonte parezca una pared plana.
	var hill_mat := _std(Color("#202633"), 1.0)
	for hill: int in 9:
		var mound := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		mound.mesh = sphere
		mound.material_override = hill_mat
		var hx := -105.0 + hill * 26.0
		mound.position = Vector3(hx, 12.0 + rng.randf_range(-2.0, 5.0), -78.0 - rng.randf_range(0.0, 12.0))
		mound.scale = Vector3(rng.randf_range(16.0, 25.0), rng.randf_range(17.0, 27.0), 8.0)
		add_child(mound)
	# Fondo oscuro que oculta el corte de las montañas y conserva profundidad.
	_box(Vector3(0, 25, -94), Vector3(260, 70, 8), _std(Color("#171d29"), 1.0))


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


# ---------- detalles del barrio: callejones, escaleras, cables y vegetacion ----------
func _build_neighborhood_details() -> void:
	var concrete := _std(Color("#555052"), 0.96)
	var worn := _std(Color("#77706a"), 0.98)
	var dark_metal := _std(Color("#292d32"), 0.72, 0.25)

	# Calles estrechas que serpentean entre las casas del cerro.
	for row: int in 4:
		var z := -19.0 - row * 10.0
		var y := 5.0 + row * 4.2
		var road := _box(Vector3(0.0, y, z), Vector3(112.0, 0.22, 2.8), concrete)
		road.rotation_degrees.y = -2.0 if row % 2 == 0 else 2.0
		for side: int in [-1, 1]:
			_box(Vector3(side * 54.0, y + 0.12, z), Vector3(1.0, 0.45, 3.2), worn)

	# Escalinatas visibles entre las viviendas, sin invadir el terreno de juego.
	for stair: int in 3:
		var sx := -34.0 + stair * 34.0
		var sz := -17.0 - (stair % 2) * 8.0
		var sy := 4.5 + stair * 2.0
		for step: int in 18:
			var block := _box(
				Vector3(sx + sin(float(step) * 0.16) * 1.4, sy + float(step) * 0.24, sz - float(step) * 0.72),
				Vector3(2.8, 0.24, 0.82),
				worn
			)
			block.rotation_degrees.y = sin(float(step) * 0.16) * 8.0
		_box(Vector3(sx - 1.8, sy + 2.0, sz - 6.0), Vector3(0.18, 4.0, 14.0), dark_metal)

	# Cableado aereo irregular, caracteristico de las calles del barrio.
	var cable_points := [
		Vector3(-48.0, 15.0, -18.0), Vector3(-20.0, 13.0, -25.0),
		Vector3(12.0, 16.0, -20.0), Vector3(45.0, 14.0, -30.0),
		Vector3(-42.0, 22.0, -43.0), Vector3(4.0, 24.0, -48.0),
		Vector3(48.0, 21.0, -48.0)
	]
	for i: int in range(cable_points.size() - 1):
		_cable(cable_points[i], cable_points[i + 1], dark_metal)
		if i % 2 == 0:
			_cable(cable_points[i], cable_points[i + 1] + Vector3(0.0, -2.2, -1.0), dark_metal)

	# Vegetación tropical: palmeras con hojas individuales y árboles frondosos.
	for tree: int in 15:
		var tx := rng.randf_range(-68.0, 68.0)
		var tz := rng.randf_range(-62.0, -17.0)
		var th := rng.randf_range(4.8, 8.5)
		var trunk_mat := _std(Color("#49382c"), 0.96)
		var leaf_mat := _std(Color("#244b35"), 0.98)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.13
		trunk_mesh.bottom_radius = 0.28
		trunk_mesh.height = th
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = Vector3(tx, 2.5 + th * 0.5, tz)
		trunk.rotation_degrees.z = rng.randf_range(-7.0, 7.0)
		add_child(trunk)
		if tree % 3 == 0:
			# Palmeras: siete hojas largas que salen de la corona.
			for frond: int in 7:
				var angle := TAU * float(frond) / 7.0 + rng.randf_range(-0.18, 0.18)
				var leaf := MeshInstance3D.new()
				var leaf_mesh := BoxMesh.new()
				leaf_mesh.size = Vector3(rng.randf_range(2.4, 3.6), 0.09, 0.34)
				leaf.mesh = leaf_mesh
				leaf.material_override = _std(Color("#2e7043") if frond % 2 == 0 else Color("#397d4b"), 0.98)
				leaf.position = Vector3(tx + cos(angle) * 1.25, 2.5 + th + 0.18, tz + sin(angle) * 1.25)
				leaf.rotation = Vector3(-0.22, -angle, -0.38)
				add_child(leaf)
		else:
			# Copas frondosas compuestas por varios volúmenes, no una sola esfera.
			for clump: int in 5:
				var angle := TAU * float(clump) / 5.0
				var crown := MeshInstance3D.new()
				var crown_mesh := SphereMesh.new()
				crown_mesh.radius = rng.randf_range(1.25, 1.9)
				crown_mesh.height = crown_mesh.radius * 1.4
				crown.mesh = crown_mesh
				crown.material_override = leaf_mat
				crown.position = Vector3(tx + cos(angle) * 0.9, 2.5 + th, tz + sin(angle) * 0.9)
				crown.scale = Vector3(1.2, 0.85, 1.0)
				add_child(crown)
	# Macizos bajos junto a calles y escalinatas.
	for bush: int in 34:
		var bx := rng.randf_range(-62.0, 62.0)
		var bz := rng.randf_range(-58.0, -17.0)
		var bush_mat := _std(Color("#244b35") if bush % 2 == 0 else Color("#315d3c"), 1.0)
		var shrub := MeshInstance3D.new()
		var shrub_mesh := SphereMesh.new()
		shrub_mesh.radius = rng.randf_range(0.45, 0.9)
		shrub_mesh.height = shrub_mesh.radius * 1.3
		shrub.mesh = shrub_mesh
		shrub.material_override = bush_mat
		shrub.position = Vector3(bx, 2.8, bz)
		shrub.scale = Vector3(1.5, 0.8, 1.0)
		add_child(shrub)


func _cable(a: Vector3, b: Vector3, mat: Material) -> void:
	var delta := b - a
	var wire := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = delta.length()
	wire.mesh = mesh
	wire.material_override = mat
	wire.position = (a + b) * 0.5
	wire.look_at(b, Vector3.UP)
	wire.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	add_child(wire)


# ---------- arquitectura de fachada para dar escala y vida al barrio ----------
func _house_front_details(x: float, z: float, w: float, h: float, d: float) -> void:
	var front := z + d * 0.5 + 0.075
	var metal := _std(Color("#34383b"), 0.72, 0.35)
	var concrete := _std(Color("#b7aaa0"), 0.92)
	var dark := _std(Color("#171b20"), 0.85)
	var door_mat := _std(Color("#49352c"), 0.9)
	var accent_colors := [Color("#e6b84a"), Color("#4d9a91"), Color("#c66b50"), Color("#d6d0bd")]
	var accent := _std(accent_colors[rng.randi() % accent_colors.size()], 0.88)

	# Marcos y contraventanas: pocas piezas por vivienda para mantener buen rendimiento.
	var floors := maxi(1, int(h / 3.0))
	for floor_idx in mini(floors, 3):
		var wy := 1.35 + floor_idx * 2.65
		if wy + 0.8 > h - 0.25:
			continue
		var wx := x + rng.randf_range(-w * 0.22, w * 0.22)
		var ww := rng.randf_range(0.85, 1.25)
		_box(Vector3(wx, wy, front), Vector3(ww + 0.22, 1.05, 0.12), dark)
		_box(Vector3(wx, wy, front + 0.085), Vector3(ww, 0.82, 0.045), accent)
		_box(Vector3(wx, wy, front + 0.12), Vector3(0.055, 0.9, 0.05), metal)
		_box(Vector3(wx, wy, front + 0.12), Vector3(ww, 0.055, 0.05), metal)
		if rng.randf() < 0.58:
			var balcony_y := wy - 0.55
			_box(Vector3(wx, balcony_y, front + 0.55), Vector3(ww + 0.55, 0.12, 1.05), concrete)
			_box(Vector3(wx, balcony_y + 0.55, front + 1.02), Vector3(ww + 0.55, 0.08, 0.08), metal)
			for rail_idx in 4:
				_box(Vector3(wx - (ww + 0.3) * 0.5 + rail_idx * (ww + 0.3) / 3.0, balcony_y + 0.28, front + 1.02), Vector3(0.045, 0.5, 0.045), metal)

	# Puerta de entrada y pequeño alero en la planta baja.
	var door_x := x + rng.randf_range(-w * 0.28, w * 0.28)
	_box(Vector3(door_x, 1.05, front + 0.04), Vector3(0.95, 2.1, 0.14), door_mat)
	_box(Vector3(door_x, 2.18, front + 0.16), Vector3(1.18, 0.12, 0.48), accent)
	_box(Vector3(door_x + 0.31, 1.0, front + 0.14), Vector3(0.07, 0.07, 0.07), _glow(Color("#f2c56b"), 0.7))

	# Unidades de aire, toldos y tuberías exteriores en algunas casas.
	if rng.randf() < 0.42:
		var ax := x + rng.randf_range(-w * 0.32, w * 0.32)
		var ay := rng.randf_range(2.8, maxf(3.0, h - 1.0))
		_box(Vector3(ax, ay, front + 0.28), Vector3(0.72, 0.42, 0.34), concrete)
		_box(Vector3(ax, ay, front + 0.47), Vector3(0.48, 0.12, 0.025), dark)
	if rng.randf() < 0.38:
		var awning_x := x + rng.randf_range(-w * 0.2, w * 0.2)
		_box(Vector3(awning_x, 2.65, front + 0.55), Vector3(rng.randf_range(1.5, 2.6), 0.12, 1.0), accent)


# Techos de losa y lámina, con parapetos y bordes irregulares.
func _house_roof(x: float, z: float, w: float, h: float, d: float) -> void:
	var slab := _std(Color("#77716b"), 0.96)
	var sheet := _std(Color("#555b60"), 0.78, 0.28)
	var edge := _std(Color("#393b3c"), 0.9)
	var roof_y := h + 0.12
	_box(Vector3(x, roof_y, z), Vector3(w + 0.28, 0.24, d + 0.28), slab)
	# Tramos de lámina acanalada sobre una parte del techo.
	if rng.randf() < 0.72:
		var aw := w * rng.randf_range(0.42, 0.78)
		var ad := d * rng.randf_range(0.35, 0.62)
		var ax := x + rng.randf_range(-w * 0.12, w * 0.12)
		var az := z + rng.randf_range(-d * 0.12, d * 0.12)
		_box(Vector3(ax, roof_y + 0.22, az), Vector3(aw, 0.10, ad), sheet)
		for rib: int in int(aw / 0.32):
			_box(Vector3(ax - aw * 0.5 + rib * 0.32, roof_y + 0.29, az), Vector3(0.035, 0.08, ad), edge)
	if rng.randf() < 0.6:
		_box(Vector3(x, roof_y + 0.42, z - d * 0.5), Vector3(w * 0.82, 0.62, 0.14), slab)
	if rng.randf() < 0.45:
		_box(Vector3(x + w * 0.5, roof_y + 0.3, z), Vector3(0.14, 0.42, d * 0.72), slab)


# Gradas improvisadas y público de barrio detrás de la malla.
func _build_crowd_and_stands() -> void:
	var concrete := _std(Color("#55575a"), 0.92)
	var seat_colors := [Color("#b64e37"), Color("#d5a84a"), Color("#426f83"), Color("#77716a")]
	# Dos niveles bajos de gradas, fuera del terreno de juego.
	for row: int in 2:
		var z := 15.2 + row * 1.15
		var y := 0.48 + row * 0.62
		_box(Vector3(0.0, y, z), Vector3(38.0, 0.42, 0.92), concrete)
		for seat: int in 19:
			var sx := -17.5 + seat * 1.95
			_box(Vector3(sx, y + 0.28, z - 0.12), Vector3(1.45, 0.12, 0.52), _std(seat_colors[(seat + row) % seat_colors.size()], 0.82))
	# Público estilizado: siluetas sencillas para dar vida sin alterar la jugabilidad.
	for person: int in 28:
		var px := rng.randf_range(-17.5, 17.5)
		var row_idx := person % 2
		var py := 1.15 + row_idx * 0.58
		var pz := 14.9 + row_idx * 1.15
		var shirt := _std(seat_colors[rng.randi() % seat_colors.size()], 0.9)
		var skin_colors := [Color("#8b5941"), Color("#b87955"), Color("#d19a70"), Color("#5b392d")]
		var skin := _std(skin_colors[rng.randi() % skin_colors.size()], 0.95)
		var torso := MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.22
		body.height = 0.82
		torso.mesh = body
		torso.material_override = shirt
		torso.position = Vector3(px, py + 0.25, pz)
		add_child(torso)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.17
		head_mesh.height = 0.34
		head.mesh = head_mesh
		head.material_override = skin
		head.position = Vector3(px, py + 0.83, pz)
		add_child(head)
		# Brazos levantados en algunos aficionados.
		if person % 4 == 0:
			for arm_side: int in [-1, 1]:
				var arm := _box(Vector3(px + arm_side * 0.31, py + 0.62, pz), Vector3(0.09, 0.58, 0.09), skin)
				arm.rotation_degrees.z = -arm_side * 24.0

# Elementos urbanos alrededor de la cancha: bancas, contenedores y postes.
func _build_street_props() -> void:
	var metal := _std(Color("#34393d"), 0.72, 0.35)
	var wood := _std(Color("#72513a"), 0.9)
	var plastic := _std(Color("#315c49"), 0.9)
	# Bancas y pequeños puestos junto a los laterales, fuera de las líneas.
	for side: int in [-1, 1]:
		for idx: int in 3:
			var z := -7.0 + idx * 6.5
			var x := side * 24.2
			_box(Vector3(x, 0.72, z), Vector3(1.65, 0.12, 0.55), wood)
			for leg_x: int in [-1, 1]:
				_box(Vector3(x + leg_x * 0.62, 0.36, z), Vector3(0.08, 0.72, 0.08), metal)
		_box(Vector3(side * 25.0, 0.72, 10.0), Vector3(0.85, 1.15, 0.85), plastic)
	# Faroles de calle en el ascenso hacia las casas.
	for lamp_idx: int in 7:
		var lx := -48.0 + lamp_idx * 16.0
		var ly := 7.0 + lamp_idx * 0.55
		var lz := -20.0 - (lamp_idx % 3) * 8.0
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.055
		pm.bottom_radius = 0.09
		pm.height = 6.0
		pole.mesh = pm
		pole.material_override = metal
		pole.position = Vector3(lx, ly + 3.0, lz)
		add_child(pole)
		_box(Vector3(lx + 0.38, ly + 5.85, lz), Vector3(0.85, 0.12, 0.16), _glow(Color("#ffd99a"), 1.6))
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ffbf78")
		glow.light_energy = 0.65
		glow.omni_range = 8.0
		glow.position = Vector3(lx + 0.35, ly + 5.5, lz)
		add_child(glow)


# Detalles pequeños sobre los techos para romper la repetición de las siluetas.
func _build_rooftop_details() -> void:
	var tank_mat := _std(Color("#285b83"), 0.58, 0.12)
	var dark_metal := _std(Color("#303338"), 0.72, 0.3)
	var water_mat := _std(Color("#4d8eb4"), 0.32, 0.15)
	for item: int in 26:
		var x := rng.randf_range(-58.0, 58.0)
		var z := rng.randf_range(-57.0, -18.0)
		var h := rng.randf_range(13.0, 35.0)
		var radius := rng.randf_range(0.48, 0.78)
		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = radius * 0.94
		tank_mesh.bottom_radius = radius
		tank_mesh.height = rng.randf_range(1.0, 1.6)
		tank.mesh = tank_mesh
		tank.material_override = tank_mat
		tank.position = Vector3(x, h + 0.9, z)
		add_child(tank)
		if item % 3 == 0:
			var lid := MeshInstance3D.new()
			var lid_mesh := CylinderMesh.new()
			lid_mesh.top_radius = radius * 0.35
			lid_mesh.bottom_radius = radius * 0.35
			lid_mesh.height = 0.08
			lid.mesh = lid_mesh
			lid.material_override = water_mat
			lid.position = Vector3(x, h + 1.72, z)
			add_child(lid)
		if item % 2 == 0:
			for leg: int in 3:
				var support := MeshInstance3D.new()
				var support_mesh := CylinderMesh.new()
				support_mesh.top_radius = 0.035
				support_mesh.bottom_radius = 0.035
				support_mesh.height = 0.9
				support.mesh = support_mesh
				support.material_override = dark_metal
				support.position = Vector3(x + cos(TAU * leg / 3.0) * radius * 0.7, h + 0.42, z + sin(TAU * leg / 3.0) * radius * 0.7)
				add_child(support)


# Antenas, platos de television y tuberias: siluetas tipicas de azoteas habitadas.
func _build_rooftop_antennas() -> void:
	var metal := _std(Color("#3c4145"), 0.7, 0.38)
	var dish_mat := _std(Color("#a6a6a0"), 0.55, 0.25)
	for idx: int in 34:
		var x := rng.randf_range(-57.0, 57.0)
		var z := rng.randf_range(-58.0, -17.0)
		var y := rng.randf_range(12.0, 37.0)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.025
		pole_mesh.bottom_radius = 0.035
		pole_mesh.height = rng.randf_range(1.1, 2.0)
		pole.mesh = pole_mesh
		pole.material_override = metal
		pole.position = Vector3(x, y + 0.8, z)
		add_child(pole)
		for cross: int in 2:
			_box(Vector3(x, y + 0.55 + cross * 0.42, z), Vector3(0.8 + cross * 0.45, 0.045, 0.045), metal)
		if idx % 2 == 0:
			var dish := MeshInstance3D.new()
			var dish_mesh := SphereMesh.new()
			dish_mesh.radius = 0.52
			dish_mesh.height = 0.22
			dish.mesh = dish_mesh
			dish.material_override = dish_mat
			dish.position = Vector3(x + 0.65, y + 0.65, z + 0.15)
			dish.scale = Vector3(1.0, 0.18, 1.0)
			add_child(dish)
	# Tuberias verticales en fachadas y bordes de azoteas.
	for pipe: int in 22:
		var x := rng.randf_range(-55.0, 55.0)
		var z := rng.randf_range(-55.0, -18.0)
		var h := rng.randf_range(3.0, 8.0)
		var tube := MeshInstance3D.new()
		var tube_mesh := CylinderMesh.new()
		tube_mesh.top_radius = 0.045
		tube_mesh.bottom_radius = 0.045
		tube_mesh.height = h
		tube.mesh = tube_mesh
		tube.material_override = metal
		tube.position = Vector3(x, h * 0.5 + 1.0, z)
		add_child(tube)


# Ropa tendida entre viviendas: pequeñas siluetas que ayudan a dar escala humana al barrio.
func _build_neighborhood_laundry() -> void:
	var cloth_colors := [Color("#e6dfd0"), Color("#b84d42"), Color("#d2a84b"), Color("#426c8a"), Color("#6c8b65"), Color("#a66a8b")]
	var cord_mat := _std(Color("#25282b"), 0.8, 0.2)
	for line_idx: int in 18:
		var x0 := rng.randf_range(-52.0, 42.0)
		var span := rng.randf_range(2.8, 5.5)
		var y := rng.randf_range(7.0, 25.0)
		var z := rng.randf_range(-55.0, -19.0)
		_cable(Vector3(x0, y, z), Vector3(x0 + span, y - rng.randf_range(0.1, 0.55), z - 0.5), cord_mat)
		var pieces := rng.randi_range(3, 6)
		for piece: int in pieces:
			var cloth := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(rng.randf_range(0.35, 0.62), rng.randf_range(0.45, 0.9))
			cloth.mesh = mesh
			var mat := _std(cloth_colors[rng.randi() % cloth_colors.size()], 0.92)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			cloth.material_override = mat
			cloth.position = Vector3(x0 + 0.25 + float(piece) * span / float(pieces), y - mesh.size.y * 0.5, z - 0.54)
			cloth.rotation_degrees.y = rng.randf_range(-8.0, 8.0)
			add_child(cloth)
