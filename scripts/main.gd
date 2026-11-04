extends Node3D
# Cancha 19 3D — reglas del juego, IA rival, controles, cámara y marcador.
# Medidas en metros. Coordenadas del juego: Vector2(x, z). El equipo 0 (azul, el tuyo) ataca hacia +x.
# Modo de pruebas: godot --path . -- --autotest --shots=/carpeta   (juega solo y saca capturas)

const Stage = preload("res://scripts/stage.gd")
const Character = preload("res://scripts/character.gd")
const Cast = preload("res://scripts/cast.gd")

const HX := 20.0
const HZ := 12.0
const GZ := 3.0
const DUR := 120.0
const BALL_R := 0.22
# [posición x (0..1 a lo largo), posición z (0..1 a lo ancho), es portero]
const FORM := [[0.04, 0.5, 1], [0.22, 0.3, 0], [0.22, 0.7, 0], [0.44, 0.27, 0], [0.44, 0.73, 0]]

const BALL_SHADER := """
shader_type spatial;
varying vec3 lp;
void vertex(){ lp = normalize(VERTEX); }
void fragment(){
	vec3 D[6] = vec3[](vec3(0.0, 0.5257, 0.8507), vec3(0.0, -0.5257, 0.8507), vec3(0.5257, 0.8507, 0.0), vec3(-0.5257, 0.8507, 0.0), vec3(0.8507, 0.0, 0.5257), vec3(0.8507, 0.0, -0.5257));
	float m = 0.0;
	for (int i = 0; i < 6; i++){ m = max(m, abs(dot(lp, D[i]))); }
	float dark = smoothstep(0.89, 0.92, m);
	ALBEDO = mix(vec3(0.96), vec3(0.07), dark);
	ROUGHNESS = 0.4;
}
"""


class Pl extends RefCounted:
	var team := 0
	var gk := false
	var idx := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var face := Vector2.RIGHT
	var fx0 := 0.0
	var fz0 := 0.0
	var cd := 0.0
	var tcd := 0.0
	var hold := 0.0
	var node: Node3D = null


var stage: Node3D
var players: Array[Pl] = []
var bpos := Vector2.ZERO
var bvel := Vector2.ZERO
var holder: Pl = null
var ctrl: Pl = null
var last_ctrl: Pl = null
var score := [0, 0]
var clock := 0.0
var state := "menu"  # menu, play, goal, end
var timer := 0.0
var scorer := -1
var charge_t := -1.0
var input_vec := Vector2.ZERO
var t_all := 0.0

var cam: Camera3D
var cam_t := Vector3.ZERO
var ball_node: Node3D
var ball_mesh: MeshInstance3D
var ball_shadow: MeshInstance3D
var confetti: CPUParticles3D

var lbl_score: Label
var lbl_time: Label
var lbl_msg: Label
var charge_bar: ProgressBar
var flash: ColorRect
var overlay: ColorRect
var ov_title: Label
var ov_text: Label
var ov_btn: Button

var autotest := false
var shot_dir := ""
var frame_n := 0


func _ready() -> void:
	randomize()
	for a: String in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
	_setup_input()
	stage = Stage.new()
	add_child(stage)
	stage.build()
	_build_ball()
	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	_build_confetti()
	_build_hud()
	_spawn_players()
	_kickoff()
	cam_t = Vector3.ZERO
	if autotest:
		_start()


# ---------- controles ----------
func _add_action(a: String, keys: Array, pads: Array = [], axes: Array = []) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.3)
	for k: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(a, e)
	for b: int in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = b as JoyButton
		InputMap.action_add_event(a, j)
	for ax: Array in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[0] as JoyAxis
		m.axis_value = ax[1]
		InputMap.action_add_event(a, m)


func _setup_input() -> void:
	_add_action("left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("pass", [KEY_X, KEY_J], [JOY_BUTTON_A])
	_add_action("shoot", [KEY_SPACE, KEY_K], [JOY_BUTTON_X, JOY_BUTTON_B])
	_add_action("run", [KEY_SHIFT, KEY_L], [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode == KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif ev.physical_keycode == KEY_ESCAPE and state == "play":
			state = "menu"
			_show_overlay("PAUSA", "Presiona Jugar para empezar un partido nuevo.", "Jugar")


# ---------- balón ----------
func _build_ball() -> void:
	ball_node = Node3D.new()
	add_child(ball_node)
	ball_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	ball_mesh.mesh = sm
	var sh := Shader.new()
	sh.code = BALL_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	ball_mesh.material_override = m
	ball_node.add_child(ball_mesh)
	ball_shadow = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = Character.shadow_tex()
	ball_shadow.mesh = qm
	ball_shadow.material_override = smat
	ball_shadow.rotation_degrees = Vector3(-90, 0, 0)
	add_child(ball_shadow)


func _build_confetti() -> void:
	confetti = CPUParticles3D.new()
	confetti.amount = 160
	confetti.one_shot = true
	confetti.emitting = false
	confetti.lifetime = 3.5
	confetti.explosiveness = 0.9
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(14.0, 0.5, 6.0)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 25.0
	confetti.initial_velocity_min = 2.0
	confetti.initial_velocity_max = 5.0
	confetti.gravity = Vector3(0, -2.0, 0)
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.24, 0.14)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = mat
	confetti.mesh = qm
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color("#ffd23a"), Color("#ff4a4a"), Color("#4aa0ff"), Color("#5aff8a"), Color("#ff7ad0"), Color("#ffffff")])
	confetti.color_initial_ramp = g
	add_child(confetti)


# ---------- HUD ----------
func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.06, 0.8)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	bar.add_child(hb)
	hb.add_child(_label("TÚ", 26, Color("#5aa0ff")))
	lbl_score = _label("0 – 0", 44)
	hb.add_child(lbl_score)
	hb.add_child(_label("RIVAL", 26, Color("#ff9a3a")))
	lbl_time = _label("0’", 24, Color("#c9d2cc"))
	hb.add_child(lbl_time)
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	lbl_msg = _label("", 96, Color("#ffe14a"))
	lbl_msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_msg.anchor_top = 0.2
	lbl_msg.anchor_bottom = 0.45
	lbl_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl_msg)

	charge_bar = ProgressBar.new()
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.show_percentage = false
	charge_bar.custom_minimum_size = Vector2(280, 18)
	charge_bar.visible = false
	root.add_child(charge_bar)
	charge_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 54)
	charge_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var help := _label("WASD / flechas: mover   ·   X: pase o cambiar   ·   Espacio: tiro (mantén y suelta)   ·   Shift: correr   ·   F11: pantalla completa", 16, Color("#e0e8e2"))
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.04, 0.03, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	cc.add_child(vb)
	ov_title = _label("CANCHA 19", 110, Color("#ffd23a"))
	vb.add_child(ov_title)
	ov_text = _label("", 24, Color("#e8efe9"))
	ov_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_text.custom_minimum_size = Vector2(760, 0)
	vb.add_child(ov_text)
	ov_btn = Button.new()
	ov_btn.text = "Jugar"
	ov_btn.add_theme_font_size_override("font_size", 32)
	ov_btn.custom_minimum_size = Vector2(260, 64)
	ov_btn.pressed.connect(_start)
	vb.add_child(ov_btn)
	_show_overlay("CANCHA 19", "Fútbol 5 contra 5 en la cancha de la favela.\nCada partido sale con un elenco distinto de personajes al azar.\n\nMover: WASD o flechas   ·   Pase / cambiar jugador: X   ·   Tiro: mantén Espacio y suelta   ·   Correr: Shift\nMando: A pase, X tiro, gatillo derecho correr.", "Jugar")


func _show_overlay(title: String, text: String, btn: String) -> void:
	ov_title.text = title
	ov_text.text = text
	ov_btn.text = btn
	overlay.visible = true
	ov_btn.grab_focus()


# ---------- partido ----------
func _spawn_players() -> void:
	for p in players:
		if p.node:
			p.node.queue_free()
	players.clear()
	var pool: Array = Cast.LIST.duplicate()
	pool.shuffle()
	var jersey := [Color("#2f7bff"), Color("#ff8a2a")]
	var shorts := [Color("#f4f4f4"), Color("#222222")]
	var gk_j := [Color("#18c4d8"), Color("#ffd23a")]
	var gk_s := [Color("#1f2a30"), Color("#2a2418")]
	var gk_g := [Color("#f4ff5a"), Color("#ff6a3a")]
	for t: int in 2:
		for i: int in 5:
			var p := Pl.new()
			p.team = t
			p.idx = i
			p.gk = int(FORM[i][2]) == 1
			p.fx0 = float(FORM[i][0])
			p.fz0 = float(FORM[i][1])
			var sp: Dictionary = pool[t * 5 + i]
			var c := Character.new()
			if p.gk:
				c.build(sp["id"], gk_j[t], gk_s[t], 1, true, gk_g[t])
			else:
				c.build(sp["id"], jersey[t], shorts[t], i + 1, false)
			c.set_name_tag(sp["name"])
			add_child(c)
			p.node = c
			players.append(p)
	ctrl = null
	last_ctrl = null


func _home(p: Pl) -> Vector2:
	var s := 0.0 if p.gk else bpos.x * 0.3
	var x := (p.fx0 - 0.5) * 40.0 + s if p.team == 0 else (0.5 - p.fx0) * 40.0 - s
	return Vector2(x, (p.fz0 - 0.5) * 24.0)


func _kickoff() -> void:
	bpos = Vector2.ZERO
	bvel = Vector2.ZERO
	holder = null
	charge_t = -1.0
	var save_b := bpos
	for p in players:
		p.vel = Vector2.ZERO
		p.cd = 0.0
		p.tcd = 0.0
		p.hold = 0.0
		p.pos = _home(p)
		p.face = Vector2.RIGHT if p.team == 0 else Vector2.LEFT
	bpos = save_b
	if ctrl == null or ctrl.team != 0 or ctrl.gk:
		ctrl = _first_of_team(0)


func _first_of_team(t: int) -> Pl:
	var best: Pl = null
	for p in players:
		if p.team == t and not p.gk and p.idx == 3:
			best = p
	return best


func _start() -> void:
	overlay.visible = false
	score = [0, 0]
	clock = 0.0
	scorer = -1
	lbl_msg.text = ""
	_spawn_players()
	_kickoff()
	state = "play"
	_update_hud()


func _finish() -> void:
	var a: int = score[0]
	var b: int = score[1]
	var title := "EMPATE" if a == b else ("¡GANASTE!" if a > b else "PERDISTE")
	_show_overlay(title, "Resultado final:  Tú %d – %d Rival" % [a, b], "Jugar otra vez")


func _switch_player() -> void:
	var best: Pl = null
	var bd := 1e9
	for p in players:
		if p.team == 0 and not p.gk and p != ctrl:
			var d := p.pos.distance_to(bpos)
			if d < bd:
				bd = d
				best = p
	if best:
		ctrl = best


func _kick(p: Pl, dir: Vector2, speed: float) -> void:
	var d := dir.normalized() if dir.length() > 0.001 else p.face
	holder = null
	bpos = p.pos + d * 0.76
	bvel = d * speed
	p.cd = 0.35
	p.face = d
	if p.node:
		p.node.kick()


func _do_shot(p: Pl, power: float, aim_z: float) -> void:
	var gx := -HX if p.team == 1 else HX
	_kick(p, Vector2(gx - p.pos.x, aim_z - p.pos.y), 11.4 + power * 21.3)


func _do_pass(p: Pl) -> void:
	var has := p == ctrl and input_vec.length() > 0.2
	var dir := input_vec.normalized() if has else p.face
	var best: Pl = null
	var bs := -1e9
	for q in players:
		if q.team != p.team or q == p:
			continue
		var to := q.pos - p.pos
		var d := maxf(to.length(), 0.1)
		var s: float
		if p.team == 0 and has:
			s = dir.dot(to / d) - d / 34.3
		else:
			var fwd := -to.x if p.team == 1 else to.x
			s = fwd / d * 0.6 - d / 34.3 + randf() * 0.4
		if s > bs:
			bs = s
			best = q
	if best:
		if p.team == 0 and not best.gk:
			ctrl = best
		var v := best.pos + best.vel * 0.3 - p.pos
		_kick(p, v, minf(23.6, 9.9 + v.length() * 1.1))
	else:
		_kick(p, dir, 9.0)


func _score_goal(t: int) -> void:
	score[t] += 1
	scorer = t
	state = "goal"
	timer = 2.2
	holder = null
	lbl_msg.text = "¡GOOOL!" if t == 0 else "Gol del rival"
	lbl_msg.add_theme_color_override("font_color", Color("#ffe14a") if t == 0 else Color("#ff9a6a"))
	flash.color = Color(1, 1, 1, 0.55)
	confetti.position = Vector3(cam_t.x, 9.0, cam_t.z)
	confetti.restart()
	confetti.emitting = true
	for p in players:
		p.node.celebrate = (p.team == t)
	_update_hud()


func _ball_in_net(dt: float) -> void:
	bpos += bvel * dt
	bvel *= pow(0.5, dt * 1.5)
	if absf(bpos.y) > GZ - 0.2:
		bpos.y = signf(bpos.y) * (GZ - 0.2)
		bvel.y *= -0.5
	var lim := HX + 1.4
	if absf(bpos.x) > lim:
		bpos.x = signf(bpos.x) * lim
		bvel.x *= -0.3


func _step(dt: float) -> void:
	if state == "goal":
		timer -= dt
		_ball_in_net(dt)
		if timer <= 0.0:
			state = "play"
			lbl_msg.text = ""
			for p in players:
				p.node.celebrate = false
			_kickoff()
		return
	if state != "play":
		return
	clock += dt
	if clock >= DUR:
		state = "end"
		_finish()
		return

	var run := Input.is_action_pressed("run")
	input_vec = Input.get_vector("left", "right", "up", "down")
	if autotest:
		input_vec = Vector2(1.0, sin(clock * 0.7) * 0.6) if int(clock / 4.0) % 2 == 0 else Vector2(-0.6, cos(clock) * 0.8)
		run = fmod(clock, 3.0) < 1.5
		if fmod(clock, 2.7) < dt:
			_press_pass()
		if fmod(clock, 3.9) < dt:
			charge_t = Time.get_ticks_msec() / 1000.0 - 0.6
			_release_shoot()
	else:
		if Input.is_action_just_pressed("pass"):
			_press_pass()
		if Input.is_action_just_pressed("shoot"):
			charge_t = Time.get_ticks_msec() / 1000.0
		if Input.is_action_just_released("shoot"):
			_release_shoot()

	# jugador controlado
	if holder != null and holder.team == 0 and not holder.gk:
		ctrl = holder
	elif ctrl == null or ctrl.gk or ctrl.team != 0:
		_switch_player()

	var near: Array = [null, null]
	for t: int in 2:
		var bd := 1e9
		for p in players:
			if p.team == t and not p.gk:
				var d := p.pos.distance_to(bpos)
				if d < bd:
					bd = d
					near[t] = p

	for p in players:
		p.cd -= dt
		p.tcd -= dt
		var target := p.pos
		var sp := 5.1
		var mv := Vector2.ZERO
		var use_input := false
		if p == ctrl:
			mv = input_vec
			sp = 7.8 if run else 5.7
			use_input = true
		elif p.gk:
			var h := _home(p)
			target = Vector2(h.x, clampf(bpos.y, -GZ + 0.4, GZ - 0.4))
			var own_end := HX if p.team == 1 else -HX
			if holder == null and bpos.distance_to(p.pos) < 5.7 and absf(bpos.x - own_end) < 7.6:
				target = bpos
			sp = 5.7
			if holder == p:
				p.hold += dt
				if p.hold > 0.7:
					p.hold = 0.0
					_do_pass(p)
		else:
			var my_ball := holder != null and holder.team == p.team
			if holder == p:
				var gx := -HX if p.team == 1 else HX
				target = Vector2(gx, 1.3 if p.pos.y < 0.0 else -1.3)
				sp = 6.5
				var dg := absf(p.pos.x - gx)
				p.hold += dt
				if dg < 11.0 and p.hold > 0.3:
					_do_shot(p, 0.5 + randf() * 0.3, (randf() - 0.5) * 4.2)
					p.hold = 0.0
				elif p.hold > 1.3 and randf() < 0.04:
					_do_pass(p)
					p.hold = 0.0
			elif near[p.team] == p and not my_ball:
				target = bpos + bvel * 0.25
				sp = 5.7 if p.team == 1 else 5.3
			else:
				var h2 := _home(p)
				target = h2 + Vector2((-2.7 if p.team == 1 else 2.7) if my_ball else 0.0, 0.0)
		if not use_input:
			var dv := target - p.pos
			var dl := dv.length()
			if dl > 0.23:
				mv = dv / dl
		p.vel += (mv * sp - p.vel) * minf(1.0, dt * 8.0)
		p.pos += p.vel * dt
		p.pos.x = clampf(p.pos.x, -HX + 0.5, HX - 0.5)
		p.pos.y = clampf(p.pos.y, -HZ + 0.5, HZ - 0.5)
		if p.vel.length() > 0.76:
			p.face = p.vel.normalized()

	# separación entre jugadores
	for i: int in players.size():
		for j: int in range(i + 1, players.size()):
			var a := players[i]
			var b := players[j]
			var dv := b.pos - a.pos
			var d := dv.length()
			if d < 0.84 and d > 0.001:
				var push := dv / d * (0.84 - d) * 0.5
				a.pos -= push
				b.pos += push

	# balón
	if holder != null:
		bpos = holder.pos + holder.face * 0.65
		bvel = holder.vel
		for o in players:
			if o.team != holder.team and o.tcd <= 0.0 and o.pos.distance_to(holder.pos) < 0.76:
				o.tcd = 0.8
				if randf() < 0.5:
					holder.cd = 0.5
					holder = o
					o.hold = 0.0
					break
	else:
		bpos += bvel * dt
		bvel *= pow(0.5, dt)
		if bpos.y < -HZ:
			bpos.y = -HZ
			bvel.y *= -0.6
		if bpos.y > HZ:
			bpos.y = HZ
			bvel.y *= -0.6
		var in_goal := absf(bpos.y) < GZ
		if absf(bpos.x) > HX:
			if in_goal:
				_score_goal(0 if bpos.x > 0.0 else 1)
				return
			bpos.x = signf(bpos.x) * HX
			bvel.x *= -0.6
		var sp_b := bvel.length()
		var cand: Pl = null
		var cdist := 1e9
		for p in players:
			if p.cd > 0.0:
				continue
			var d := p.pos.distance_to(bpos)
			if d < (0.9 if p.gk else 0.65) and sp_b < (34.0 if p.gk else 14.5) and d < cdist:
				cdist = d
				cand = p
		if cand:
			if cand.gk and sp_b > 24.8 and randf() < 0.3:
				bvel.x *= -0.4
				bvel.y += (randf() - 0.5) * 11.4
				cand.cd = 0.4
			else:
				holder = cand
				cand.hold = 0.0


func _press_pass() -> void:
	if holder != null and holder.team == 0:
		_do_pass(holder)
	else:
		_switch_player()


func _release_shoot() -> void:
	if charge_t < 0.0:
		return
	var power := clampf((Time.get_ticks_msec() / 1000.0 - charge_t) / 1.0, 0.0, 1.0)
	charge_t = -1.0
	if holder != null and holder.team == 0 and state == "play":
		_do_shot(holder, maxf(0.15, power), input_vec.y * 2.1)


# ---------- dibujo cada cuadro ----------
func _process(delta: float) -> void:
	t_all += delta
	var dt := minf(delta, 0.05)
	if autotest:
		for i: int in 6:
			_step(1.0 / 60.0)
		dt = 6.0 / 60.0
	else:
		_step(dt)
	_update_visuals(dt)
	_update_cam(dt)
	_update_hud()
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 1.4)
	charge_bar.visible = charge_t >= 0.0 and state == "play"
	if charge_bar.visible:
		charge_bar.value = clampf((Time.get_ticks_msec() / 1000.0 - charge_t) / 1.0, 0.0, 1.0)
	if autotest:
		frame_n += 1
		if frame_n == 100 and state == "play":
			_score_goal(0)
		if shot_dir != "" and (frame_n == 30 or frame_n == 80 or frame_n == 106 or frame_n == 140):
			get_viewport().get_texture().get_image().save_png("%s/auto_%d.png" % [shot_dir, frame_n])
		if frame_n == 145:
			print("AUTOTEST OK  marcador %d-%d  reloj %.1f  estado %s" % [score[0], score[1], clock, state])
			get_tree().quit()


func _update_visuals(dt: float) -> void:
	for p in players:
		var n: Node3D = p.node
		n.position = Vector3(p.pos.x, 0.0, p.pos.y)
		n.animate(dt, p.vel.length(), p.face)
		n.ready_pose = p.gk and state == "play" and holder == null and p.pos.distance_to(bpos) < 6.0
		var on := (p == ctrl and state == "play")
		if on != (p == last_ctrl):
			n.set_controlled(on)
			if on:
				if last_ctrl:
					last_ctrl.node.set_controlled(false)
				last_ctrl = p
	if ctrl == null and last_ctrl:
		last_ctrl.node.set_controlled(false)
		last_ctrl = null
	var hop := 0.0
	if holder != null and holder.vel.length() > 1.0:
		hop = absf(sin(t_all * 11.0)) * 0.1
	ball_node.position = Vector3(bpos.x, BALL_R + hop, bpos.y)
	var spd := bvel.length()
	if spd > 0.05:
		var axis := Vector3.UP.cross(Vector3(bvel.x, 0.0, bvel.y)).normalized()
		ball_mesh.global_rotate(axis, spd * dt / BALL_R)
	ball_shadow.position = Vector3(bpos.x + 0.05, 0.02, bpos.y + 0.03)
	var k := 1.0 - hop * 2.0
	ball_shadow.scale = Vector3(k, k, 1.0)


func _update_cam(dt: float) -> void:
	var tgt: Vector3
	if state == "menu":
		tgt = Vector3(sin(t_all * 0.2) * 9.0, 0.0, 0.0)
	else:
		tgt = Vector3(clampf(bpos.x + bvel.x * 0.15, -12.0, 12.0), 0.0, clampf(bpos.y + bvel.y * 0.15, -4.0, 4.0) * 0.6)
	cam_t = cam_t.lerp(tgt, 1.0 - exp(-dt * 4.0))
	cam.position = cam_t + Vector3(0.0, 13.5, 17.0)
	cam.look_at(cam_t + Vector3(0.0, 0.0, 0.3))


func _update_hud() -> void:
	lbl_score.text = "%d – %d" % [score[0], score[1]]
	lbl_time.text = "%d’" % mini(90, int(clock / DUR * 90.0))
