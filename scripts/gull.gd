class_name Gull
extends Node3D
## The seagull, built in code (the same design as the browser version): a white body with a grey
## mantle, a white head, a yellow beak with a red spot, a white fan tail and tucked orange legs. The
## wings are tapered two-layer panels (grey on top, white underneath) with black tips and a white
## spot, so the gull reads from behind and from below. The wings flap from the shoulder and fold at
## the wrist. Faces +z (the direction of flight). Each part is one vertex-coloured mesh.

signal flapped

const GREY := "#9AA6B2"
const WHITE := "#F8FAFC"
const BLACK := "#111827"
## Outlines relative to the joint (shoulder for the inner wing, wrist for the outer one): [x out, z forward].
const WING_INNER := [[0.0, 0.52], [1.5, 0.44], [1.5, -0.42], [0.8, -0.62], [0.0, -0.78]]
const WING_OUTER := [[0.0, 0.44], [1.0, 0.2], [1.0, -0.38], [0.0, -0.42]]
const WING_TIP := [[1.0, 0.2], [1.62, -0.12], [1.45, -0.3], [1.0, -0.38]]
const TAIL := [[-0.28, -0.75], [0.28, -0.75], [0.48, -1.75], [0.0, -1.62], [-0.48, -1.75]]
const SHOULDER := Vector3(0.45, 0.15, 0.25)
const WRIST_X := 1.5
## The wings are pitched leading-edge-up, so the camera sees the grey back and wing tops instead of thin
## edges. The body is pitched a little nose-up, DIHEDRAL lifts the wings into a slight V and AMP is the
## flap amplitude at the shoulder (radians).
const WING_PITCH := -0.6
const BODY_PITCH := -0.15
const DIHEDRAL := 0.12
const AMP := 0.55

static var _shared: Dictionary = {}

var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _wrist_l: Node3D
var _wrist_r: Node3D
var _trail: CPUParticles3D
var _phase: float = 0.0
var _cycle: int = 0
var _clock: float = 0.0


func _ready() -> void:
	var mat := material()
	_body = Node3D.new()
	add_child(_body)
	_part(_body, body_mesh(), mat)
	_wing_r = Node3D.new()
	_wing_r.position = SHOULDER
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)
	for w in [_wing_r, _wing_l]:
		w.rotation.x = WING_PITCH
		_body.add_child(w)
	_part(_wing_r, inner_wing_mesh(1.0), mat)
	_part(_wing_l, inner_wing_mesh(-1.0), mat)
	_wrist_r = Node3D.new()
	_wrist_r.position = Vector3(WRIST_X, 0.0, 0.0)
	_wing_r.add_child(_wrist_r)
	_wrist_l = Node3D.new()
	_wrist_l.position = Vector3(-WRIST_X, 0.0, 0.0)
	_wing_l.add_child(_wrist_l)
	_part(_wrist_r, outer_wing_mesh(1.0), mat)
	_part(_wrist_l, outer_wing_mesh(-1.0), mat)
	_trail = Fx.trail(self, Color(1.0, 1.0, 1.0, 0.7), 4)


func _part(parent: Node3D, mesh: Mesh, mat: Material) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)


## Wing and body motion. diving folds the wings faster and tilts the nose down.
func animate(dt: float, diving: bool, speed_ratio: float, bank: float, pitch: float) -> void:
	_clock += dt
	_phase += dt * (4.5 if diving else 10.0) * (0.85 + 0.15 * speed_ratio)
	var amp := 0.15 if diving else AMP + 0.12 * sin(_clock * 0.9)
	var flap := amp * sin(_phase) + DIHEDRAL
	_wing_r.rotation.z = flap
	_wing_l.rotation.z = -flap
	# Wrist: the outer wing folds on the upstroke and stretches on the downstroke.
	var wrist := 0.45 * flap - (0.35 if diving else 0.12)
	_wrist_r.rotation.z = wrist
	_wrist_l.rotation.z = -wrist
	_body.rotation = Vector3(pitch + BODY_PITCH, 0.0, -bank * 0.8)
	var cycle := floori(_phase / TAU)
	if cycle != _cycle:
		_cycle = cycle
		if not diving:
			flapped.emit()


func set_trail(on: bool) -> void:
	_trail.emitting = on


# ---------- shared meshes (also used by the rival flock) ----------

## The gull material: vertex colours (sRGB) and a faint glow that keeps the white gull readable when it
## is backlit and at night.
static func material() -> StandardMaterial3D:
	if not _shared.has("mat"):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = Color.html("#2B2F36")
		_shared["mat"] = mat
	return _shared["mat"]


static func body_mesh() -> ArrayMesh:
	if not _shared.has("body"):
		var st := _begin()
		_body_parts(st)
		_shared["body"] = st.commit()
	return _shared["body"]


static func inner_wing_mesh(side: float) -> ArrayMesh:
	var key := "inner%d" % int(side)
	if not _shared.has(key):
		var st := _begin()
		_inner_wing(st, side, Vector3.ZERO)
		_shared[key] = st.commit()
	return _shared[key]


static func outer_wing_mesh(side: float) -> ArrayMesh:
	var key := "outer%d" % int(side)
	if not _shared.has(key):
		var st := _begin()
		_outer_wing(st, side, Vector3.ZERO)
		_shared[key] = st.commit()
	return _shared[key]


## The rival flock bird: the same gull with the wings spread flat, as one mesh (the flock shader flaps it).
static func rival_mesh() -> ArrayMesh:
	if not _shared.has("rival"):
		var st := _begin()
		_body_parts(st)
		for side: float in [1.0, -1.0]:
			var shoulder := Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)
			_inner_wing(st, side, shoulder)
			_outer_wing(st, side, shoulder + Vector3(WRIST_X * side, 0.0, 0.0))
		_shared["rival"] = st.commit()
	return _shared["rival"]


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _body_parts(st: SurfaceTool) -> void:
	var white := Color.html(WHITE)
	MeshKit.add_primitive(st, MeshKit.sphere(0.62, 14, 10), Transform3D(Basis.from_scale(Vector3(0.9, 0.78, 1.55)), Vector3.ZERO), white)
	MeshKit.add_primitive(st, MeshKit.sphere(0.6, 12, 8), Transform3D(Basis.from_scale(Vector3(0.82, 0.45, 1.2)), Vector3(0.0, 0.2, -0.15)), Color.html(GREY))
	MeshKit.add_primitive(st, MeshKit.sphere(0.42, 12, 8), Transform3D(Basis(), Vector3(0.0, 0.34, 1.0)), white)
	var beak := MeshKit.cylinder(0.0, 0.11, 0.55, 6)
	# The cone's tip points along +y; turned about x it points forward (+z).
	MeshKit.add_primitive(st, beak, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.28, 1.6)), Color.html("#FACC15"))
	MeshKit.add_primitive(st, MeshKit.sphere(0.05, 5, 4), Transform3D(Basis(), Vector3(0.0, 0.21, 1.62)), Color.html("#DC2626"))
	for sx: float in [1.0, -1.0]:
		MeshKit.add_primitive(st, MeshKit.sphere(0.065, 6, 4), Transform3D(Basis(), Vector3(0.22 * sx, 0.44, 1.18)), Color.html(BLACK))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.2 * sx, -0.45, -0.55)), Vector3(0.07, 0.07, 0.35), Color.html("#F97316"))
	_panel2(st, TAIL, 1.0, white, Color.html("#E2E8F0"), Vector3(0.0, 0.08, 0.0))


static func _inner_wing(st: SurfaceTool, side: float, at: Vector3) -> void:
	_panel2(st, WING_INNER, side, Color.html(GREY), Color.html(WHITE), at)


static func _outer_wing(st: SurfaceTool, side: float, at: Vector3) -> void:
	_panel2(st, WING_OUTER, side, Color.html(GREY), Color.html(WHITE), at)
	_panel2(st, WING_TIP, side, Color.html(BLACK), Color.html(BLACK), at)
	MeshKit.add_box(st, Transform3D(Basis(), at + Vector3(1.32 * side, 0.055, -0.12)), Vector3(0.14, 0.02, 0.12), Color.html(WHITE))


## Two 0.05-thick layers of one outline: the top colour above y = 0, the bottom colour below it.
static func _panel2(st: SurfaceTool, pts: Array, side: float, top: Color, bottom: Color, at: Vector3) -> void:
	_prism(st, pts, side, at + Vector3(0.0, -0.05, 0.0), 0.05, bottom)
	_prism(st, pts, side, at, 0.05, top)


## A flat prism from an outline in the x/z plane (side mirrors x), thick tall, bottom at at.y.
static func _prism(st: SurfaceTool, pts: Array, side: float, at: Vector3, thick: float, color: Color) -> void:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p[0] * side, p[1]))
	var tris := Geometry2D.triangulate_polygon(poly)
	var lo := func(v: Vector2) -> Vector3: return at + Vector3(v.x, 0.0, v.y)
	var hi := func(v: Vector2) -> Vector3: return at + Vector3(v.x, thick, v.y)
	for i in range(0, tris.size(), 3):
		var a := poly[tris[i]]
		var b := poly[tris[i + 1]]
		var c := poly[tris[i + 2]]
		_tri(st, hi.call(a), hi.call(b), hi.call(c), Vector3.UP, color)
		_tri(st, lo.call(a), lo.call(b), lo.call(c), Vector3.DOWN, color)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var edge := b - a
		var normal := Vector3(edge.y, 0.0, -edge.x).normalized()
		# Outward: away from the outline's centre.
		var centre := Vector2.ZERO
		for q in poly:
			centre += q / poly.size()
		if Vector2(normal.x, normal.z).dot((a + b) * 0.5 - centre) < 0.0:
			normal = -normal
		MeshKit.add_quad(st, Transform3D(), color, lo.call(a), lo.call(b), hi.call(b), hi.call(a), normal)


## One triangle wound so that its front face looks along normal (Godot: clockwise is front).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	var pts := [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for p in pts:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(p)
