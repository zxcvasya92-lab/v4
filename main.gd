extends Node3D
# BMX Street — порт прототипа 0.6 на Godot 4 (GDScript).
# Сцена, байк и интерфейс строятся кодом. Редактор открывать для настройки не нужно.

const G := 9.81
const FIXED := 1.0 / 120.0
const MAXS := 13.0
const LIM := 88.0
const GROUND := 0
const AIR := 1
const BAIL := 2
const SPAWN_X := 0.0
const SPAWN_Z := 10.0
const SPAWN_B := PI / 2.0

# ---- НОВАЯ МЕХАНИКА: толчок ногами (педали L и R при отведённом назад весе) ----
const PUSH_MAX := 3.0     # сколько «заряда» копится (чередующееся нажатие = 1.3, то же самое = 0.3)
const PUSH_BOOST := 1.7   # добавка к вертикальной скорости прыжка при полном заряде, м/с
const PUSH_DECAY := 0.5   # заряд утекает со скоростью, ед/с (толчок должен быть «свежим»)

const HELP_TEXT := "УПРАВЛЕНИЕ (раскладка как в эмуляторе PSP)\nЛевый стик или крестовина — руль (влево/вправо) и вес: вниз — назад (нос вверх), вверх — вперёд. Удерживай у точки баланса — мануал.\nПравый стик — голова ведёт вращение (180, 360); в воздухе вверх/вниз — барспин.\nL и R — ноги: жми по очереди для разгона.\nКрест — быстрый хоп. Треугольник — тормоз.\nКвадрат — отпустить левую руку, Круг — правую.\n\nБАНИХОП: левый стик вниз, затем резко вверх.\nТОЛЧОК НОГАМИ: пока вес отведён назад, жми L и R по очереди — прыжок выше (шкала «толчок»).\nРУКИ: в воздухе обе руки отпущены — ноу-хэндер, одна — ван-хэндер (очки). Приземление без обеих рук — бейл. Без рук руль почти не работает.\n\nStart — меню, Select — сброс.\nКлавиатура: WASD — левый стик, стрелки — правый, Q/E — L/R, Space — хоп, Z/X — левая/правая рука, C — тормоз, R — сброс, Esc — меню."

class Box:
	var x0 := 0.0
	var x1 := 0.0
	var z0 := 0.0
	var z1 := 0.0
	var h := 0.0

class Ramp:
	var cx := 0.0
	var cz := 0.0
	var rot := 0.0
	var L := 1.0
	var w := 1.0
	var H := 1.0
	var quarter := false
	var pw := 1.8
	var c := 1.0
	var s := 0.0

var boxes: Array[Box] = []
var ramps: Array[Ramp] = []

# ---- состояние байка ----
var px := SPAWN_X
var pz := SPAWN_Z
var py := 0.0
var yaw := SPAWN_B
var spd := 0.0
var vy := 0.0
var wvx := 0.0
var wvz := 0.0
var mode := GROUND
var th := 0.0
var om := 0.0
var pitch := 0.0
var gp := 0.0
var roll := 0.0
var vy_g := 0.0
var ws := 0.0
var crank := 0.0
var wheel_a := 0.0
var spin_w := 0.0
var spin_acc := 0.0
var nose_acc := 0.0
var air_t := 0.0
var hop_t := 999.0
var mair := SPAWN_B
var take_y := 0.0
var bar_angle := 0.0
var bar_rem := 0.0
var bar_dir := 1.0
var bar_count := 0
var bar_cool := 0.0
var bail_t := 0.0
var tumble := 0.0
var tum_dir := 1.0
var safe_x := SPAWN_X
var safe_z := SPAWN_Z
var safe_b := SPAWN_B
var safe_t := 0.0

# банихоп и толчок ногами
var hop_armed := false
var hop_since := 9.0
var hop_peak := 0.0
var hop_push := 0.0
var kb_hop := false

# руки, тормоз, руление
const WHEELBASE := 1.6
var steer_ang := 0.0
var pitch_w := 0.0
var hand_l_off := false
var hand_r_off := false
var brake_held := false
var hl_amt := 0.0
var hr_amt := 0.0
var noh_t := 0.0
var oneh_t := 0.0
var hint_t := 14.0
var pad_a := false
var pad_start := false
var pad_back := false
var kesc := false

# виртуальные кнопки, меню и редактор раскладки
var ctrls := {}
var touch_role := {}
var stick_vec := {"stick": Vector2.ZERO, "stick2": Vector2.ZERO}
var dpad_dir := Vector2.ZERO
var dpad_dig := Vector2.ZERO
var ui_opacity := 0.55
var ui_scale := 1.0
var show_labels := true
var menu_open := false
var edit_mode := false
var edit_sel := ""
var edit_drag := -1
var edit_off := Vector2.ZERO
var menu_panel: PanelContainer
var edit_bar: PanelContainer
var edit_lbl: Label

# ---- ввод ----
var in_lx := 0.0
var in_ly := 0.0
var in_rx := 0.0
var in_ry := 0.0
var kb_lx := 0.0
var kb_ly := 0.0
var kb_rx := 0.0
var kb_ry := 0.0
var pedal_down := {"L": false, "R": false}
var pedal_last := 0
var pedal_kick := 0.0
var pedal_tap := 0.0
var pedal_both_t := 0.0
var pad_l := false
var pad_r := false
var kq := false
var ke := false
var kspace := false
var kr := false

# ---- настройки ----
var assist_bal := true
var assist_land := true
var invert_y := false

# ---- очки ----
var score := 0
var combo_items: Array = []
var combo_pts := 0.0
var combo_idle := 0.0
var has_manual := false
var has_nose := false
var toast_text := ""
var toast_t := 0.0
var toast_good := true

# ---- узлы ----
var root: Node3D
var body: Node3D
var fork: Node3D
var bar_g: Node3D
var rear_w: Node3D
var front_w: Node3D
var cam: Camera3D
var ui: CanvasLayer
var hud: Control
var crank_l: MeshInstance3D
var crank_r: MeshInstance3D
var pedal_l_m: MeshInstance3D
var pedal_r_m: MeshInstance3D
var pelvis: MeshInstance3D
var chest: MeshInstance3D
var torso: MeshInstance3D
var th_l: MeshInstance3D
var th_r: MeshInstance3D
var sh_l: MeshInstance3D
var sh_r: MeshInstance3D
var ua_l: MeshInstance3D
var ua_r: MeshInstance3D
var fa_l: MeshInstance3D
var fa_r: MeshInstance3D
var knee_l: MeshInstance3D
var knee_r: MeshInstance3D
var hand_l: MeshInstance3D
var hand_r: MeshInstance3D
var foot_l: MeshInstance3D
var foot_r: MeshInstance3D
var head_g: Node3D

var rig_ly := 0.0
var rig_head := 0.0
var rig_tors := 0.0
var rig_crouch := 0.0
var rig_steer := 0.0

var cam_yaw := SPAWN_B
var cam_pos := Vector3(0, 3, 15)
var cam_look := Vector3(0, 1, 0)
var acc_t := 0.0

var m_ledge: StandardMaterial3D
var m_ramp: StandardMaterial3D
var m_edge: StandardMaterial3D
var m_red: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_rubber: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_jersey: StandardMaterial3D
var m_pants: StandardMaterial3D
var m_skin: StandardMaterial3D
var m_shoe: StandardMaterial3D
var m_visor: StandardMaterial3D

const POLE_LEG := Vector3(1, 0.15, 0)
const POLE_ARM_L := Vector3(-0.5, 0.25, -1)
const POLE_ARM_R := Vector3(-0.5, 0.25, 1)
const C_VEC := Vector3(-0.78, 0, 0)
const C_VEC_F := Vector3(0.82, 0, 0)


# =====================================================================
# УТИЛИТЫ
# =====================================================================
func damp(a: float, b: float, k: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-k * dt))

func wrap_half(a: float) -> float:
	return a - roundf(a / PI) * PI

func dir_of(a: float) -> Vector2:
	return Vector2(cos(a), -sin(a))

func deadzone(v: Vector2, d: float = 0.14) -> Vector2:
	var m := v.length()
	if m < d:
		return Vector2.ZERO
	return v * ((m - d) / (1.0 - d) / m)

func vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func mat(color: String, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = rough
	m.metallic = metal
	return m

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://bmx.cfg") == OK:
		assist_bal = cf.get_value("s", "assist_bal", true)
		assist_land = cf.get_value("s", "assist_land", true)
		invert_y = cf.get_value("s", "invert_y", false)
		show_labels = cf.get_value("s", "show_labels", true)
		ui_opacity = cf.get_value("s", "ui_opacity", 0.55)
		ui_scale = cf.get_value("s", "ui_scale", 1.0)

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "assist_bal", assist_bal)
	cf.set_value("s", "assist_land", assist_land)
	cf.set_value("s", "invert_y", invert_y)
	cf.set_value("s", "show_labels", show_labels)
	cf.set_value("s", "ui_opacity", ui_opacity)
	cf.set_value("s", "ui_scale", ui_scale)
	cf.save("user://bmx.cfg")


# =====================================================================
# РЕЛЬЕФ
# =====================================================================
func ramp_profile(r: Ramp, t: float) -> float:
	if r.quarter:
		var tt := minf(t, 0.97)
		var k := 1.0 - sqrt(1.0 - tt * tt)
		var km := 1.0 - sqrt(1.0 - 0.97 * 0.97)
		return r.H * minf(1.0, k / km)
	return r.H * pow(t, r.pw)

func terrain_h(x: float, z: float) -> float:
	var h := 0.0
	for b in boxes:
		if x >= b.x0 and x <= b.x1 and z >= b.z0 and z <= b.z1 and b.h > h:
			h = b.h
	for r in ramps:
		var dx := x - r.cx
		var dz := z - r.cz
		var lx := dx * r.c - dz * r.s
		var lz := dx * r.s + dz * r.c
		if absf(lz) <= r.w * 0.5 and lx >= -r.L * 0.5 and lx <= r.L * 0.5:
			var v := ramp_profile(r, (lx + r.L * 0.5) / r.L)
			if v > h:
				h = v
	return h

func slope_along(x: float, z: float, b: float) -> float:
	var fx := cos(b) * 0.5
	var fz := -sin(b) * 0.5
	return terrain_h(x + fx, z + fz) - terrain_h(x - fx, z - fz)

func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot: лицевая сторона — по часовой стрелке. Порядок подбираем под нужную нормаль.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(st, a, b, c, n)
	tri(st, a, c, d, n)

func ramp_mesh(r: Ramp) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 22
	var hw := r.w * 0.5
	var L := r.L
	for i in range(n):
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var x0 := -L * 0.5 + t0 * L
		var x1 := -L * 0.5 + t1 * L
		var h0 := ramp_profile(r, t0)
		var h1 := ramp_profile(r, t1)
		var nrm := Vector3(-(h1 - h0), x1 - x0, 0.0).normalized()
		quad(st, Vector3(x0, h0, -hw), Vector3(x1, h1, -hw), Vector3(x1, h1, hw), Vector3(x0, h0, hw), nrm)
		quad(st, Vector3(x0, 0, hw), Vector3(x1, 0, hw), Vector3(x1, h1, hw), Vector3(x0, h0, hw), Vector3(0, 0, 1))
		quad(st, Vector3(x0, 0, -hw), Vector3(x1, 0, -hw), Vector3(x1, h1, -hw), Vector3(x0, h0, -hw), Vector3(0, 0, -1))
	var hb := ramp_profile(r, 1.0)
	quad(st, Vector3(L * 0.5, 0, -hw), Vector3(L * 0.5, 0, hw), Vector3(L * 0.5, hb, hw), Vector3(L * 0.5, hb, -hw), Vector3(1, 0, 0))
	return st.commit()

func lines_mesh(pts: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for p in pts:
		st.add_vertex(p)
	return st.commit()

func add_lines(pts: PackedVector3Array, pos: Vector3, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = lines_mesh(pts)
	mi.material_override = m_edge
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func add_box(cx: float, cz: float, sx: float, sz: float, h: float) -> void:
	var b := Box.new()
	b.x0 = cx - sx * 0.5
	b.x1 = cx + sx * 0.5
	b.z0 = cz - sz * 0.5
	b.z1 = cz + sz * 0.5
	b.h = h
	boxes.append(b)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(sx, h, sz)
	mi.mesh = bm
	mi.material_override = m_ledge
	mi.position = Vector3(cx, h * 0.5, cz)
	add_child(mi)
	var a := Vector3(-sx * 0.5, -h * 0.5, -sz * 0.5)
	var c := Vector3(sx * 0.5, h * 0.5, sz * 0.5)
	var pts := PackedVector3Array()
	for y in [a.y, c.y]:
		pts.append_array(PackedVector3Array([Vector3(a.x, y, a.z), Vector3(c.x, y, a.z), Vector3(c.x, y, a.z), Vector3(c.x, y, c.z),
			Vector3(c.x, y, c.z), Vector3(a.x, y, c.z), Vector3(a.x, y, c.z), Vector3(a.x, y, a.z)]))
	for xz in [Vector2(a.x, a.z), Vector2(c.x, a.z), Vector2(c.x, c.z), Vector2(a.x, c.z)]:
		pts.append_array(PackedVector3Array([Vector3(xz.x, a.y, xz.y), Vector3(xz.x, c.y, xz.y)]))
	add_lines(pts, mi.position, 0.0)

func add_ramp(cx: float, cz: float, rot: float, L: float, w: float, hh: float, kind: String = "curve", pw: float = 1.8) -> void:
	var r := Ramp.new()
	r.cx = cx
	r.cz = cz
	r.rot = rot
	r.L = L
	r.w = w
	r.H = hh
	r.quarter = (kind == "quarter")
	r.pw = pw
	r.c = cos(rot)
	r.s = sin(rot)
	ramps.append(r)
	var mi := MeshInstance3D.new()
	mi.mesh = ramp_mesh(r)
	mi.material_override = m_ramp
	mi.position = Vector3(cx, 0, cz)
	mi.rotation.y = rot
	add_child(mi)
	var pts := PackedVector3Array()
	var n := 22
	var hw := w * 0.5
	for i in range(n):
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var p0 := Vector3(-L * 0.5 + t0 * L, ramp_profile(r, t0), 0)
		var p1 := Vector3(-L * 0.5 + t1 * L, ramp_profile(r, t1), 0)
		for zz in [-hw, hw]:
			pts.append(Vector3(p0.x, p0.y, zz))
			pts.append(Vector3(p1.x, p1.y, zz))
	var hb := ramp_profile(r, 1.0)
	pts.append_array(PackedVector3Array([Vector3(L * 0.5, 0, -hw), Vector3(L * 0.5, hb, -hw), Vector3(L * 0.5, 0, hw), Vector3(L * 0.5, hb, hw),
		Vector3(L * 0.5, hb, -hw), Vector3(L * 0.5, hb, hw), Vector3(-L * 0.5, 0, -hw), Vector3(-L * 0.5, 0, hw)]))
	add_lines(pts, mi.position, rot)

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bc5d9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfdbe4")
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("9bc5d9")
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-14, 26, 10), Vector3.ZERO, Vector3.UP)
	cam = Camera3D.new()
	cam.far = 400.0
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()

func build_ground() -> void:
	var img := Image.create(256, 256, true, Image.FORMAT_RGBA8)
	img.fill(Color("7b858c"))
	for i in range(1600):
		var c := Color(1, 1, 1, 1) if randf() < 0.5 else Color(0.3, 0.33, 0.36, 1)
		var base := Color("7b858c")
		var col := base.lerp(c, 0.12)
		var x := randi() % 255
		var y := randi() % 255
		img.set_pixel(x, y, col)
		img.set_pixel(x + 1, y, col)
		img.set_pixel(x, y + 1, col)
		img.set_pixel(x + 1, y + 1, col)
	var line := Color("5c666d")
	img.fill_rect(Rect2i(0, 0, 256, 3), line)
	img.fill_rect(Rect2i(0, 253, 256, 3), line)
	img.fill_rect(Rect2i(0, 0, 3, 256), line)
	img.fill_rect(Rect2i(253, 0, 3, 256), line)
	var thin := Color("6c777e")
	img.fill_rect(Rect2i(128, 0, 1, 256), thin)
	img.fill_rect(Rect2i(0, 128, 256, 1), thin)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = tex
	gm.uv1_scale = Vector3(60, 60, 1)
	gm.roughness = 0.9
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	var fl := MeshInstance3D.new()
	fl.mesh = pm
	fl.material_override = gm
	add_child(fl)
	# дальние дома для ориентации
	var bms := [mat("55616b"), mat("6d7983"), mat("4a545c")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(26):
		var a := float(i) / 26.0 * TAU
		var r := 100.0 + rng.randf() * 14.0
		var hh := 8.0 + rng.randf() * 22.0
		var ww := 8.0 + rng.randf() * 10.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ww, hh, ww)
		mi.mesh = bm
		mi.material_override = bms[i % 3]
		mi.position = Vector3(cos(a) * r, hh * 0.5, sin(a) * r)
		add_child(mi)

func build_park() -> void:
	m_ledge = mat("9aa3a9")
	m_ramp = mat("8d979e")
	m_edge = StandardMaterial3D.new()
	m_edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_edge.albedo_color = Color("2b3238")
	add_box(-9, -5, 2.6, 3, 0.35)
	add_box(-9, -10, 2.6, 3, 0.6)
	add_box(-9, -15, 2.6, 3, 0.9)
	add_box(6, -8, 2.2, 16, 0.28)
	add_ramp(0, -16, PI / 2, 4.5, 4, 1.3)
	add_ramp(0, -28, PI / 2, 5, 5, 1.1, "curve", 1.4)
	add_box(0, -34.5, 5, 8, 1.1)
	add_ramp(0, -41, -PI / 2, 5, 5, 1.1, "curve", 1.4)
	add_ramp(12, -8, 0, 4.2, 6, 2.2, "quarter")
	add_box(16.5, -8, 4.8, 6, 2.2)
	add_ramp(-16, -30, PI / 2, 4, 3, 1.0)
	add_ramp(-18, -24, -PI / 2, 4, 3, 1.0)
	add_box(20, -30, 4, 4, 0.45)
	add_box(20, -36, 4, 4, 0.75)


# =====================================================================
# БАЙК И РАЙДЕР
# =====================================================================
func make_seg(parent: Node3D, r: float, material: Material, rad: int = 8) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = rad
	cm.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = cm
	m.material_override = material
	parent.add_child(m)
	return m

func place_seg(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.00001:
		m.visible = false
		return
	m.visible = true
	d = d / l
	var q := Quaternion(Vector3(0, 1, 0), d)
	m.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1.0, l, 1.0)), (a + b) * 0.5)

func tube(parent: Node3D, a: Vector3, b: Vector3, r: float, material: Material) -> MeshInstance3D:
	var m := make_seg(parent, r, material)
	place_seg(m, a, b)
	return m

func make_sphere(parent: Node3D, r: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	var m := MeshInstance3D.new()
	m.mesh = sm
	m.material_override = material
	m.position = pos
	parent.add_child(m)
	return m

func make_box(parent: Node3D, size: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var m := MeshInstance3D.new()
	m.mesh = bm
	m.material_override = material
	m.position = pos
	parent.add_child(m)
	return m

func make_wheel(parent: Node3D, x: float, y: float) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(x, y, 0)
	parent.add_child(g)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.36
	tm.rings = 30
	tm.ring_segments = 10
	var tire := MeshInstance3D.new()
	tire.mesh = tm
	tire.material_override = m_rubber
	tire.rotation.x = PI / 2.0
	g.add_child(tire)
	var rm := TorusMesh.new()
	rm.inner_radius = 0.288
	rm.outer_radius = 0.312
	rm.rings = 26
	rm.ring_segments = 6
	var rim := MeshInstance3D.new()
	rim.mesh = rm
	rim.material_override = m_metal
	rim.rotation.x = PI / 2.0
	g.add_child(rim)
	make_sphere(g, 0.05, m_metal)
	for i in range(4):
		var a := float(i) * PI / 4.0
		tube(g, Vector3(cos(a) * 0.3, sin(a) * 0.3, 0), Vector3(-cos(a) * 0.3, -sin(a) * 0.3, 0), 0.007, m_metal)
	return g

func build_bike() -> void:
	m_red = mat("e64a37", 0.45)
	m_dark = mat("20262b", 0.6)
	m_rubber = mat("111315", 0.9)
	m_metal = mat("c2c9cf", 0.3, 0.6)
	m_jersey = mat("2a5bd7", 0.8)
	m_pants = mat("23262e", 0.85)
	m_skin = mat("d8a47c", 0.8)
	m_shoe = mat("f0f0f0", 0.8)
	m_visor = mat("111820", 0.2, 0.3)
	root = Node3D.new()
	add_child(root)
	body = Node3D.new()
	root.add_child(body)
	rear_w = make_wheel(body, -0.78, 0.36)
	var BB := Vector3(0.05, 0.34, 0)
	var ST := Vector3(-0.42, 0.82, 0)
	var HT := Vector3(0.52, 0.8, 0)
	var HB := Vector3(0.5, 0.62, 0)
	var RA := Vector3(-0.78, 0.36, 0)
	for z in [-0.05, 0.05]:
		var o := Vector3(0, 0, z)
		tube(body, ST + o, HT + o, 0.03, m_red)
		tube(body, BB + o, HB + o, 0.034, m_red)
		tube(body, ST + o, RA + o, 0.022, m_red)
		tube(body, BB + o, RA + o, 0.024, m_red)
	tube(body, ST, BB, 0.032, m_red)
	tube(body, HB, HT, 0.04, m_red)
	tube(body, ST, Vector3(-0.42, 1.0, 0), 0.03, m_metal)
	make_box(body, Vector3(0.3, 0.06, 0.12), m_dark, Vector3(-0.42, 1.03, 0))
	fork = Node3D.new()
	fork.position = Vector3(0.55, 0, 0)
	body.add_child(fork)
	front_w = make_wheel(fork, 0.27, 0.36)
	for z in [-0.07, 0.07]:
		tube(fork, Vector3(0, 0.86, z), Vector3(0.27, 0.36, z), 0.022, m_metal)
	tube(fork, Vector3(0, 0.78, 0), Vector3(0.03, 1.02, 0), 0.04, m_dark)
	bar_g = Node3D.new()
	bar_g.position = Vector3(0.03, 1.02, 0)
	fork.add_child(bar_g)
	tube(bar_g, Vector3(0, 0, -0.1), Vector3(0, 0.18, -0.32), 0.02, m_dark)
	tube(bar_g, Vector3(0, 0, 0.1), Vector3(0, 0.18, 0.32), 0.02, m_dark)
	tube(bar_g, Vector3(0, 0.18, -0.36), Vector3(0, 0.18, 0.36), 0.022, m_dark)
	tube(bar_g, Vector3(0, 0.18, -0.43), Vector3(0, 0.18, -0.3), 0.034, m_rubber)
	tube(bar_g, Vector3(0, 0.18, 0.3), Vector3(0, 0.18, 0.43), 0.034, m_rubber)
	crank_l = make_seg(body, 0.022, m_metal)
	crank_r = make_seg(body, 0.022, m_metal)
	pedal_l_m = make_box(body, Vector3(0.13, 0.035, 0.1), m_dark)
	pedal_r_m = make_box(body, Vector3(0.13, 0.035, 0.1), m_dark)
	tube(body, Vector3(0.05, 0.34, -0.2), Vector3(0.05, 0.34, 0.2), 0.03, m_metal)
	# райдер
	pelvis = make_sphere(body, 0.17, m_pants)
	chest = make_sphere(body, 0.19, m_jersey)
	torso = make_seg(body, 0.165, m_jersey, 10)
	th_l = make_seg(body, 0.075, m_pants)
	th_r = make_seg(body, 0.075, m_pants)
	sh_l = make_seg(body, 0.06, m_pants)
	sh_r = make_seg(body, 0.06, m_pants)
	ua_l = make_seg(body, 0.05, m_jersey)
	ua_r = make_seg(body, 0.05, m_jersey)
	fa_l = make_seg(body, 0.043, m_skin)
	fa_r = make_seg(body, 0.043, m_skin)
	knee_l = make_sphere(body, 0.075, m_pants)
	knee_r = make_sphere(body, 0.075, m_pants)
	hand_l = make_sphere(body, 0.05, m_dark)
	hand_r = make_sphere(body, 0.05, m_dark)
	foot_l = make_box(body, Vector3(0.26, 0.1, 0.11), m_shoe)
	foot_r = make_box(body, Vector3(0.26, 0.1, 0.11), m_shoe)
	head_g = Node3D.new()
	body.add_child(head_g)
	make_sphere(head_g, 0.125, m_skin)
	var hm := SphereMesh.new()
	hm.radius = 0.145
	hm.height = 0.145
	hm.is_hemisphere = true
	hm.radial_segments = 16
	hm.rings = 6
	var helmet := MeshInstance3D.new()
	helmet.mesh = hm
	helmet.material_override = m_red
	helmet.position = Vector3(0, 0.035, 0)
	head_g.add_child(helmet)
	make_box(head_g, Vector3(0.09, 0.06, 0.2), m_visor, Vector3(0.115, 0.03, 0))

func ik2(A: Vector3, T: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := T - A
	var dist := maxf(d.length(), 0.05)
	d = d / dist
	var maxd := l1 + l2 - 0.002
	if dist > maxd:
		dist = maxd
	var E := A + d * dist
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var p := pole - d * pole.dot(d)
	if p.length_squared() < 0.000001:
		p = Vector3(0, 0, 1)
	p = p.normalized()
	var J := A + d * a + p * h
	return [J, E]


# =====================================================================
# ОЧКИ
# =====================================================================
func show_toast(text: String, good: bool) -> void:
	toast_text = text
	toast_good = good
	toast_t = 1.5

func add_trick(trick_name: String, pts: float) -> void:
	combo_items.append(trick_name)
	combo_pts += pts
	combo_idle = 0.0

func combo_mult() -> float:
	var u := {}
	for it in combo_items:
		u[it] = true
	return 1.0 + 0.25 * float(u.size() - 1)

func reset_combo() -> void:
	combo_items = []
	combo_pts = 0.0
	combo_idle = 0.0
	has_manual = false
	has_nose = false

func bank_combo() -> void:
	if combo_items.is_empty():
		return
	var total := int(roundf(combo_pts * combo_mult()))
	score += total
	show_toast("+%d · %s" % [total, " + ".join(PackedStringArray(combo_items))], true)
	reset_combo()

func spin_name(n: int) -> String:
	var d := n * 180
	if d == 360:
		return "360 · треха"
	return str(d)

func spin_pts(n: int) -> float:
	var arr := [0.0, 150.0, 400.0, 800.0, 1400.0, 2200.0, 3200.0]
	var v: float = arr[mini(n, 6)]
	return v * (2.0 if n > 6 else 1.0)


# =====================================================================
# ФИЗИКА
# =====================================================================
func bail(msg: String) -> void:
	if mode == BAIL:
		return
	if mode == GROUND:
		var f := dir_of(yaw)
		var sl := slope_along(px, pz, yaw)
		var ca := 1.0 / sqrt(1.0 + sl * sl)
		wvx = f.x * spd * ca
		wvz = f.y * spd * ca
		vy = maxf(vy_g, 0.0)
	mode = BAIL
	bail_t = 0.0
	tum_dir = -1.0 if randf() < 0.5 else 1.0
	tumble = 0.0
	th = 0.0
	om = 0.0
	nose_acc = 0.0
	hop_armed = false
	hop_push = 0.0
	show_toast("БЕЙЛ · " + msg, false)
	reset_combo()

func respawn(full: bool) -> void:
	var x0 := SPAWN_X
	var z0 := SPAWN_Z
	var b0 := SPAWN_B
	if not full:
		x0 = safe_x
		z0 = safe_z
		b0 = safe_b
	px = x0
	pz = z0
	yaw = b0
	py = terrain_h(x0, z0)
	spd = 0.0
	vy = 0.0
	wvx = 0.0
	wvz = 0.0
	mode = GROUND
	th = 0.0
	om = 0.0
	pitch = 0.0
	pitch_w = 0.0
	gp = 0.0
	roll = 0.0
	vy_g = 0.0
	ws = 0.0
	spin_w = 0.0
	spin_acc = 0.0
	nose_acc = 0.0
	air_t = 0.0
	tumble = 0.0
	bar_angle = 0.0
	bar_rem = 0.0
	if full:
		safe_x = SPAWN_X
		safe_z = SPAWN_Z
		safe_b = SPAWN_B
		reset_combo()
	hop_armed = false
	hop_peak = 0.0
	hop_push = 0.0
	cam_yaw = b0
	cam_pos = Vector3(x0 - cos(b0) * 5.0, 3.0, z0 + sin(b0) * 5.0)

func start_air(nx: float, nz: float, y: float) -> void:
	mode = AIR
	px = nx
	pz = nz
	py = y
	air_t = 0.0
	hop_t = 999.0
	spin_acc = 0.0
	take_y = y
	bar_count = 0
	bar_cool = 0.0
	var vh := Vector2(wvx, wvz).length()
	mair = atan2(-wvz, wvx) if vh > 0.5 else yaw
	spin_w = -in_rx * 5.5 if absf(in_rx) > 0.3 else 0.0
	nose_acc = 0.0
	pitch = gp + th
	pitch_w = 0.0
	noh_t = 0.0
	oneh_t = 0.0
	om = 0.0

func pop_hop(power: float) -> void:
	var f := dir_of(yaw)
	var sl := slope_along(px, pz, yaw)
	var ca := 1.0 / sqrt(1.0 + sl * sl)
	# толчок ногами: накопленный заряд от нажатий L/R добавляет скорость прыжка
	var boost := clampf(hop_push / PUSH_MAX, 0.0, 1.0) * PUSH_BOOST
	vy = 2.5 + 2.4 * power + boost + maxf(vy_g, 0.0) * 0.5
	wvx = f.x * spd * ca
	wvz = f.y * spd * ca
	start_air(px, pz, py + 0.001)
	pitch = gp + th * 0.8
	pitch_w = 0.0
	hop_t = 0.0
	th = 0.0
	om = 0.0
	rig_crouch = -0.4 - 0.25 * (boost / PUSH_BOOST)
	hop_push = 0.0
	if boost > 0.35:
		show_toast("Толчок ногами!", true)

func land_now(nx: float, nz: float, hN: float) -> void:
	px = nx
	pz = nz
	py = hN
	var f := dir_of(yaw)
	var sl := slope_along(nx, nz, yaw)
	var ca := 1.0 / sqrt(1.0 + sl * sl)
	var gpn := atan(sl)
	var v_along := wvx * f.x + wvz * f.y
	var vh := Vector2(wvx, wvz).length()
	var m := atan2(-wvz, wvx)
	var e_face := absf(wrap_half(yaw - m))
	var err := pitch - gpn
	var vn := (-sl * v_along + vy) / sqrt(1.0 + sl * sl)
	var impact := maxf(0.0, -vn)
	var why := ""
	var hands_off := (1 if hand_l_off else 0) + (1 if hand_r_off else 0)
	if vh > 1.5 and e_face > 0.7:
		why = "боком"
	elif err < -1.05:
		why = "через руль"
	elif err > 1.05:
		why = "назад через заднее"
	elif impact > 13.5:
		why = "слишком жёстко"
	if why == "" and hands_off == 2:
		why = "без рук"
	if why != "":
		py = hN
		bail("приземление " + why)
		return
	mode = GROUND
	spd = v_along / ca * (1.0 - 0.25 * sin(minf(e_face, 1.2)))
	if hands_off == 1:
		spd *= 0.7
	th = clampf(err, -1.1, 1.0) if absf(err) > 0.12 else 0.0
	om = 0.0
	gp = gpn
	pitch = gpn + th
	vy_g = 0.0
	vy = 0.0
	ws = spd
	rig_crouch = clampf(impact / 9.0, 0.0, 1.0) * 0.9
	var air := air_t
	var n := int(roundf(absf(spin_acc) / PI))
	if air > 0.25:
		if n >= 1:
			add_trick(spin_name(n), spin_pts(n))
		if bar_count > 0:
			add_trick("Барспин ×%d" % bar_count if bar_count > 1 else "Барспин", 100.0 * bar_count)
		if air > 0.8:
			add_trick("Эйр %.1fс" % air, roundf(air * 60.0))
		if hN - take_y > 0.3:
			add_trick("На препятствие", 80.0)
		if noh_t > 0.35:
			add_trick("Ноу-хэндер", roundf(120.0 * noh_t))
		elif oneh_t > 0.35:
			add_trick("Ван-хэндер", roundf(70.0 * oneh_t))
	noh_t = 0.0
	oneh_t = 0.0
	if not combo_items.is_empty():
		combo_idle = 0.0
	bar_angle = 0.0
	bar_rem = 0.0

func ground_step(dt: float) -> void:
	var f := dir_of(yaw)
	var sl := slope_along(px, pz, yaw)
	var ca := 1.0 / sqrt(1.0 + sl * sl)
	var sa := sl * ca
	spd -= G * sa * dt
	var ly := in_ly
	# банихоп: потянул назад, затем резко вперёд
	if ly < -0.55:
		hop_since = 0.0
		hop_armed = true
	else:
		hop_since += dt
		if hop_since > 0.45:
			hop_armed = false
			hop_peak = 0.0
	if hop_armed:
		hop_peak = maxf(hop_peak, th)
		# толчок ногами: нажатия педалей при отведённом весе копят заряд
		hop_push = minf(hop_push + pedal_tap, PUSH_MAX)
		hop_push = maxf(0.0, hop_push - PUSH_DECAY * dt)
	else:
		hop_push = 0.0
	pedal_tap = 0.0
	if kb_hop:
		kb_hop = false
		pop_hop(0.55)
		return
	if hop_armed and ly > 0.35 and hop_since < 0.45 and th < 0.95:
		var power := clampf(0.25 + hop_peak / 0.6 * 0.75, 0.25, 1.0)
		hop_armed = false
		hop_peak = 0.0
		pop_hop(power)
		return
	# мануал как балансировка перевёрнутого маятника
	var lean := -ly
	var BAL := 0.55
	var K := 7.0 * (0.5 if assist_bal else 1.0)
	var sgn := 0.0
	if absf(th) > 0.0001:
		sgn = signf(th)
	elif lean > 0.0:
		sgn = 1.0
	elif lean < 0.0:
		sgn = -1.0
	if sgn == 0.0:
		th = 0.0
		om = 0.0
	else:
		var acc := K * (th - sgn * BAL) + 13.0 * lean - 1.8 * om
		if absf(th) <= 0.0001 and sgn * acc <= 0.0:
			th = 0.0
			om = 0.0
		else:
			om += acc * dt
			var nt := th + om * dt
			if nt * sgn < 0.0:
				th = 0.0
				om = 0.0
			else:
				th = nt
	if th > 1.3:
		bail("мануал: перевернулся назад")
		return
	if th < -1.2:
		bail("перелетел через руль")
		return
	# разгон: поочерёдные нажатия L/R; обе вместе — тормоз
	if absf(th) < 0.4 and pedal_kick > 0.0:
		var room := (1.0 - clampf(spd / MAXS, 0.0, 1.0)) if spd >= 0.0 else 1.0
		spd += pedal_kick * room
	pedal_kick = 0.0
	if (pedal_both_t > 0.25 or brake_held) and not hop_armed:
		var br := 9.0 * dt
		spd = maxf(0.0, spd - br) if spd > 0.0 else minf(0.0, spd + br)
	var drag := (0.3 + 0.008 * spd * spd) * dt
	spd = maxf(0.0, spd - drag) if spd > 0.0 else minf(0.0, spd + drag)
	spd = clampf(spd, -8.0, MAXS)
	# руление: кинематическая модель велосипеда (колёсная база, угол руля)
	var hand_k := 1.0
	if hand_l_off and hand_r_off:
		hand_k = 0.15
	elif hand_l_off or hand_r_off:
		hand_k = 0.55
	var slow := 0.6 if absf(th) > 0.1 else 1.0
	steer_ang = -in_lx * 0.75 / (1.0 + absf(spd) * 0.14) * hand_k
	var yaw_rate := spd * tan(steer_ang) / WHEELBASE * slow
	yaw += yaw_rate * dt
	# ноуз-пивот
	if th < -0.25:
		spin_w = clampf(spin_w + (-in_rx * 19.0 - spin_w * 2.0) * dt, -11.0, 11.0)
		var dB := spin_w * dt
		if dB != 0.0:
			var cx := px + f.x * 0.82
			var cz := pz + f.y * 0.82
			yaw += dB
			nose_acc += dB
			var f2 := dir_of(yaw)
			px = cx - f2.x * 0.82
			pz = cz - f2.y * 0.82
		spd *= exp(-0.9 * dt)
	else:
		spin_w = 0.0
	if th > -0.12 and nose_acc != 0.0:
		var nn := int(roundf(absf(nose_acc) / PI))
		if nn >= 1:
			add_trick("Ноуз-пивот %d" % (nn * 180), roundf(spin_pts(nn) * 0.8))
		nose_acc = 0.0
	f = dir_of(yaw)
	# движение
	var step_h := spd * ca * dt
	var nx := px + f.x * step_h
	var nz := pz + f.y * step_h
	var hN := terrain_h(nx, nz)
	if hN > py + 0.38:
		if absf(spd) > 8.0:
			bail("врезался в препятствие")
			return
		spd = -spd * 0.3 if absf(spd) > 1.5 else 0.0
		vy_g = 0.0
		return
	var y_free := py + maxf(vy_g, 0.0) * dt - 0.5 * G * dt * dt
	if hN < y_free - 0.012 and (vy_g > 0.6 or py - hN > 0.15):
		wvx = f.x * spd * ca
		wvz = f.y * spd * ca
		vy = vy_g if vy_g > 0.6 else minf(vy_g, 0.0)
		start_air(nx, nz, maxf(hN, y_free))
		return
	vy_g = damp(vy_g, (hN - py) / dt, 60.0, dt)
	px = nx
	pz = nz
	py = hN
	if absf(px) > LIM:
		px = clampf(px, -LIM, LIM)
		spd *= -0.3
	if absf(pz) > LIM:
		pz = clampf(pz, -LIM, LIM)
		spd *= -0.3
	gp = damp(gp, atan(sl), 25.0, dt)
	pitch = gp + th
	ws = spd
	roll = damp(roll, clampf(-atan(spd * yaw_rate / G), -0.6, 0.6), 8.0, dt)
	safe_t += dt
	if safe_t > 0.7 and absf(sl) < 0.12 and absf(th) < 0.05 and absf(spd) > 0.3:
		safe_x = px
		safe_z = pz
		safe_b = yaw
		safe_t = 0.0

func air_step(dt: float) -> void:
	air_t += dt
	if hand_l_off and hand_r_off:
		noh_t += dt
	elif hand_l_off or hand_r_off:
		oneh_t += dt
	hop_t += dt
	vy -= G * dt
	var a := -in_rx * 19.0 - spin_w * 1.6
	var hh := py - terrain_h(px, pz)
	if assist_land and vy < 0.0:
		var w := clampf((1.5 - hh) / 1.0, 0.0, 1.0) * (1.0 - 0.85 * absf(in_rx))
		if w > 0.0:
			var e := wrap_half(yaw - mair)
			a += w * (-e * 40.0 - spin_w * 7.0)
	spin_w = clampf(spin_w + a * dt, -13.0, 13.0)
	var dB := spin_w * dt
	yaw += dB
	spin_acc += dB
	# барспин
	bar_cool -= dt
	if bar_rem <= 0.0 and bar_cool <= 0.0 and absf(in_ry) > 0.8:
		bar_rem = TAU
		bar_dir = 1.0 if in_ry > 0.0 else -1.0
	if bar_rem > 0.0:
		var d := minf(bar_rem, 18.0 * dt)
		bar_angle += d * bar_dir
		bar_rem -= d
		if bar_rem <= 0.0:
			bar_count += 1
			bar_cool = 0.25
			bar_angle = 0.0
	# тангаж
	var vh := Vector2(wvx, wvz).length()
	var traj := atan2(vy, maxf(vh, 2.0))
	var kick_t := 0.35 * (1.0 - hop_t / 0.22) if hop_t < 0.22 else 0.0
	var tgt := clampf(traj, -0.9, 0.9) * 0.45 + (-in_ly) * 0.75 + kick_t
	if assist_land and vy < 0.0:
		var w2 := clampf((0.9 - hh) / 0.6, 0.0, 1.0) * 0.7 * (1.0 - absf(in_ly) * 0.8)
		if w2 > 0.0:
			tgt = tgt + (atan(slope_along(px, pz, yaw)) + 0.04 - tgt) * w2
	pitch_w += (28.0 * (tgt - pitch) - 8.0 * pitch_w) * dt
	pitch += pitch_w * dt
	roll = damp(roll, in_lx * 0.45, 6.0, dt)
	ws *= exp(-0.2 * dt)
	# перемещение
	var nx := px + wvx * dt
	var nz := pz + wvz * dt
	var ny := py + vy * dt
	var hN := terrain_h(nx, nz)
	if hN > ny + 0.38:
		var sp := Vector2(wvx, wvz).length()
		wvx *= -0.2
		wvz *= -0.2
		nx = px
		nz = pz
		hN = terrain_h(nx, nz)
		if sp > 8.0:
			py = ny
			bail("врезался в воздухе")
			return
		mair = atan2(-wvz, wvx)
	if absf(nx) > LIM:
		nx = clampf(nx, -LIM, LIM)
		wvx *= -0.3
	if absf(nz) > LIM:
		nz = clampf(nz, -LIM, LIM)
		wvz *= -0.3
	if ny <= hN:
		land_now(nx, nz, hN)
		return
	px = nx
	pz = nz
	py = ny

func bail_step(dt: float) -> void:
	bail_t += dt
	vy -= G * dt
	px += wvx * dt
	pz += wvz * dt
	py += vy * dt
	var h := terrain_h(px, pz)
	if py <= h:
		py = h
		vy = 0.0
		var k := exp(-3.5 * dt)
		wvx *= k
		wvz *= k
	px = clampf(px, -LIM, LIM)
	pz = clampf(pz, -LIM, LIM)
	tumble = damp(tumble, 1.45, 5.0, dt)
	pitch = damp(pitch, 0.0, 4.0, dt)
	ws *= exp(-2.0 * dt)
	if bail_t > 1.7:
		respawn(false)

func physics(dt: float) -> void:
	if mode != GROUND:
		pedal_kick = 0.0
		pedal_tap = 0.0
	if mode == BAIL:
		bail_step(dt)
	elif mode == GROUND:
		ground_step(dt)
	else:
		air_step(dt)

func update_gameplay(dt: float) -> void:
	if mode == GROUND:
		if th > 0.25:
			if not has_manual:
				has_manual = true
				combo_items.append("Мануал")
			combo_pts += 90.0 * dt
			combo_idle = 0.0
		elif th < -0.25:
			if not has_nose:
				has_nose = true
				combo_items.append("Ноуз-мануал")
			combo_pts += 110.0 * dt
			combo_idle = 0.0
		elif not combo_items.is_empty():
			combo_idle += dt
			if combo_idle > 1.4:
				bank_combo()


# =====================================================================
# ПОЗА, КАМЕРА
# =====================================================================
func pose_visuals(dt: float) -> void:
	root.position = Vector3(px, py, pz)
	root.rotation = Vector3(0, yaw, 0)
	var rl := tumble * tum_dir if mode == BAIL else roll
	body.basis = Basis(Vector3(0, 0, 1), pitch) * Basis(Vector3(1, 0, 0), rl)
	var m := clampf(absf(th) / 0.1, 0.0, 1.0) if mode == GROUND else 0.0
	var cv := C_VEC_F if th < 0.0 else C_VEC
	if m > 0.0:
		var qg := Basis(Vector3(0, 0, 1), gp)
		body.position = ((qg * cv) - (body.basis * cv)) * m
	else:
		body.position = Vector3.ZERO
	# колёса, педали
	wheel_a -= ws * dt / 0.36
	rear_w.rotation.z = wheel_a
	front_w.rotation.z = wheel_a
	crank += ws * dt * 0.9
	# руль
	var steer_t := steer_ang if mode == GROUND else (-in_lx * 0.15)
	rig_steer = damp(rig_steer, steer_t, 14.0, dt)
	fork.rotation.y = rig_steer
	bar_g.rotation.y = bar_angle
	var cr := 0.17
	var cs := cos(crank)
	var sn := sin(crank)
	var pR := Vector3(0.05 + cr * cs, 0.34 + cr * sn, 0.22)
	var pL := Vector3(0.05 - cr * cs, 0.34 - cr * sn, -0.22)
	place_seg(crank_r, Vector3(0.05, 0.34, 0.2), pR)
	place_seg(crank_l, Vector3(0.05, 0.34, -0.2), pL)
	pedal_r_m.position = pR
	pedal_l_m.position = pL
	# райдер
	rig_ly = damp(rig_ly, in_ly, 14.0, dt)
	rig_head = damp(rig_head, -in_rx * 1.15, 14.0, dt)
	rig_tors = damp(rig_tors, -in_rx * 0.6, 9.0, dt)
	var cr_t := 0.0
	if hop_armed and mode == GROUND:
		cr_t = 0.45 + 0.25 * clampf(hop_push / PUSH_MAX, 0.0, 1.0)
	rig_crouch = damp(rig_crouch, cr_t, 10.0, dt)
	var hx := -0.10 + rig_ly * 0.2
	var hy := 0.98 - rig_crouch * 0.24
	var ta := 0.55 + rig_ly * 0.5 + rig_crouch * 0.25
	var hip_l := Vector3(hx, hy, -0.1)
	var hip_r := Vector3(hx, hy, 0.1)
	var sp := Vector3(hx + 0.62 * sin(ta), hy + 0.62 * cos(ta), 0)
	pelvis.position = Vector3(hx, hy, 0)
	chest.position = sp
	place_seg(torso, pelvis.position, sp)
	var off := Vector3(sin(rig_tors) * 0.2, 0, cos(rig_tors) * 0.2)
	var sho_r := sp + off
	var sho_l := sp - off
	head_g.position = Vector3(sp.x + sin(ta) * 0.16 + 0.05, sp.y + 0.27, 0)
	head_g.rotation.y = rig_head
	# ноги
	var res: Array = ik2(hip_r, Vector3(pR.x + 0.02, pR.y + 0.075, pR.z), 0.5, 0.5, POLE_LEG)
	var tj: Vector3 = res[0]
	var te: Vector3 = res[1]
	knee_r.position = tj
	place_seg(th_r, hip_r, tj)
	place_seg(sh_r, tj, te)
	foot_r.position = Vector3(te.x + 0.03, te.y - 0.02, te.z)
	res = ik2(hip_l, Vector3(pL.x + 0.02, pL.y + 0.075, pL.z), 0.5, 0.5, POLE_LEG)
	tj = res[0]
	te = res[1]
	knee_l.position = tj
	place_seg(th_l, hip_l, tj)
	place_seg(sh_l, tj, te)
	foot_l.position = Vector3(te.x + 0.03, te.y - 0.02, te.z)
	# руки к рулю
	hl_amt = damp(hl_amt, 1.0 if hand_l_off else 0.0, 14.0, dt)
	hr_amt = damp(hr_amt, 1.0 if hand_r_off else 0.0, 14.0, dt)
	var sa := rig_steer
	var cs2 := cos(sa)
	var sn2 := sin(sa)
	for si in range(2):
		var side := 1.0 if si == 0 else -1.0
		var lx := 0.03
		var lz := 0.36 * side
		var gx := 0.55 + lx * cs2 + lz * sn2
		var gz := -lx * sn2 + lz * cs2
		var shoulder := sho_r if si == 0 else sho_l
		var pole := POLE_ARM_R if si == 0 else POLE_ARM_L
		var amt: float = hr_amt if si == 0 else hl_amt
		var tgt3 := Vector3(gx - 0.12 * amt, 1.2 + 0.42 * amt, gz * (1.0 + 0.9 * amt))
		res = ik2(shoulder, tgt3, 0.4, 0.4, pole)
		tj = res[0]
		te = res[1]
		if si == 0:
			place_seg(ua_r, shoulder, tj)
			place_seg(fa_r, tj, te)
			hand_r.position = te
		else:
			place_seg(ua_l, shoulder, tj)
			place_seg(fa_l, tj, te)
			hand_l.position = te

func update_camera(dt: float) -> void:
	var vx := wvx
	var vz := wvz
	if mode == GROUND:
		var f := dir_of(yaw)
		vx = f.x * spd
		vz = f.y * spd
	var sp := Vector2(vx, vz).length()
	var tgt := cam_yaw
	if sp > 1.5:
		tgt = atan2(-vz, vx)
	elif mode == GROUND:
		tgt = yaw
	cam_yaw += wrapf(tgt - cam_yaw, -PI, PI) * (1.0 - exp(-3.2 * dt))
	var dist := 5.2 + sp * 0.07
	var cx := cos(cam_yaw)
	var cz := -sin(cam_yaw)
	var want_x := px - cx * dist
	var want_z := pz - cz * dist
	var want_y := 2.1 + py * 0.65
	var k := 1.0 - exp(-8.0 * dt)
	cam_pos.x += (want_x - cam_pos.x) * k
	cam_pos.z += (want_z - cam_pos.z) * k
	cam_pos.y += (want_y - cam_pos.y) * (1.0 - exp(-5.0 * dt))
	cam_look = Vector3(px + cx * 2.0, py * 0.8 + 1.1, pz + cz * 2.0)
	cam.look_at_from_position(cam_pos, cam_look, Vector3.UP)
	cam.fov = damp(cam.fov, 62.0 + minf(sp, 13.0) * 1.3, 3.0, dt)


# =====================================================================
# ВИРТУАЛЬНЫЕ КНОПКИ (раскладка как в эмуляторе PSP) И ВВОД
# =====================================================================
const HIT_ORDER := ["L", "R", "cross", "circle", "square", "triangle", "start", "select", "dpad", "stick", "stick2"]
const KEY_RU := {
	"L": "L — левая нога",
	"R": "R — правая нога",
	"dpad": "крестовина (руль и вес)",
	"stick": "левый стик (руль и вес)",
	"stick2": "правый стик (голова, барспин)",
	"cross": "Крест — хоп",
	"circle": "Круг — правая рука",
	"square": "Квадрат — левая рука",
	"triangle": "Треугольник — тормоз",
	"start": "Start — меню",
	"select": "Select — сброс",
}

func add_ctrl(key: String, kind: String, pos: Vector2, caption: String) -> void:
	ctrls[key] = {"kind": kind, "pos": pos, "dpos": pos, "scale": 1.0, "caption": caption,
		"down": false, "touch": -1, "off": Vector2.ZERO}

func default_layout() -> void:
	ctrls = {}
	add_ctrl("L", "rect", Vector2(0.085, 0.065), "нога Л")
	add_ctrl("R", "rect", Vector2(0.915, 0.065), "нога П")
	add_ctrl("dpad", "dpad", Vector2(0.12, 0.60), "")
	add_ctrl("stick", "stick", Vector2(0.25, 0.80), "руль · вес")
	add_ctrl("stick2", "stick", Vector2(0.75, 0.80), "голова · барспин")
	add_ctrl("triangle", "circle", Vector2(0.891, 0.492), "тормоз")
	add_ctrl("square", "circle", Vector2(0.839, 0.583), "лев. рука")
	add_ctrl("circle", "circle", Vector2(0.942, 0.583), "пр. рука")
	add_ctrl("cross", "circle", Vector2(0.891, 0.675), "хоп")
	add_ctrl("select", "rect", Vector2(0.44, 0.94), "")
	add_ctrl("start", "rect", Vector2(0.56, 0.94), "")

func reset_layout() -> void:
	for key in ctrls:
		var c: Dictionary = ctrls[key]
		c["pos"] = c["dpos"]
		c["scale"] = 1.0
	save_layout()

func load_layout() -> void:
	default_layout()
	var cf := ConfigFile.new()
	if cf.load("user://layout.cfg") != OK:
		return
	for key in ctrls:
		var c: Dictionary = ctrls[key]
		var p: Vector2 = c["pos"]
		p.x = cf.get_value("l", str(key) + "_x", p.x)
		p.y = cf.get_value("l", str(key) + "_y", p.y)
		c["pos"] = p
		c["scale"] = cf.get_value("l", str(key) + "_s", 1.0)

func save_layout() -> void:
	var cf := ConfigFile.new()
	for key in ctrls:
		var c: Dictionary = ctrls[key]
		var p: Vector2 = c["pos"]
		cf.set_value("l", str(key) + "_x", p.x)
		cf.set_value("l", str(key) + "_y", p.y)
		cf.set_value("l", str(key) + "_s", c["scale"])
	cf.save("user://layout.cfg")

func ctrl_center(key: String) -> Vector2:
	var c: Dictionary = ctrls[key]
	var p: Vector2 = c["pos"]
	return p * vp_size()

func ctrl_radius(key: String) -> float:
	var c: Dictionary = ctrls[key]
	var kind: String = c["kind"]
	var base := 40.0
	if kind == "dpad":
		base = 80.0
	elif kind == "stick":
		base = 62.0
	return base * float(c["scale"]) * ui_scale

func ctrl_halfsize(key: String) -> Vector2:
	var c: Dictionary = ctrls[key]
	var base := Vector2(40, 15)
	if key == "L" or key == "R":
		base = Vector2(70, 27)
	return base * float(c["scale"]) * ui_scale

func ctrl_hit(key: String, p: Vector2) -> bool:
	var c: Dictionary = ctrls[key]
	var kind: String = c["kind"]
	var cc := ctrl_center(key)
	if kind == "rect":
		var hs := ctrl_halfsize(key) + Vector2(8, 8)
		return absf(p.x - cc.x) <= hs.x and absf(p.y - cc.y) <= hs.y
	var r := ctrl_radius(key)
	if kind == "stick":
		r *= 1.25
	return p.distance_to(cc) <= r

func is_down(key: String) -> bool:
	var c: Dictionary = ctrls[key]
	return bool(c["down"])

func release_all() -> void:
	touch_role.clear()
	for key in ctrls:
		var c: Dictionary = ctrls[key]
		c["down"] = false
		c["touch"] = -1
		c["off"] = Vector2.ZERO
	stick_vec["stick"] = Vector2.ZERO
	stick_vec["stick2"] = Vector2.ZERO
	dpad_dir = Vector2.ZERO
	pedal_release("L")
	pedal_release("R")
	kb_hop = false

func toggle_menu() -> void:
	if edit_mode:
		return
	menu_open = not menu_open
	menu_panel.visible = menu_open
	if menu_open:
		release_all()

func enter_edit() -> void:
	edit_mode = true
	menu_open = false
	menu_panel.visible = false
	edit_bar.visible = true
	edit_sel = ""
	edit_drag = -1
	release_all()

func exit_edit() -> void:
	edit_mode = false
	edit_bar.visible = false
	edit_drag = -1
	menu_open = true
	menu_panel.visible = true
	save_layout()

func edit_scale(f: float) -> void:
	if edit_sel == "":
		return
	var c: Dictionary = ctrls[edit_sel]
	c["scale"] = clampf(float(c["scale"]) * f, 0.5, 2.5)
	save_layout()

func pedal_press(side: String) -> void:
	if pedal_down[side]:
		return
	pedal_down[side] = true
	var v := -1 if side == "L" else 1
	var val := 1.3 if v != pedal_last else 0.3
	pedal_kick += val
	pedal_tap += val
	pedal_last = v

func pedal_release(side: String) -> void:
	pedal_down[side] = false

func ctrl_press(key: String) -> void:
	match key:
		"L":
			pedal_press("L")
		"R":
			pedal_press("R")
		"cross":
			kb_hop = true
		"start":
			toggle_menu()
		"select":
			respawn(true)

func ctrl_release(key: String) -> void:
	var c: Dictionary = ctrls[key]
	c["touch"] = -1
	c["down"] = false
	c["off"] = Vector2.ZERO
	if key == "L":
		pedal_release("L")
	elif key == "R":
		pedal_release("R")
	elif key == "stick" or key == "stick2":
		stick_vec[key] = Vector2.ZERO
	elif key == "dpad":
		dpad_dir = Vector2.ZERO

func ctrl_update(key: String, p: Vector2) -> void:
	var c: Dictionary = ctrls[key]
	var kind: String = c["kind"]
	var cc := ctrl_center(key)
	if kind == "stick":
		var R := ctrl_radius(key)
		var d := p - cc
		if d.length() > R:
			d = d / d.length() * R
		c["off"] = d
		stick_vec[key] = deadzone(Vector2(d.x / R, -d.y / R))
	elif kind == "dpad":
		var r := ctrl_radius(key)
		var d2 := p - cc
		var v := Vector2.ZERO
		if d2.x > r * 0.28:
			v.x = 1.0
		elif d2.x < -r * 0.28:
			v.x = -1.0
		if -d2.y > r * 0.28:
			v.y = 1.0
		elif -d2.y < -r * 0.28:
			v.y = -1.0
		dpad_dir = v

func gui_blocks(p: Vector2) -> bool:
	if menu_panel.visible and menu_panel.get_global_rect().has_point(p):
		return true
	if edit_bar.visible and edit_bar.get_global_rect().has_point(p):
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			touch_down(t.index, t.position)
		else:
			touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		touch_move(d.index, d.position)

func touch_down(idx: int, p: Vector2) -> void:
	if gui_blocks(p):
		return
	if edit_mode:
		for key in HIT_ORDER:
			if ctrl_hit(key, p):
				edit_sel = key
				edit_drag = idx
				edit_off = ctrl_center(key) - p
				return
		return
	if menu_open:
		return
	for key in HIT_ORDER:
		if ctrl_hit(key, p):
			var c: Dictionary = ctrls[key]
			if int(c["touch"]) != -1:
				continue
			c["touch"] = idx
			c["down"] = true
			touch_role[idx] = key
			ctrl_press(key)
			ctrl_update(key, p)
			return

func touch_move(idx: int, p: Vector2) -> void:
	if edit_mode:
		if idx == edit_drag and edit_sel != "":
			var c: Dictionary = ctrls[edit_sel]
			var np := (p + edit_off) / vp_size()
			np.x = clampf(np.x, 0.03, 0.97)
			np.y = clampf(np.y, 0.04, 0.96)
			c["pos"] = np
		return
	var key: String = touch_role.get(idx, "")
	if key == "stick" or key == "stick2" or key == "dpad":
		ctrl_update(key, p)

func touch_up(idx: int) -> void:
	if edit_mode:
		if idx == edit_drag:
			edit_drag = -1
			save_layout()
		return
	var key: String = touch_role.get(idx, "")
	if key == "":
		return
	touch_role.erase(idx)
	ctrl_release(key)

func poll_input(dt: float) -> void:
	# клавиатура (физические клавиши — работают при любой раскладке)
	var paused := menu_open or edit_mode
	var q := Input.is_physical_key_pressed(KEY_Q)
	var e := Input.is_physical_key_pressed(KEY_E)
	if q and not kq:
		pedal_press("L")
	if not q and kq:
		pedal_release("L")
	if e and not ke:
		pedal_press("R")
	if not e and ke:
		pedal_release("R")
	kq = q
	ke = e
	var sp := Input.is_physical_key_pressed(KEY_SPACE)
	if sp and not kspace and not paused:
		kb_hop = true
	kspace = sp
	var rr := Input.is_physical_key_pressed(KEY_R)
	if rr and not kr and not paused:
		respawn(true)
	kr = rr
	var esc := Input.is_physical_key_pressed(KEY_ESCAPE)
	if esc and not kesc:
		toggle_menu()
	kesc = esc
	var kzv := Input.is_physical_key_pressed(KEY_Z)
	var kxv := Input.is_physical_key_pressed(KEY_X)
	var kcv := Input.is_physical_key_pressed(KEY_C)
	pedal_both_t = (pedal_both_t + dt) if (pedal_down["L"] and pedal_down["R"]) else 0.0
	var tx := 0.0
	var ty := 0.0
	var tcx := 0.0
	var tcy := 0.0
	if Input.is_physical_key_pressed(KEY_D):
		tx += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		tx -= 1.0
	if Input.is_physical_key_pressed(KEY_W):
		ty += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		ty -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		tcx += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		tcx -= 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		tcy += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		tcy -= 1.0
	kb_lx = damp(kb_lx, tx, 16.0, dt)
	kb_ly = damp(kb_ly, ty, 16.0, dt)
	kb_rx = damp(kb_rx, tcx, 16.0, dt)
	kb_ry = damp(kb_ry, tcy, 16.0, dt)
	dpad_dig.x = damp(dpad_dig.x, dpad_dir.x, 16.0, dt)
	dpad_dig.y = damp(dpad_dig.y, dpad_dir.y, 16.0, dt)
	# геймпад: A — хоп, X/B — руки, Y — тормоз, Start — меню, Back — сброс
	var pl := Vector2.ZERO
	var pr := Vector2.ZERO
	var pxh := false
	var pbh := false
	var pyh := false
	var pads := Input.get_connected_joypads()
	if pads.size() > 0:
		var j: int = pads[0]
		pl = deadzone(Vector2(Input.get_joy_axis(j, JOY_AXIS_LEFT_X), -Input.get_joy_axis(j, JOY_AXIS_LEFT_Y)))
		pr = deadzone(Vector2(Input.get_joy_axis(j, JOY_AXIS_RIGHT_X), -Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y)))
		var bl := Input.is_joy_button_pressed(j, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(j, JOY_AXIS_TRIGGER_LEFT) > 0.5
		var br := Input.is_joy_button_pressed(j, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(j, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		if bl and not pad_l:
			pedal_press("L")
		if not bl and pad_l:
			pedal_release("L")
		if br and not pad_r:
			pedal_press("R")
		if not br and pad_r:
			pedal_release("R")
		pad_l = bl
		pad_r = br
		var pa := Input.is_joy_button_pressed(j, JOY_BUTTON_A)
		if pa and not pad_a and not paused:
			kb_hop = true
		pad_a = pa
		var ps := Input.is_joy_button_pressed(j, JOY_BUTTON_START)
		if ps and not pad_start:
			toggle_menu()
		pad_start = ps
		var pk := Input.is_joy_button_pressed(j, JOY_BUTTON_BACK)
		if pk and not pad_back and not paused:
			respawn(true)
		pad_back = pk
		pxh = Input.is_joy_button_pressed(j, JOY_BUTTON_X)
		pbh = Input.is_joy_button_pressed(j, JOY_BUTTON_B)
		pyh = Input.is_joy_button_pressed(j, JOY_BUTTON_Y)
	hand_l_off = is_down("square") or kzv or pxh
	hand_r_off = is_down("circle") or kxv or pbh
	brake_held = is_down("triangle") or kcv or pyh
	var sl: Vector2 = stick_vec["stick"]
	var sr: Vector2 = stick_vec["stick2"]
	in_lx = clampf(kb_lx + sl.x + dpad_dig.x + pl.x, -1.0, 1.0)
	in_ly = clampf(kb_ly + sl.y + dpad_dig.y + pl.y, -1.0, 1.0) * (-1.0 if invert_y else 1.0)
	in_rx = clampf(kb_rx + sr.x + pr.x, -1.0, 1.0)
	in_ry = clampf(kb_ry + sr.y + pr.y, -1.0, 1.0)


# =====================================================================
# МЕНЮ, РЕДАКТОР РАСКЛАДКИ, ОТРИСОВКА
# =====================================================================
func make_check(text: String, state: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = state
	c.add_theme_font_size_override("font_size", 16)
	c.toggled.connect(cb)
	return c

func make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b

func make_slider(text: String, mn: float, mx: float, val: float, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 16)
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.05
	sl.value = val
	sl.custom_minimum_size = Vector2(260, 28)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(cb)
	h.add_child(sl)
	return h

func _on_bal(v: bool) -> void:
	assist_bal = v
	save_settings()

func _on_land(v: bool) -> void:
	assist_land = v
	save_settings()

func _on_inv(v: bool) -> void:
	invert_y = v
	save_settings()

func _on_labels(v: bool) -> void:
	show_labels = v
	save_settings()

func _on_opacity(v: float) -> void:
	ui_opacity = v
	save_settings()

func _on_uiscale(v: float) -> void:
	ui_scale = v
	save_settings()

func _on_minus() -> void:
	edit_scale(0.9)

func _on_plus() -> void:
	edit_scale(1.1)

func _on_reset_layout() -> void:
	reset_layout()

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	hud.draw.connect(_on_hud_draw)
	# --- меню (Start) ---
	menu_panel = PanelContainer.new()
	menu_panel.visible = false
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui.add_child(menu_panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(640, 460)
	menu_panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(610, 0)
	sc.add_child(vb)
	var title := Label.new()
	title.text = "МЕНЮ"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)
	vb.add_child(make_button("Продолжить", toggle_menu))
	vb.add_child(make_button("Расположение кнопок (перетаскивание)", enter_edit))
	vb.add_child(make_button("Сбросить расположение кнопок", _on_reset_layout))
	vb.add_child(make_slider("Прозрачность кнопок", 0.15, 1.0, ui_opacity, _on_opacity))
	vb.add_child(make_slider("Общий размер кнопок", 0.6, 1.6, ui_scale, _on_uiscale))
	vb.add_child(make_check("Подписи под кнопками", show_labels, _on_labels))
	vb.add_child(make_check("Помощь баланса мануала", assist_bal, _on_bal))
	vb.add_child(make_check("Помощь приземления", assist_land, _on_land))
	vb.add_child(make_check("Инвертировать вертикаль левого стика", invert_y, _on_inv))
	var lab := Label.new()
	lab.text = HELP_TEXT
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(600, 0)
	lab.add_theme_font_size_override("font_size", 14)
	vb.add_child(lab)
	# --- панель редактора раскладки ---
	edit_bar = PanelContainer.new()
	edit_bar.visible = false
	edit_bar.anchor_left = 0.5
	edit_bar.anchor_right = 0.5
	edit_bar.offset_top = 8.0
	edit_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui.add_child(edit_bar)
	var hb := HBoxContainer.new()
	edit_bar.add_child(hb)
	edit_lbl = Label.new()
	edit_lbl.custom_minimum_size = Vector2(300, 0)
	edit_lbl.add_theme_font_size_override("font_size", 15)
	hb.add_child(edit_lbl)
	hb.add_child(make_button("−", _on_minus))
	hb.add_child(make_button("+", _on_plus))
	hb.add_child(make_button("Сброс", _on_reset_layout))
	hb.add_child(make_button("Готово", exit_edit))

func draw_ctrl(key: String, f: Font) -> void:
	var c: Dictionary = ctrls[key]
	var kind: String = c["kind"]
	var down: bool = c["down"]
	var cc := ctrl_center(key)
	var A := maxf(ui_opacity, 0.5) if edit_mode else ui_opacity
	var fill := Color(1, 1, 1, (0.5 if down else 0.2) * A)
	var line := Color(1, 1, 1, 0.85 * A)
	var ta := minf(1.0, A + 0.3)
	var cap: String = c["caption"]
	var cap_y := cc.y
	if kind == "rect":
		var hs := ctrl_halfsize(key)
		var rc := Rect2(cc - hs, hs * 2.0)
		if key == "L" or key == "R":
			var want := (pedal_last == 1) if key == "L" else (pedal_last == -1)
			if hop_armed:
				line = Color(1.0, 0.65, 0.15, 0.95)
			elif want and not down:
				line = Color(0.6, 0.95, 0.5, 0.95)
		hud.draw_rect(rc, fill, true)
		hud.draw_rect(rc, line, false, 2.5)
		var txt := key if (key == "L" or key == "R") else key.to_upper()
		var fs := int(hs.y * 0.85)
		hud.draw_string(f, Vector2(cc.x - hs.x, cc.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, hs.x * 2.0, fs, Color(1, 1, 1, ta))
		cap_y = cc.y + hs.y + 13.0
	elif kind == "circle":
		var r := ctrl_radius(key)
		hud.draw_circle(cc, r, fill)
		hud.draw_arc(cc, r, 0.0, TAU, 40, line, 2.5)
		var s := r * 0.42
		if key == "cross":
			var col := Color(0.45, 0.65, 1.0, ta)
			hud.draw_line(cc + Vector2(-s, -s), cc + Vector2(s, s), col, 4.0)
			hud.draw_line(cc + Vector2(-s, s), cc + Vector2(s, -s), col, 4.0)
		elif key == "circle":
			hud.draw_arc(cc, s * 1.05, 0.0, TAU, 28, Color(1.0, 0.4, 0.4, ta), 4.0)
		elif key == "square":
			hud.draw_rect(Rect2(cc - Vector2(s, s) * 0.95, Vector2(s, s) * 1.9), Color(1.0, 0.55, 0.85, ta), false, 4.0)
		elif key == "triangle":
			var pts := PackedVector2Array([cc + Vector2(0, -s * 1.1), cc + Vector2(s * 1.0, s * 0.8), cc + Vector2(-s * 1.0, s * 0.8), cc + Vector2(0, -s * 1.1)])
			hud.draw_polyline(pts, Color(0.5, 0.95, 0.55, ta), 4.0)
		cap_y = cc.y + r + 13.0
	elif kind == "dpad":
		var r := ctrl_radius(key)
		var a := r * 0.36
		var plus := PackedVector2Array([
			cc + Vector2(-a, -r), cc + Vector2(a, -r), cc + Vector2(a, -a), cc + Vector2(r, -a),
			cc + Vector2(r, a), cc + Vector2(a, a), cc + Vector2(a, r), cc + Vector2(-a, r),
			cc + Vector2(-a, a), cc + Vector2(-r, a), cc + Vector2(-r, -a), cc + Vector2(-a, -a)])
		hud.draw_colored_polygon(plus, Color(1, 1, 1, 0.2 * A))
		var outline := plus.duplicate()
		outline.append(plus[0])
		hud.draw_polyline(outline, line, 2.5)
		var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
		for di in range(4):
			var dv: Vector2 = dirs[di]
			var pv := Vector2(-dv.y, dv.x)
			var on := (dpad_dir.x != 0.0 and dv.x == dpad_dir.x) or (dpad_dir.y != 0.0 and dv.y == -dpad_dir.y)
			var ac := Color(1, 1, 1, (0.95 if on else 0.55) * ta)
			hud.draw_colored_polygon(PackedVector2Array([cc + dv * r * 0.84, cc + dv * r * 0.56 + pv * a * 0.6, cc + dv * r * 0.56 - pv * a * 0.6]), ac)
		cap_y = cc.y + r + 13.0
	elif kind == "stick":
		var r := ctrl_radius(key)
		hud.draw_circle(cc, r, Color(1, 1, 1, 0.1 * A))
		hud.draw_arc(cc, r, 0.0, TAU, 48, line, 2.5)
		var off: Vector2 = c["off"]
		hud.draw_circle(cc + off, r * 0.47, Color(1, 1, 1, (0.55 if down else 0.3) * A))
		hud.draw_arc(cc + off, r * 0.47, 0.0, TAU, 28, line, 2.0)
		cap_y = cc.y + r + 13.0
	if (show_labels or edit_mode) and cap != "":
		hud.draw_string(f, Vector2(cc.x - 70, cap_y), cap, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(1, 1, 1, 0.75 * ta))
	if edit_mode and edit_sel == key:
		var yel := Color(1.0, 0.9, 0.3, 0.95)
		if kind == "rect":
			var hs2 := ctrl_halfsize(key)
			hud.draw_rect(Rect2(cc - hs2, hs2 * 2.0).grow(6.0), yel, false, 3.0)
		else:
			var r2 := ctrl_radius(key)
			hud.draw_arc(cc, r2 + 7.0, 0.0, TAU, 48, yel, 3.0)

func _on_hud_draw() -> void:
	var s := vp_size()
	var f := ThemeDB.fallback_font
	for key in ctrls:
		draw_ctrl(key, f)
	# табло
	var iy := 72.0
	hud.draw_rect(Rect2(10, iy, 250, 78), Color(0.04, 0.07, 0.1, 0.6), true)
	hud.draw_string(f, Vector2(20, iy + 22), "BMX STREET  прототип 0.7", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var speed := absf(spd) if mode == GROUND else Vector2(wvx, wvz).length()
	var label := "Земля"
	if mode == BAIL:
		label = "Бейл"
	elif mode == AIR:
		label = "Воздух"
	elif th > 0.05:
		label = "Мануал"
	elif th < -0.05:
		label = "Ноуз-мануал"
	elif spd < -0.5:
		label = "Фэйки"
	hud.draw_string(f, Vector2(20, iy + 44), "%d км/ч · %s" % [int(roundf(speed * 3.6)), label], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.92, 1))
	hud.draw_string(f, Vector2(20, iy + 66), "Очки: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.5))
	# комбо
	if not combo_items.is_empty():
		var ct := " + ".join(PackedStringArray(combo_items))
		if combo_items.size() > 1:
			ct += "  ×%.2f" % combo_mult()
		hud.draw_string_outline(f, Vector2(0, 118), ct, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, 5, Color(0, 0, 0, 0.8))
		hud.draw_string(f, Vector2(0, 118), ct, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color.WHITE)
		var pt := str(int(roundf(combo_pts * combo_mult())))
		hud.draw_string_outline(f, Vector2(0, 150), pt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, 6, Color(0, 0, 0, 0.8))
		hud.draw_string(f, Vector2(0, 150), pt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(1, 0.9, 0.4))
	# всплывающая надпись
	if toast_t > 0.0:
		var tc := Color(0.55, 1, 0.55) if toast_good else Color(1, 0.45, 0.4)
		tc.a = clampf(toast_t / 0.4, 0.0, 1.0)
		var oc := Color(0, 0, 0, tc.a * 0.8)
		hud.draw_string_outline(f, Vector2(0, s.y * 0.32), toast_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, 7, oc)
		hud.draw_string(f, Vector2(0, s.y * 0.32), toast_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, tc)
	if hint_t > 0.0 and not menu_open and not edit_mode:
		hud.draw_string_outline(f, Vector2(0, s.y - 64), "Start — меню, настройки и расположение кнопок", HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, 4, Color(0, 0, 0, 0.7))
		hud.draw_string(f, Vector2(0, s.y - 64), "Start — меню, настройки и расположение кнопок", HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color(1, 1, 1, 0.85))
	# шкалы баланса и толчка ногами (рядом с райдером)
	var bar_h := 154.0
	var bx := s.x * 0.5 + 190.0
	var by := s.y * 0.5 - 80.0
	if mode == GROUND and absf(th) > 0.03:
		hud.draw_rect(Rect2(bx, by, 16, bar_h), Color(0.04, 0.07, 0.1, 0.55), true)
		var band_b := (0.55 - 0.14) / 1.3 * bar_h
		var band_h := 0.28 / 1.3 * bar_h
		hud.draw_rect(Rect2(bx, by + bar_h - band_b - band_h, 16, band_h), Color(0.4, 0.9, 0.4, 0.5), true)
		var mk := clampf(absf(th) / 1.3, 0.0, 1.0) * bar_h
		hud.draw_rect(Rect2(bx - 3, by + bar_h - mk - 3, 22, 6), Color.WHITE, true)
	if hop_armed and mode == GROUND:
		var pxb := bx - 30.0
		hud.draw_rect(Rect2(pxb, by, 16, bar_h), Color(0.04, 0.07, 0.1, 0.55), true)
		var fh := clampf(hop_push / PUSH_MAX, 0.0, 1.0) * bar_h
		hud.draw_rect(Rect2(pxb, by + bar_h - fh, 16, fh), Color(1.0, 0.65, 0.15, 0.9), true)
		hud.draw_string(f, Vector2(pxb - 14, by + bar_h + 16), "толчок", HORIZONTAL_ALIGNMENT_CENTER, 44, 12, Color(1, 0.85, 0.5))


# =====================================================================
# ЗАПУСК И ГЛАВНЫЙ ЦИКЛ
# =====================================================================
func _ready() -> void:
	load_settings()
	load_layout()
	build_environment()
	build_ground()
	build_park()
	build_bike()
	build_ui()
	respawn(true)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	poll_input(dt)
	if not (menu_open or edit_mode):
		acc_t += dt
		var n := 0
		while acc_t >= FIXED and n < 12:
			physics(FIXED)
			acc_t -= FIXED
			n += 1
		if n >= 12:
			acc_t = 0.0
		update_gameplay(dt)
	pose_visuals(dt)
	update_camera(dt)
	if toast_t > 0.0:
		toast_t -= dt
	if hint_t > 0.0:
		hint_t -= dt
	if edit_mode:
		var nm := "Перетаскивайте кнопки пальцем"
		if edit_sel != "":
			nm = "Выбрано: " + String(KEY_RU[edit_sel])
		edit_lbl.text = nm
	hud.queue_redraw()
